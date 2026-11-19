import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:scaneliq/features/subscription/data/subscription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePlayBillingAdapter implements PlayBillingAdapter {
  final StreamController<List<PurchaseDetails>> controller =
      StreamController<List<PurchaseDetails>>.broadcast();
  bool available = true;
  bool shouldReturnProducts = true;
  bool restoreCalled = false;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    if (!shouldReturnProducts) {
      return ProductDetailsResponse(
        productDetails: const [],
        notFoundIDs: identifiers.toList(),
      );
    }
    return ProductDetailsResponse(
      productDetails: [
        ProductDetails(
          id: SubscriptionService.skuProMonthly,
          title: 'Scaneliq Pro',
          description: 'Unlimited OCR and PDF workflows',
          price: '\$4.99',
          rawPrice: 4.99,
          currencyCode: 'USD',
        ),
      ],
      notFoundIDs: const [SubscriptionService.skuUltraMonthly],
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    controller.add([
      PurchaseDetails(
        productID: purchaseParam.productDetails.id,
        verificationData: PurchaseVerificationData(
          localVerificationData: 'local',
          serverVerificationData: 'server',
          source: 'google_play',
        ),
        transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
        status: PurchaseStatus.purchased,
      )..pendingCompletePurchase = true,
    ]);
    return true;
  }

  @override
  Future<void> restorePurchases() async {
    restoreCalled = true;
    controller.add([
      PurchaseDetails(
        productID: SubscriptionService.skuUltraMonthly,
        verificationData: PurchaseVerificationData(
          localVerificationData: 'local',
          serverVerificationData: 'server',
          source: 'google_play',
        ),
        transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
        status: PurchaseStatus.restored,
      )..pendingCompletePurchase = false,
    ]);
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  Future<void> dispose() => controller.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Stage 10: SubscriptionService, Quotas & Play Billing', () {
    test('Tracks Free daily quotas, blocks once exhausted, resets on new day, and unlocks on Pro', () async {
      final prefs = await SharedPreferences.getInstance();
      final subs = SubscriptionService.instance;
      await subs.configureForTesting(prefs: prefs);
      await subs.init();

      final day1 = DateTime(2026, 11, 19, 10);
      final limit =
          SubscriptionService.freeDailyLimits[QuotaFeature.objectCountCam]!;
      expect(limit, 20);

      for (int i = 0; i < limit; i++) {
        final res = await subs.consumeQuota(
          QuotaFeature.objectCountCam,
          now: day1,
        );
        expect(res.allowed, isTrue);
        expect(res.usedToday, i + 1);
      }

      final blocked = await subs.consumeQuota(
        QuotaFeature.objectCountCam,
        now: day1,
      );
      expect(blocked.allowed, isFalse);
      expect(blocked.remaining, 0);

      // Day 2 resets counters automatically
      final day2 = DateTime(2026, 11, 20, 8);
      final nextDayRes = await subs.consumeQuota(
        QuotaFeature.objectCountCam,
        now: day2,
      );
      expect(nextDayRes.allowed, isTrue);
      expect(nextDayRes.usedToday, 1);

      // Pro tier grants unlimited (-1) access
      await subs.setTierForTesting(SubscriptionTier.pro);
      final proRes = await subs.checkQuota(
        QuotaFeature.objectCountCam,
        now: day1,
      );
      expect(proRes.allowed, isTrue);
      expect(proRes.dailyLimit, -1);
    });

    test('Handles missing Play Console SKUs honestly without fabricating purchases', () async {
      final prefs = await SharedPreferences.getInstance();
      final adapter = _FakePlayBillingAdapter()..shouldReturnProducts = false;
      final subs = SubscriptionService.instance;
      await subs.configureForTesting(billingAdapter: adapter, prefs: prefs);

      final initiated = await subs.purchaseSubscription(SubscriptionTier.pro);
      expect(initiated, isFalse);
      expect(
        subs.billingStatus,
        StoreBillingStatus.storeUnavailableOrUnconfigured,
      );
      expect(subs.currentTier, SubscriptionTier.free);

      await adapter.dispose();
    });

    test('Processes Play Billing purchase & restore stream transitions into persisted tier', () async {
      final prefs = await SharedPreferences.getInstance();
      final adapter = _FakePlayBillingAdapter();
      final subs = SubscriptionService.instance;
      await subs.configureForTesting(billingAdapter: adapter, prefs: prefs);

      final initiated = await subs.purchaseSubscription(SubscriptionTier.pro);
      expect(initiated, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(subs.currentTier, SubscriptionTier.pro);
      expect(prefs.getString('sub_active_tier'), SubscriptionTier.pro.name);

      await subs.restorePurchases();
      await Future<void>.delayed(Duration.zero);
      expect(adapter.restoreCalled, isTrue);
      expect(subs.currentTier, SubscriptionTier.ultra);
      expect(subs.billingStatus, StoreBillingStatus.restored);

      await adapter.dispose();
    });
  });
}
