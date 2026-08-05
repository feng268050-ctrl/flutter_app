import 'package:flutter/widgets.dart';

/// Product chrome date + weekday (home clock line / page status-bar prefix).
///
/// - English: `Wed Aug 5`
/// - Chinese (CN): `8月5日 周三` (space before weekday)
/// - Chinese (TW): `8月5日 週三`
String formatProductDateWeekday(DateTime date, Locale locale) {
  if (locale.languageCode == 'zh') {
    final traditional = locale.countryCode == 'TW' ||
        locale.scriptCode == 'Hant';
    final week = traditional
        ? const ['週一', '週二', '週三', '週四', '週五', '週六', '週日']
        : const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${date.month}月${date.day}日 ${week[date.weekday - 1]}';
  }

  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${weekdays[date.weekday - 1]} ${months[date.month - 1]} ${date.day}';
}
