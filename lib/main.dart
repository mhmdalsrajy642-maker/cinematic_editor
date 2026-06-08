// lib/main.dart
// نقطة الانطلاق الرئيسية للتطبيق
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'shared/theme/app_theme.dart';
import 'features/editor/presentation/screens/editor_screen.dart';
import 'features/subscription/services/device_security_service.dart';
// حاوي الخدمات العالمية (Service Locator)
final GetIt serviceLocator = GetIt.instance;
Future<void> main() async {
  // التأكد من تهيئة Flutter قبل أي عملية
  WidgetsFlutterBinding.ensureInitialized();
  // إجبار الشاشة على الوضع الرأسي فقط
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // تهيئة الخدمات العالمية
  await _initializeServices();
  runApp(const CinematicEditorApp());
}
Future<void> _initializeServices() async {
  // تسجيل الخدمات في حاوي الاعتماديات
  serviceLocator.registerLazySingleton<DeviceSecurityService>(
    () => DeviceSecurityService(),
  );
}
class CinematicEditorApp extends StatelessWidget {
  const CinematicEditorApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cinematic Editor',
      debugShowCheckedModeBanner: false,
      // تطبيق الثيم الداكن
      theme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      // الصفحة الرئيسية (مؤقتاً المحرر مباشرة، لاحقاً ستُضاف شاشة البداية)
      home: const EditorScreen(projectId: 'default_project'),
      // إعدادات الأداء
      builder: (context, child) {
        return ScrollConfiguration(
          // إزالة أثر التمرير الأزرق في أندرويد
          behavior: const ScrollBehavior().copyWith(overscroll: false),
          child: child!,
        );
      },
    );
  }
}
