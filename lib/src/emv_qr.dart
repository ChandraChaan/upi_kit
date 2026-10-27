import 'amount.dart';
import 'issues.dart';
import 'payment_link.dart';
import 'tlv.dart';
import 'vpa.dart';

/// NPCI's RuPay RID, the globally unique ID of the UPI templates (fields 26
/// and 27) in a Bharat QR code.
const npciRid = 'A000000524';

/// Whether a QR code is printed once and reused, or made for one payment.
enum PointOfInitiation {
  /// `11`: the same code for every payment, such as a shop's standee.
  staticCode('11'),

  /// `12`: made for one payment, usually with an amount.
  dynamicCode('12');

  const PointOfInitiation(this.code);

  final String code;
}

/// The UPI details in a Bharat QR code (fields 26 and 27).
final class EmvUpiAccount {
  const EmvUpiAccount({
    required this.vpa,
    this.minimumAmount,
    this.transactionRef,
    this.referenceUrl,
  });

  /// Field 26, sub-field 01.
  final String vpa;

  /// Field 26, sub-field 02.
  final UpiAmount? minimumAmount;

  /// Field 27, sub-field 01.
  final String? transactionRef;

  /// Field 27, sub-field 02.
  final String? referenceUrl;
}

/// The additional data template (field 62).
final class EmvAdditionalData {
  const EmvAdditionalData(this.fields);

  final List<TlvField> fields;

  String? _sub(String id) => _find(fields, id);

  String? get billNumber => _sub('01');
  String? get mobileNumber => _sub('02');
  String? get storeLabel => _sub('03');
  String? get loyaltyNumber => _sub('04');
  String? get referenceLabel => _sub('05');
  String? get customerLabel => _sub('06');
  String? get terminalLabel => _sub('07');
  String? get purpose => _sub('08');
}

/// An EMV merchant-presented QR code (EMVCo QRCPS-MPM), the format behind
/// Bharat QR and most card and wallet QR codes around the world.
///
/// [parse] checks the structure and the CRC. [bharatQr] builds a UPI-ready
/// code with a correct CRC.
final class EmvQr {
  EmvQr._(this.fields);

  /// Builds a code from [fields], adding field 00 if it's missing and a fresh
  /// CRC (field 63) at the end. Other fields are written in ID order.
  factory EmvQr.fromFields(Iterable<TlvField> fields) {
    final sorted = fields.where((f) => f.id != '63').toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    if (sorted.isEmpty || sorted.first.id != '00') {
      sorted.insert(0, const TlvField('00', '01'));
    }
    final body = '${encodeTlv(sorted)}6304';
    return EmvQr._(
        List.unmodifiable([...sorted, TlvField('63', crc16Hex(body))]));
  }

  /// A Bharat QR code that UPI apps can pay.
  ///
  /// Give an [amount] (and usually a [transactionRef]) for a one-time code;
  /// leave it out for a reusable shop code. [merchantName] is cut to 25
  /// characters and [merchantCity] to 15, as the specification requires.
  factory EmvQr.bharatQr({
    required String vpa,
    required String merchantName,
    required String merchantCity,
    String merchantCategoryCode = '0000',
    UpiAmount? amount,
    UpiAmount? minimumAmount,
    String? transactionRef,
    String? referenceUrl,
    String? postalCode,
    String? billNumber,
    String? storeLabel,
    String? terminalLabel,
  }) {
    String cut(String text, int max) =>
        text.length <= max ? text : text.substring(0, max);
    final additional = [
      if (billNumber != null) TlvField('01', billNumber),
      if (storeLabel != null) TlvField('03', storeLabel),
      if (terminalLabel != null) TlvField('07', terminalLabel),
    ];
    final isDynamic = amount != null || transactionRef != null;
    return EmvQr.fromFields([
      const TlvField('00', '01'),
      TlvField(
          '01',
          isDynamic
              ? PointOfInitiation.dynamicCode.code
              : PointOfInitiation.staticCode.code),
      TlvField(
          '26',
          encodeTlv([
            const TlvField('00', npciRid),
            TlvField('01', vpa),
            if (minimumAmount != null) TlvField('02', minimumAmount.format()),
          ])),
      if (transactionRef != null || referenceUrl != null)
        TlvField(
            '27',
            encodeTlv([
              const TlvField('00', npciRid),
              if (transactionRef != null) TlvField('01', transactionRef),
              if (referenceUrl != null) TlvField('02', referenceUrl),
            ])),
      TlvField('52', merchantCategoryCode),
      const TlvField('53', '356'),
      if (amount != null) TlvField('54', amount.format()),
      const TlvField('58', 'IN'),
      TlvField('59', cut(merchantName, 25)),
      TlvField('60', cut(merchantCity, 15)),
      if (postalCode != null) TlvField('61', postalCode),
      if (additional.isNotEmpty) TlvField('62', encodeTlv(additional)),
    ]);
  }

  /// Parses an EMV QR payload.
  ///
  /// Throws a [FormatException] if the fields can't be read, the code doesn't
  /// start with field 00 or end with field 63, or (when [verifyCrc] is true)
  /// the CRC doesn't match.
  static EmvQr parse(String payload, {bool verifyCrc = true}) {
    final text = payload.trim();
    final fields = parseTlv(text);
    if (fields.isEmpty || fields.first.id != '00') {
      throw FormatException(
          'An EMV QR code starts with field 00 (payload format)', payload);
    }
    if (fields.last.id != '63' || fields.last.value.length != 4) {
      throw FormatException(
          'An EMV QR code ends with field 63 (a four-character CRC)', payload);
    }
    if (verifyCrc) {
      final body = text.substring(0, text.length - 4);
      final expected = crc16Hex(body);
      if (fields.last.value.toUpperCase() != expected) {
        throw FormatException(
            'CRC mismatch: the code says ${fields.last.value} but the data '
            'gives $expected. It was probably scanned or copied wrongly.',
            payload);
      }
    }
    return EmvQr._(List.unmodifiable(fields));
  }

  /// Like [parse], but returns null instead of throwing.
  static EmvQr? tryParse(String payload, {bool verifyCrc = true}) {
    try {
      return parse(payload, verifyCrc: verifyCrc);
    } on FormatException {
      return null;
    }
  }

  /// Whether [input] looks like an EMV payload (starts with `000201`),
  /// without parsing it.
  static bool looksLikeEmv(String input) => input.trim().startsWith('000201');

  /// Every top-level field, in order, including the CRC.
  final List<TlvField> fields;

  /// The value of the top-level field [id], if present.
  String? operator [](String id) => _find(fields, id);

  /// The payload to put in the QR code.
  String get payload => encodeTlv(fields);

  PointOfInitiation? get pointOfInitiation => switch (this['01']) {
        '11' => PointOfInitiation.staticCode,
        '12' => PointOfInitiation.dynamicCode,
        _ => null,
      };

  /// Field 52.
  String? get merchantCategoryCode => this['52'];

  /// Field 53: the ISO 4217 numeric code, `356` for rupees.
  String? get currencyCode => this['53'];

  bool get isInr => currencyCode == '356';

  /// Field 54, if it holds a valid amount.
  UpiAmount? get amount {
    final value = this['54'];
    return value == null ? null : UpiAmount.tryParse(value);
  }

  /// Field 58: the two-letter country code.
  String? get countryCode => this['58'];

  /// Field 59.
  String? get merchantName => this['59'];

  /// Field 60.
  String? get merchantCity => this['60'];

  /// Field 61.
  String? get postalCode => this['61'];

  /// Field 63.
  String get crc => fields.last.value;

  /// Field 62, if present and readable.
  EmvAdditionalData? get additionalData {
    final value = this['62'];
    if (value == null) return null;
    try {
      return EmvAdditionalData(parseTlv(value));
    } on FormatException {
      return null;
    }
  }

  /// Merchant account fields 02 to 51 (card networks, UPI and others),
  /// by ID.
  Map<String, String> get merchantAccounts => {
        for (final field in fields)
          if (_isMerchantAccount(field.id)) field.id: field.value,
      };

  /// The UPI details from fields 26 and 27, if this code can be paid with
  /// UPI.
  EmvUpiAccount? get upi {
    final account = _template('26');
    final vpa = account == null ? null : _find(account, '01');
    if (vpa == null) return null;
    final reference = _template('27');
    final minimum = _find(account!, '02');
    return EmvUpiAccount(
      vpa: vpa,
      minimumAmount: minimum == null ? null : UpiAmount.tryParse(minimum),
      transactionRef: reference == null ? null : _find(reference, '01'),
      referenceUrl: reference == null ? null : _find(reference, '02'),
    );
  }

  List<TlvField>? _template(String id) {
    final value = this[id];
    if (value == null) return null;
    try {
      return parseTlv(value);
    } on FormatException {
      return null;
    }
  }

  /// The same payment as a `upi://pay` link, or null if the code has no UPI
  /// details.
  UpiPaymentLink? toPaymentLink() {
    final account = upi;
    if (account == null) return null;
    final mcc = merchantCategoryCode;
    return UpiPaymentLink(
      payeeVpa: account.vpa,
      payeeName: merchantName,
      amount: amount,
      minimumAmount: account.minimumAmount,
      transactionRef: account.transactionRef,
      url: account.referenceUrl,
      merchantCategoryCode: mcc == null || mcc == '0000' ? null : mcc,
    );
  }

  /// Checks the fields the EMV specification requires, and the UPI details
  /// when there are any.
  List<UpiIssue> validate() {
    final issues = <UpiIssue>[];
    void require(String id, String name) {
      if (this[id] == null) {
        issues.add(UpiIssue(
            UpiIssueCode.missingField, id, 'Field $id ($name) is required'));
      }
    }

    if (this['00'] != '01') {
      issues.add(UpiIssue(UpiIssueCode.unexpectedValue, '00',
          'Field 00 (payload format) should be "01", not "${this['00']}"'));
    }
    if (merchantAccounts.isEmpty) {
      issues.add(const UpiIssue(UpiIssueCode.missingField, '26',
          'There is no merchant account (fields 02 to 51), so nothing can pay it'));
    }
    require('52', 'merchant category code');
    require('53', 'currency');
    require('58', 'country code');
    require('59', 'merchant name');
    require('60', 'merchant city');

    final mcc = merchantCategoryCode;
    if (mcc != null && !RegExp(r'^\d{4}$').hasMatch(mcc)) {
      issues.add(const UpiIssue(UpiIssueCode.invalidMerchantCategoryCode, '52',
          'The merchant category code must be four digits'));
    }
    if (this['54'] != null && amount == null) {
      issues.add(UpiIssue(UpiIssueCode.unexpectedValue, '54',
          '"${this['54']}" is not an amount'));
    } else if (amount != null && amount!.isZero) {
      issues.add(const UpiIssue(
          UpiIssueCode.zeroAmount, '54', 'The amount must be more than zero'));
    }

    final account = upi;
    if (account != null) {
      if (!isInr) {
        issues.add(UpiIssue(UpiIssueCode.unsupportedCurrency, '53',
            'UPI only supports rupees (356), not "$currencyCode"'));
      }
      if (!Vpa.isValid(account.vpa)) {
        issues.add(UpiIssue(UpiIssueCode.invalidVpa, '26',
            '"${account.vpa}" is not a valid UPI ID (expected name@handle)'));
      }
      if (_find(_template('26')!, '00') != npciRid) {
        issues.add(const UpiIssue(UpiIssueCode.unexpectedValue, '26',
            'Field 26 should start with NPCI\'s ID ($npciRid)',
            severity: UpiIssueSeverity.warning));
      }
      final ref = account.transactionRef;
      if (ref != null && (ref.length < 4 || ref.length > 35)) {
        issues.add(const UpiIssue(UpiIssueCode.transactionRefLength, '27',
            'The transaction reference should be 4 to 35 characters',
            severity: UpiIssueSeverity.warning));
      }
    }
    return issues;
  }

  @override
  bool operator ==(Object other) => other is EmvQr && other.payload == payload;

  @override
  int get hashCode => payload.hashCode;

  @override
  String toString() => payload;
}

bool _isMerchantAccount(String id) {
  final n = int.tryParse(id);
  return n != null && n >= 2 && n <= 51;
}

String? _find(List<TlvField> fields, String id) {
  for (final field in fields) {
    if (field.id == id) return field.value;
  }
  return null;
}
