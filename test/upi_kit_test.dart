import 'package:test/test.dart';
import 'package:upi_kit/upi_kit.dart';

/// The worked example from the EMVCo merchant-presented QR specification.
/// It has a Chinese alternate-language template, so it also checks that
/// lengths count characters and the CRC covers UTF-8 bytes.
const emvcoExample = '00020101021229300012D156000000000510A93FO3230Q'
    '31280012D15600000001030812345678520441115802CN5914BEST TRANSPORT'
    '6007BEIJING64200002ZH0104最佳运输0202北京540523.7253031565502016233030412'
    '340603***0708A60086670902ME91320016A0112233449988770708123456786304A13A';

void main() {
  group('UpiAmount', () {
    test('parses rupees and paise', () {
      expect(UpiAmount.parse('149').paise, 14900);
      expect(UpiAmount.parse('149.5').paise, 14950);
      expect(UpiAmount.parse(' 149.05 ').paise, 14905);
      expect(UpiAmount.parse('0.01').paise, 1);
    });

    test('rejects what payment apps reject', () {
      for (final bad in ['1,000', '₹10', '-5', '1.234', '.5', '', 'ten']) {
        expect(UpiAmount.tryParse(bad), isNull, reason: bad);
      }
      expect(() => UpiAmount.parse('1.234'), throwsFormatException);
    });

    test('always formats two decimal places', () {
      expect(UpiAmount.paise(14950).format(), '149.50');
      expect(UpiAmount.paise(7).format(), '0.07');
      expect(UpiAmount.paise(100000).toString(), '₹1000.00');
    });

    test('rupees() avoids floating-point drift', () {
      expect(UpiAmount.rupees(0.1 + 0.2).paise, 30);
      expect(UpiAmount.rupees(19.99).paise, 1999);
      expect(() => UpiAmount.rupees(1.005), throwsArgumentError);
      expect(() => UpiAmount.rupees(-1), throwsArgumentError);
    });

    test('compares', () {
      expect(UpiAmount.parse('10') > UpiAmount.parse('9.99'), isTrue);
      expect(UpiAmount.parse('10.0'), UpiAmount.parse('10.00'));
    });
  });

  group('Vpa', () {
    test('accepts real-world shapes', () {
      for (final good in [
        'sharmastores@okicici',
        '9876543210@ybl',
        'first.last-1_x@paytm',
        'Shop@OkHdfcBank',
      ]) {
        expect(Vpa.isValid(good), isTrue, reason: good);
      }
      expect(Vpa.parse('Shop@OkHdfcBank').handle, 'okhdfcbank');
    });

    test('rejects malformed IDs', () {
      for (final bad in [
        'shop',
        '@ybl',
        'a@ybl',
        'shop@',
        'shop@1bank',
        's p@ybl'
      ]) {
        expect(Vpa.isValid(bad), isFalse, reason: bad);
      }
    });
  });

  group('UpiPaymentLink', () {
    final link = UpiPaymentLink(
      payeeVpa: 'sharmastores@okicici',
      payeeName: 'Sharma Stores',
      amount: UpiAmount.parse('149.5'),
      note: 'Order #1043 & tip',
      transactionRef: 'ORD1043',
    );

    test('builds a link in the order apps expect', () {
      expect(
        link.toLink(),
        'upi://pay?pa=sharmastores@okicici&pn=Sharma%20Stores&tr=ORD1043'
        '&tn=Order%20%231043%20%26%20tip&am=149.50&cu=INR',
      );
    });

    test('builds app-specific links for iOS', () {
      expect(link.toLink(UpiApp.phonePe), startsWith('phonepe://pay?pa='));
      expect(link.toLink(UpiApp.googlePay), startsWith('gpay://upi/pay?pa='));
      expect(link.toUri().scheme, 'upi');
    });

    test('round-trips', () {
      expect(UpiPaymentLink.parse(link.toLink()), link);
    });

    test('parses upper-case, plus-encoded and trailing-slash links', () {
      final parsed = UpiPaymentLink.parse(
          'UPI://PAY/?PA=SHOP@YBL&PN=Ravi+Kumar&AM=20&TN=chai%20and%20samosa');
      expect(parsed.payeeVpa, 'SHOP@YBL');
      expect(parsed.payeeName, 'Ravi Kumar');
      expect(parsed.amount, UpiAmount.paise(2000));
      expect(parsed.note, 'chai and samosa');
    });

    test('keeps unknown parameters and encodes Unicode', () {
      final parsed = UpiPaymentLink.parse(
          'upi://pay?pa=shop@ybl&pn=%E0%A4%B6%E0%A4%B0%E0%A5%8D%E0%A4%AE%E0%A4%BE&sign=abc%3D');
      expect(parsed.payeeName, 'शर्मा');
      expect(parsed.extra, {'sign': 'abc='});
      expect(parsed.toLink(), contains('&sign=abc%3D'));
    });

    test('keeps a stray % instead of failing', () {
      expect(UpiPaymentLink.parse('upi://pay?pa=a1@ybl&tn=100%').note, '100%');
    });

    test('rejects things that are not payment links', () {
      expect(UpiPaymentLink.tryParse('https://example.com'), isNull);
      expect(UpiPaymentLink.tryParse('upi://mandate?pa=a1@ybl'), isNull);
      expect(() => UpiPaymentLink.parse('upi://pay?pn=Nobody'),
          throwsFormatException);
      expect(() => UpiPaymentLink.parse('upi://pay?pa=a1@ybl&am=1,000'),
          throwsFormatException);
    });

    test('a complete link has no issues', () {
      expect(link.validate(), isEmpty);
      expect(link.isValid, isTrue);
    });

    test('validate finds every problem', () {
      final bad = UpiPaymentLink(
        payeeVpa: 'not-a-vpa',
        amount: const UpiAmount.paise(0),
        minimumAmount: UpiAmount.parse('5'),
        merchantCategoryCode: '54',
        currency: 'USD',
        transactionRef: 'x' * 40,
        url: 'ftp://example.com',
      );
      final codes = bad.validate().map((i) => i.code).toSet();
      expect(codes, {
        UpiIssueCode.invalidVpa,
        UpiIssueCode.missingPayeeName,
        UpiIssueCode.zeroAmount,
        UpiIssueCode.minimumAboveAmount,
        UpiIssueCode.invalidMerchantCategoryCode,
        UpiIssueCode.unsupportedCurrency,
        UpiIssueCode.transactionRefLength,
        UpiIssueCode.invalidUrl,
      });
      expect(bad.isValid, isFalse);
    });

    test('a missing name is only a warning', () {
      final noName = UpiPaymentLink(payeeVpa: 'shop@ybl');
      expect(noName.validate().single.severity, UpiIssueSeverity.warning);
      expect(noName.isValid, isTrue);
    });
  });

  group('TLV and CRC', () {
    test('CRC-16/CCITT-FALSE check value', () {
      expect(crc16('123456789'.codeUnits), 0x29B1);
      expect(crc16Hex('123456789'), '29B1');
    });

    test('splits and joins fields', () {
      final fields = parseTlv('0002015913SHARMA STORES');
      expect(fields, [
        const TlvField('00', '01'),
        const TlvField('59', 'SHARMA STORES'),
      ]);
      expect(encodeTlv(fields), '0002015913SHARMA STORES');
    });

    test('reports cut-short and malformed data', () {
      expect(() => parseTlv('5920SHORT'), throwsFormatException);
      expect(() => parseTlv('59'), throwsFormatException);
      expect(() => parseTlv('5AXXabc'), throwsFormatException);
      expect(() => parseTlv('59x1a'), throwsFormatException);
    });

    test('field values are limited to 99 characters', () {
      expect(() => TlvField('59', 'x' * 100).encode(), throwsArgumentError);
    });
  });

  group('EmvQr', () {
    test('parses the EMVCo specification example', () {
      final qr = EmvQr.parse(emvcoExample);
      expect(qr.pointOfInitiation, PointOfInitiation.dynamicCode);
      expect(qr.merchantName, 'BEST TRANSPORT');
      expect(qr.merchantCity, 'BEIJING');
      expect(qr.merchantCategoryCode, '4111');
      expect(qr.currencyCode, '156');
      expect(qr.amount, UpiAmount.parse('23.72'));
      expect(qr.countryCode, 'CN');
      expect(qr.crc, 'A13A');
      expect(qr.merchantAccounts.keys, ['29', '31']);
      expect(qr.additionalData!.storeLabel, '1234');
      expect(qr.additionalData!.customerLabel, '***');
      expect(qr.additionalData!.terminalLabel, 'A6008667');
      expect(parseTlv(qr['64']!)[1].value, '最佳运输');
      expect(qr.upi, isNull);
      expect(qr.toPaymentLink(), isNull);
      expect(qr.payload, emvcoExample);
    });

    test('rejects a code with a wrong CRC', () {
      final tampered = emvcoExample.replaceFirst('23.72', '93.72');
      expect(() => EmvQr.parse(tampered), throwsFormatException);
      expect(EmvQr.tryParse(tampered, verifyCrc: false), isNotNull);
    });

    test('rejects codes without the framing fields', () {
      expect(EmvQr.tryParse('5913SHARMA STORES6304ABCD'), isNull);
      expect(EmvQr.tryParse('0002015913SHARMA STORES'), isNull);
    });

    test('builds a Bharat QR code that parses back', () {
      final qr = EmvQr.bharatQr(
        vpa: 'sharmastores@okicici',
        merchantName: 'Sharma Stores',
        merchantCity: 'Bengaluru',
        merchantCategoryCode: '5411',
        amount: UpiAmount.parse('149.50'),
        transactionRef: 'ORD1043',
        billNumber: 'INV-1043',
        postalCode: '560001',
      );
      final parsed = EmvQr.parse(qr.payload);
      expect(parsed, qr);
      expect(parsed.pointOfInitiation, PointOfInitiation.dynamicCode);
      expect(parsed.isInr, isTrue);
      expect(parsed.upi!.vpa, 'sharmastores@okicici');
      expect(parsed.upi!.transactionRef, 'ORD1043');
      expect(parsed.additionalData!.billNumber, 'INV-1043');
      expect(parsed.validate(), isEmpty);
      expect(
        parsed.toPaymentLink()!.toLink(),
        'upi://pay?pa=sharmastores@okicici&pn=Sharma%20Stores&mc=5411'
        '&tr=ORD1043&am=149.50&cu=INR',
      );
    });

    test('a static code has no amount and is reusable', () {
      final qr = EmvQr.bharatQr(
        vpa: 'chaiwala@ybl',
        merchantName: 'A very long merchant name for a tea stall',
        merchantCity: 'Thiruvananthapuram',
      );
      expect(qr.pointOfInitiation, PointOfInitiation.staticCode);
      expect(qr.amount, isNull);
      expect(qr.merchantName!.length, 25);
      expect(qr.merchantCity, 'Thiruvananthapu');
      expect(qr['27'], isNull);
      expect(qr.payload, startsWith('000201010211'));
      expect(qr.toPaymentLink()!.merchantCategoryCode, isNull);
    });

    test('fromFields orders fields and computes the CRC', () {
      final qr = EmvQr.fromFields([
        const TlvField('59', 'X'),
        const TlvField('63', 'FFFF'),
        const TlvField('01', '11'),
      ]);
      expect(qr.fields.map((f) => f.id), ['00', '01', '59', '63']);
      expect(EmvQr.tryParse(qr.payload), isNotNull);
    });

    test('validate reports missing and wrong fields', () {
      final qr = EmvQr.fromFields([
        TlvField(
            '26',
            encodeTlv(
                [const TlvField('00', 'X'), const TlvField('01', 'bad')])),
        const TlvField('27', '0010A00000052401020'),
        const TlvField('52', '12'),
        const TlvField('53', '840'),
        const TlvField('54', '0'),
      ]);
      final codes = qr.validate().map((i) => '${i.field}:${i.code.name}');
      expect(
          codes,
          containsAll([
            '58:missingField',
            '59:missingField',
            '60:missingField',
            '52:invalidMerchantCategoryCode',
            '54:zeroAmount',
            '53:unsupportedCurrency',
            '26:invalidVpa',
            '26:unexpectedValue',
          ]));
    });
  });

  group('UpiQr', () {
    test('recognises both kinds of payment QR code', () {
      final fromLink = UpiQr.parse('upi://pay?pa=shop@ybl&pn=Shop');
      final fromEmv = UpiQr.parse(EmvQr.bharatQr(
              vpa: 'shop@ybl', merchantName: 'Shop', merchantCity: 'Pune')
          .payload);

      String describe(UpiQr qr) => switch (qr) {
            UpiLinkQr(:final link) => 'link to ${link.payeeVpa}',
            EmvUpiQr(:final qr) => 'EMV code for ${qr.merchantName}',
          };

      expect(describe(fromLink), 'link to shop@ybl');
      expect(describe(fromEmv), 'EMV code for Shop');
      expect(fromLink.toPaymentLink()!.payeeVpa, 'shop@ybl');
      expect(fromEmv.toPaymentLink()!.payeeVpa, 'shop@ybl');
      expect(fromEmv.validate(), isEmpty);
    });

    test('rejects other QR codes', () {
      expect(UpiQr.tryParse('https://example.com'), isNull);
      expect(UpiQr.tryParse('WIFI:S:home;T:WPA;P:secret;;'), isNull);
      expect(() => UpiQr.parse(''), throwsFormatException);
    });
  });
}
