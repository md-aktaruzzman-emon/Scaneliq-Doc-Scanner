import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scaneliq/core/theme/app_theme.dart';
import 'package:scaneliq/features/intelligence/data/receipt_parser_service.dart';

class ReceiptDialog extends StatefulWidget {
  final File? initialImage;

  const ReceiptDialog({super.key, this.initialImage});

  static Future<void> show(BuildContext context, {File? imageFile}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReceiptDialog(initialImage: imageFile),
    );
  }

  @override
  State<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<ReceiptDialog> {
  bool _isProcessing = false;
  ParsedReceipt? _receipt;

  @override
  void initState() {
    super.initState();
    if (widget.initialImage != null) {
      _processImage(widget.initialImage!);
    }
  }

  Future<void> _pickImage() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (picked.isNotEmpty && picked.first.path != null) {
      _processImage(File(picked.first.path!));
    }
  }

  Future<void> _processImage(File file) async {
    setState(() => _isProcessing = true);
    try {
      final receipt = await ReceiptParserService.instance.extractFromImage(
        file,
      );
      setState(() {
        _receipt = receipt;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read receipt: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _exportCsv() async {
    if (_receipt == null) return;
    try {
      final file = await ReceiptParserService.instance.exportCsvFile(_receipt!);
      if (mounted) {
        SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'Receipt Expense Export: ${_receipt!.merchantName}',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.surface1Dark : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_rounded,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Receipt & Invoice Scanner',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(40.0),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Parsing receipt lines, totals & verifying math consistency...',
                  ),
                ],
              ),
            )
          else if (_receipt == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36.0),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_outlined,
                    size: 64,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Select a photo of a receipt or invoice to parse',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Pick Receipt Image'),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: ListView(
                children: [
                  // Merchant & Date Header Card
                  Card(
                    color: isDark
                        ? AppColors.surface2Dark
                        : const Color(0xFFF8FAFC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _receipt!.merchantName.isNotEmpty
                                      ? _receipt!.merchantName
                                      : 'Unknown Merchant',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _receipt!.isMathConsistent
                                      ? AppColors.success.withValues(
                                          alpha: 0.15,
                                        )
                                      : AppColors.warning.withValues(
                                          alpha: 0.15,
                                        ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _receipt!.isMathConsistent
                                          ? Icons.check_circle_rounded
                                          : Icons.warning_amber_rounded,
                                      size: 14,
                                      color: _receipt!.isMathConsistent
                                          ? AppColors.success
                                          : AppColors.warning,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _receipt!.isMathConsistent
                                          ? 'Math Verified'
                                          : 'Review Totals',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _receipt!.isMathConsistent
                                            ? AppColors.success
                                            : AppColors.warning,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_receipt!.date.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Date: ${_receipt!.date}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Financial Breakdown Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildAmountCard(
                          label: 'Subtotal',
                          amount: _receipt!.subtotal != null
                              ? '${_receipt!.currency} ${_receipt!.subtotal!.toStringAsFixed(2)}'
                              : '—',
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildAmountCard(
                          label: 'Tax',
                          amount: _receipt!.tax != null
                              ? '${_receipt!.currency} ${_receipt!.tax!.toStringAsFixed(2)}'
                              : '—',
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildAmountCard(
                          label: 'Grand Total',
                          amount: _receipt!.total != null
                              ? '${_receipt!.currency} ${_receipt!.total!.toStringAsFixed(2)}'
                              : '—',
                          isDark: isDark,
                          isHighlight: true,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Line Items section
                  if (_receipt!.lineItems.isNotEmpty) ...[
                    const Text(
                      'Detected Line Items',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ..._receipt!.lineItems.map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.description,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Text(
                              '${_receipt!.currency} ${item.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Pick Another'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _exportCsv,
                          icon: const Icon(Icons.table_chart_outlined),
                          label: const Text('Export Expense CSV'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAmountCard({
    required String label,
    required String amount,
    required bool isDark,
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: isHighlight
            ? AppColors.brandPrimary.withValues(alpha: 0.1)
            : (isDark ? AppColors.surface2Dark : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlight
              ? AppColors.brandPrimary.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isHighlight
                  ? AppColors.brandPrimary
                  : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isHighlight ? AppColors.brandPrimary : null,
            ),
          ),
        ],
      ),
    );
  }
}
