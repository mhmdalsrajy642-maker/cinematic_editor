// lib/features/auth/models/device_models.dart

import 'package:equatable/equatable.dart';

enum DeviceStatus {
  registered,
  unregistered,
  pending,
  blocked,
}

extension DeviceStatusX on DeviceStatus {
  String toJson() => name;

  static DeviceStatus fromJson(String value) {
    return DeviceStatus.values.byName(value);
  }
}

class DeviceInfo extends Equatable {
  final String deviceId;
  final String manufacturer;
  final String model;
  final String osVersion;
  final String locale;

  const DeviceInfo({
    required this.deviceId,
    required this.manufacturer,
    required this.model,
    required this.osVersion,
    required this.locale,
  });

  DeviceInfo copyWith({
    String? deviceId,
    String? manufacturer,
    String? model,
    String? osVersion,
    String? locale,
  }) {
    return DeviceInfo(
      deviceId: deviceId ?? this.deviceId,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      osVersion: osVersion ?? this.osVersion,
      locale: locale ?? this.locale,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'manufacturer': manufacturer,
      'model': model,
      'osVersion': osVersion,
      'locale': locale,
    };
  }

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      deviceId: json['deviceId'] as String,
      manufacturer: json['manufacturer'] as String,
      model: json['model'] as String,
      osVersion: json['osVersion'] as String,
      locale: json['locale'] as String,
    );
  }

  @override
  List<Object?> get props => [deviceId, manufacturer, model, osVersion, locale];
}

class DeviceRegistration extends Equatable {
  final String registrationId;
  final String userId;
  final DeviceInfo deviceInfo;
  final DeviceStatus status;
  final DateTime registeredAt;
  final DateTime? lastSeenAt;

  const DeviceRegistration({
    required this.registrationId,
    required this.userId,
    required this.deviceInfo,
    required this.status,
    required this.registeredAt,
    this.lastSeenAt,
  });

  DeviceRegistration copyWith({
    String? registrationId,
    String? userId,
    DeviceInfo? deviceInfo,
    DeviceStatus? status,
    DateTime? registeredAt,
    DateTime? lastSeenAt,
  }) {
    return DeviceRegistration(
      registrationId: registrationId ?? this.registrationId,
      userId: userId ?? this.userId,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      status: status ?? this.status,
      registeredAt: registeredAt ?? this.registeredAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'registrationId': registrationId,
      'userId': userId,
      'deviceInfo': deviceInfo.toJson(),
      'status': status.toJson(),
      'registeredAt': registeredAt.toIso8601String(),
      'lastSeenAt': lastSeenAt?.toIso8601String(),
    };
  }

  factory DeviceRegistration.fromJson(Map<String, dynamic> json) {
    return DeviceRegistration(
      registrationId: json['registrationId'] as String,
      userId: json['userId'] as String,
      deviceInfo: DeviceInfo.fromJson(json['deviceInfo'] as Map<String, dynamic>),
      status: DeviceStatusX.fromJson(json['status'] as String),
      registeredAt: DateTime.parse(json['registeredAt'] as String),
      lastSeenAt: json['lastSeenAt'] == null
          ? null
          : DateTime.parse(json['lastSeenAt'] as String),
    );
  }

  @override
  List<Object?> get props => [registrationId, userId, deviceInfo, status, registeredAt, lastSeenAt];
}
