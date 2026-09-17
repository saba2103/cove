import 'dart:convert';
import 'package:intl/intl.dart';

class CheckinReminder {
  final String id;
  final int hour;
  final int minute;
  final String message;
  final bool isEnabled;
  final DateTime createdAt;

  const CheckinReminder({
    required this.id,
    required this.hour,
    required this.minute,
    required this.message,
    this.isEnabled = true,
    required this.createdAt,
  });

  String get formattedTime {
    final dt = DateTime(2026, 1, 1, hour, minute);
    return DateFormat('h:mm a').format(dt);
  }

  CheckinReminder copyWith({
    String? id,
    int? hour,
    int? minute,
    String? message,
    bool? isEnabled,
    DateTime? createdAt,
  }) {
    return CheckinReminder(
      id: id ?? this.id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      message: message ?? this.message,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hour': hour,
      'minute': minute,
      'message': message,
      'isEnabled': isEnabled,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CheckinReminder.fromMap(Map<String, dynamic> map) {
    return CheckinReminder(
      id: map['id'] as String,
      hour: map['hour'] as int,
      minute: map['minute'] as int,
      message: (map['message'] as String?) ?? 'A quiet moment for us • Check in on our sanctuary',
      isEnabled: map['isEnabled'] as bool? ?? true,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory CheckinReminder.fromJson(String source) =>
      CheckinReminder.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

const List<String> kDefaultWarmPresets = [
  'A quiet moment for us • Check in on our sanctuary',
  'Take a breath together • Reflect on today’s little joys',
  'How was your day? Let’s stay close & in sync.',
  'A gentle pause to share our calm rhythm.',
  'Thinking of you & our home. Open Cove to stay connected.',
  'Evening unwind • A loving moment to reflect together.',
  'Morning light • Beginning our day in quiet harmony.',
];
