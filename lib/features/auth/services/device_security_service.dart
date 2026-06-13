import '../models/device_models.dart';

/// Service responsible for device registration and validation logic.
class DeviceSecurityService {
  final Map<String, DeviceRegistration> _registeredDevices = {};
  DeviceInfo? _currentDevice;

  DeviceSecurityService({DeviceInfo? currentDevice})
      : _currentDevice = currentDevice;

  /// Registers a device for the given user.
  Future<DeviceRegistration> registerDevice({
    required String registrationId,
    required String userId,
    required DeviceInfo deviceInfo,
  }) async {
    final registration = DeviceRegistration(
      registrationId: registrationId,
      userId: userId,
      deviceInfo: deviceInfo,
      status: DeviceStatus.registered,
      registeredAt: DateTime.now(),
      lastSeenAt: DateTime.now(),
    );

    _registeredDevices[registrationId] = registration;
    _currentDevice = deviceInfo;
    return registration;
  }

  /// Validates whether the device is currently registered and active.
  Future<bool> validateDevice({
    required String registrationId,
    required String userId,
  }) async {
    final registration = _registeredDevices[registrationId];
    if (registration == null) {
      return false;
    }
    final isOwner = registration.userId == userId;
    final isActive = registration.status == DeviceStatus.registered || registration.status == DeviceStatus.pending;
    if (isOwner && isActive) {
      _registeredDevices[registrationId] = registration.copyWith(lastSeenAt: DateTime.now());
      return true;
    }
    return false;
  }

  /// Revokes a registered device.
  Future<bool> revokeDevice(String registrationId) async {
    final registration = _registeredDevices[registrationId];
    if (registration == null) {
      return false;
    }

    _registeredDevices[registrationId] = registration.copyWith(status: DeviceStatus.blocked);
    return true;
  }

  /// Returns the currently active device information.
  DeviceInfo? getCurrentDevice() {
    return _currentDevice;
  }

  /// Loads a device registration entry by ID.
  DeviceRegistration? getDeviceRegistration(String registrationId) {
    return _registeredDevices[registrationId];
  }
}
