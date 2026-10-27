/// How serious an [UpiIssue] is.
enum UpiIssueSeverity {
  /// Payment apps will reject the payment.
  error,

  /// Payment apps may accept it, but often warn the payer or behave
  /// differently from app to app.
  warning,
}

/// What an [UpiIssue] is about.
enum UpiIssueCode {
  invalidVpa,
  missingPayeeName,
  zeroAmount,
  minimumAboveAmount,
  invalidMerchantCategoryCode,
  unsupportedCurrency,
  transactionRefLength,
  invalidUrl,
  missingField,
  unexpectedValue,
}

/// A problem found by `validate()` on a payment link or an EMV QR code.
final class UpiIssue {
  const UpiIssue(this.code, this.field, this.message,
      {this.severity = UpiIssueSeverity.error});

  final UpiIssueCode code;

  /// The parameter (`pa`, `am`) or EMV tag (`59`) the issue is about.
  final String field;

  /// A sentence you can show a developer or log.
  final String message;

  final UpiIssueSeverity severity;

  bool get isError => severity == UpiIssueSeverity.error;

  @override
  String toString() => '${severity.name} [$field] $message';
}
