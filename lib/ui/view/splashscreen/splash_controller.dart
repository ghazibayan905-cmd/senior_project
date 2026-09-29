import 'package:get/get.dart';
import 'package:senior/ui/view/camera.dart';

class SplashController extends GetxController {

  @override
  void onInit() {
    super.onInit();
    navigateToHome();
  }

  void navigateToHome() async {
    await Future.delayed(const Duration(seconds: 3));

     Get.off(() => const CameraScreen());
  }
}