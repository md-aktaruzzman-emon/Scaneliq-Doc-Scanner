import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SubscriptionTier { free, pro, ultra }

enum StoreBillingStatus {
  idle,
  ready,
  purchasing,
  restored,
  storeUnavailableOrUnconfigured,
  cancelled,
  error,
}

enum QuotaFeature {
  ocrExtraction,
  aiSummary,
  offlineTranslation,
  batchPdfExport,
  objectCountCam,
}

class SubscriptionPlanSpec {
  final SubscriptionTier tier;
  final String title;
  final String priceLabel;
  final String productId;
  final String summary;
  final List<String> highlights;

  const SubscriptionPlanSpec({
    required this.tier,
    required this.title,
    required this.priceLabel,
    required this.productId,
    required this.summary,
    required this.highlights,
  });
}

class QuotaCheckResult {
  final bool allowed;
  final SubscriptionTier tier;
  final int usedToday;
  final int dailyLimit; // -1 means unlimited
  final String message;

  const QuotaCheckResult({
    required this.allowed,
    required this.tier,
    required this.usedToday,
    required this.dailyLimit,
    required this.message,
  });

  int get remaining =>
      dailyLimit < 0 ? -1 : (dailyLimit - usedToday).clamp(0, dailyLimit);
}

/// Abstract gateway wrapping `in_app_purchase` so tests can verify real
/// purchase/restore stream state transitions without Play Store console SKUs.
abstract class PlayBillingAdapter {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<bool> isAvailable();
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});
  Future<void> restorePurchases();
  Future<void> completePurchase(PurchaseDetails purchase);
}

class LivePlayBillingAdapter implements PlayBillingAdapter {
  final InAppPurchase _iap;
  LivePlayBillingAdapter([InAppPurchase? iap])
    : _iap = iap ?? InAppPurchase.instance;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) =>
      _iap.queryProductDetails(identifiers);

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      _iap.buyNonConsumable(purchaseParam: purchaseParam);

  @override
  Future<void> restorePurchases() => _iap.restorePurchases();

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _iap.completePurchase(purchase);
}

/// Subscription entitlement, daily quota metering, and Google Play Billing
/// manager (`in_app_purchase`). Never fabricates active Play Store receipts.
class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  static const String skuProMonthly = 'scaneliq_pro_monthly';
  static const String skuUltraMonthly = 'scaneliq_ultra_monthly';

  static const String _prefTier = 'sub_active_tier';
  static const String _prefQuotaDate = 'sub_quota_date_ymd';
  static const String _prefQuotaCounts = 'sub_quota_counts_json';

  static const List<SubscriptionPlanSpec> plans = [
    SubscriptionPlanSpec(
      tier: SubscriptionTier.free,
      title: 'Standard Free',
      priceLabel: '\$0 / forever',
      productId: 'free_tier',
      summary:
          'Full offline scanning, Bengali & English OCR, PDF tools & vault.',
      highlights: [
        'Local-first scanner & PDF creation (no watermarks)',
        'Daily metering on batch AI/CountCam operations',
        'Encrypted .scaneliq local & WebDAV backup',
      ],
    ),
    SubscriptionPlanSpec(
      tier: SubscriptionTier.pro,
      title: 'Scaneliq Pro',
      priceLabel: '\$4.99 / mo',
      productId: skuProMonthly,
      summary: 'Unlimited on-device OCR, batch PDF pipelines & CountCam.',
      highlights: [
        'Unlimited Bengali/Mixed OCR & searchable PDF layers',
        'Unlimited PDF Flatten & Scrub redaction & exports',
        'Unlimited CountCam object detection & CSV export',
      ],
    ),
    SubscriptionPlanSpec(
      tier: SubscriptionTier.ultra,
      title: 'Scaneliq Ultra',
      priceLabel: '\$9.99 / mo',
      productId: skuUltraMonthly,
      summary:
          'Priority multi-device encrypted sync & AI document intelligence.',
      highlights: [
        'Everything in Pro with unlimited AI Vault Q&A',
        'Multi-device encrypted sync scheduling & templates',
        'Priority support & commercial-ready productivity',
      ],
    ),
  ];

  static const Map<QuotaFeature, int> freeDailyLimits = {
    QuotaFeature.ocrExtraction: 40,
    QuotaFeature.aiSummary: 20,
    QuotaFeature.offlineTranslation: 30,
    QuotaFeature.batchPdfExport: 25,
    QuotaFeature.objectCountCam: 20,
  };

  PlayBillingAdapter? _billingAdapter;
  SharedPreferences? _prefsOverride;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  SubscriptionTier _tier = SubscriptionTier.free;
  StoreBillingStatus _billingStatus = StoreBillingStatus.idle;
  String? _lastBillingMessage;
  final Map<String, ProductDetails> _loadedProducts = {};

  SubscriptionTier get currentTier => _tier;
  StoreBillingStatus get billingStatus => _billingStatus;
  String? get lastBillingMessage => _lastBillingMessage;
  Map<String, ProductDetails> get loadedProducts =>
      Map.unmodifiable(_loadedProducts);

  @visibleForTesting
  Future<void> configureForTesting({
    PlayBillingAdapter? billingAdapter,
    SharedPreferences? prefs,
  }) async {
    await _purchaseSub?.cancel();
    _purchaseSub = null;
    _billingAdapter = billingAdapter;
    _prefsOverride = prefs;
    _loadedProducts.clear();
    _billingStatus = StoreBillingStatus.idle;
    _lastBillingMessage = null;
    _tier = SubscriptionTier.free;
  }

  Future<SharedPreferences> _getPrefs() async =>
      _prefsOverride ?? await SharedPreferences.getInstance();

  PlayBillingAdapter _adapter() => _billingAdapter ??= LivePlayBillingAdapter();

  Future<void> init() async {
    final prefs = await _getPrefs();
    final saved = prefs.getString(_prefTier);
    _tier = SubscriptionTier.values.firstWhere(
      (t) => t.name == saved,
      orElse: () => SubscriptionTier.free,
    );
    await _resetQuotaIfNewDay(prefs);
  }

  Future<void> connectPlayStoreBilling() async {
    await init();
    try {
      final adapter = _adapter();
      final available = await adapter.isAvailable();
      if (!available) {
        _billingStatus = StoreBillingStatus.storeUnavailableOrUnconfigured;
        _lastBillingMessage = 'Google Play Billing is unavailable on this device or store session.';
        return;
      }

      _purchaseSub ??= adapter.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (Object err) {
          _billingStatus = StoreBillingStatus.error;
          _lastBillingMessage = 'Billing stream error: $err';
        },
      );

      final response = await adapter.queryProductDetails({
        skuProMonthly,
        skuUltraMonthly,
      });
      _loadedProducts.clear();
      for (final prod in response.productDetails) {
        _loadedProducts[prod.id] = prod;
      }

      if (_loadedProducts.isEmpty) {
        _billingStatus = StoreBillingStatus.storeUnavailableOrUnconfigured;
        _lastBillingMessage =
            'Play Console SKUs ($skuProMonthly, $skuUltraMonthly) are not registered yet for com.scaneliq.scaneliq.';
      } else {
        _billingStatus = StoreBillingStatus.ready;
        _lastBillingMessage =
            'Play Store catalog connected (${_loadedProducts.length} plan(s)).';
      }
    } on MissingPluginException {
      _billingStatus = StoreBillingStatus.storeUnavailableOrUnconfigured;
      _lastBillingMessage =
          'Billing plugin unavailable in this runtime environment.';
    } on PlatformException catch (e) {
      _billingStatus = StoreBillingStatus.error;
      _lastBillingMessage = 'Store query failed: ${e.message ?? e.code}';
    }
  }

  Future<bool> purchaseSubscription(SubscriptionTier targetTier) async {
    if (targetTier == SubscriptionTier.free) return false;
    await connectPlayStoreBilling();

    final sku = targetTier == SubscriptionTier.ultra
        ? skuUltraMonthly
        : skuProMonthly;
    final product = _loadedProducts[sku];
    if (product == null) {
      _billingStatus = StoreBillingStatus.storeUnavailableOrUnconfigured;
      _lastBillingMessage =
          'Cannot start Play Billing checkout: product "$sku" is not configured in Google Play Console.';
      return false;
    }

    _billingStatus = StoreBillingStatus.purchasing;
    try {
      return await _adapter().buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } on PlatformException catch (e) {
      _billingStatus = StoreBillingStatus.error;
      _lastBillingMessage = 'Checkout error: ${e.message ?? e.code}';
      return false;
    }
  }

  Future<void> restorePurchases() async {
    await connectPlayStoreBilling();
    if (_billingStatus == StoreBillingStatus.storeUnavailableOrUnconfigured &&
        _billingAdapter == null) {
      return;
    }
    try {
      await _adapter().restorePurchases();
    } on MissingPluginException {
      _billingStatus = StoreBillingStatus.storeUnavailableOrUnconfigured;
      _lastBillingMessage = 'Restore unavailable without Google Play Store.';
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _billingStatus = StoreBillingStatus.purchasing;
          _lastBillingMessage = 'Purchase pending Play Store confirmation...';
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final tier = purchase.productID == skuUltraMonthly
              ? SubscriptionTier.ultra
              : SubscriptionTier.pro;
          await _persistTier(tier);
          _billingStatus = purchase.status == PurchaseStatus.restored
              ? StoreBillingStatus.restored
              : StoreBillingStatus.ready;
          _lastBillingMessage =
              '${tier.name.toUpperCase()} entitlement active.';
          break;
        case PurchaseStatus.canceled:
          _billingStatus = StoreBillingStatus.cancelled;
          _lastBillingMessage = 'Purchase cancelled by user.';
          break;
        case PurchaseStatus.error:
          _billingStatus = StoreBillingStatus.error;
          _lastBillingMessage =
              purchase.error?.message ?? 'Store purchase failed.';
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _adapter().completePurchase(purchase);
      }
    }
  }

  Future<void> _persistTier(SubscriptionTier tier) async {
    _tier = tier;
    final prefs = await _getPrefs();
    await prefs.setString(_prefTier, tier.name);
  }

  @visibleForTesting
  Future<void> setTierForTesting(SubscriptionTier tier) => _persistTier(tier);

  static String _todayKey(DateTime now) =>
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  Future<Map<String, int>> _resetQuotaIfNewDay(
    SharedPreferences prefs, {
    DateTime? now,
  }) async {
    final today = _todayKey(now ?? DateTime.now());
    final savedDate = prefs.getString(_prefQuotaDate);
    if (savedDate != today) {
      await prefs.setString(_prefQuotaDate, today);
      await prefs.setString(_prefQuotaCounts, '{}');
      return {};
    }
    final raw = prefs.getString(_prefQuotaCounts) ?? '{}';
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  int dailyLimitFor(QuotaFeature feature) {
    if (_tier == SubscriptionTier.pro || _tier == SubscriptionTier.ultra) {
      return -1;
    }
    return freeDailyLimits[feature] ?? 20;
  }

  Future<QuotaCheckResult> checkQuota(
    QuotaFeature feature, {
    DateTime? now,
  }) async {
    await init();
    final prefs = await _getPrefs();
    final counts = await _resetQuotaIfNewDay(prefs, now: now);
    final used = counts[feature.name] ?? 0;
    final limit = dailyLimitFor(feature);

    if (limit < 0) {
      return QuotaCheckResult(
        allowed: true,
        tier: _tier,
        usedToday: used,
        dailyLimit: -1,
        message: '${_tier.name.toUpperCase()} tier: unlimited access.',
      );
    }

    final allowed = used < limit;
    return QuotaCheckResult(
      allowed: allowed,
      tier: _tier,
      usedToday: used,
      dailyLimit: limit,
      message: allowed
          ? '${limit - used} of $limit daily uses remaining on Free plan.'
          : 'Daily Free quota reached ($limit/$limit). Upgrade to Scaneliq Pro for unlimited usage.',
    );
  }

  Future<QuotaCheckResult> consumeQuota(
    QuotaFeature feature, {
    DateTime? now,
  }) async {
    final status = await checkQuota(feature, now: now);
    if (!status.allowed) return status;

    final prefs = await _getPrefs();
    final counts = await _resetQuotaIfNewDay(prefs, now: now);
    final nextUsed = (counts[feature.name] ?? 0) + 1;
    counts[feature.name] = nextUsed;
    await prefs.setString(_prefQuotaCounts, jsonEncode(counts));

    return QuotaCheckResult(
      allowed: true,
      tier: _tier,
      usedToday: nextUsed,
      dailyLimit: status.dailyLimit,
      message: status.dailyLimit < 0
          ? '${_tier.name.toUpperCase()} tier: unlimited access.'
          : '${(status.dailyLimit - nextUsed).clamp(0, status.dailyLimit)} of ${status.dailyLimit} daily uses remaining.',
    );
  }
}
