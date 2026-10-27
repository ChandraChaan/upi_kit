/// A UPI ID (virtual payment address), such as `sharmastores@okicici`.
///
/// This checks the format only. Whether the account exists is something only
/// a payment app or a UPI verification API can tell you.
final class Vpa {
  const Vpa._(this.username, this.handle);

  static final _pattern = RegExp(
      r'^([a-zA-Z0-9][a-zA-Z0-9._-]{1,255})@([a-zA-Z][a-zA-Z0-9]{1,63})$');

  /// Parses [input], ignoring surrounding spaces.
  ///
  /// Throws a [FormatException] if it isn't a well-formed UPI ID.
  static Vpa parse(String input) {
    final vpa = tryParse(input);
    if (vpa == null) throw FormatException('Not a UPI ID', input);
    return vpa;
  }

  /// Like [parse], but returns null instead of throwing.
  static Vpa? tryParse(String input) {
    final match = _pattern.firstMatch(input.trim());
    if (match == null) return null;
    return Vpa._(match.group(1)!, match.group(2)!.toLowerCase());
  }

  static bool isValid(String input) => tryParse(input) != null;

  /// The part before the `@`.
  final String username;

  /// The payment provider's handle after the `@`, in lower case, such as
  /// `okicici` or `ybl`.
  final String handle;

  String get address => '$username@$handle';

  @override
  bool operator ==(Object other) =>
      other is Vpa &&
      other.username.toLowerCase() == username.toLowerCase() &&
      other.handle == handle;

  @override
  int get hashCode => Object.hash(username.toLowerCase(), handle);

  @override
  String toString() => address;
}
