// lib/core/services/realtime_notification_service.dart
import 'dart:async';

class RealtimeNotificationService {
  static final RealtimeNotificationService _instance =
      RealtimeNotificationService._internal();
  factory RealtimeNotificationService() => _instance;
  RealtimeNotificationService._internal();

  final StreamController<Map<String, dynamic>> _notificationStream =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationStream.stream;

  void notifyNewRequest(Map<String, dynamic> data) {
    _notificationStream.add({
      'type': 'new_request',
      'timestamp': DateTime.now().toIso8601String(),
      ...data,
    });
  }

  void notifyResponse(Map<String, dynamic> data) {
    _notificationStream.add({
      'type': 'response',
      'timestamp': DateTime.now().toIso8601String(),
      ...data,
    });
  }

  void notifyStatusUpdate(Map<String, dynamic> data) {
    _notificationStream.add({
      'type': 'status_update',
      'timestamp': DateTime.now().toIso8601String(),
      ...data,
    });
  }

  void dispose() {
    _notificationStream.close();
  }
}
