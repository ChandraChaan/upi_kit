import 'dart:convert';

/// One ID-length-value field of an EMV QR code: a two-digit [id], then a
/// two-digit length, then the [value].
///
/// Template fields (merchant account information, additional data) hold more
/// fields inside their value; read them with [children].
final class TlvField {
  const TlvField(this.id, this.value)
      : assert(id.length == 2, 'An EMV field ID has two digits');

  final String id;
  final String value;

  /// The fields nested inside a template's [value].
  ///
  /// Throws a [FormatException] if the value isn't nested fields.
  List<TlvField> get children => parseTlv(value);

  /// The field as it appears in the payload: `5913SHARMA STORES`.
  String encode() {
    final length = value.runes.length;
    if (length > 99) {
      throw ArgumentError.value(
          value, 'value', 'An EMV field holds at most 99 characters');
    }
    return '$id${length.toString().padLeft(2, '0')}$value';
  }

  @override
  bool operator ==(Object other) =>
      other is TlvField && other.id == id && other.value == value;

  @override
  int get hashCode => Object.hash(id, value);

  @override
  String toString() => encode();
}

/// Splits an EMV payload (or a template's value) into its fields.
///
/// Lengths count characters, as the EMV QR specification does, so fields in
/// Hindi or other scripts are read correctly. Throws a [FormatException] if a
/// field is cut short or its length isn't two digits.
List<TlvField> parseTlv(String data) {
  final fields = <TlvField>[];
  final chars = data.runes.toList();
  var i = 0;
  while (i < chars.length) {
    if (i + 4 > chars.length) {
      throw FormatException('A field header is cut short', data, i);
    }
    final id = String.fromCharCodes(chars, i, i + 2);
    final lengthText = String.fromCharCodes(chars, i + 2, i + 4);
    if (!RegExp(r'^\d\d$').hasMatch(id)) {
      throw FormatException('Field ID "$id" is not two digits', data, i);
    }
    if (!RegExp(r'^\d\d$').hasMatch(lengthText)) {
      throw FormatException(
          'Field $id has a length "$lengthText" that is not two digits',
          data,
          i + 2);
    }
    final length = int.parse(lengthText);
    final start = i + 4;
    final end = start + length;
    if (end > chars.length) {
      throw FormatException(
          'Field $id says it has $length characters but the data ends first',
          data,
          start);
    }
    fields.add(TlvField(id, String.fromCharCodes(chars, start, end)));
    i = end;
  }
  return fields;
}

/// Joins fields into a payload.
String encodeTlv(Iterable<TlvField> fields) =>
    fields.map((field) => field.encode()).join();

/// CRC-16/CCITT-FALSE (polynomial 0x1021, initial value 0xFFFF): the
/// checksum in field 63 of every EMV QR code.
int crc16(List<int> bytes) {
  var crc = 0xFFFF;
  for (final byte in bytes) {
    crc ^= byte << 8;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) : crc << 1;
      crc &= 0xFFFF;
    }
  }
  return crc;
}

/// The four upper-case hex digits of [crc16] over the UTF-8 bytes of [text].
String crc16Hex(String text) =>
    crc16(utf8.encode(text)).toRadixString(16).toUpperCase().padLeft(4, '0');
