import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  String? _modelPath;
  bool _loading = true;
  static const MethodChannel _platform = MethodChannel("voice_service_channel");

  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText sttInstance = stt.SpeechToText();

  bool wakeWordDetected = false;
  bool assistantBusy = false;
  bool isSpeaking = false;
  bool readingText = false;

  final GlobalKey _cameraKey = GlobalKey();

  DateTime lastListenTime = DateTime.now().subtract(const Duration(seconds: 3));
  DateTime lastSpeakTime = DateTime.now().subtract(const Duration(seconds: 1));
  DateTime lastVibrationTime = DateTime.now().subtract(
    const Duration(seconds: 1),
  );

  String _lastSpokenMessage = '';
  DateTime _lastMessageTime = DateTime.now().subtract(
    const Duration(seconds: 10),
  );

  static const _candidateModelPaths = <String>[
    'assets/models/yolov8n_saved_model/yolov8n_float32.tflite',
    'assets/models/yolov8n_saved_model/yolov8n_float16.tflite',
    'assets/models/yolov8n_float16.tflite',
    'assets/models/yolov8n_float32.tflite',
    'assets/models/yolov8n.tflite',
  ];

  @override
  void initState() {
    super.initState();

    // ⭐ نسخ ملف اللغة داخل cache
    _initTesseract();

    _loadModel();

    tts.setLanguage("ar");
    tts.setSpeechRate(0.5);
    tts.setPitch(1.0);
    tts.awaitSpeakCompletion(true);

    initVoiceAssistant();
  }

  // ⭐ دالة نسخ ملف اللغة داخل app documents (تعمل 100% على Huawei/Honor)
  Future<void> _initTesseract() async {
    final dir = await getApplicationDocumentsDirectory(); // ← app documents
    final tessdataDir = Directory("${dir.path}/tessdata");

    if (!tessdataDir.existsSync()) {
      tessdataDir.createSync(recursive: true);
    }

    final trainedDataPath = "${tessdataDir.path}/ara.traineddata";

    if (!File(trainedDataPath).existsSync()) {
      final data = await rootBundle.load("assets/tessdata/ara.traineddata");
      final bytes = data.buffer.asUint8List();
      await File(trainedDataPath).writeAsBytes(bytes);
    }

    // Copy tessdata_config.json as well
    final configPath = "${dir.path}/tessdata_config.json";
    if (!File(configPath).existsSync()) {
      final configData = await rootBundle.loadString(
        "assets/tessdata_config.json",
      );
      await File(configPath).writeAsString(configData);
    }
  }

  // ---------------------------
  // WEATHER (دمشق)
  // ---------------------------
  Future<String> getWeather() async {
    const city = "دمشق";
    final url = Uri.parse(
      "https://api.open-meteo.com/v1/forecast?"
      "latitude=33.5138&longitude=36.2765"
      "&current=temperature_2m,weather_code&timezone=Asia%2FDamascus",
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data["current"];
        final temp = current["temperature_2m"];
        final code = current["weather_code"];
        final desc = _weatherCodeToArabic(code);
        return "طقس $city حالياً $desc، ودرجة الحرارة $temp درجة مئوية";
      } else {
        return "تعذر الحصول على حالة الطقس حالياً";
      }
    } catch (e) {
      return "حدث خطأ أثناء جلب الطقس";
    }
  }

  String _weatherCodeToArabic(dynamic code) {
    final c = code is num ? code.toInt() : -1;
    if (c == 0) return "صحو";
    if (c == 1 || c == 2) return "غائم جزئياً";
    if (c == 3) return "غائم";
    if (c == 45 || c == 48) return "ضباب";
    if (c == 51 || c == 53 || c == 55) return "رذاذ";
    if (c == 61 || c == 63 || c == 65) return "ممطر";
    if (c == 71 || c == 73 || c == 75) return "ثلوج";
    if (c == 80 || c == 81 || c == 82) return "زخات مطر";
    if (c == 95 || c == 96 || c == 99) return "عاصفة رعدية";
    return "طقس غير مستقر";
  }

  // ---------------------------
  // Voice Assistant
  // ---------------------------

  Future<void> initVoiceAssistant() async {
    await sttInstance.initialize();
    startVoiceLoop();
  }

  String _normalizeSpeech(String text) {
    return text
        .toLowerCase()
        .replaceAll("أ", "ا")
        .replaceAll("إ", "ا")
        .replaceAll("آ", "ا")
        .replaceAll("ة", "ه")
        .replaceAll("ى", "ي")
        .replaceAll(RegExp(r'[^\u0600-\u06FFa-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _isTimeCommand(String text) {
    return text.contains("وقت") ||
        text.contains("ساعه") ||
        text.contains("كم ساعه") ||
        text.contains("قديش الساعه") ||
        text.contains("شو الوقت") ||
        text.contains("الوقت");
  }

  bool _isWeatherCommand(String text) {
    return text.contains("طقس") ||
        text.contains("جو") ||
        text.contains("كيف الجو") ||
        text.contains("شو الجو") ||
        text.contains("شو الطقس");
  }

  void startVoiceLoop() async {
    while (mounted) {
      if (!assistantBusy &&
          !isSpeaking &&
          !sttInstance.isListening &&
          DateTime.now().difference(lastListenTime).inSeconds >= 3) {
        lastListenTime = DateTime.now();
        listenForWakeWord();
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  void listenForWakeWord() {
    if (assistantBusy || isSpeaking) return;

    sttInstance.listen(
      onResult: (result) async {
        final text = _normalizeSpeech(result.recognizedWords);

        if (text.contains("فيجن")) {
          await sttInstance.stop();

          assistantBusy = true;
          wakeWordDetected = true;

          await tts.speak("نعم، كيف أستطيع مساعدتك؟");

          Future.delayed(const Duration(seconds: 2), () {
            listenForCommands();
          });
        }
      },
      localeId: "ar-SA",
      partialResults: true,
    );
  }

  void listenForCommands() {
    sttInstance.listen(
      onResult: (result) async {
        final text = _normalizeSpeech(result.recognizedWords);

        final isTime = _isTimeCommand(text);
        final isWeather = _isWeatherCommand(text);

        if (!(isTime || isWeather)) return;

        if (isTime) {
          final now = DateTime.now();
          await tts.speak("الساعة الآن ${now.hour} و ${now.minute}");
        } else if (isWeather) {
          final weather = await getWeather();
          await tts.speak(weather);
        }

        assistantBusy = false;
        wakeWordDetected = false;

        Future.delayed(const Duration(milliseconds: 500), () {
          listenForCommands();
        });
      },
      localeId: "ar-SA",
      partialResults: true,
    );
  }

  // ---------------------------
  // OCR — التقاط صورة من الشاشة
  // ---------------------------

  Future<Uint8List?> _capturePng() async {
    try {
      RenderRepaintBoundary boundary =
          _cameraKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  // ---------------------------
  // ⭐ OCR باستخدام Tesseract (نسخة Huawei/Honor)
  // ---------------------------

  Future<void> _readTextFromCamera() async {
    if (readingText) return;
    readingText = true;

    debugPrint('📸 OCR: Starting text reading...');

    final pngBytes = await _capturePng();
    if (pngBytes == null) {
      debugPrint('❌ OCR: Failed to capture PNG');
      readingText = false;
      return;
    }

    debugPrint('📸 OCR: PNG captured, size: ${pngBytes.length} bytes');

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/ocr.png');
    await file.writeAsBytes(pngBytes);

    // ⭐ نفس المسار المستخدم في _initTesseract()
    final dir = await getApplicationDocumentsDirectory();
    final tessdataPath = "${dir.path}/tessdata";

    debugPrint('📸 OCR: Using tessdata path: $tessdataPath');

    try {
      String text = await FlutterTesseractOcr.extractText(
        file.path,
        language: "ara",
        args: {"tessdata": tessdataPath},
      );

      debugPrint('📸 OCR: Extracted text: "$text"');

      text = text.trim();

      if (text.isEmpty) {
        debugPrint('📸 OCR: No text found');
        await tts.speak("لم أستطع قراءة أي نص");
      } else {
        debugPrint('📸 OCR: Speaking text: "$text"');
        await tts.speak(text);
      }
    } catch (e) {
      debugPrint('❌ OCR error: $e');
      await tts.speak("حدث خطأ في قراءة النص");
    }

    readingText = false;
  }

  // ---------------------------
  // تحميل YOLO
  // ---------------------------

  Future<void> _loadModel() async {
    final data = await rootBundle.load(_candidateModelPaths.first);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/model.tflite');
    await file.writeAsBytes(data.buffer.asUint8List());

    setState(() {
      _modelPath = file.path;
      _loading = false;
    });
  }

  // ---------------------------
  // ترجمة عربية كاملة
  // ---------------------------

  String _translate(String label) {
    switch (label) {
      case "person":
        return "شخص";
      case "bicycle":
        return "دراجة";
      case "car":
        return "سيارة";
      case "motorcycle":
        return "دراجة نارية";
      case "airplane":
        return "طائرة";
      case "bus":
        return "باص";
      case "train":
        return "قطار";
      case "truck":
        return "شاحنة";
      case "boat":
        return "قارب";
      case "traffic light":
        return "إشارة مرور";
      case "fire hydrant":
        return "صنبور إطفاء";
      case "stop sign":
        return "إشارة توقف";
      case "parking meter":
        return "عداد موقف";
      case "bench":
        return "مقعد";
      case "bird":
        return "طائر";
      case "cat":
        return "قطة";
      case "dog":
        return "كلب";
      case "horse":
        return "حصان";
      case "sheep":
        return "خروف";
      case "cow":
        return "بقرة";
      case "elephant":
        return "فيل";
      case "bear":
        return "دب";
      case "zebra":
        return "حمار وحشي";
      case "giraffe":
        return "زرافة";
      case "backpack":
        return "حقيبة ظهر";
      case "umbrella":
        return "مظلة";
      case "handbag":
        return "حقيبة يد";
      case "tie":
        return "ربطة عنق";
      case "suitcase":
        return "حقيبة سفر";
      case "frisbee":
        return "قرص طائر";
      case "skis":
        return "زلاجات";
      case "snowboard":
        return "لوح تزلج";
      case "sports ball":
        return "كرة رياضية";
      case "kite":
        return "طائرة ورقية";
      case "baseball bat":
        return "مضرب بيسبول";
      case "baseball glove":
        return "قفاز بيسبول";
      case "skateboard":
        return "لوح تزلج";
      case "surfboard":
        return "لوح ركوب الأمواج";
      case "tennis racket":
        return "مضرب تنس";
      case "bottle":
        return "زجاجة";
      case "wine glass":
        return "كأس";
      case "cup":
        return "فنجان";
      case "fork":
        return "شوكة";
      case "knife":
        return "سكين";
      case "spoon":
        return "ملعقة";
      case "bowl":
        return "وعاء";
      case "banana":
        return "موزة";
      case "apple":
        return "تفاحة";
      case "sandwich":
        return "ساندويتش";
      case "orange":
        return "برتقالة";
      case "broccoli":
        return "بروكلي";
      case "carrot":
        return "جزرة";
      case "hot dog":
        return "هوت دوغ";
      case "pizza":
        return "بيتزا";
      case "donut":
        return "دونات";
      case "cake":
        return "كيك";
      case "chair":
        return "كرسي";
      case "couch":
        return "كنبة";
      case "potted plant":
        return "نبتة";
      case "bed":
        return "تخت";
      case "dining table":
        return "طاولة طعام";
      case "toilet":
        return "مرحاض";
      case "tv":
        return "تلفاز";
      case "laptop":
        return "لابتوب";
      case "mouse":
        return "فأرة";
      case "remote":
        return "ريموت";
      case "keyboard":
        return "كيبورد";
      case "cell phone":
        return "موبايل";
      case "microwave":
        return "ميكرويف";
      case "oven":
        return "فرن";
      case "toaster":
        return "محمر خبز";
      case "sink":
        return "مغسلة";
      case "refrigerator":
        return "براد";
      case "book":
        return "كتاب";
      case "clock":
        return "ساعة";
      case "vase":
        return "مزهرية";
      case "scissors":
        return "مقص";
      case "teddy bear":
        return "دبدوب";
      case "hair drier":
        return "مجفف شعر";
      case "toothbrush":
        return "فرشاة أسنان";
      default:
        return label;
    }
  }

  // ---------------------------
  // UI + YOLO + OCR Double Tap
  // ---------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("نظام الرؤية الذكي"),
        backgroundColor: Colors.amber,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onDoubleTap: () async {
                await _readTextFromCamera();
              },
              child: RepaintBoundary(
                key: _cameraKey,
                child: YOLOView(
                  modelPath: _modelPath!,
                  task: YOLOTask.detect,
                  useGpu: false,
                  onResult: (results) async {
                    if (assistantBusy) return;
                    if (results.isEmpty) return;

                    results = results.where((r) => r.confidence > 0.5).toList();
                    if (results.isEmpty) return;

                    results.sort(
                      (a, b) => (b.boundingBox.width * b.boundingBox.height)
                          .compareTo(
                            a.boundingBox.width * a.boundingBox.height,
                          ),
                    );

                    final r = results.first;
                    final rect = r.boundingBox;

                    final screenWidth = MediaQuery.of(context).size.width;
                    final screenHeight = MediaQuery.of(context).size.height;
                    final screenArea = screenWidth * screenHeight;

                    final centerX = rect.center.dx;
                    String direction;

                    if (centerX < screenWidth * 0.33) {
                      direction = "على يسارك";
                    } else if (centerX > screenWidth * 0.66) {
                      direction = "على يمينك";
                    } else {
                      direction = "أمامك";
                    }

                    final area = rect.width * rect.height;
                    String distance;
                    bool danger = false;

                    if (area > screenArea * 0.40) {
                      distance = "قريب جدًا";
                      danger = true;
                    } else if (area > screenArea * 0.25) {
                      distance = "قريب";
                    } else if (area > screenArea * 0.10) {
                      distance = "متوسط";
                    } else {
                      distance = "بعيد";
                    }

                    if (DateTime.now()
                            .difference(lastSpeakTime)
                            .inMilliseconds <
                        1800) {
                      return;
                    }

                    if (isSpeaking) return;

                    final name = _translate(r.className);

                    String message;

                    if (danger) {
                      message = "تحذير! جسم قريب جدًا أمامك";
                    } else {
                      message = "$direction $name $distance";
                    }

                    if (_lastSpokenMessage == message &&
                        DateTime.now().difference(_lastMessageTime).inSeconds <
                            4) {
                      return;
                    }

                    assistantBusy = true;
                    isSpeaking = true;
                    lastSpeakTime = DateTime.now();

                    try {
                      await tts.speak(message);
                      _lastSpokenMessage = message;
                      _lastMessageTime = DateTime.now();
                    } finally {
                      isSpeaking = false;
                      assistantBusy = false;
                    }
                  },
                ),
              ),
            ),
    );
  }
}
