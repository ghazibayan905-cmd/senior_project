// import 'package:flutter/material.dart';
// import 'package:ultralytics_yolo/ultralytics_yolo.dart';
// import 'package:flutter/services.dart' show MethodChannel, rootBundle;
// import 'package:path_provider/path_provider.dart';
// import 'dart:io';
// import 'package:flutter_tts/flutter_tts.dart';
// import 'package:vibration/vibration.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;
// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:flutter/rendering.dart';
// import 'dart:typed_data';
// import 'dart:ui' as ui;
// import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
// import 'package:translator/translator.dart';
// import 'package:webview_flutter/webview_flutter.dart';

// class CameraScreen extends StatefulWidget {
//   const CameraScreen({super.key});

//   @override
//   State<CameraScreen> createState() => _CameraScreenState();
// }

// class _CameraScreenState extends State<CameraScreen> {
//   String? _modelPath;
//   bool _loading = true;
//   static const MethodChannel _platform = MethodChannel("voice_service_channel");

//   final FlutterTts tts = FlutterTts();
//   final stt.SpeechToText sttInstance = stt.SpeechToText();
//   final translator = GoogleTranslator();
//   static const String _placeServerUrl = 'http://192.168.2.165:5000';
//   // عداد الضغطات
//   int _tapCount = 0;
//   DateTime _lastTapTime = DateTime.now();

//   // موديل العملة
//   late YOLO currencyModel;
//   late final WebViewController webcontroller;

//   bool wakeWordDetected = false;
//   bool assistantBusy = false;
//   bool isSpeaking = false;
//   bool readingText = false;
//   bool detectingPlace = false;
//   bool webviewLoaded = false;
//   String webviewError = "";
//   DateTime lastPlaceDetection = DateTime.now().subtract(
//     const Duration(seconds: 10),
//   );

//   final GlobalKey _cameraKey = GlobalKey();

//   DateTime lastListenTime = DateTime.now().subtract(const Duration(seconds: 3));
//   DateTime lastSpeakTime = DateTime.now().subtract(const Duration(seconds: 1));
//   DateTime lastVibrationTime = DateTime.now().subtract(
//     const Duration(seconds: 1),
//   );

//   String _lastSpokenMessage = '';
//   DateTime _lastMessageTime = DateTime.now().subtract(
//     const Duration(seconds: 10),
//   );

//   static const _candidateModelPaths = <String>[
//     'assets/models/yolov8n_saved_model/yolov8n_float32.tflite',
//     'assets/models/yolov8n_saved_model/yolov8n_float16.tflite',
//     'assets/models/yolov8n_float16.tflite',
//     'assets/models/yolov8n_float32.tflite',
//     'assets/models/yolov8n.tflite',
//   ];

//   @override
//   void initState() {
//     super.initState();
//     webcontroller = WebViewController()
//       ..setJavaScriptMode(JavaScriptMode.unrestricted)
//       ..setNavigationDelegate(
//         NavigationDelegate(
//           onPageStarted: (String url) {
//             print("WebView: Loading started - $url");
//           },
//           onPageFinished: (String url) {
//             print("WebView: Loading finished - $url");
//             setState(() {
//               webviewLoaded = true;
//               webviewError = "";
//             });
//           },
//           onWebResourceError: (WebResourceError error) {
//             print("WebView Error: ${error.description}");
//             setState(() {
//               webviewError = "خطأ في التحميل: ${error.description}";
//             });
//           },
//         ),
//       )
//       ..loadRequest(Uri.parse("http://10.171.6.41/stream"));

//     // ⭐ نسخ ملف اللغة داخل cache
//     _initTesseract();

//     _loadModel();
//     _loadCurrencyModel();

//     tts.setLanguage("ar");
//     tts.setSpeechRate(0.5);
//     tts.setPitch(1.0);
//     tts.awaitSpeakCompletion(true);
//     tts.speak(
//       "أهلاً بك. هذا التطبيق يدعم التعرف على الطقس، الوقت، التعرف على المكان، والتعرف على الأشياء.",
//     );
//     initVoiceAssistant();
//   }

//   Future<void> _loadCurrencyModel() async {
//     final data = await rootBundle.load(
//       'assets/models/currency/best_float32.tflite',
//     );
//     final dir = await getTemporaryDirectory();
//     final file = File('${dir.path}/currency.tflite');
//     await file.writeAsBytes(data.buffer.asUint8List());

//     currencyModel = YOLO(modelPath: file.path, task: YOLOTask.detect);
//   }

//   // ⭐ دالة نسخ ملف اللغة داخل app documents (تعمل 100% على Huawei/Honor)
//   Future<void> _initTesseract() async {
//     final dir = await getApplicationDocumentsDirectory(); // ← app documents
//     final tessdataDir = Directory("${dir.path}/tessdata");

//     if (!tessdataDir.existsSync()) {
//       tessdataDir.createSync(recursive: true);
//     }

//     final trainedDataPath = "${tessdataDir.path}/ara.traineddata";

//     if (!File(trainedDataPath).existsSync()) {
//       final data = await rootBundle.load("assets/tessdata/ara.traineddata");
//       final bytes = data.buffer.asUint8List();
//       await File(trainedDataPath).writeAsBytes(bytes);
//     }

//     // Copy tessdata_config.json as well
//     final configPath = "${dir.path}/tessdata_config.json";
//     if (!File(configPath).existsSync()) {
//       final configData = await rootBundle.loadString(
//         "assets/tessdata_config.json",
//       );
//       await File(configPath).writeAsString(configData);
//     }
//   }

//   Future<void> _detectCurrency() async {
//     if (assistantBusy) return;

//     assistantBusy = true;
//     isSpeaking = true;

//     final pngBytes = await _capturePng();
//     if (pngBytes == null) {
//       await tts.speak("فشل التقاط الصورة");
//       assistantBusy = false;
//       isSpeaking = false;
//       return;
//     }

//     final tempDir = await getTemporaryDirectory();
//     final file = File('${tempDir.path}/currency.png');
//     await file.writeAsBytes(pngBytes);

//     final bytes = await file.readAsBytes();
//     final results = await currencyModel.predict(bytes);

//     print("CURRENCY MODEL OUTPUT: $results");
//     print("CURRENCY MODEL TYPE: ${results.runtimeType}");

//     // ⭐ استخراج الصناديق من Map أو List
//     List<dynamic> boxes = [];

//     if (results is Map && results["boxes"] is List) {
//       boxes = results["boxes"];
//     } else if (results is List) {
//       boxes = results as List;
//     }

//     if (boxes.isEmpty) {
//       await tts.speak("لم أتعرف على أي عملة");
//       assistantBusy = false;
//       isSpeaking = false;
//       return;
//     }

//     // ⭐ تجميع أسماء العملات
//     List<String> labels = [];

//     for (var r in boxes) {
//       String label = "غير معروفة";

//       if (r is YOLOResult && r.className != null) {
//         label = r.className.toString();
//       } else if (r is Map) {
//         label =
//             r["className"]?.toString() ??
//             r["class"]?.toString() ??
//             "غير معروفة";
//       }

//       labels.add(label);
//     }

//     // ⭐ نطق حسب عدد العملات
//     if (labels.length == 1) {
//       // عملة واحدة فقط
//       await tts.stop();
//       await tts.speak("العملة هي ${labels.first}");
//     } else {
//       // أكثر من عملة
//       String joined = labels.join(" و ");
//       await tts.stop();
//       await tts.speak("لديك أكثر من عملة: $joined");
//     }

//     assistantBusy = false;
//     isSpeaking = false;
//   }

//   // ---------------------------
//   // WEATHER (دمشق)
//   // ---------------------------
//   Future<String> getWeather() async {
//     const city = "دمشق";
//     final url = Uri.parse(
//       "https://api.open-meteo.com/v1/forecast?"
//       "latitude=33.5138&longitude=36.2765"
//       "&current=temperature_2m,weather_code&timezone=Asia%2FDamascus",
//     );

//     try {
//       final response = await http.get(url);

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         final current = data["current"];
//         final temp = current["temperature_2m"];
//         final code = current["weather_code"];
//         final desc = _weatherCodeToArabic(code);
//         return "طقس $city حالياً $desc، ودرجة الحرارة $temp درجة مئوية";
//       } else {
//         return "تعذر الحصول على حالة الطقس حالياً";
//       }
//     } catch (e) {
//       return "حدث خطأ أثناء جلب الطقس";
//     }
//   }

//   String _weatherCodeToArabic(dynamic code) {
//     final c = code is num ? code.toInt() : -1;
//     if (c == 0) return "صحو";
//     if (c == 1 || c == 2) return "غائم جزئياً";
//     if (c == 3) return "غائم";
//     if (c == 45 || c == 48) return "ضباب";
//     if (c == 51 || c == 53 || c == 55) return "رذاذ";
//     if (c == 61 || c == 63 || c == 65) return "ممطر";
//     if (c == 71 || c == 73 || c == 75) return "ثلوج";
//     if (c == 80 || c == 81 || c == 82) return "زخات مطر";
//     if (c == 95 || c == 96 || c == 99) return "عاصفة رعدية";
//     return "طقس غير مستقر";
//   }

//   // ---------------------------
//   // Voice Assistant
//   // ---------------------------

//   Future<void> initVoiceAssistant() async {
//     await sttInstance.initialize();
//     startVoiceLoop();
//   }

//   String _normalizeSpeech(String text) {
//     return text
//         .toLowerCase()
//         .replaceAll("أ", "ا")
//         .replaceAll("إ", "ا")
//         .replaceAll("آ", "ا")
//         .replaceAll("ة", "ه")
//         .replaceAll("ى", "ي")
//         .replaceAll(RegExp(r'[^\u0600-\u06FFa-z0-9\s]'), ' ')
//         .replaceAll(RegExp(r'\s+'), ' ')
//         .trim();
//   }

//   bool _isTimeCommand(String text) {
//     return text.contains("وقت") ||
//         text.contains("ساعه") ||
//         text.contains("كم ساعه") ||
//         text.contains("قديش الساعه") ||
//         text.contains("شو الوقت") ||
//         text.contains("الوقت");
//   }

//   bool _isWeatherCommand(String text) {
//     return text.contains("طقس") ||
//         text.contains("جو") ||
//         text.contains("كيف الجو") ||
//         text.contains("شو الجو") ||
//         text.contains("شو الطقس");
//   }

//   void startVoiceLoop() {
//     Future.doWhile(() async {
//       if (!mounted) return false;

//       if (!assistantBusy &&
//           !isSpeaking &&
//           !sttInstance.isListening &&
//           DateTime.now().difference(lastListenTime).inSeconds >= 3) {
//         lastListenTime = DateTime.now();
//         listenForWakeWord();
//       }

//       await Future.delayed(const Duration(milliseconds: 500));

//       return mounted;
//     });
//   }

//   void listenForWakeWord() {
//     if (assistantBusy || isSpeaking) return;

//     sttInstance.listen(
//       onResult: (result) async {
//         final text = _normalizeSpeech(result.recognizedWords);

//         if (text.contains("فيجن")) {
//           await sttInstance.stop();

//           assistantBusy = true;
//           wakeWordDetected = true;

//           await tts.speak("نعم، كيف أستطيع مساعدتك؟");

//           Future.delayed(const Duration(seconds: 2), () {
//             listenForCommands();
//           });
//         }
//       },
//       localeId: "ar-SA",
//       partialResults: true,
//     );
//   }

//   void listenForCommands() {
//     sttInstance.listen(
//       onResult: (result) async {
//         final text = _normalizeSpeech(result.recognizedWords);

//         final isTime = _isTimeCommand(text);
//         final isWeather = _isWeatherCommand(text);

//         if (!(isTime || isWeather)) return;

//         if (isTime) {
//           final now = DateTime.now();
//           await tts.speak("الساعة الآن ${now.hour} و ${now.minute}");
//         } else if (isWeather) {
//           final weather = await getWeather();
//           await tts.speak(weather);
//         }

//         assistantBusy = false;
//         wakeWordDetected = false;

//         Future.delayed(const Duration(milliseconds: 500), () {
//           listenForCommands();
//         });
//       },
//       localeId: "ar-SA",
//       partialResults: true,
//     );
//   }

//   // ---------------------------
//   // OCR — التقاط صورة من الشاشة
//   // ---------------------------

//   Future<Uint8List?> _capturePng() async {
//     try {
//       RenderRepaintBoundary boundary =
//           _cameraKey.currentContext!.findRenderObject()
//               as RenderRepaintBoundary;

//       final image = await boundary.toImage(pixelRatio: 0.5);

//       final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

//       final bytes = byteData?.buffer.asUint8List();

//       image.dispose();

//       return bytes;
//     } catch (e) {
//       print("CAPTURE ERROR: $e");
//       return null;
//     }
//   }

//   // ---------------------------
//   // ⭐ OCR باستخدام Tesseract (نسخة Huawei/Honor)
//   // ---------------------------

//   Future<void> _readTextFromCamera() async {
//     if (readingText) return;
//     readingText = true;

//     debugPrint('📸 OCR: Starting text reading...');

//     final pngBytes = await _capturePng();
//     if (pngBytes == null) {
//       debugPrint('❌ OCR: Failed to capture PNG');
//       readingText = false;
//       return;
//     }

//     debugPrint('📸 OCR: PNG captured, size: ${pngBytes.length} bytes');

//     final tempDir = await getTemporaryDirectory();
//     final file = File('${tempDir.path}/ocr.png');
//     await file.writeAsBytes(pngBytes);

//     // ⭐ نفس المسار المستخدم في _initTesseract()
//     final dir = await getApplicationDocumentsDirectory();
//     final tessdataPath = "${dir.path}/tessdata";

//     debugPrint('📸 OCR: Using tessdata path: $tessdataPath');

//     try {
//       String text = await FlutterTesseractOcr.extractText(
//         file.path,
//         language: "ara",
//         args: {"tessdata": tessdataPath},
//       );

//       debugPrint('📸 OCR: Extracted text: "$text"');

//       text = text.trim();

//       if (text.isEmpty) {
//         debugPrint('📸 OCR: No text found');
//         await tts.speak("لم أستطع قراءة أي نص");
//       } else {
//         debugPrint('📸 OCR: Speaking text: "$text"');
//         await tts.speak(text);
//       }
//     } catch (e) {
//       debugPrint('❌ OCR error: $e');
//       await tts.speak("حدث خطأ في قراءة النص");
//     }

//     readingText = false;
//   }

//   // ---------------------------
//   // تحميل YOLO
//   // ---------------------------

//   Future<void> _loadModel() async {
//     final data = await rootBundle.load(_candidateModelPaths.first);
//     final dir = await getTemporaryDirectory();
//     final file = File('${dir.path}/model.tflite');
//     await file.writeAsBytes(data.buffer.asUint8List());

//     setState(() {
//       _modelPath = file.path;
//       _loading = false;
//     });
//   }

//   // ---------------------------
//   // ترجمة عربية كاملة
//   // ---------------------------

//   String _translate(String label) {
//     switch (label) {
//       case "person":
//         return "شخص";
//       case "bicycle":
//         return "دراجة";
//       case "car":
//         return "سيارة";
//       case "motorcycle":
//         return "دراجة نارية";
//       case "airplane":
//         return "طائرة";
//       case "bus":
//         return "باص";
//       case "train":
//         return "قطار";
//       case "truck":
//         return "شاحنة";
//       case "boat":
//         return "قارب";
//       case "traffic light":
//         return "إشارة مرور";
//       case "fire hydrant":
//         return "صنبور إطفاء";
//       case "stop sign":
//         return "إشارة توقف";
//       case "parking meter":
//         return "عداد موقف";
//       case "bench":
//         return "مقعد";
//       case "bird":
//         return "طائر";
//       case "cat":
//         return "قطة";
//       case "dog":
//         return "كلب";
//       case "horse":
//         return "حصان";
//       case "sheep":
//         return "خروف";
//       case "cow":
//         return "بقرة";
//       case "elephant":
//         return "فيل";
//       case "bear":
//         return "دب";
//       case "zebra":
//         return "حمار وحشي";
//       case "giraffe":
//         return "زرافة";
//       case "backpack":
//         return "حقيبة ظهر";
//       case "umbrella":
//         return "مظلة";
//       case "handbag":
//         return "حقيبة يد";
//       case "tie":
//         return "ربطة عنق";
//       case "suitcase":
//         return "حقيبة سفر";
//       case "frisbee":
//         return "قرص طائر";
//       case "skis":
//         return "زلاجات";
//       case "snowboard":
//         return "لوح تزلج";
//       case "sports ball":
//         return "كرة رياضية";
//       case "kite":
//         return "طائرة ورقية";
//       case "baseball bat":
//         return "مضرب بيسبول";
//       case "baseball glove":
//         return "قفاز بيسبول";
//       case "skateboard":
//         return "لوح تزلج";
//       case "surfboard":
//         return "لوح ركوب الأمواج";
//       case "tennis racket":
//         return "مضرب تنس";
//       case "bottle":
//         return "زجاجة";
//       case "wine glass":
//         return "كأس";
//       case "cup":
//         return "فنجان";
//       case "fork":
//         return "شوكة";
//       case "knife":
//         return "سكين";
//       case "spoon":
//         return "ملعقة";
//       case "bowl":
//         return "وعاء";
//       case "banana":
//         return "موزة";
//       case "apple":
//         return "تفاحة";
//       case "sandwich":
//         return "ساندويتش";
//       case "orange":
//         return "برتقالة";
//       case "broccoli":
//         return "بروكلي";
//       case "carrot":
//         return "جزرة";
//       case "hot dog":
//         return "هوت دوغ";
//       case "pizza":
//         return "بيتزا";
//       case "donut":
//         return "دونات";
//       case "cake":
//         return "كيك";
//       case "chair":
//         return "كرسي";
//       case "couch":
//         return "كنبة";
//       case "potted plant":
//         return "نبتة";
//       case "bed":
//         return "تخت";
//       case "dining table":
//         return "طاولة طعام";
//       case "toilet":
//         return "مرحاض";
//       case "tv":
//         return "تلفاز";
//       case "laptop":
//         return "لابتوب";
//       case "mouse":
//         return "فأرة";
//       case "remote":
//         return "ريموت";
//       case "keyboard":
//         return "كيبورد";
//       case "cell phone":
//         return "موبايل";
//       case "microwave":
//         return "ميكرويف";
//       case "oven":
//         return "فرن";
//       case "toaster":
//         return "محمر خبز";
//       case "sink":
//         return "مغسلة";
//       case "refrigerator":
//         return "براد";
//       case "book":
//         return "كتاب";
//       case "clock":
//         return "ساعة";
//       case "vase":
//         return "مزهرية";
//       case "scissors":
//         return "مقص";
//       case "teddy bear":
//         return "دبدوب";
//       case "hair drier":
//         return "مجفف شعر";
//       case "toothbrush":
//         return "فرشاة أسنان";
//       default:
//         return label;
//     }
//   }

//   String _translatePlace(String place) {
//     switch (place.toLowerCase()) {
//       case "bedroom":
//         return "غرفة نوم";

//       case "living_room":
//       case "living room":
//         return "غرفة جلوس";

//       case "kitchen":
//         return "مطبخ";

//       case "bathroom":
//         return "حمام";

//       case "office":
//         return "مكتب";

//       case "corridor":
//         return "ممر";

//       case "street":
//         return "شارع";

//       case "restaurant":
//         return "مطعم";

//       case "classroom":
//         return "صف";

//       case "library":
//         return "مكتبة";

//       case "supermarket":
//         return "سوبرماركت";

//       case "park":
//         return "حديقة";

//       case "hospital":
//         return "مشفى";

//       case "airport":
//         return "مطار";

//       case "train_station":
//       case "train station":
//         return "محطة قطار";

//       case "bus_station":
//       case "bus station":
//         return "محطة باص";

//       case "beach":
//         return "شاطئ";

//       case "forest":
//         return "غابة";

//       case "mountain":
//         return "جبل";

//       case "bridge":
//         return "جسر";

//       case "stadium":
//         return "ملعب";

//       case "gym":
//         return "نادي رياضي";

//       case "cafe":
//         return "مقهى";

//       case "shop":
//         return "متجر";

//       case "hotel":
//         return "فندق";

//       default:
//         return place.replaceAll("_", " ");
//     }
//   }
//   // ---------------------------
//   // UI + YOLO + OCR Double Tap
//   // ---------------------------
//   // ---------------------------
//   // Places365 API
//   // ---------------------------

//   Future<void> _detectPlace() async {
//     print("START PLACE DETECTION");

//     // منع التكرار
//     if (detectingPlace) return;

//     if (DateTime.now().difference(lastPlaceDetection).inSeconds < 8) {
//       return;
//     }

//     detectingPlace = true;
//     assistantBusy = true;
//     isSpeaking = true;
//     lastPlaceDetection = DateTime.now();

//     try {
//       await tts.stop();

//       // التقاط صورة
//       final pngBytes = await _capturePng();

//       if (pngBytes == null) {
//         await tts.speak("فشل التقاط الصورة");

//         assistantBusy = false;
//         isSpeaking = false;
//         detectingPlace = false;

//         return;
//       }

//       // حفظ الصورة مؤقتاً
//       final tempDir = await getTemporaryDirectory();

//       final file = File('${tempDir.path}/place.png');

//       await file.writeAsBytes(pngBytes);

//       print("IMAGE SAVED: ${file.path}");

//       // إرسال الطلب للسيرفر
//       var request = http.MultipartRequest(
//         'POST',
//         Uri.parse('$_placeServerUrl/predict_place'),
//       );

//       // إضافة الصورة
//       request.files.add(await http.MultipartFile.fromPath('image', file.path));

//       print("SENDING REQUEST...");

//       // إرسال الطلب
//       final response = await request.send();

//       print("STATUS CODE: ${response.statusCode}");

//       // قراءة الرد
//       final responseData = await response.stream.bytesToString();

//       print("RESPONSE: $responseData");

//       // نجاح
//       if (response.statusCode == 200) {
//         final data = jsonDecode(responseData);

//         String place = data["place"];

//         print("PLACE RESULT: $place");

//         // تنسيق الاسم
//         place = place.replaceAll("_", " ");

//         await tts.stop();

//         await tts.setLanguage("ar");

//         await tts.setSpeechRate(0.5);

//         print("SPEAKING PLACE: $place");

//         // نطق المكان
//         place = place.replaceAll("_", " ");
//         final translated = await translator.translate(
//           place,
//           from: 'en',
//           to: 'ar',
//         );

//         await tts.speak("أنت في ${translated.text}");

//         // منع YOLO من المقاطعة
//         await Future.delayed(const Duration(seconds: 4));
//       } else {
//         print("SERVER ERROR");

//         await tts.speak("فشل التعرف على المكان");
//       }
//     } catch (e) {
//       print("PLACE ERROR FULL: ${e.toString()}");

//       await tts.speak("حدث خطأ في الاتصال بالسيرفر");
//     }
//     assistantBusy = false;
//     isSpeaking = false;
//     detectingPlace = false;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,

//       body: _loading
//           ? const Center(child: CircularProgressIndicator(color: Colors.white))
//           : Stack(
//               children: [
//                 // ESP32-CAM Stream
//                 SizedBox.expand(
//                   child: WebViewWidget(controller: webcontroller),
//                 ),

//                 // Loading Indicator while WebView loads
//                 if (!webviewLoaded)
//                   const Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         CircularProgressIndicator(color: Colors.white),
//                         SizedBox(height: 20),
//                         Text(
//                           "جاري تحميل البث...",
//                           style: TextStyle(color: Colors.white, fontSize: 18),
//                         ),
//                       ],
//                     ),
//                   ),

//                 // Error Message
//                 if (webviewError.isNotEmpty)
//                   Positioned(
//                     top: 100,
//                     left: 20,
//                     right: 20,
//                     child: Container(
//                       padding: const EdgeInsets.all(20),
//                       decoration: BoxDecoration(
//                         color: Colors.red.withOpacity(0.9),
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       child: Column(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           const Text(
//                             "❌ خطأ في الاتصال",
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontSize: 18,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           const SizedBox(height: 10),
//                           Text(
//                             webviewError,
//                             style: const TextStyle(
//                               color: Colors.white,
//                               fontSize: 16,
//                             ),
//                             textAlign: TextAlign.center,
//                           ),
//                           const SizedBox(height: 15),
//                           ElevatedButton(
//                             onPressed: () {
//                               setState(() {
//                                 webviewError = "";
//                                 webviewLoaded = false;
//                               });
//                               webcontroller.reload();
//                             },
//                             child: const Text("🔄 أعد المحاولة"),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),

//                 // =========================
//                 // CAMERA VIEW - Hidden (keeping for capture functionality)
//                 // =========================
//                 RepaintBoundary(
//                   key: _cameraKey,
//                   child: Opacity(
//                     opacity: 0,
//                     child: SizedBox(
//                       width: 1,
//                       height: 1,
//                       child: YOLOView(
//                         modelPath: _modelPath!,
//                         task: YOLOTask.detect,
//                         useGpu: false,
//                         onResult: (results) async {},
//                       ),
//                     ),
//                   ),
//                 ),
//                 Positioned.fill(
//                   child: GestureDetector(
//                     behavior: HitTestBehavior.translucent,

//                     // ⭐ سحب للأعلى
//                     onPanUpdate: (details) async {
//                       if (details.delta.dy < -15) {
//                         print("DEBUG: swipe up → currency");
//                         await _detectCurrency();
//                       }
//                     },

//                     // ⭐ دبل تاب → OCR
//                     onDoubleTap: () async {
//                       print("DEBUG: double tap detected");
//                       await _readTextFromCamera();
//                     },

//                     // ⭐ لونغ برس → مكان
//                     onLongPress: () async {
//                       print("DEBUG: long press detected");
//                       await _detectPlace();
//                     },

//                     child: Container(color: Colors.transparent),
//                   ),
//                 ),

//                 // =========================
//                 // TOP STATUS BAR
//                 // =========================
//                 Positioned(
//                   top: 50,
//                   left: 20,
//                   right: 20,

//                   child: Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 20,
//                       vertical: 14,
//                     ),

//                     decoration: BoxDecoration(
//                       color: Colors.black.withOpacity(0.6),

//                       borderRadius: BorderRadius.circular(20),

//                       border: Border.all(color: Colors.white24),
//                     ),

//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,

//                       children: [
//                         Row(
//                           children: [
//                             Container(
//                               width: 12,
//                               height: 12,

//                               decoration: BoxDecoration(
//                                 color: isSpeaking ? Colors.red : Colors.green,

//                                 shape: BoxShape.circle,
//                               ),
//                             ),

//                             const SizedBox(width: 10),

//                             Text(
//                               isSpeaking ? "يتحدث" : "جاهز",

//                               style: const TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 18,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ],
//                         ),

//                         const Text(
//                           "وضع التنقل",

//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 18,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),

//                 // =========================
//                 // MIC INDICATOR
//                 // =========================
//                 if (sttInstance.isListening)
//                   Positioned(
//                     bottom: 160,
//                     left: 0,
//                     right: 0,

//                     child: Center(
//                       child: Container(
//                         padding: const EdgeInsets.all(20),

//                         decoration: BoxDecoration(
//                           color: Colors.blue.withOpacity(0.8),

//                           shape: BoxShape.circle,
//                         ),

//                         child: const Icon(
//                           Icons.mic,
//                           color: Colors.white,
//                           size: 45,
//                         ),
//                       ),
//                     ),
//                   ),

//                 // =========================
//                 // DETECTION CARD
//                 // =========================
//                 Positioned(
//                   bottom: 40,
//                   left: 20,
//                   right: 20,

//                   child: AnimatedContainer(
//                     duration: const Duration(milliseconds: 300),

//                     padding: const EdgeInsets.all(20),

//                     decoration: BoxDecoration(
//                       color: Colors.black.withOpacity(0.75),

//                       borderRadius: BorderRadius.circular(24),

//                       border: Border.all(color: Colors.white24),
//                     ),

//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,

//                       children: [
//                         const Text(
//                           "آخر تنبيه",

//                           style: TextStyle(color: Colors.white70, fontSize: 16),
//                         ),

//                         const SizedBox(height: 10),

//                         Text(
//                           _lastSpokenMessage.isEmpty
//                               ? "بانتظار الكشف..."
//                               : _lastSpokenMessage,

//                           textAlign: TextAlign.center,

//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 24,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//     );
//   }

//   @override
//   void dispose() {
//     sttInstance.stop();
//     tts.stop();
//     super.dispose();
//   }
// }
