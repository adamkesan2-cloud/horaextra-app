// lib/data/models/request/service_request_model.dart (completo)
import 'package:horaextra_app/data/models/location/location_model.dart';

class ServiceRequestModel {
  final String id;
  final String serviceId;
  final String serviceName;
  final String clientId;
  final String clientName;
  final String clientAddress;
  final double clientLatitude;
  final double clientLongitude;
  final String? providerId;
  final String? providerName;
  final double price;
  String _status;
  final bool isUrgent;
  final DateTime createdAt;
  final DateTime? scheduledDate;
  final String? observations;
  final Map<String, dynamic>? metadata;

  String get status => _status;
  set status(String value) {
    _status = value;
  }

  double get clientLat => clientLatitude;
  double get clientLng => clientLongitude;
  String? get providerPhone => null;

  ServiceRequestModel({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.clientId,
    required this.clientName,
    required this.clientAddress,
    required this.clientLatitude,
    required this.clientLongitude,
    this.providerId,
    this.providerName,
    required this.price,
    required String status,
    this.isUrgent = false,
    required this.createdAt,
    this.scheduledDate,
    this.observations,
    this.metadata,
  }) : _status = status;

  factory ServiceRequestModel.fromJson(Map<String, dynamic> json) {
    return ServiceRequestModel(
      id: json['id'] ?? '',
      serviceId: json['service_id'] ?? '',
      serviceName: json['service_name'] ?? '',
      clientId: json['client_id'] ?? '',
      clientName: json['client_name'] ?? '',
      clientAddress: json['client_address'] ?? 'Maputo, Moçambique',
      clientLatitude: (json['client_latitude'] ?? -25.9692).toDouble(),
      clientLongitude: (json['client_longitude'] ?? 32.5732).toDouble(),
      providerId: json['provider_id'],
      providerName: json['provider_name'],
      price: (json['price'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      isUrgent: json['is_urgent'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      scheduledDate: json['scheduled_date'] != null
          ? DateTime.parse(json['scheduled_date'])
          : null,
      observations: json['observations'],
      metadata: json['metadata'],
    );
  }

  get pricePerProvider => null;

  get providerCount => null;

  get isPriceDivided => null;

  get acceptedProviders => null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'service_id': serviceId,
        'service_name': serviceName,
        'client_id': clientId,
        'client_name': clientName,
        'client_address': clientAddress,
        'client_latitude': clientLatitude,
        'client_longitude': clientLongitude,
        'provider_id': providerId,
        'provider_name': providerName,
        'price': price,
        'status': _status,
        'is_urgent': isUrgent,
        'created_at': createdAt.toIso8601String(),
        'scheduled_date': scheduledDate?.toIso8601String(),
        'observations': observations,
        'metadata': metadata,
      };
}
