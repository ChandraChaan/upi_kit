## 0.1.0

- First release.
- `UpiPaymentLink`: build, parse and validate `upi://pay` links, with app-specific links for iOS (`UpiApp`).
- `EmvQr`: parse and build EMV merchant-presented QR codes (Bharat QR), with CRC-16 checking and typed UPI, amount and additional-data fields.
- `UpiQr`: one entry point for whatever a QR scanner returns.
- `UpiAmount` (whole paise, no floating point) and `Vpa` (UPI ID format).
