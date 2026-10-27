import 'emv_qr.dart';
import 'issues.dart';
import 'payment_link.dart';

/// The text read from a payment QR code: either a `upi://pay` link or an EMV
/// (Bharat QR) payload.
///
/// Hand [parse] whatever your scanner returns and `switch` on the result:
///
/// ```dart
/// switch (UpiQr.parse(scanned)) {
///   case UpiLinkQr(:final link): print(link.payeeVpa);
///   case EmvUpiQr(:final qr): print(qr.merchantName);
/// }
/// ```
sealed class UpiQr {
  const UpiQr();

  /// Reads the text of a scanned payment QR code.
  ///
  /// Throws a [FormatException] if it is neither a `upi://pay` link nor an
  /// EMV payload, or if it is one but can't be read.
  static UpiQr parse(String scanned) {
    if (UpiPaymentLink.looksLikeLink(scanned)) {
      return UpiLinkQr(UpiPaymentLink.parse(scanned));
    }
    if (EmvQr.looksLikeEmv(scanned)) {
      return EmvUpiQr(EmvQr.parse(scanned));
    }
    throw FormatException(
        'Not a payment QR code: expected a upi://pay link or an EMV payload',
        scanned);
  }

  /// Like [parse], but returns null instead of throwing.
  static UpiQr? tryParse(String scanned) {
    try {
      return parse(scanned);
    } on FormatException {
      return null;
    }
  }

  /// The payment as a `upi://pay` link, or null for an EMV code that has no
  /// UPI details (a card-only code, for example).
  UpiPaymentLink? toPaymentLink();

  /// Problems payment apps would object to.
  List<UpiIssue> validate();
}

/// A QR code holding a `upi://pay` link.
final class UpiLinkQr extends UpiQr {
  const UpiLinkQr(this.link);

  final UpiPaymentLink link;

  @override
  UpiPaymentLink toPaymentLink() => link;

  @override
  List<UpiIssue> validate() => link.validate();
}

/// A QR code holding an EMV payload, such as a Bharat QR code.
final class EmvUpiQr extends UpiQr {
  const EmvUpiQr(this.qr);

  final EmvQr qr;

  @override
  UpiPaymentLink? toPaymentLink() => qr.toPaymentLink();

  @override
  List<UpiIssue> validate() => qr.validate();
}
