/// An amount in Indian rupees, stored as whole paise.
///
/// UPI amounts have at most two decimal places. Keeping them as an integer
/// number of paise means `0.1 + 0.2` problems can never creep into a payment.
final class UpiAmount implements Comparable<UpiAmount> {
  /// An amount of [paise] (one rupee is 100 paise).
  const UpiAmount.paise(this.paise)
      : assert(paise >= 0, 'An amount cannot be negative');

  /// An amount of whole and fractional [rupees], such as `149.5`.
  ///
  /// Throws an [ArgumentError] if [rupees] is negative, not finite or has more
  /// than two decimal places.
  factory UpiAmount.rupees(num rupees) {
    if (!rupees.isFinite || rupees < 0) {
      throw ArgumentError.value(rupees, 'rupees', 'Must be zero or positive');
    }
    final scaled = rupees * 100;
    final paise = scaled.round();
    if ((scaled - paise).abs() > 1e-6) {
      throw ArgumentError.value(
          rupees, 'rupees', 'Has more than two decimal places');
    }
    return UpiAmount.paise(paise);
  }

  static final _pattern = RegExp(r'^(\d{1,13})(?:\.(\d{1,2}))?$');

  /// Parses a UPI amount string such as `149`, `149.5` or `149.50`.
  ///
  /// Throws a [FormatException] for anything else, including thousands
  /// separators (`1,000`), a currency sign or more than two decimal places.
  static UpiAmount parse(String input) {
    final amount = tryParse(input);
    if (amount == null) {
      throw FormatException(
          'Not a UPI amount: use digits with up to two decimal places', input);
    }
    return amount;
  }

  /// Like [parse], but returns null instead of throwing.
  static UpiAmount? tryParse(String input) {
    final match = _pattern.firstMatch(input.trim());
    if (match == null) return null;
    final rupees = int.parse(match.group(1)!);
    final fraction = (match.group(2) ?? '').padRight(2, '0');
    return UpiAmount.paise(rupees * 100 + int.parse(fraction));
  }

  /// The amount in paise.
  final int paise;

  /// The whole-rupee part.
  int get rupees => paise ~/ 100;

  /// The amount as UPI and EMV QR codes write it, always with two decimal
  /// places: `149.50`.
  String format() =>
      '${paise ~/ 100}.${(paise % 100).toString().padLeft(2, '0')}';

  bool get isZero => paise == 0;

  @override
  int compareTo(UpiAmount other) => paise.compareTo(other.paise);

  bool operator <(UpiAmount other) => paise < other.paise;
  bool operator >(UpiAmount other) => paise > other.paise;

  @override
  bool operator ==(Object other) => other is UpiAmount && other.paise == paise;

  @override
  int get hashCode => paise.hashCode;

  @override
  String toString() => '₹${format()}';
}
