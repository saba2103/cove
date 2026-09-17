import 'package:intl/intl.dart';

/// Centralized Indian numbering system formatter (e.g. 1,00,00,000 format).
final NumberFormat _coveAmountFormat = NumberFormat('#,##,##0.00', 'en_IN');
final NumberFormat _coveIntegerAmountFormat = NumberFormat('#,##,##0', 'en_IN');

/// Formats a numeric amount string using the 1,00,00,000 Indian comma pattern with 2 decimal places.
String formatCoveAmount(num amount) {
  return _coveAmountFormat.format(amount);
}

/// Formats an integer amount string using the 1,00,00,000 Indian comma pattern without decimals.
String formatCoveIntegerAmount(num amount) {
  return _coveIntegerAmountFormat.format(amount);
}

/// Formats an amount with optional decimals: omits decimals if exactly whole, else 2 decimal places.
String formatCoveAmountAuto(num amount) {
  if (amount % 1 == 0) {
    return _coveIntegerAmountFormat.format(amount);
  }
  return _coveAmountFormat.format(amount);
}

/// Formats an amount prefixed by the given currency symbol using the 1,00,00,000 Indian comma pattern.
String formatCoveCurrency(num amount, String symbol, {bool? showDecimals}) {
  final bool withDecimals = showDecimals ?? (amount % 1 != 0);
  final formatted = withDecimals ? _coveAmountFormat.format(amount) : _coveIntegerAmountFormat.format(amount);
  return '$symbol$formatted';
}
