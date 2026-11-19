import 'package:flutter/material.dart';
import 'package:scaneliq/core/theme/scaneliq_radius.dart';
import 'package:scaneliq/core/theme/scaneliq_tokens.dart';
import 'package:scaneliq/core/widgets/scaneliq_content_widgets.dart';
import 'package:scaneliq/features/subscription/data/subscription_service.dart';

/// Concept A editorial plan management & Play Billing paywall sheet.
class SubscriptionSheet extends StatefulWidget {
  const SubscriptionSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SubscriptionSheet(),
    );
  }

  @override
  State<SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends State<SubscriptionSheet> {
  final SubscriptionService _subs = SubscriptionService.instance;
  bool _loading = true;
  bool _busyAction = false;
  final Map<QuotaFeature, QuotaCheckResult> _quotas = {};

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    setState(() => _loading = true);
    await _subs.connectPlayStoreBilling();
    for (final feature in QuotaFeature.values) {
      _quotas[feature] = await _subs.checkQuota(feature);
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _subscribe(SubscriptionTier tier) async {
    setState(() => _busyAction = true);
    await _subs.purchaseSubscription(tier);
    await _loadState();
    if (mounted) {
      setState(() => _busyAction = false);
      final msg = _subs.lastBillingMessage;
      if (msg != null && msg.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _restore() async {
    setState(() => _busyAction = true);
    await _subs.restorePurchases();
    await _loadState();
    if (mounted) {
      setState(() => _busyAction = false);
    }
  }

  String _featureLabel(QuotaFeature f) => switch (f) {
    QuotaFeature.ocrExtraction => 'OCR Recognition',
    QuotaFeature.aiSummary => 'AI Document Intelligence',
    QuotaFeature.offlineTranslation => 'Offline Translation',
    QuotaFeature.batchPdfExport => 'Batch PDF Exports',
    QuotaFeature.objectCountCam => 'CountCam Object AI',
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final currentTier = _subs.currentTier;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: ScaneliqRadius.modalSheetBorderRadius,
        border: Border.all(color: tokens.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Icon(Icons.workspace_premium_outlined, color: tokens.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scaneliq Plans & Quotas',
                        style: textTheme.titleLarge,
                      ),
                      Text(
                        'Active tier: ${currentTier.name.toUpperCase()}',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _busyAction ? null : _restore,
                  child: const Text('Restore'),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: tokens.hairline),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(36),
              child: CircularProgressIndicator(),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_subs.lastBillingMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: tokens.bg,
                          borderRadius: ScaneliqRadius.inputBorderRadius,
                          border: Border.all(color: tokens.hairline),
                        ),
                        child: Text(
                          _subs.lastBillingMessage!,
                          style: textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    const ScaneliqSectionHeader(title: 'Today’s Metering'),
                    const SizedBox(height: 8),
                    for (final entry in _quotas.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _featureLabel(entry.key),
                              style: textTheme.bodySmall,
                            ),
                            Text(
                              entry.value.dailyLimit < 0
                                  ? 'Unlimited'
                                  : '${entry.value.usedToday} / ${entry.value.dailyLimit}',
                              style: textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const ScaneliqSectionHeader(title: 'Available Tiers'),
                    const SizedBox(height: 10),
                    for (final plan in SubscriptionService.plans)
                      _buildPlanCard(
                        context,
                        plan: plan,
                        isActive: plan.tier == currentTier,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context, {
    required SubscriptionPlanSpec plan,
    required bool isActive,
  }) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final storeProduct = _subs.loadedProducts[plan.productId];
    final priceText = storeProduct?.price ?? plan.priceLabel;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive ? tokens.accentSoft : tokens.bg,
        borderRadius: ScaneliqRadius.buttonBorderRadius,
        border: Border.all(
          color: isActive ? tokens.accent : tokens.hairline,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(plan.title, style: textTheme.titleMedium)),
              ScaneliqStatusLabel(
                text: isActive ? 'ACTIVE' : priceText,
                tone: isActive
                    ? ScaneliqStatusTone.success
                    : ScaneliqStatusTone.accent,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(plan.summary, style: textTheme.bodySmall),
          const SizedBox(height: 8),
          for (final item in plan.highlights)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  Icon(Icons.check_rounded, size: 14, color: tokens.accent),
                  const SizedBox(width: 6),
                  Expanded(child: Text(item, style: textTheme.bodySmall)),
                ],
              ),
            ),
          if (!isActive && plan.tier != SubscriptionTier.free) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busyAction ? null : () => _subscribe(plan.tier),
                child: Text('Subscribe · $priceText'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
