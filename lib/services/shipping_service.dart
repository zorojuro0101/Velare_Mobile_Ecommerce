import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of a shipping fee calculation for a single seller/shop.
class ShopShippingResult {
  final String shopName;
  final String sellerId;
  final double fee;
  final ShippingTier tier;
  final String tierLabel;

  ShopShippingResult({
    required this.shopName,
    required this.sellerId,
    required this.fee,
    required this.tier,
    required this.tierLabel,
  });
}

enum ShippingTier {
  sameCity,      // Tier 1 — ₱49
  sameProvince,  // Tier 2 — ₱79
  sameRegion,    // Tier 3 — ₱109
  sameIsland,    // Tier 4 — ₱149
  crossIsland,   // Tier 5 — ₱199
}

class ShippingService {
  static final ShippingService _instance = ShippingService._internal();
  factory ShippingService() => _instance;
  ShippingService._internal();

  final _supabase = Supabase.instance.client;

  // ─── Tier Fees ──────────────────────────────────────────────────────────────
  static const Map<ShippingTier, double> _tierFees = {
    ShippingTier.sameCity: 49.0,
    ShippingTier.sameProvince: 79.0,
    ShippingTier.sameRegion: 109.0,
    ShippingTier.sameIsland: 149.0,
    ShippingTier.crossIsland: 199.0,
  };

  static const Map<ShippingTier, String> _tierLabels = {
    ShippingTier.sameCity: 'Same City',
    ShippingTier.sameProvince: 'Same Province',
    ShippingTier.sameRegion: 'Same Region',
    ShippingTier.sameIsland: 'Nearby Region',
    ShippingTier.crossIsland: 'Cross-Island',
  };

  // ─── Island Group Mapping ────────────────────────────────────────────────────
  // Maps each Philippine region code to its island group.
  static const Map<String, String> _regionToIsland = {
    // Luzon
    'region i': 'luzon',
    'ilocos region': 'luzon',
    'region ii': 'luzon',
    'cagayan valley': 'luzon',
    'region iii': 'luzon',
    'central luzon': 'luzon',
    'region iv-a': 'luzon',
    'calabarzon': 'luzon',
    'region iv-b': 'luzon',
    'mimaropa': 'luzon',
    'region v': 'luzon',
    'bicol region': 'luzon',
    'ncr': 'luzon',
    'national capital region': 'luzon',
    'car': 'luzon',
    'cordillera administrative region': 'luzon',

    // Visayas
    'region vi': 'visayas',
    'western visayas': 'visayas',
    'region vii': 'visayas',
    'central visayas': 'visayas',
    'region viii': 'visayas',
    'eastern visayas': 'visayas',

    // Mindanao
    'region ix': 'mindanao',
    'zamboanga peninsula': 'mindanao',
    'region x': 'mindanao',
    'northern mindanao': 'mindanao',
    'region xi': 'mindanao',
    'davao region': 'mindanao',
    'region xii': 'mindanao',
    'soccsksargen': 'mindanao',
    'region xiii': 'mindanao',
    'caraga': 'mindanao',
    'barmm': 'mindanao',
    'bangsamoro': 'mindanao',
  };

  // ─── Public API ──────────────────────────────────────────────────────────────

  /// Fetches seller addresses for a list of sellerIds and computes the shipping
  /// fee per shop based on the buyer's selected address.
  Future<List<ShopShippingResult>> calculateShippingPerShop({
    required Map<String, String> buyerAddress, // {'city', 'province', 'region'}
    required List<Map<String, dynamic>> cartItems, // [{seller_id, shop_name, ...}]
  }) async {
    // Get unique sellers (seller_id -> shop_name)
    final Map<String, String> sellerShops = {};
    for (var item in cartItems) {
      final sellerId = item['seller_id']?.toString() ?? '';
      final shopName = item['shop_name']?.toString() ?? 'Unknown Shop';
      if (sellerId.isNotEmpty && !sellerShops.containsKey(sellerId)) {
        sellerShops[sellerId] = shopName;
      }
    }

    if (sellerShops.isEmpty) return [];

    // Fetch seller addresses from DB
    final sellerAddresses = await _fetchSellerAddresses(sellerShops.keys.toList());

    // Compute per-shop shipping
    final results = <ShopShippingResult>[];
    for (var entry in sellerShops.entries) {
      final sellerId = entry.key;
      final shopName = entry.value;
      final sellerAddr = sellerAddresses[sellerId];

      final tier = _determineTier(buyerAddress, sellerAddr);
      final fee = _tierFees[tier]!;
      final label = _tierLabels[tier]!;

      results.add(ShopShippingResult(
        shopName: shopName,
        sellerId: sellerId,
        fee: fee,
        tier: tier,
        tierLabel: label,
      ));
    }

    return results;
  }

  /// Returns the total shipping fee, optionally excluding a specific seller
  /// (used when a free-shipping voucher is applied to that seller).
  double totalFee(
    List<ShopShippingResult> results, {
    String? excludeSellerId,
  }) {
    return results
        .where((r) => r.sellerId != excludeSellerId)
        .fold(0.0, (sum, r) => sum + r.fee);
  }

  // ─── Private Helpers ─────────────────────────────────────────────────────────

  /// Fetches the default/first address for each seller from the `addresses` table.
  Future<Map<String, Map<String, String>?>> _fetchSellerAddresses(
    List<String> sellerIds,
  ) async {
    final result = <String, Map<String, String>?>{};

    try {
      final intIds = sellerIds
          .map((id) => int.tryParse(id))
          .whereType<int>()
          .toList();

      if (intIds.isEmpty) {
        for (var id in sellerIds) {
          result[id] = null;
        }
        return result;
      }

      final response = await _supabase
          .from('addresses')
          .select('user_ref_id, region, province, city')
          .eq('user_type', 'seller')
          .inFilter('user_ref_id', intIds);

      // Build a map: seller_id (string) -> address fields
      final Map<String, Map<String, String>?> addressMap = {};
      for (var row in response as List) {
        final refId = row['user_ref_id'].toString();
        if (!addressMap.containsKey(refId)) {
          addressMap[refId] = {
            'region': (row['region'] ?? '').toString().toLowerCase().trim(),
            'province': (row['province'] ?? '').toString().toLowerCase().trim(),
            'city': (row['city'] ?? '').toString().toLowerCase().trim(),
          };
        }
      }

      for (var id in sellerIds) {
        result[id] = addressMap[id];
      }
    } catch (e) {
      print('ShippingService - Error fetching seller addresses: $e');
      for (var id in sellerIds) {
        result[id] = null;
      }
    }

    return result;
  }

  /// Core tier determination logic.
  ShippingTier _determineTier(
    Map<String, String> buyerAddr,
    Map<String, String>? sellerAddr,
  ) {
    // If seller has no address on record, default to same-region pricing
    if (sellerAddr == null) {
      return ShippingTier.sameRegion;
    }

    final buyerCity = buyerAddr['city']?.toLowerCase().trim() ?? '';
    final buyerProvince = buyerAddr['province']?.toLowerCase().trim() ?? '';
    final buyerRegion = buyerAddr['region']?.toLowerCase().trim() ?? '';

    final sellerCity = sellerAddr['city']?.toLowerCase().trim() ?? '';
    final sellerProvince = sellerAddr['province']?.toLowerCase().trim() ?? '';
    final sellerRegion = sellerAddr['region']?.toLowerCase().trim() ?? '';

    // Tier 1 — Same City
    if (buyerCity.isNotEmpty &&
        sellerCity.isNotEmpty &&
        buyerCity == sellerCity) {
      return ShippingTier.sameCity;
    }

    // Tier 2 — Same Province
    if (buyerProvince.isNotEmpty &&
        sellerProvince.isNotEmpty &&
        buyerProvince == sellerProvince) {
      return ShippingTier.sameProvince;
    }

    // Tier 3 — Same Region
    if (buyerRegion.isNotEmpty &&
        sellerRegion.isNotEmpty &&
        buyerRegion == sellerRegion) {
      return ShippingTier.sameRegion;
    }

    // Tier 4 vs 5 — Compare island groups
    final buyerIsland = _getIslandGroup(buyerRegion);
    final sellerIsland = _getIslandGroup(sellerRegion);

    if (buyerIsland != null &&
        sellerIsland != null &&
        buyerIsland == sellerIsland) {
      return ShippingTier.sameIsland;
    }

    return ShippingTier.crossIsland;
  }

  String? _getIslandGroup(String region) {
    if (region.isEmpty) return null;
    // Try exact match first
    if (_regionToIsland.containsKey(region)) {
      return _regionToIsland[region];
    }
    // Try partial match (e.g., "Region III - Central Luzon" → "central luzon")
    for (var entry in _regionToIsland.entries) {
      if (region.contains(entry.key) || entry.key.contains(region)) {
        return entry.value;
      }
    }
    return null;
  }

  double feeForTier(ShippingTier tier) => _tierFees[tier]!;
  String labelForTier(ShippingTier tier) => _tierLabels[tier]!;
}
