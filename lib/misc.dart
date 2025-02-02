import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

extension DateExtensions on DateTime {
  String format(String format) => DateFormat(format).format(this);

  String diffForHumans([DateTime? other]) {
    return timeago.format(
      other ?? this,
      locale: 'en',
      allowFromNow: false,
    );
  }

  String diffForHumansShort([DateTime? other]) {
    return timeago.format(
      other ?? this,
      locale: 'en_short',
      allowFromNow: false,
    );
  }
}
