import 'package:intl/intl.dart';

/// 日期工具类
class DateUtils {
  static const String defaultDateFormat = 'yyyy-MM-dd';
  static const String defaultDateTimeFormat = 'yyyy-MM-dd HH:mm:ss';
  static const String displayDateFormat = 'yyyy年MM月dd日';

  /// 格式化日期
  static String formatDate(DateTime date, {String pattern = defaultDateFormat}) {
    return DateFormat(pattern).format(date);
  }

  /// 格式化日期时间
  static String formatDateTime(DateTime date, {String pattern = defaultDateTimeFormat}) {
    return DateFormat(pattern).format(date);
  }

  /// 格式化显示日期
  static String formatDisplayDate(DateTime date) {
    return DateFormat(displayDateFormat).format(date);
  }

  /// 解析日期字符串
  static DateTime? parseDate(String dateStr, {String pattern = defaultDateFormat}) {
    try {
      return DateFormat(pattern).parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  /// 获取今天的日期（仅日期部分）
  static DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// 获取某日期的开始时间
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// 获取某日期的结束时间
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  /// 计算两个日期之间的天数差
  static int daysBetween(DateTime from, DateTime to) {
    from = startOfDay(from);
    to = startOfDay(to);
    return to.difference(from).inDays;
  }

  /// 格式化 Duration 为友好的显示文本
  static String formatDuration(Duration duration) {
    final days = duration.inDays;
    if (days >= 365) {
      final years = (days / 365).toStringAsFixed(1);
      return '${years}年';
    } else if (days >= 30) {
      final months = (days / 30).toStringAsFixed(1);
      return '${months}个月';
    } else if (days > 0) {
      return '${days}天';
    } else {
      final hours = duration.inHours;
      if (hours > 0) {
        return '${hours}小时';
      }
      final minutes = duration.inMinutes;
      if (minutes > 0) {
        return '${minutes}分钟';
      }
      return '刚刚';
    }
  }

  /// 判断是否是今天
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  /// 判断是否是昨天
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year && 
           date.month == yesterday.month && 
           date.day == yesterday.day;
  }

  /// 获取相对时间描述
  static String getRelativeTime(DateTime date) {
    if (isToday(date)) {
      return '今天';
    } else if (isYesterday(date)) {
      return '昨天';
    } else {
      final days = daysBetween(date, DateTime.now());
      if (days < 7) {
        return '${days}天前';
      } else if (days < 30) {
        final weeks = (days / 7).floor();
        return '${weeks}周前';
      } else if (days < 365) {
        final months = (days / 30).floor();
        return '${months}个月前';
      } else {
        final years = (days / 365).floor();
        return '${years}年前';
      }
    }
  }
}
