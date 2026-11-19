import 'package:kabob/data/db/enums.dart';

class SeedCategory {
  const SeedCategory(this.key, this.icon, this.color, this.type);

  /// Localization key; the display name comes from the ARB files.
  final String key;
  final String icon;
  final int color;
  final CategoryType type;
}

const seedCategories = <SeedCategory>[
  SeedCategory('food', 'food', 0xFFEF6C57, CategoryType.expense),
  SeedCategory('transport', 'transport', 0xFF3B82F6, CategoryType.expense),
  SeedCategory('shopping', 'shopping', 0xFFA855F7, CategoryType.expense),
  SeedCategory('bills', 'bills', 0xFFF97316, CategoryType.expense),
  SeedCategory('entertainment', 'entertainment', 0xFF6366F1, CategoryType.expense),
  SeedCategory('health', 'health', 0xFF0D9488, CategoryType.expense),
  SeedCategory('education', 'education', 0xFF0EA5E9, CategoryType.expense),
  SeedCategory('family', 'family', 0xFFEC4899, CategoryType.expense),
  SeedCategory('other', 'other', 0xFF64748B, CategoryType.expense),
  SeedCategory('salary', 'salary', 0xFF16A34A, CategoryType.income),
  SeedCategory('freelance', 'work', 0xFF8B5CF6, CategoryType.income),
  SeedCategory('business', 'business', 0xFF0D9488, CategoryType.income),
  SeedCategory('gift', 'gift', 0xFFF59E0B, CategoryType.income),
  SeedCategory('bonus', 'bonus', 0xFF3B82F6, CategoryType.income),
  SeedCategory('other_income', 'other', 0xFF64748B, CategoryType.income),
];
