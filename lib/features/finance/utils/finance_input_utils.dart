import 'package:intl/intl.dart';

class FinanceInputUtils {
  const FinanceInputUtils._();

  static int? parseAmountToPaisa(
    String raw, {
    String? localeCode,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
    // Defensive null return - validation failed
      return null;
    }

    final sanitized = trimmed
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'[^0-9,\.\-\s]'), '')
        .replaceAll(' ', '');

    if (sanitized.isEmpty || sanitized == '-' || sanitized == '.' || sanitized == ',') {
    // Defensive null return - validation failed
      return null;
    }

    String normalized = sanitized;

    final hasComma = normalized.contains(',');
    final hasDot = normalized.contains('.');

    if (hasComma && hasDot) {
      final lastComma = normalized.lastIndexOf(',');
      final lastDot = normalized.lastIndexOf('.');
      final decimalSeparator = lastComma > lastDot ? ',' : '.';
      final groupingSeparator = decimalSeparator == ',' ? '.' : ',';
      normalized = normalized.replaceAll(groupingSeparator, '');
      if (decimalSeparator == ',') {
        normalized = normalized.replaceAll(',', '.');
      }
    } else if (hasComma) {
      final locale = _resolvedLocale(localeCode);
      final symbols = NumberFormat.decimalPattern(locale).symbols;
      if (symbols.DECIMAL_SEP == ',') {
        normalized = normalized.replaceAll('.', '');
        normalized = normalized.replaceAll(',', '.');
      } else {
        normalized = normalized.replaceAll(',', '');
      }
    } else if (hasDot) {
      final locale = _resolvedLocale(localeCode);
      final symbols = NumberFormat.decimalPattern(locale).symbols;
      if (symbols.DECIMAL_SEP == ',') {
        normalized = normalized.replaceAll('.', '');
      }
    }

    final value = double.tryParse(normalized);
    if (value == null) {
    // Defensive null return - validation failed
      return null;
    }

    return (value * 100).round();
  }

  static String formatFromPaisa({
    required int paisa,
    required String currencySymbol,
    int fractionDigits = 2,
  }) {
    return '$currencySymbol ${(paisa / 100).toStringAsFixed(fractionDigits)}';
  }

  static String _resolvedLocale(String? localeCode) {
    if (localeCode == null || localeCode.trim().isEmpty) {
      return 'en_US';
    }

    final normalized = localeCode.replaceAll('-', '_');
    if (normalized.contains('_')) {
      return normalized;
    }

    if (normalized == 'bn') {
      return 'bn_BD';
    }

    if (normalized == 'en') {
      return 'en_US';
    }

    return normalized;
  }
}
