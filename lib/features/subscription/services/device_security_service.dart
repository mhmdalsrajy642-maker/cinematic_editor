// lib/features/subscription/services/device_security_service.dart
// هذا الملف يبني نظام الحماية المتكامل للفترة التجريبية
// يربط الحساب ببصمة الجهاز بشكل دائم لمنع التحايل
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../shared/constants/app_constants.dart';
class DeviceSecurityService {
  final FlutterSecureStorage _secureStorage;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  DeviceSecurityService()
      : _secureStorage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock,
          ),
        );
  // ====================================================
  // الحصول على بصمة الجهاز الفريدة
  // تجمع معلومات متعددة لضمان التفرد وصعوبة التزوير
  // ====================================================
  Future<String> getDeviceFingerprint() async {
    // تحقق أولاً إذا كانت البصمة محفوظة مسبقاً
    final stored = await _secureStorage.read(key: AppConstants.deviceIdKey);
    if (stored != null) return stored;
    // بناء البصمة من معلومات الجهاز
    final rawFingerprint = await _buildRawFingerprint();
    
    // تشفير البصمة بـ SHA-256 لجعلها أمنة
    final bytes = utf8.encode(rawFingerprint);
    final digest = sha256.convert(bytes);
    final fingerprint = digest.toString();
    // حفظ البصمة في مخزن مشفر
    await _secureStorage.write(
      key: AppConstants.deviceIdKey,
      value: fingerprint,
    );
    return fingerprint;
  }
  // ====================================================
  // بناء البصمة الخام من معلومات الجهاز
  // ====================================================
  Future<String> _buildRawFingerprint() async {
    final components = <String>[];
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      // معرف الجهاز الفريد من أندرويد
      components.addAll([
        androidInfo.id,
        androidInfo.brand,
        androidInfo.model,
        androidInfo.board,
        androidInfo.bootloader,
        androidInfo.hardware,
        androidInfo.host,
      ]);
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      // معرف الجهاز من iOS
      components.addAll([
        iosInfo.identifierForVendor ?? '',
        iosInfo.model,
        iosInfo.name,
        iosInfo.systemVersion,
      ]);
    }
    // إضافة اسم التطبيق لضمان تفرد البصمة لكل تطبيق
    final packageInfo = await PackageInfo.fromPlatform();
    components.add(packageInfo.packageName);
    return components.join('|');
  }
  // ====================================================
  // التحقق من حالة الفترة التجريبية
  // ====================================================
  Future<TrialStatus> checkTrialStatus() async {
    final deviceId = await getDeviceFingerprint();
    
    // جلب تاريخ بداية التجربة من التخزين المشفر
    final trialStartStr = await _secureStorage.read(
      key: AppConstants.trialStartKey,
    );
    
    if (trialStartStr == null) {
      // أول تشغيل للتطبيق - بدء الفترة التجريبية
      return TrialStatus(
        isFirstLaunch: true,
        isTrialActive: false,
        daysRemaining: 0,
        deviceId: deviceId,
        trialStartDate: null,
      );
    }
    
    final trialStart = DateTime.fromMillisecondsSinceEpoch(
      int.parse(trialStartStr),
    );
    final now = DateTime.now();
    final daysPassed = now.difference(trialStart).inDays;
    final daysRemaining = AppConstants.freeTrialDays - daysPassed;
    return TrialStatus(
      isFirstLaunch: false,
      isTrialActive: daysRemaining > 0,
      daysRemaining: daysRemaining.clamp(0, AppConstants.freeTrialDays),
      deviceId: deviceId,
      trialStartDate: trialStart,
    );
  }
  // ====================================================
  // بدء الفترة التجريبية (يُستدعى مرة واحدة فقط)
  // ====================================================
  Future<void> startTrial() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _secureStorage.write(
      key: AppConstants.trialStartKey,
      value: now.toString(),
    );
  }
  // ====================================================
  // التحقق من حدود التصدير
  // ====================================================
  Future<ExportPermission> checkExportPermission({
    required String resolution,
    required bool hasSubscription,
  }) async {
    // المشتركون لديهم تصدير غير محدود
    if (hasSubscription) {
      return ExportPermission.allowed();
    }
    final trialStatus = await checkTrialStatus();
    
    // إذا انتهت الفترة التجريبية، لا يُسمح بالتصدير بجودة عالية
    if (!trialStatus.isTrialActive) {
      if (resolution == '4K' || resolution == '1080p') {
        return ExportPermission.denied(
          reason: 'انتهت فترتك التجريبية. اشترك لمواصلة التصدير.',
        );
      }
    }
    // حساب عدد مرات التصدير
    final exportCountKey = AppConstants.exportCountKey + resolution;
    final countStr = await _secureStorage.read(key: exportCountKey) ?? '0';
    final exportCount = int.parse(countStr);
    final limit = resolution == '4K'
        ? AppConstants.freeExportLimit4K
        : AppConstants.freeExportLimit1080p;
    if (exportCount >= limit) {
      return ExportPermission.denied(
        reason: 'وصلت للحد الأقصى للتصدير المجاني ($limit مرة).',
        currentCount: exportCount,
        limit: limit,
      );
    }
    return ExportPermission.allowed(
      currentCount: exportCount,
      limit: limit,
    );
  }
  // ====================================================
  // زيادة عداد التصدير
  // ====================================================
  Future<void> incrementExportCount(String resolution) async {
    final exportCountKey = AppConstants.exportCountKey + resolution;
    final countStr = await _secureStorage.read(key: exportCountKey) ?? '0';
    final newCount = int.parse(countStr) + 1;
    await _secureStorage.write(
      key: exportCountKey,
      value: newCount.toString(),
    );
  }
  // ====================================================
  // تسجيل الجهاز في السيرفر (يُستدعى عند التسجيل)
  // ====================================================
  Future<bool> registerDeviceWithServer({
    required String userId,
    required String userToken,
  }) async {
    try {
      final deviceId = await getDeviceFingerprint();
      
      // سيتم إرسال البصمة للسيرفر لتسجيلها مع الحساب
      // هذا يمنع استخدام الفترة التجريبية مرتين بنفس الجهاز
      // حتى بعد حذف التطبيق وإعادة تثبيته
      
      // TODO: استدعاء API لتسجيل الجهاز
      // await _apiService.registerDevice(userId, deviceId, userToken);
      
      return true;
    } catch (e) {
      return false;
    }
  }
}
// ====================================================
// نماذج البيانات
// ====================================================
class TrialStatus {
  final bool isFirstLaunch;
  final bool isTrialActive;
  final int daysRemaining;
  final String deviceId;
  final DateTime? trialStartDate;
  const TrialStatus({
    required this.isFirstLaunch,
    required this.isTrialActive,
    required this.daysRemaining,
    required this.deviceId,
    required this.trialStartDate,
  });
}
class ExportPermission {
  final bool isAllowed;
  final String? denialReason;
  final int? currentCount;
  final int? limit;
  const ExportPermission._({
    required this.isAllowed,
    this.denialReason,
    this.currentCount,
    this.limit,
  });
  factory ExportPermission.allowed({int? currentCount, int? limit}) {
    return ExportPermission._(
      isAllowed: true,
      currentCount: currentCount,
      limit: limit,
    );
  }
  factory ExportPermission.denied({
    required String reason,
    int? currentCount,
    int? limit,
  }) {
    return ExportPermission._(
      isAllowed: false,
      denialReason: reason,
      currentCount: currentCount,
      limit: limit,
    );
  }
}
