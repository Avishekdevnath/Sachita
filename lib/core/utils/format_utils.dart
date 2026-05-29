import 'package:flutter/material.dart';

String greetingFor(DateTime now) {
  final hour = now.hour;
  if (hour < 12) {
    return 'Good morning';
  }
  if (hour < 17) {
    return 'Good afternoon';
  }
  return 'Good evening';
}

String formatDate(DateTime date) {
  final y = date.year;
  final m = monthName(date.month);
  final d = date.day;
  final dow = dayOfWeek(date.weekday);
  return '$dow, $d $m $y';
}

String monthName(int month) {
  const months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  return months[month - 1];
}

String dayOfWeek(int weekday) {
  const days = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  return days[weekday - 1];
}

String formatAmount({
  required int paisa,
  required String currencySymbol,
  bool includeSign = false,
}) {
  if (!includeSign) {
    return '$currencySymbol ${(paisa / 100).toStringAsFixed(2)}';
  }

  final sign = paisa >= 0 ? '+' : '-';
  final absolute = paisa.abs();
  final absoluteAmount = (absolute / 100).toStringAsFixed(2);
  return '$sign$currencySymbol $absoluteAmount';
}

IconData iconForGroup(String iconKey) {
  switch (iconKey) {
    case 'group':
      return Icons.group_outlined;
    case 'family':
      return Icons.family_restroom_outlined;
    case 'home':
      return Icons.home_outlined;
    case 'work':
      return Icons.work_outline;
    case 'travel':
      return Icons.luggage_outlined;
    case 'event':
      return Icons.event_outlined;
    default:
      return Icons.group_outlined;
  }
}

Color parseColor(String hexColor) {
  final cleaned = hexColor.trim().replaceFirst('#', '');
  final parsed = int.tryParse('FF$cleaned', radix: 16);
  if (parsed == null) {
    return const Color(0xFF4ECDC4);
  }
  return Color(parsed);
}
