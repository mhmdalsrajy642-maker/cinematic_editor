// lib/main.dart
// نقطة الانطلاق الرئيسية للتطبيق
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'features/ai_commands/presentation/cubit/ai_cubit.dart';
import 'features/ai_commands/services/ai_command_parser_service.dart';
import 'features/ai_commands/services/background_removal_service.dart';
import 'features/ai_commands/services/inference_pipeline_service.dart';
import 'features/ai_commands/services/local_ai_engine.dart';
import 'features/ai_commands/services/model_download_service.dart';
import 'features/audio/services/auto_caption_service.dart';
import 'features/editor/presentation/screens/editor_screen.dart';
import 'features/editor/services/motion_tracking_service.dart';
import 'features/editor/services/stabilization_service.dart';
import 'features/subscription/services/device_security_service.dart';
import 'features/export/domain/export_queue_service.dart';
import 'features/export/domain/export_service.dart';
import 'features/export/services/export_pipeline_service.dart';
import 'core/services/proxy_generation_service.dart';
import 'core/services/task_queue_service.dart';
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

  // AI services
  serviceLocator.registerLazySingleton<LocalAiEngine>(
    () => LocalAiEngine(),
  );
  serviceLocator.registerLazySingleton<AiCommandParserService>(
    () => AiCommandParserService(),
  );
  serviceLocator.registerLazySingleton<BackgroundRemovalService>(
    () => BackgroundRemovalService.withDefaults(
      engine: serviceLocator<LocalAiEngine>(),
    ),
  );
  serviceLocator.registerLazySingleton<ModelDownloadService>(
    () => ModelDownloadService(
      aiEngine: serviceLocator<LocalAiEngine>(),
    ),
  );
  serviceLocator.registerLazySingleton<TaskQueueService>(
    () => TaskQueueService(),
  );
  serviceLocator.registerLazySingleton<ProxyGenerationService>(
    () => ProxyGenerationService(
      taskQueueService: serviceLocator<TaskQueueService>(),
    ),
  );
  serviceLocator.registerLazySingleton<AutoCaptionService>(
    () => AutoCaptionService(),
  );
  serviceLocator.registerLazySingleton<MotionTrackingService>(
    () => MotionTrackingService(),
  );
  serviceLocator.registerLazySingleton<StabilizationService>(
    () => StabilizationService(),
  );
  serviceLocator.registerLazySingleton<InferencePipelineService>(
    () => InferencePipelineService(
      parserService: serviceLocator<AiCommandParserService>(),
      aiEngine: serviceLocator<LocalAiEngine>(),
      backgroundRemovalService: serviceLocator<BackgroundRemovalService>(),
      downloadService: serviceLocator<ModelDownloadService>(),
      captionService: serviceLocator<AutoCaptionService>(),
    ),
  );
  serviceLocator.registerLazySingleton<ExportService>(
    () => ExportService(
      securityService: serviceLocator<DeviceSecurityService>(),
    ),
  );
  serviceLocator.registerLazySingleton<ExportPipelineService>(
    () => ExportPipelineService(
      exportService: serviceLocator<ExportService>(),
    ),
  );
  serviceLocator.registerLazySingleton<ExportQueueService>(
    () => ExportQueueService(
      pipelineService: serviceLocator<ExportPipelineService>(),
    ),
  );
  serviceLocator.registerFactory<AICubit>(
    () => AICubit(
      inferencePipelineService:
          serviceLocator<InferencePipelineService>(),
    ),
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
