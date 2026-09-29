// import 'dart:io';
// import 'dart:typed_data';
// import 'dart:ui' as ui;

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter/rendering.dart';

// import 'package:path_provider/path_provider.dart';
// import 'package:senior/ui/view/camera.dart';
// import 'package:ultralytics_yolo/ultralytics_yolo.dart';
// import 'package:flutter_tts/flutter_tts.dart';
// class CurrencyScreen extends StatefulWidget {
//   const CurrencyScreen({super.key});

//   @override
//   State<CurrencyScreen> createState() => _CurrencyScreenState();
// }
//  class _CurrencyScreenState extends State<CurrencyScreen> {

//   String? _modelPath;
//   bool _loading = true;

//   final FlutterTts tts = FlutterTts();

//   late YOLO currencyModel;

//   bool assistantBusy = false;
//   bool isSpeaking = false;

//   final GlobalKey _cameraKey = GlobalKey();

//   static const List<String> _currencyLabels = [
//     '200-new',
//     '2000-old',
//     '25-new',
//     '50-new',
//     '500-new',
//     '5000-old',
//   ];

//   static const Map<String, String> _currencyLabelArabic = {
//     '200-new': '200 ليرة جديدة',
//     '2000-old': '2000 ليرة قديمة',
//     '25-new': '25 ليرة جديدة',
//     '50-new': '50 ليرة جديدة',
//     '500-new': '500 ليرة جديدة',
//     '5000-old': '5000 ليرة قديمة',
//   };
//   @override
// void initState() {
//   super.initState();

//   _loadCurrencyModel();

//   tts.setLanguage("ar");
//   tts.setSpeechRate(0.5);
//   tts.setPitch(1.0);
//   tts.awaitSpeakCompletion(true);

//   tts.speak("تم تشغيل نظام التعرف على العملات");
// }
// Future<void> _loadCurrencyModel() async {
//   final data = await rootBundle.load(
//     'assets/models/currency/best_float32.tflite',
//   );

//   final dir = await getTemporaryDirectory();

//   final file = File('${dir.path}/currency.tflite');

//   await file.writeAsBytes(data.buffer.asUint8List());

//   currencyModel = YOLO(
//     modelPath: file.path,
//     task: YOLOTask.detect,
//   );

//   await currencyModel.loadModel();

//   setState(() {
//     _modelPath = file.path;
//     _loading = false;
//   });

//   print("Currency Model Loaded");
// }
// Future<Uint8List?> _capturePng() async {
//   try {
//     RenderRepaintBoundary boundary =
//         _cameraKey.currentContext!.findRenderObject()
//             as RenderRepaintBoundary;

//     final image = await boundary.toImage(pixelRatio: 0.5);

//     final byteData = await image.toByteData(
//       format: ui.ImageByteFormat.png,
//     );

//     return byteData?.buffer.asUint8List();
//   } catch (e) {
//     print("CAPTURE ERROR: $e");
//     return null;
//   }
// }
// Future<void> _detectCurrency() async {
//   if (assistantBusy) return;

//   assistantBusy = true;
//   isSpeaking = true;

//   final pngBytes = await _capturePng();

//   if (pngBytes == null) {
//     await tts.speak("فشل التقاط الصورة");
//     assistantBusy = false;
//     isSpeaking = false;
//     return;
//   }

//   final tempDir = await getTemporaryDirectory();
//   final file = File('${tempDir.path}/currency.png');
//   await file.writeAsBytes(pngBytes);

//   final results = await currencyModel.predict(pngBytes);

//   print("RESULTS: $results");

//   List<dynamic> boxes = [];

//   if (results is Map && results["boxes"] is List) {
//     boxes = results["boxes"];
//   } else if (results is List) {
//     boxes = results as List;
//   }

//   if (boxes.isEmpty) {
//     await tts.speak("لم أتعرف على أي عملة");
//     assistantBusy = false;
//     isSpeaking = false;
//     return;
//   }

//   List<String> labels = [];

//   for (var r in boxes) {
//     String rawLabel = "";
//     double confidence = 0.0;

//     if (r is YOLOResult) {
//       rawLabel = r.className ?? "";
//       confidence = r.confidence ?? 0;
//     } else if (r is Map) {
//       rawLabel = r["className"]?.toString() ?? "";
//       confidence = (r["confidence"] ?? 0).toDouble();
//     }

//     if (!_currencyLabels.contains(rawLabel) || confidence < 0.5) continue;

//     labels.add(_currencyLabelArabic[rawLabel] ?? rawLabel);
//   }

//   if (labels.isEmpty) {
//     await tts.speak("لم أتعرف على أي عملة");
//   } else if (labels.length == 1) {
//     await tts.speak("العملة هي ${labels.first}");
//   } else {
//     await tts.speak("يوجد عدة عملات: ${labels.join(' و ')}");
//   }

//   assistantBusy = false;
//   isSpeaking = false;
// }

// @override
// Widget build(BuildContext context) {
//   return Scaffold(
//     backgroundColor: Colors.black,

//     body: _loading
//         ? const Center(
//             child: CircularProgressIndicator(color: Colors.white),
//           )
//         : Stack(
//             children: [
//               // =========================
//               // CAMERA VIEW
//               // =========================
//               RepaintBoundary(
//                 key: _cameraKey,
//                 child: Container(
//                   color: Colors.black,
//                   child: const Center(
//                     child: Text(
//                       "الكاميرا تعمل بالخلف (YOLO)",
//                       style: TextStyle(color: Colors.white),
//                     ),
//                   ),
//                 ),
//               ),

//               // =========================
//               // GESTURES (SWIPE UP ONLY)
//               // =========================
//               Positioned.fill(
//                 child: GestureDetector(
//                   behavior: HitTestBehavior.translucent,

//                   onPanUpdate: (details) async {
//                     if (details.delta.dy < -15) {
//                       await _detectCurrency();
//                     }
//                   },

//                   child: Container(color: Colors.transparent),
//                 ),
//               ),

//               // =========================
//               // STATUS BAR
//               // =========================
//               Positioned(
//                 top: 50,
//                 left: 20,
//                 right: 20,
//                 child: Container(
//                   padding: const EdgeInsets.all(16),
//                   decoration: BoxDecoration(
//                     color: Colors.black.withOpacity(0.6),
//                     borderRadius: BorderRadius.circular(16),
//                     border: Border.all(color: Colors.white24),
//                   ),
//                   child: const Text(
//                     "اسحب للأعلى للتعرف على العملة",
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 18,
//                     ),
//                   ),
//                 ),
//               ),

//               // =========================
//               // RESULT DISPLAY (OPTIONAL)
//               // =========================
//               Positioned(
//                 bottom: 80,
//                 left: 20,
//                 right: 20,
//                 child: Container(
//                   padding: const EdgeInsets.all(20),
//                   decoration: BoxDecoration(
//                     color: Colors.black.withOpacity(0.7),
//                     borderRadius: BorderRadius.circular(20),
//                     border: Border.all(color: Colors.white24),
//                   ),
//                   child: Text(
//                     isSpeaking
//                         ? "جاري التحليل..."
//                         : "جاهز",
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 22,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//   );
// }
// @override
// void dispose() {
//   tts.stop();
//   super.dispose();
// }
// }