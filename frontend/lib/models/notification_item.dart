enum NotificationType { info, success, warning, win }

extension NotificationTypeExtension on NotificationType {
  static NotificationType fromString(String val) {
    switch (val.toLowerCase()) {
      case 'success':
        return NotificationType.success;
      case 'warning':
        return NotificationType.warning;
      case 'win':
        return NotificationType.win;
      case 'info':
      default:
        return NotificationType.info;
    }
  }
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final String timestamp;
  final bool read;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    this.type = NotificationType.info,
    required this.timestamp,
    this.read = false,
  });

  NotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    String? timestamp,
    bool? read,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      read: read ?? this.read,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'type': type.name,
        'timestamp': timestamp,
        'read': read,
      };

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        type: NotificationTypeExtension.fromString(
            json['type'] as String? ?? 'info'),
        timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
        read: json['read'] as bool? ?? false,
      );
}
