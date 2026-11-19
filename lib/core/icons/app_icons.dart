import 'package:flutter/material.dart';

/// Icons are stored in the database by key (never by code point) so that
/// release builds can tree-shake the Material icon font safely.
const Map<String, IconData> appIcons = {
  'food': Icons.restaurant_rounded,
  'coffee': Icons.local_cafe_rounded,
  'transport': Icons.directions_car_rounded,
  'fuel': Icons.local_gas_station_rounded,
  'shopping': Icons.shopping_bag_rounded,
  'bills': Icons.receipt_long_rounded,
  'home': Icons.home_rounded,
  'phone': Icons.phone_android_rounded,
  'entertainment': Icons.movie_rounded,
  'health': Icons.local_hospital_rounded,
  'education': Icons.school_rounded,
  'family': Icons.family_restroom_rounded,
  'pets': Icons.pets_rounded,
  'travel': Icons.flight_rounded,
  'sports': Icons.sports_soccer_rounded,
  'beauty': Icons.spa_rounded,
  'gift': Icons.card_giftcard_rounded,
  'salary': Icons.payments_rounded,
  'work': Icons.work_rounded,
  'business': Icons.storefront_rounded,
  'bonus': Icons.star_rounded,
  'savings': Icons.savings_rounded,
  'other': Icons.category_rounded,
  'cash': Icons.money_rounded,
  'wallet': Icons.account_balance_wallet_rounded,
  'bank': Icons.account_balance_rounded,
  'card': Icons.credit_card_rounded,
  'mobile': Icons.phone_iphone_rounded,
};

const categoryIconKeys = <String>[
  'food', 'coffee', 'transport', 'fuel', 'shopping', 'bills', 'home', 'phone',
  'entertainment', 'health', 'education', 'family', 'pets', 'travel', 'sports',
  'beauty', 'gift', 'salary', 'work', 'business', 'bonus', 'savings', 'other',
];

const walletIconKeys = <String>['cash', 'wallet', 'bank', 'card', 'mobile', 'savings'];

IconData iconFor(String key) => appIcons[key] ?? Icons.category_rounded;
