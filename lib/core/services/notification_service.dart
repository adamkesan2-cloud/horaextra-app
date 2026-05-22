// lib/core/services/notification_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:horaextra_app/core/providers/app_provider.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final StreamController<Map<String, dynamic>> _requestStream =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get requestStream => _requestStream.stream;

  void notifyNewRequest(Map<String, dynamic> request) {
    _requestStream.add(request);
  }

  void notifyProviderResponse(
      String requestId, String providerId, bool accepted) {
    _requestStream.add({
      'type': 'response',
      'requestId': requestId,
      'providerId': providerId,
      'accepted': accepted,
    });
  }

  void dispose() {
    _requestStream.close();
  }
}
