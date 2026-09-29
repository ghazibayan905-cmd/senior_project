import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:senior/ui/view/widget/feauture.dart';
import 'splash_controller.dart';

class SplashScreen extends GetView<SplashController> {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(SplashController());

    return Scaffold(
      backgroundColor: const Color(0xFF020817),
      body: Stack(
        children: [

          /// تأثير الخلفية
          Positioned(
            bottom: -50,
            left: -50,
            right: -50,
            child: Container(
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(200),
                gradient: RadialGradient(
                  colors: [
                    Colors.blue.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
              
                  const SizedBox(height: 120),
              
                  /// الشعار
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 40,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/logo.jpg',
                      fit: BoxFit.contain,
                    ),
                  ),
              
                  const SizedBox(height: 20),
              
                  /// اسم التطبيق
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Vision',
                          style: TextStyle(
                            color: Color(0xFF42A5F5),
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: 'Mate',
                          style: TextStyle(
                            color: Color(0xFFFFC107),
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              
                  const SizedBox(height: 8),
              
                  const Text(
                    'See the world. Live independently.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
              
                  const SizedBox(height: 60),
              
                  /// الميزات
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: const [
              
                        FeatureItem(
                          icon: Icons.camera_alt_outlined,
                          title: 'Object\nRecognition',
                          color: Colors.blue,
                        ),
              
                        FeatureItem(
                          icon: Icons.text_fields,
                          title: 'Text\nRecognition',
                          color: Colors.blue,
                        ),
              
                        FeatureItem(
                          icon: Icons.location_on_outlined,
                          title: 'Place\nRecognition',
                          color: Colors.amber,
                        ),
              
                        FeatureItem(
                          icon: Icons.attach_money,
                          title: 'Currency\nRecognition',
                          color: Colors.amber,
                        ),
              
                        FeatureItem(
                          icon: Icons.wb_cloudy_outlined,
                          title: 'Weather\n& Time',
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 40),

              
              
                  /// التحميل
                  const CircularProgressIndicator(
                    color: Color(0xFFFFC107),
                  ),
              
                  const SizedBox(height: 12),
              
                  const Text(
                    'Loading...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
              
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}