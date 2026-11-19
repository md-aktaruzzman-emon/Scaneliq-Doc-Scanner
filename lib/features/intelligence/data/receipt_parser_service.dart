import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:scaneliq/features/ocr/data/ocr_service.dart';

class ReceiptItem {
  final String description;
  final double amount;
  final int quantity;
  final double? unitPrice;

  const ReceiptItem({
    required this.description,
    required this.amount,
    this.quantity = 1,
    this.unitPrice,
  });
}

class ParsedReceipt {
  final String documentKind; // 'Receipt' or 'Invoice'
  final String merchantName;
  final String date;
  final String dueDate;
  final String invoiceNumber;
  final String poNumber;
  final String vendorTaxId;
  final String currency;
  final double? subtotal;
  final double? tax;
  final double? discount;
  final double? tip;
  final double? total;
  final List<ReceiptItem> lineItems;
  final String rawText;

  const ParsedReceipt({
    this.documentKind = 'Receipt',
    this.merchantName = '',
    this.date = '',
    this.dueDate = '',
    this.invoiceNumber = '',
    this.poNumber = '',
    this.vendorTaxId = '',
    this.currency = '\$',
    this.subtotal,
    this.tax,
    this.discount,
    this.tip,
    this.total,
    this.lineItems = const [],
    this.rawText = '',
  });

  ParsedReceipt copyWith({
    String? documentKind,
    String? merchantName,
    String? date,
    String? dueDate,
    String? invoiceNumber,
    String? poNumber,
    String? vendorTaxId,
    String? currency,
    double? subtotal,
    double? tax,
    double? discount,
    double? tip,
    double? total,
    List<ReceiptItem>? lineItems,
    String? rawText,
  }) {
    return ParsedReceipt(
      documentKind: documentKind ?? this.documentKind,
      merchantName: merchantName ?? this.merchantName,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      poNumber: poNumber ?? this.poNumber,
      vendorTaxId: vendorTaxId ?? this.vendorTaxId,
      currency: currency ?? this.currency,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      discount: discount ?? this.discount,
      tip: tip ?? this.tip,
      total: total ?? this.total,
      lineItems: lineItems ?? this.lineItems,
      rawText: rawText ?? this.rawText,
    );
  }

  /// Validates if `subtotal + tax + tip - discount == total` within `0.05` tolerance.
  bool get isMathConsistent {
    if (total == null) return false;
    if (subtotal != null && tax != null) {
      final expected = subtotal! + tax! + (tip ?? 0.0) - (discount ?? 0.0);
      return (expected - total!).abs() <= 0.05;
    }
    return true;
  }

  /// Exports standardized accounting CSV preserving core receipt columns plus Invoice metadata.
  String toCsv() {
    final buffer = StringBuffer();
    buffer.writeln(
      'Merchant,Date,Subtotal,Tax,Tip,Total,Currency,Consistent,Discount,Kind,InvoiceNo,PONumber,TaxID,DueDate',
    );
    String clean(String s) => s.replaceAll(',', ' ').trim();
    buffer.writeln(
      '${clean(merchantName)},${clean(date)},${subtotal?.toStringAsFixed(2) ?? ''},${tax?.toStringAsFixed(2) ?? ''},${tip?.toStringAsFixed(2) ?? ''},${total?.toStringAsFixed(2) ?? ''},$currency,$isMathConsistent,${discount?.toStringAsFixed(2) ?? ''},${clean(documentKind)},${clean(invoiceNumber)},${clean(poNumber)},${clean(vendorTaxId)},${clean(dueDate)}',
    );
    if (lineItems.isNotEmpty) {
      buffer.writeln('\nItem,Quantity,UnitPrice,Amount');
      for (final item in lineItems) {
        buffer.writeln(
          '${clean(item.description)},${item.quantity},${item.unitPrice?.toStringAsFixed(2) ?? ''},${item.amount.toStringAsFixed(2)}',
        );
      }
    }
    return buffer.toString();
  }
}

/// Service providing Receipt & Invoice structured field extraction (English + বাংলা),
/// math verification, inline editing models, and CSV accounting export.
class ReceiptParserService {
  ReceiptParserService._();
  static final ReceiptParserService instance = ReceiptParserService._();

  static final RegExp _currencyRegex = RegExp(
    r'[\$€£৳₹]|(?:USD|EUR|GBP|BDT|CAD|AUD|TK\.?|টাকা)',
    caseSensitive: false,
  );

  static final RegExp _dateRegex = RegExp(
    r'\b(?:\d{4}[-/.]\d{1,2}[-/.]\d{1,2}|\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}|(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2},?\s+\d{4})\b',
    caseSensitive: false,
  );

  Future<ParsedReceipt> extractFromImage(
    File imageFile, {
    OcrScript script = OcrScript.mixedBengaliEnglish,
  }) async {
    final ocrText = await OcrService.instance.extractText(
      imageFile,
      script: script,
    );
    return parseText(ocrText);
  }

  ParsedReceipt parseText(String text) {
    if (text.trim().isEmpty) {
      return const ParsedReceipt();
    }

    // Normalize Bengali numerals (`০-৯` -> `0-9`) for reliable accounting math validation
    final normalizedText = OcrService.convertBanglaToAsciiDigits(text);
    final lines = normalizedText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final lowerFull = normalizedText.toLowerCase();
    final isInvoice =
        lowerFull.contains('invoice') ||
        lowerFull.contains('po #') ||
        lowerFull.contains('p.o.') ||
        lowerFull.contains('bill to') ||
        text.contains('ইনভয়েস');

    String foundMerchant = '';
    String foundDate = '';
    String foundDueDate = '';
    String foundInvoiceNo = '';
    String foundPoNo = '';
    String foundTaxId = '';
    String foundCurrency = '\$';
    double? foundSubtotal;
    double? foundTax;
    double? foundDiscount;
    double? foundTip;
    double? foundTotal;
    final List<ReceiptItem> foundItems = [];

    final currencyMatch = _currencyRegex.firstMatch(normalizedText);
    if (currencyMatch != null) {
      final token = currencyMatch.group(0)!;
      foundCurrency = (token == 'টাকা' || token.toUpperCase().startsWith('TK'))
          ? '৳'
          : token;
    }

    final invMatch = RegExp(
      r'(?:invoice|inv)\s*(?:no\.?|number|#|:)?\s*[:#\-]?\s*([A-Z0-9][A-Z0-9\-/]{2,})',
      caseSensitive: false,
    ).firstMatch(normalizedText);
    if (invMatch != null) {
      foundInvoiceNo = invMatch.group(1)!.trim();
    }

    final poMatch = RegExp(
      r'(?:p\.?o\.?|purchase\s+order)\s*(?:no\.?|number|#|:)?\s*[:#\-]?\s*([A-Z0-9][A-Z0-9\-/]{2,})',
      caseSensitive: false,
    ).firstMatch(normalizedText);
    if (poMatch != null) {
      foundPoNo = poMatch.group(1)!.trim();
    }

    final taxIdMatch = RegExp(
      r'(?:TIN|VAT\s*Reg|TAX\s*ID|BIN|EIN)\s*[:#\-]?\s*([A-Z0-9\-]{5,})',
      caseSensitive: false,
    ).firstMatch(normalizedText);
    if (taxIdMatch != null) {
      foundTaxId = taxIdMatch.group(1)!.trim();
    }

    // Separate Issue Date vs Due Date
    for (final line in lines) {
      final lower = line.toLowerCase();
      final dMatch = _dateRegex.firstMatch(line);
      if (dMatch == null) continue;
      if (lower.contains('due')) {
        foundDueDate = dMatch.group(0)!;
      } else if (foundDate.isEmpty) {
        foundDate = dMatch.group(0)!;
      }
    }

    // Merchant Detection: First clean header line
    for (int i = 0; i < lines.length && i < 4; i++) {
      final line = lines[i];
      if (!_dateRegex.hasMatch(line) &&
          !RegExp(r'\b\d+\.\d{2}\b').hasMatch(line) &&
          line.length > 2 &&
          !line.toLowerCase().contains('receipt') &&
          !line.toLowerCase().contains('invoice')) {
        foundMerchant = line;
        break;
      }
    }

    double? parseDecimalAmount(String str) {
      final matches = RegExp(r'\d+(?:,\d{3})*(?:\.\d{2})')
          .allMatches(str)
          .toList();
      if (matches.isEmpty) return null;
      final cleaned = matches.last.group(0)!.replaceAll(',', '');
      return double.tryParse(cleaned);
    }

    final List<double> allAmounts = [];

    for (final line in lines) {
      final lower = line.toLowerCase();
      final amt = parseDecimalAmount(line);
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
          lower.contains('hst') ||
          line.contains('ভ্যাট')) {
        if (amt != null && !lower.contains('id')) foundTax = amt;
      } else if (lower.contains('discount')) {
        if (amt != null) foundDiscount = amt;
      } else if (lower.contains('tip') || lower.contains('gratuity')) {
        if (amt != null) foundTip = amt;
      } else if (lower.contains('total') ||
          lower.contains('amount due') ||
          lower.contains('grand total') ||
          lower.contains('balance due') ||
          line.contains('মোট')) {
        if (amt != null && !lower.contains('subtotal')) {
          foundTotal = amt;
        }
      } else if (amt != null && amt > 0) {
        int qty = 1;
        double? unitPrice;
        final qtyMatch = RegExp(r'(\d+)\s*[xX×]\s*(\d+(?:\.\d{2})?)')
            .firstMatch(line);
        if (qtyMatch != null) {
          qty = int.tryParse(qtyMatch.group(1)!) ?? 1;
          unitPrice = double.tryParse(qtyMatch.group(2)!);
        }
        final desc = line
            .replaceAll(RegExp(r'\d+(?:,\d{3})*\.\d{2}'), '')
            .replaceAll(_currencyRegex, '')
            .trim();
        if (desc.isNotEmpty && desc.length > 2) {
          foundItems.add(
            ReceiptItem(
              description: desc,
              amount: amt,
              quantity: qty,
              unitPrice: unitPrice,
            ),
          );
        }
      }
    }

    if (foundTotal == null && allAmounts.isNotEmpty) {
      allAmounts.sort();
      foundTotal = allAmounts.last;
    }

    if (foundSubtotal == null && foundTotal != null && foundTax != null) {
      final diff =
          foundTotal - foundTax - (foundTip ?? 0) + (foundDiscount ?? 0);
      if (diff > 0) foundSubtotal = double.parse(diff.toStringAsFixed(2));
    }

    return ParsedReceipt(
      documentKind: isInvoice ? 'Invoice' : 'Receipt',
      merchantName: foundMerchant,
      date: foundDate,
      dueDate: foundDueDate,
      invoiceNumber: foundInvoiceNo,
      poNumber: foundPoNo,
      vendorTaxId: foundTaxId,
      currency: foundCurrency,
      subtotal: foundSubtotal,
      tax: foundTax,
      discount: foundDiscount,
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
