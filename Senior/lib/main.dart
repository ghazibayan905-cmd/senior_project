import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:senior/ui/view/camera.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) طلب الأذونات قبل تشغيل الخدمة
  await _requestPermissions();

  // 2) الحصول على الكاميرات
  cameras = await availableCameras();

  // 3) تشغيل خدمة الاستماع للخلفية
  const platform = MethodChannel("voice_service_channel");
  try {
    await platform.invokeMethod("startService");
  } catch (e) {
    debugPrint("Background service start failed: $e");
  }

  runApp(const MyApp());
}

Future<void> _requestPermissions() async {
  await Permission.camera.request();
  await Permission.microphone.request();
  await Permission.notification.request();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.amber),
      debugShowCheckedModeBanner: false,
      home: const CameraScreen(),
    );
  }
}
