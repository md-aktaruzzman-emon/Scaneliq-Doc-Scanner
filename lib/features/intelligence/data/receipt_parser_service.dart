import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:scaneliq/features/ocr/data/ocr_service.dart';

class ReceiptItem {
  final String description;
  final double amount;
  final int quantity;

  const ReceiptItem({
    required this.description,
    required this.amount,
    this.quantity = 1,
  });
}

class ParsedReceipt {
  final String merchantName;
  final String date;
  final String currency;
  final double? subtotal;
  final double? tax;
  final double? tip;
  final double? total;
  final List<ReceiptItem> lineItems;
  final String rawText;

  const ParsedReceipt({
    this.merchantName = '',
    this.date = '',
    this.currency = '\$',
    this.subtotal,
    this.tax,
    this.tip,
    this.total,
    this.lineItems = const [],
    this.rawText = '',
  });

  /// Validates if subtotal + tax + tip equals total within 0.05 tolerance
  bool get isMathConsistent {
    if (total == null) return false;
    if (subtotal != null && tax != null) {
      final expected = subtotal! + tax! + (tip ?? 0.0);
      return (expected - total!).abs() <= 0.05;
    }
    return true; // Cannot disprove consistency
  }

  /// Exports as standardized CSV format for accounting / expense software
  String toCsv() {
    final buffer = StringBuffer();
    buffer.writeln(
      'Merchant,Date,Category,Subtotal,Tax,Tip,Total,Currency,Consistent',
    );
    final safeMerchant = merchantName.replaceAll(',', ' ');
    final safeDate = date.replaceAll(',', ' ');
    buffer.writeln(
      '$safeMerchant,$safeDate,Receipt,${subtotal?.toStringAsFixed(2) ?? ''},${tax?.toStringAsFixed(2) ?? ''},${tip?.toStringAsFixed(2) ?? ''},${total?.toStringAsFixed(2) ?? ''},$currency,$isMathConsistent',
    );
    if (lineItems.isNotEmpty) {
      buffer.writeln('\nItem,Quantity,Amount');
      for (final item in lineItems) {
        final safeDesc = item.description.replaceAll(',', ' ');
        buffer.writeln(
          '$safeDesc,${item.quantity},${item.amount.toStringAsFixed(2)}',
        );
      }
    }
    return buffer.toString();
  }
}

/// Service providing Receipt / Invoice data extraction, math verification, and CSV export (F-34).
class ReceiptParserService {
  ReceiptParserService._();
  static final ReceiptParserService instance = ReceiptParserService._();

  static final RegExp _currencyRegex = RegExp(
    r'[\$€£৳₹]|(?:USD|EUR|GBP|BDT|CAD|AUD)\b',
    caseSensitive: false,
  );

  static final RegExp _dateRegex = RegExp(
    r'\b(?:\d{4}[-/.]\d{1,2}[-/.]\d{1,2}|\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}|(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]* \d{1,2},? \d{4})\b',
    caseSensitive: false,
  );

  static final RegExp _amountRegex = RegExp(r'\b\d+[\.,]\d{2}\b');

  Future<ParsedReceipt> extractFromImage(File imageFile) async {
    final ocrText = await OcrService.instance.extractText(imageFile);
    return parseText(ocrText);
  }

  ParsedReceipt parseText(String text) {
    if (text.trim().isEmpty) {
      return const ParsedReceipt();
    }

    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String foundMerchant = '';
    String foundDate = '';
    String foundCurrency = '\$';
    double? foundSubtotal;
    double? foundTax;
    double? foundTip;
    double? foundTotal;
    final List<ReceiptItem> foundItems = [];

    // Currency Detection
    final currencyMatch = _currencyRegex.firstMatch(text);
    if (currencyMatch != null) {
      foundCurrency = currencyMatch.group(0)!;
    }

    // Date Detection
    final dateMatch = _dateRegex.firstMatch(text);
    if (dateMatch != null) {
      foundDate = dateMatch.group(0)!;
    }

    // Merchant Detection: First non-date, non-numeric line (usually top line of receipt)
    for (int i = 0; i < lines.length && i < 4; i++) {
      final line = lines[i];
      if (!_dateRegex.hasMatch(line) &&
          !_amountRegex.hasMatch(line) &&
          line.length > 2 &&
          !line.toLowerCase().contains('receipt') &&
          !line.toLowerCase().contains('invoice')) {
        foundMerchant = line;
        break;
      }
    }

    // Number parsing helper
    double? parseAmount(String str) {
      final match = _amountRegex.firstMatch(str);
      if (match == null) return null;
      final cleaned = match.group(0)!.replaceAll(',', '.');
      return double.tryParse(cleaned);
    }

    // Line scanning for Subtotal, Tax, Tip, Total and items
    final List<double> allAmounts = [];

    for (final line in lines) {
      final lower = line.toLowerCase();
      final amt = parseAmount(line);
      if (amt != null) {
        allAmounts.add(amt);
      }

      if (lower.contains('subtotal') ||
          lower.contains('sub total') ||
          lower.contains('sub-total')) {
        if (amt != null) foundSubtotal = amt;
      } else if (lower.contains('tax') ||
          lower.contains('vat') ||
          lower.contains('gst') ||
          lower.contains('hst')) {
        if (amt != null) foundTax = amt;
      } else if (lower.contains('tip') || lower.contains('gratuity')) {
        if (amt != null) foundTip = amt;
      } else if (lower.contains('total') ||
          lower.contains('amount due') ||
          lower.contains('grand total') ||
          lower.contains('balance due')) {
        if (amt != null && !lower.contains('subtotal')) {
          foundTotal = amt;
        }
      } else if (amt != null && amt > 0) {
        // Line Item candidate
        final desc = line
            .replaceAll(_amountRegex, '')
            .replaceAll(_currencyRegex, '')
            .trim();
        if (desc.isNotEmpty && desc.length > 2) {
          foundItems.add(ReceiptItem(description: desc, amount: amt));
        }
      }
    }

    // Fallback: If total was not explicitly found by label, the highest parsed amount is usually the total
    if (foundTotal == null && allAmounts.isNotEmpty) {
      allAmounts.sort();
      foundTotal = allAmounts.last;
    }

    // Subtotal fallback if missing
    if (foundSubtotal == null && foundTotal != null && foundTax != null) {
      final diff = foundTotal - foundTax - (foundTip ?? 0);
      if (diff > 0) foundSubtotal = double.parse(diff.toStringAsFixed(2));
    }

    return ParsedReceipt(
      merchantName: foundMerchant,
      date: foundDate,
      currency: foundCurrency,
      subtotal: foundSubtotal,
      tax: foundTax,
      tip: foundTip,
      total: foundTotal,
      lineItems: foundItems,
      rawText: text,
    );
  }

  Future<File> exportCsvFile(ParsedReceipt receipt, {String? fileName}) async {
    final dir = await getTemporaryDirectory();
    final safeName =
        (receipt.merchantName.isNotEmpty
                ? receipt.merchantName.replaceAll(RegExp(r'[^\w\s\-]'), '_')
                : 'Receipt_${DateTime.now().millisecondsSinceEpoch}')
            .replaceAll(' ', '_');
    final file = File('${dir.path}/${fileName ?? safeName}.csv');
    await file.writeAsString(receipt.toCsv());
    return file;
  }
}
