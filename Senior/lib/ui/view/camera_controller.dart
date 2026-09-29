// import 'package:camera/camera.dart';
// import 'package:get/get.dart';
// import 'package:ultralytics_yolo/ultralytics_yolo.dart';

// class CameraControllerX extends GetxController {
//   final CameraDescription camera;
//   late CameraController cameraController;
//   late Future<void> initializeControllerFuture;

//   YOLO? _yolo;
//   List<YOLOResult> detections = [];
//   bool _isProcessing = false;

//   CameraControllerX({required this.camera});

//   @override
//   void onInit() {
//     super.onInit();
//     _initYOLO();

//     cameraController = CameraController(
//       camera,
//       ResolutionPreset.medium,
//       enableAudio: false,
//       imageFormatGroup: ImageFormatGroup.yuv420,
//     );

//     initializeControllerFuture = cameraController.initialize().then((_) {
//       cameraController.startImageStream((image) {
//         _runInference(image);
//       });
//       update();
//     });
//   }

// Future<void> _initYOLO() async {
//   _yolo = YOLO(
//     modelPath: 'assets/models/yolov8m_float32.tflite',
//     task: YOLOTask.detect, // إلزامي
//   );
// }

//   void _runInference(CameraImage image) async {
//     if (_yolo == null || _isProcessing) return;

//     _isProcessing = true;

//     final results = await _yolo!.detect(image);

//     detections = results;
//     update();

//     _isProcessing = false;
//   }

//   @override
//   void onClose() {
//     cameraController.stopImageStream();
//     cameraController.dispose();
//     _yolo?.close();
//     super.onClose();
//   }
// }
