import 'package:upi_kit/upi_kit.dart';

void main() {
  // 1. Build a payment link, for a QR code or to open a UPI app.
  final link = UpiPaymentLink(
    payeeVpa: 'sharmastores@okicici',
    payeeName: 'Sharma Stores',
    amount: UpiAmount.parse('149.50'),
    note: 'Order 1043',
    transactionRef: 'ORD1043',
  );
  print(link); // upi://pay?pa=sharmastores@okicici&pn=Sharma%20Stores&...
  print(link.toLink(UpiApp.phonePe)); // phonepe://pay?... for iOS

  // 2. Build a Bharat QR (EMV) code with a correct CRC.
  final qr = EmvQr.bharatQr(
    vpa: 'sharmastores@okicici',
    merchantName: 'Sharma Stores',
    merchantCity: 'Bengaluru',
    merchantCategoryCode: '5411',
    amount: UpiAmount.parse('149.50'),
    transactionRef: 'ORD1043',
  );
  print(qr.payload); // 000201010212... ends with 6304 and the CRC

  // 3. Read whatever a QR scanner gives you.
  for (final scanned in [link.toLink(), qr.payload, 'upi://pay?pa=oops']) {
    final result = UpiQr.tryParse(scanned);
    if (result == null) {
      print('Not a payment QR code');
      continue;
    }
    final description = switch (result) {
      UpiLinkQr(:final link) => 'UPI link to ${link.payeeVpa}',
      EmvUpiQr(:final qr) => 'Bharat QR for ${qr.merchantName}',
    };
    print(description);
    for (final issue in result.validate()) {
      print('  $issue');
    }
  }
}
