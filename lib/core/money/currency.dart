/// Currencies supported by Kabob. Amounts are always stored as integers in
/// the currency's minor unit (cents for USD, riel for KHR) so that no
/// floating-point rounding ever touches the user's money.
enum CurrencyCode {
  usd,
  khr;

  String get code => this == CurrencyCode.usd ? 'USD' : 'KHR';

  String get symbol => this == CurrencyCode.usd ? r'$' : '៛';

  /// Number of decimal places used when entering / displaying amounts.
  int get decimals => this == CurrencyCode.usd ? 2 : 0;
}
