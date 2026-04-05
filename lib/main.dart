import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:get/get.dart';
// تأكدي أن هذا المسار يؤدي لملف الكاميرا الذي سنضع فيه كود YOLO
import 'package:senior/ui/view/camera.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // الحصول على الكاميرات المتاحة
  cameras = await availableCameras();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.amber,
      ), // لون احترافي
      debugShowCheckedModeBanner: false,
      // تمرير الكاميرا الخلفية (first) لشاشة الكاميرا
      home: CameraScreen(),
    );
  }
}
