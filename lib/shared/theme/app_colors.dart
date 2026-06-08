// lib/shared/theme/app_colors.dart
// هذا الملف يحدد كل ألوان التطبيق في مكان واحد مركزي
// السبب: أي تغيير في اللون المستقبلي يكون في مكان واحد فقط
import 'package:flutter/material.dart';
class AppColors {
  // منع إنشاء كائن من هذه الكلاس لأنها static فقط
  AppColors._();
  // ====== الألوان الأساسية لخلفية التطبيق ======
  // نستخدم درجات الرمادي الداكن جداً لإعطاء إحساس المونتاج الاحترافي
  static const Color backgroundPrimary = Color(0xFF0A0A0F);    // أسود مائل للبنفسجي
  static const Color backgroundSecondary = Color(0xFF12121A);  // خلفية البطاقات
  static const Color backgroundTertiary = Color(0xFF1A1A26);   // خلفية الحقول
  static const Color backgroundElevated = Color(0xFF22222F);   // عناصر مرتفعة
  // ====== ألوان مسارات التايم لاين ======
  static const Color timelineBackground = Color(0xFF0D0D15);
  static const Color timelineTrackVideo = Color(0xFF1E3A5F);   // أزرق داكن للفيديو
  static const Color timelineTrackAudio = Color(0xFF1F4A2E);   // أخضر داكن للصوت
  static const Color timelineTrackText = Color(0xFF4A2E1F);    // برتقالي داكن للنصوص
  static const Color timelinePlayhead = Color(0xFFFF3B3B);     // أحمر لمؤشر التشغيل
  static const Color timelineClipBorder = Color(0xFF3D3D5C);
  // ====== الألوان التمييزية (Accent Colors) ======
  static const Color accentPrimary = Color(0xFF6C63FF);        // بنفسجي كهربائي - اللون الرئيسي
  static const Color accentSecondary = Color(0xFF00D4FF);      // أزرق سماوي للتوهج
  static const Color accentAI = Color(0xFF9D4EDD);             // بنفسجي للذكاء الاصطناعي
  static const Color accentSuccess = Color(0xFF00E676);        // أخضر للنجاح
  static const Color accentWarning = Color(0xFFFFAB00);        // أصفر للتحذير
  static const Color accentDanger = Color(0xFFFF3D00);         // أحمر للخطر
  // ====== ألوان النصوص ======
  static const Color textPrimary = Color(0xFFF5F5FF);          // أبيض مائل للبنفسجي
  static const Color textSecondary = Color(0xFFB0B0CC);        // رمادي فاتح
  static const Color textTertiary = Color(0xFF6B6B8A);         // رمادي متوسط
  static const Color textDisabled = Color(0xFF3D3D5C);         // رمادي داكن
  // ====== ألوان الأزرار ======
  static const Color buttonPrimary = Color(0xFF6C63FF);
  static const Color buttonSecondary = Color(0xFF22222F);
  static const Color buttonDanger = Color(0xFFFF3D00);
  // ====== تدرجات الألوان (Gradients) ======
  // تدرج زر AI المتوهج في المنتصف
  static const LinearGradient aiButtonGradient = LinearGradient(
    colors: [Color(0xFF9D4EDD), Color(0xFF6C63FF), Color(0xFF00D4FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  // تدرج خلفية شريط الأدوات السفلي
  static const LinearGradient toolbarGradient = LinearGradient(
    colors: [Color(0xFF0A0A0F), Color(0xFF12121A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  // تدرج الـ Preview Player
  static const LinearGradient previewOverlayGradient = LinearGradient(
    colors: [Colors.transparent, Color(0x990A0A0F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  // ====== ظلال الإضاءة (Glow Effects) ======
  static List<BoxShadow> aiButtonGlow = [
    BoxShadow(
      color: const Color(0xFF9D4EDD).withOpacity(0.6),
      blurRadius: 20,
      spreadRadius: 2,
    ),
    BoxShadow(
      color: const Color(0xFF6C63FF).withOpacity(0.4),
      blurRadius: 40,
      spreadRadius: 5,
    ),
  ];
  static List<BoxShadow> accentGlow = [
    BoxShadow(
      color: accentPrimary.withOpacity(0.4),
      blurRadius: 15,
      spreadRadius: 1,
    ),
  ];
}
