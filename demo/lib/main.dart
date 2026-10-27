import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:upi_kit/upi_kit.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const PlaygroundApp());

class PlaygroundApp extends StatelessWidget {
  const PlaygroundApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness brightness) => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1B5E20),
        brightness: brightness,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );
    return MaterialApp(
      title: 'upi_kit playground',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: const PlaygroundPage(),
    );
  }
}

class PlaygroundPage extends StatelessWidget {
  const PlaygroundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('upi_kit playground'),
          actions: [
            TextButton(
              onPressed: () =>
                  launchUrl(Uri.parse('https://pub.dev/packages/upi_kit')),
              child: const Text('pub.dev'),
            ),
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse('https://github.com/ChandraChaan/upi_kit'),
              ),
              child: const Text('GitHub'),
            ),
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.qr_code_2), text: 'Create'),
              Tab(icon: Icon(Icons.qr_code_scanner), text: 'Decode'),
            ],
          ),
        ),
        body: const TabBarView(children: [CreateTab(), DecodeTab()]),
      ),
    );
  }
}

/// Centres content and switches between one and two columns.
class _Columns extends StatelessWidget {
  const _Columns({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
        final content = wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: left),
                  const SizedBox(width: 24),
                  Expanded(child: right),
                ],
              )
            : Column(children: [left, const SizedBox(height: 24), right]);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: content,
            ),
          ),
        );
      },
    );
  }
}

enum OutputFormat { link, bharatQr }

class CreateTab extends StatefulWidget {
  const CreateTab({super.key});

  @override
  State<CreateTab> createState() => _CreateTabState();
}

class _CreateTabState extends State<CreateTab> {
  final _vpa = TextEditingController(text: 'sharmastores@okicici');
  final _name = TextEditingController(text: 'Sharma Stores');
  final _amount = TextEditingController(text: '149.50');
  final _note = TextEditingController(text: 'Order 1043');
  final _ref = TextEditingController(text: 'ORD1043');
  final _mcc = TextEditingController(text: '5411');
  final _city = TextEditingController(text: 'Bengaluru');
  var _format = OutputFormat.link;

  @override
  void dispose() {
    for (final c in [_vpa, _name, _amount, _note, _ref, _mcc, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _text(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  @override
  Widget build(BuildContext context) {
    final amountText = _text(_amount);
    final amount = amountText == null ? null : UpiAmount.tryParse(amountText);
    final amountError = amountText != null && amount == null
        ? 'Digits with up to two decimals, no commas'
        : null;

    String payload;
    List<UpiIssue> issues;
    if (_format == OutputFormat.link) {
      final link = UpiPaymentLink(
        payeeVpa: _vpa.text.trim(),
        payeeName: _text(_name),
        amount: amount,
        note: _text(_note),
        transactionRef: _text(_ref),
        merchantCategoryCode: _text(_mcc),
      );
      payload = link.toLink();
      issues = link.validate();
    } else {
      final qr = EmvQr.bharatQr(
        vpa: _vpa.text.trim(),
        merchantName: _text(_name) ?? '',
        merchantCity: _text(_city) ?? '',
        merchantCategoryCode: _text(_mcc) ?? '0000',
        amount: amount,
        transactionRef: _text(_ref),
      );
      payload = qr.payload;
      issues = qr.validate();
    }

    Widget field(
      TextEditingController c,
      String label, {
      String? helper,
      String? error,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          errorText: error,
        ),
      ),
    );

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<OutputFormat>(
          segments: const [
            ButtonSegment(
              value: OutputFormat.link,
              label: Text('UPI link'),
              icon: Icon(Icons.link),
            ),
            ButtonSegment(
              value: OutputFormat.bharatQr,
              label: Text('Bharat QR (EMV)'),
              icon: Icon(Icons.qr_code),
            ),
          ],
          selected: {_format},
          onSelectionChanged: (s) => setState(() => _format = s.first),
        ),
        const SizedBox(height: 16),
        field(_vpa, 'UPI ID (pa)'),
        field(_name, 'Payee name (pn)'),
        field(
          _amount,
          'Amount in ₹ (am)',
          helper: 'Leave empty to let the payer type it',
          error: amountError,
        ),
        if (_format == OutputFormat.link) field(_note, 'Note (tn)'),
        if (_format == OutputFormat.bharatQr) field(_city, 'Merchant city'),
        field(_ref, 'Your reference (tr)'),
        field(
          _mcc,
          'Merchant category code (mc)',
          helper: '4 digits, e.g. 5411 for grocery',
        ),
      ],
    );

    final output = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(data: payload, size: 220),
              ),
            ),
            const SizedBox(height: 16),
            _PayloadBox(payload),
            const SizedBox(height: 12),
            _IssueList(issues),
          ],
        ),
      ),
    );

    return _Columns(left: form, right: output);
  }
}

class DecodeTab extends StatefulWidget {
  const DecodeTab({super.key});

  @override
  State<DecodeTab> createState() => _DecodeTabState();
}

class _DecodeTabState extends State<DecodeTab> {
  static final _samples = {
    'UPI link':
        'upi://pay?pa=chaiwala@ybl&pn=Ravi%20Tea%20Stall&am=20&tn=2%20chai&cu=INR',
    'Bharat QR': EmvQr.bharatQr(
      vpa: 'sharmastores@okicici',
      merchantName: 'Sharma Stores',
      merchantCity: 'Bengaluru',
      merchantCategoryCode: '5411',
      amount: UpiAmount.parse('149.50'),
      transactionRef: 'ORD1043',
      billNumber: 'INV-1043',
    ).payload,
    'Static shop QR': EmvQr.bharatQr(
      vpa: '9876543210@paytm',
      merchantName: 'Anand Medicals',
      merchantCity: 'Pune',
      merchantCategoryCode: '5912',
    ).payload,
    'Mistyped QR': EmvQr.bharatQr(
      vpa: 'sharmastores@okicici',
      merchantName: 'Sharma Stores',
      merchantCity: 'Bengaluru',
      amount: UpiAmount.parse('149.50'),
    ).payload.replaceFirst('149.50', '949.50'),
    'Broken link': 'UPI://PAY?PA=shop&AM=0&CU=USD',
  };

  final _input = TextEditingController(text: _samples['Bharat QR']);

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final input = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Paste what your QR scanner read',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _input,
          onChanged: (_) => setState(() {}),
          minLines: 4,
          maxLines: 8,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'upi://pay?pa=… or 000201…',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in _samples.entries)
              ActionChip(
                label: Text(entry.key),
                onPressed: () => setState(() => _input.text = entry.value),
              ),
          ],
        ),
      ],
    );
    return _Columns(left: input, right: _DecodeResult(_input.text));
  }
}

class _DecodeResult extends StatelessWidget {
  const _DecodeResult(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final UpiQr qr;
    try {
      qr = UpiQr.parse(text);
    } on FormatException catch (e) {
      return Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: ListTile(
          leading: const Icon(Icons.error_outline),
          title: const Text('Can’t read this'),
          subtitle: Text(e.message),
        ),
      );
    }

    final (kind, rows) = switch (qr) {
      UpiLinkQr(:final link) => (
        'UPI payment link',
        {
          'Pay to (pa)': link.payeeVpa,
          'Name (pn)': link.payeeName,
          'Amount (am)': link.amount?.toString(),
          'Minimum (mam)': link.minimumAmount?.toString(),
          'Note (tn)': link.note,
          'Reference (tr)': link.transactionRef,
          'Category (mc)': link.merchantCategoryCode,
          'Currency (cu)': link.currency,
          for (final e in link.extra.entries) e.key: e.value,
        },
      ),
      EmvUpiQr(:final qr) => (
        'EMV / Bharat QR · ${qr.pointOfInitiation == PointOfInitiation.dynamicCode ? 'one-time' : 'reusable'} code',
        {
          'Pay to (26·01)': qr.upi?.vpa,
          'Merchant (59)': qr.merchantName,
          'City (60)': qr.merchantCity,
          'Amount (54)': qr.amount?.toString(),
          'Reference (27·01)': qr.upi?.transactionRef,
          'Category (52)': qr.merchantCategoryCode,
          'Currency (53)': qr.currencyCode,
          'Country (58)': qr.countryCode,
          'Bill number (62·01)': qr.additionalData?.billNumber,
          'Other accounts': qr.merchantAccounts.keys
              .where((id) => id != '26' && id != '27')
              .join(', '),
          'CRC (63)': '${qr.crc} ✓',
        },
      ),
    };
    final link = qr.toPaymentLink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(kind, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Table(
              columnWidths: const {0: IntrinsicColumnWidth()},
              children: [
                for (final row in rows.entries)
                  if (row.value != null && row.value!.isNotEmpty)
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 4, 16, 4),
                          child: Text(
                            row.key,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: SelectableText(row.value!),
                        ),
                      ],
                    ),
              ],
            ),
            const SizedBox(height: 12),
            _IssueList(qr.validate()),
            if (link != null && qr is EmvUpiQr) ...[
              const SizedBox(height: 12),
              Text(
                'Same payment as a UPI link',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              _PayloadBox(link.toLink()),
            ],
          ],
        ),
      ),
    );
  }
}

class _PayloadBox extends StatelessWidget {
  const _PayloadBox(this.payload);

  final String payload;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              payload,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: payload));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Copied')));
            },
          ),
        ],
      ),
    );
  }
}

class _IssueList extends StatelessWidget {
  const _IssueList(this.issues);

  final List<UpiIssue> issues;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (issues.isEmpty) {
      return Row(
        children: [
          Icon(Icons.check_circle, color: scheme.primary),
          const SizedBox(width: 8),
          const Text('No issues: UPI apps should accept this'),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final issue in issues)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  issue.isError ? Icons.error : Icons.warning_amber,
                  size: 20,
                  color: issue.isError ? scheme.error : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text('${issue.field}: ${issue.message}')),
              ],
            ),
          ),
      ],
    );
  }
}
