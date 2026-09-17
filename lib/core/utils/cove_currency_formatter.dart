import 'package:intl/intl.dart';

/// Centralized Indian numbering system formatter (e.g. 1,00,00,000 format).
final NumberFormat _coveDecimalAmountFormat = NumberFormat('#,##,##0.##', 'en_IN');
final NumberFormat _coveIntegerAmountFormat = NumberFormat('#,##,##0', 'en_IN');

/// Formats a numeric amount string using the 1,00,00,000 Indian comma pattern.
/// If decimal value is .00 then omits decimals; only shows decimals (up to 2 places) if non-zero.
String formatCoveAmount(num amount) {
  final roundedCents = (amount * 100).round();
  if (roundedCents % 100 == 0) {
    return _coveIntegerAmountFormat.format(roundedCents ~/ 100);
  }
  return _coveDecimalAmountFormat.format(roundedCents / 100.0);
}

/// Formats an integer amount string using the 1,00,00,000 Indian comma pattern without decimals.
String formatCoveIntegerAmount(num amount) {
  return _coveIntegerAmountFormat.format(amount);
}

/// Formats an amount with optional decimals: omits decimals if .00, else up to 2 decimal places.
String formatCoveAmountAuto(num amount) {
  return formatCoveAmount(amount);
}

/// Formats an amount prefixed by the given currency symbol using the 1,00,00,000 Indian comma pattern.
String formatCoveCurrency(num amount, String symbol, {bool? showDecimals}) {
  if (showDecimals == false) {
    return '$symbol${formatCoveIntegerAmount(amount)}';
  }
  return '$symbol${formatCoveAmount(amount)}';
}
