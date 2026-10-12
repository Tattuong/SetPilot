import 'package:flutter_test/flutter_test.dart';
import 'package:setpilot/core/constants/iap_constants.dart';
import 'package:setpilot/core/services/iap_config_service.dart';
import 'package:setpilot/models/shop_item.dart';

void main() {
  test('SetPilot IAP ids and N316 endpoint', () {
    expect(IapConstants.productPrefix, 'sp');
    expect(IapConstants.remoteConfigUrl,
        'https://api2.blwsmartware.net/N316.json');
    expect(IapConstants.coinPackIds.first, 'sp_pack_1');
    expect(IapConstants.coinPackIds.last, 'sp_pack_10');
    expect(IapConstants.coinPackIds, hasLength(10));
    expect(IapConstants.removeAdsProductId, 'sp_remove_ads');
    expect(IapConstants.proProductId, 'sp_pro');
    expect(IapConstants.allProductIds,
        containsAll([...IapConstants.coinPackIds, 'sp_remove_ads', 'sp_pro']));
    expect(IapConstants.coinsForProduct('sp_pack_5'), 500);
    expect(IapConstants.freeArchiveLimit, 8);
    expect(IapConstants.proArchiveLimit, 99);
  });

  test('disable=1 hides billing only', () {
    final off = IapRemoteConfig.fromJson({'disable': 1, 'name': 'SetPilot'});
    expect(off.billingDisabled, isTrue);
    final on = IapRemoteConfig.fromJson(
        {'disable': 0, 'name': 'SetPilot', 'code': 'FULL_IAP'});
    expect(on.billingDisabled, isFalse);
    expect(on.name, 'SetPilot');
  });

  test('shop catalog extras can be applied and reverted', () {
    expect(
        ShopCatalog.items.where((e) => e.id.startsWith('theme_')), isNotEmpty);
    expect(ShopCatalog.find(ShopCatalog.featPro), isNotNull);
    expect(ShopCatalog.find('remove_ads'), isNotNull);
    expect(ShopCatalog.find(ShopCatalog.featHint), isNotNull);
    expect(ShopCatalog.find(ShopCatalog.featSound), isNotNull);
    expect(ShopCatalog.isDefaultId(ShopCatalog.defaultThemeId), isTrue);
  });
}
