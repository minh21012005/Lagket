import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

class DateFormatter {
  DateFormatter._();

  static String timeAgo(DateTime dateTime) {
    return timeago.format(dateTime, locale: 'en_short');
  }

  static String timeAgoLong(DateTime dateTime) {
    return timeago.format(dateTime);
  }

  static String formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays == 0) {
      return 'Today ${DateFormat('h:mm a').format(dateTime)}';
    } else if (diff.inDays == 1) {
      return 'Yesterday ${DateFormat('h:mm a').format(dateTime)}';
    } else if (diff.inDays < 7) {
      return DateFormat('EEEE, h:mm a').format(dateTime);
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }

  static String formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  static String formatShort(DateTime dateTime) {
    return DateFormat('MMM d').format(dateTime);
  }
}
