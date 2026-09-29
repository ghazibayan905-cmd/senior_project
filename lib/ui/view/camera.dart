import 'dart:async';

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
import 'package:translator/translator.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  String? _modelPath;
  bool _loading = true;
  String espIp = "10.159.248.41";

  String get espCaptureUrl => "http://$espIp/capture";

  static const MethodChannel _platform = MethodChannel("voice_service_channel");

  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText sttInstance = stt.SpeechToText();
  final translator = GoogleTranslator();
  static const String _placeServerUrl = 'http://192.168.2.174:5000';
  // عداد الضغطات
  int _tapCount = 0;
  DateTime _lastTapTime = DateTime.now();

  // موديل العملة
  late YOLO currencyModel;
  late YOLO objectModel;

  bool wakeWordDetected = false;
  bool assistantBusy = false;
  bool isSpeaking = false;
  bool readingText = false;
  bool detectingPlace = false;
  bool useEspCamera = false;

  static const List<String> _currencyLabels = [
    '200-new',
    '2000-old',
    '25-new',
    '50-new',
    '500-new',
    '5000-old',
  ];

  static const Map<String, String> _currencyLabelArabic = {
    '200-new': '200 ليرة جديدة',
    '2000-old': '2000 ليرة قديمة',
    '25-new': '25 ليرة جديدة',
    '50-new': '50 ليرة جديدة',
    '500-new': '500 ليرة جديدة',
    '5000-old': '5000 ليرة قديمة',
  };

  Timer? espTimer;
  String lastEspmessage = "";
  DateTime lastPlaceDetection = DateTime.now().subtract(
    const Duration(seconds: 10),
  );

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

  // متغيرات عرض المسافة
  double _currentDistance = 0.0; // المسافة التقريبية بالسنتيمتر
  String _currentDistanceCategory = "بعيد";
  double _distancePercentage = 0.0; // نسبة الاقتراب من 0 إلى 1

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
    _loadCurrencyModel();

    tts.setLanguage("ar");
    tts.setSpeechRate(0.5);
    tts.setPitch(1.0);
    tts.awaitSpeakCompletion(true);
    tts.speak(
      "أهلاً بكَ  في  تطبيق   فيجن ، تمَ  تشغيل  ميزة  التعرف  على الأشياء  تلقائياً    يمكنكَ   سحب    الشاشة   للأعلى  للتعرف على  العملات،   أو الضغط   مرتين  لقراءة  النصوص  ،  أو  الضغط  مطولاً   للتعرف   على   المكان . كما  يمكنكَ  الاستفسار  عن  الوقت و  الطقس  عند  سؤال  فيجن . عندَ استخدامكَ  الكاميرا  الخارجية  يرجى   وصلها  بمصدر  طاقة  خارجي . بخصوص  المسافات: إذا كان الجسم قريب جداً فالمسافة تكون أقل من 50 سنتيمتر. إذا كان قريب فالمسافة بين 50 و 100 سنتيمتر. إذا كان متوسط فالمسافة بين 1 متر و متر ونصف. إذا كان بعيد فالمسافة أكثر  من متر ونصف.",
    );
    initVoiceAssistant();
    espTimer = Timer.periodic(const Duration(milliseconds: 700), (_) async {
      if (!useEspCamera) return;

      if (!assistantBusy && !isSpeaking) {
        await testObjectModel();
      }
    });
  }

  Future<void> _loadCurrencyModel() async {
    final data = await rootBundle.load(
      'assets/models/currency/best_float32.tflite',
    );
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/currency.tflite');
    await file.writeAsBytes(data.buffer.asUint8List());

    currencyModel = YOLO(modelPath: file.path, task: YOLOTask.detect);
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

  Future<void> _detectCurrency() async {
    if (assistantBusy) return;

    assistantBusy = true;
    isSpeaking = true;

    final pngBytes = await _capturePng();
    if (pngBytes == null) {
      await tts.speak("فشل التقاط الصورة");
      assistantBusy = false;
      isSpeaking = false;
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/currency.png');
    await file.writeAsBytes(pngBytes);

    final bytes = await file.readAsBytes();
    final results = await currencyModel.predict(bytes);

    print("CURRENCY MODEL OUTPUT: $results");
    print("CURRENCY MODEL TYPE: ${results.runtimeType}");

    // ⭐ استخراج الصناديق من Map أو List
    List<dynamic> boxes = [];

    if (results is Map && results["boxes"] is List) {
      boxes = results["boxes"];
    } else if (results is List) {
      boxes = results as List;
    }

    if (boxes.isEmpty) {
      await tts.speak("لم أتعرف على أي عملة");
      assistantBusy = false;
      isSpeaking = false;
      return;
    }

    // ⭐ تجميع أسماء العملات المسموح بها فقط
    List<String> labels = [];

    for (var r in boxes) {
      String rawLabel = "";
      double confidence = 0.0;

      if (r is YOLOResult && r.className != null) {
        rawLabel = r.className.toString();
        confidence = r.confidence ?? 0.0;
      } else if (r is Map) {
        rawLabel = r["className"]?.toString() ?? r["class"]?.toString() ?? "";
        confidence = (r["confidence"] is num)
            ? (r["confidence"] as num).toDouble()
            : 0.0;
      }

      if (!_currencyLabels.contains(rawLabel) || confidence < 0.5) {
        print("IGNORE CURRENCY RESULT: $rawLabel (confidence=$confidence)");
        continue;
      }

      labels.add(_currencyLabelArabic[rawLabel] ?? rawLabel);
    }

    if (labels.isEmpty) {
      await tts.speak("لم أتعرف على أي عملة");
      assistantBusy = false;
      isSpeaking = false;
      return;
    }

    // ⭐ نطق حسب عدد العملات
    if (labels.length == 1) {
      await tts.stop();
      await tts.speak("العملة هي ${labels.first}");
    } else {
      String joined = labels.join(" و ");
      await tts.stop();
      await tts.speak("لديك أكثر من عملة: $joined");
    }

    assistantBusy = false;
    isSpeaking = false;
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

  void startVoiceLoop() {
    Future.doWhile(() async {
      if (!mounted) return false;

      if (!assistantBusy &&
          !isSpeaking &&
          !sttInstance.isListening &&
          DateTime.now().difference(lastListenTime).inSeconds >= 3) {
        lastListenTime = DateTime.now();
        listenForWakeWord();
      }

      await Future.delayed(const Duration(milliseconds: 500));

      return mounted;
    });
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
        final isExternalMode =
            text.contains("الوضع الخارجي") ||
            text.contains("فعل الوضع الخارجي") ||
            text.contains("تفعيل الوضع الخارجي");

        final isInternalMode =
            text.contains("الوضع الداخلي") ||
            text.contains("فعل الوضع الداخلي") ||
            text.contains("تفعيل الوضع الداخلي");
        print("TEXT = $text");
        print("External = $isExternalMode");
        print("Internal = $isInternalMode");
        if (!(isTime || isWeather || isExternalMode || isInternalMode)) return;
        if (isExternalMode) {
          print("1- External command");

          final frame = await getEspFrame();

          print("2- Frame received = ${frame != null}");

          if (frame != null) {
            print("3- Before setState");

            setState(() {
              useEspCamera = true;
            });

            print("4- Before speak");

            await tts.speak("تم تفعيل الوضع الخارجي");

            print("5- After speak");
          } else {
            print("ESP NOT AVAILABLE");

            setState(() {
              useEspCamera = false;
            });

            await tts.speak("الرجاء وصل الكاميرا بمصدر طاقة لاستخدامها");
          }
        } else if (isInternalMode) {
          setState(() {
            useEspCamera = false;
          });

          await tts.speak("تم تفعيل الوضع الداخلي");
        } else if (isTime) {
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

      final image = await boundary.toImage(pixelRatio: 0.5);

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      final bytes = byteData?.buffer.asUint8List();

      image.dispose();

      return bytes;
    } catch (e) {
      print("CAPTURE ERROR: $e");
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

    _modelPath = file.path;

    objectModel = YOLO(modelPath: _modelPath!, task: YOLOTask.detect);

    await objectModel.loadModel();
    print("OBJECT MODEL LOADED");

    setState(() {
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

  // دالة حساب المسافة التقريبية من مساحة الكائن
  Map<String, dynamic> _calculateDistance(
    double objectArea,
    double screenArea,
  ) {
    String category;
    double estimatedDistance; // المسافة التقريبية بالسنتيمتر
    double percentage; // نسبة الاقتراب (0 = بعيد جداً، 1 = قريب جداً)

    final areaRatio = objectArea / screenArea;

    if (areaRatio > 0.40) {
      category = "قريب جدًا";
      estimatedDistance = 30; // 30 سم
      percentage = 1.0;
    } else if (areaRatio > 0.25) {
      category = "قريب";
      estimatedDistance = 60; // 60 سم
      percentage = 0.75;
    } else if (areaRatio > 0.10) {
      category = "متوسط";
      estimatedDistance = 120; // 1.2 متر
      percentage = 0.4;
    } else if (areaRatio > 0.04) {
      category = "بعيد";
      estimatedDistance = 250; // 2.5 متر
      percentage = 0.15;
    } else {
      category = "بعيد جداً";
      estimatedDistance = 500; // 5 متر+
      percentage = 0.05;
    }

    return {
      'category': category,
      'distance': estimatedDistance,
      'percentage': percentage,
      'areaRatio': areaRatio,
    };
  }

  // دالة تحويل المسافة إلى رسالة صوتية واضحة
  String _getDistanceMessage(double distanceInCm) {
    if (distanceInCm < 50) {
      return "على مسافة ${distanceInCm.toStringAsFixed(0)} سنتيمتر فقط";
    } else if (distanceInCm < 100) {
      return "على مسافة ${distanceInCm.toStringAsFixed(0)} سنتيمتر";
    } else if (distanceInCm < 200) {
      int remainingCm = (distanceInCm % 100).toInt();
      if (remainingCm == 0) {
        return "على بعد متر واحد";
      } else {
        return "على بعد متر و${remainingCm} سنتيمتر";
      }
    } else if (distanceInCm < 500) {
      double meters = distanceInCm / 100;
      return "على بعد ${meters.toStringAsFixed(1)} متر";
    } else {
      double meters = distanceInCm / 100;
      return "على بعد حوالي ${meters.toStringAsFixed(0)} متر";
    }
  }

  String _translatePlace(String place) {
    switch (place.toLowerCase()) {
      case "bedroom":
        return "غرفة نوم";

      case "living_room":
      case "living room":
        return "غرفة جلوس";

      case "kitchen":
        return "مطبخ";

      case "bathroom":
        return "حمام";

      case "office":
        return "مكتب";

      case "corridor":
        return "ممر";

      case "street":
        return "شارع";

      case "restaurant":
        return "مطعم";

      case "classroom":
        return "صف";

      case "library":
        return "مكتبة";

      case "supermarket":
        return "سوبرماركت";

      case "park":
        return "حديقة";

      case "hospital":
        return "مشفى";

      case "airport":
        return "مطار";

      case "train_station":
      case "train station":
        return "محطة قطار";

      case "bus_station":
      case "bus station":
        return "محطة باص";

      case "beach":
        return "شاطئ";

      case "forest":
        return "غابة";

      case "mountain":
        return "جبل";

      case "bridge":
        return "جسر";

      case "stadium":
        return "ملعب";

      case "gym":
        return "نادي رياضي";

      case "cafe":
        return "مقهى";

      case "shop":
        return "متجر";

      case "hotel":
        return "فندق";

      default:
        return place.replaceAll("_", " ");
    }
  }
  // ---------------------------
  // UI + YOLO + OCR Double Tap
  // ---------------------------
  // ---------------------------
  // Places365 API
  // ---------------------------

  Future<void> _detectPlace() async {
    print("START PLACE DETECTION");

    // منع التكرار
    if (detectingPlace) return;

    if (DateTime.now().difference(lastPlaceDetection).inSeconds < 8) {
      return;
    }

    detectingPlace = true;
    assistantBusy = true;
    isSpeaking = true;
    lastPlaceDetection = DateTime.now();

    try {
      await tts.stop();

      // التقاط صورة
      final pngBytes = await _capturePng();
      print("PNG SIZE = ${pngBytes?.length}");

      if (pngBytes == null) {
        await tts.speak("فشل التقاط الصورة");

        assistantBusy = false;
        isSpeaking = false;
        detectingPlace = false;

        return;
      }

      // حفظ الصورة مؤقتاً
      final tempDir = await getTemporaryDirectory();

      final file = File('${tempDir.path}/place.png');

      await file.writeAsBytes(pngBytes);

      print("IMAGE SAVED: ${file.path}");

      // إرسال الطلب للسيرفر
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_placeServerUrl/predict_place'),
      );

      // إضافة الصورة
      request.files.add(await http.MultipartFile.fromPath('image', file.path));

      print("SENDING REQUEST...");

      // إرسال الطلب
      final response = await request.send().timeout(
        const Duration(seconds: 10),
      );
      print("STATUS CODE: ${response.statusCode}");

      // قراءة الرد
      final responseData = await response.stream.bytesToString();

      print("RESPONSE: $responseData");

      // نجاح
      if (response.statusCode == 200) {
        final data = jsonDecode(responseData);

        String place = data["place"];

        print("PLACE RESULT: $place");

        // تنسيق الاسم
        place = place.replaceAll("_", " ");

        await tts.stop();

        await tts.setLanguage("ar");

        await tts.setSpeechRate(0.5);

        print("SPEAKING PLACE: $place");

        // نطق المكان
        place = place.replaceAll("_", " ");
        final translated = await translator.translate(
          place,
          from: 'en',
          to: 'ar',
        );

        await tts.speak("أنت في ${translated.text}");

        // منع YOLO من المقاطعة
        await Future.delayed(const Duration(seconds: 4));
      } else {
        print("SERVER ERROR");

        await tts.speak("فشل التعرف على المكان");
      }
    } catch (e) {
      print("PLACE ERROR FULL: ${e.toString()}");

      await tts.speak("حدث خطأ في الاتصال بالسيرفر");
    }
    assistantBusy = false;
    isSpeaking = false;
    detectingPlace = false;
  }

  Future<Uint8List?> getEspFrame() async {
    try {
      final response = await http.get(Uri.parse(espCaptureUrl));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }

      return null;
    } catch (e) {
      print("ESP ERROR: $e");
      return null;
    }
  }

  Future<void> testObjectModel() async {
    final frame = await getEspFrame();

    if (frame == null) {
      print("NO FRAME");
      return;
    }

    final results = await objectModel.predict(frame);

    final boxes = results["boxes"] as List;

    if (boxes.isEmpty) return;

    // ترتيب حسب أكبر مساحة (الأقرب أولاً)
    boxes.sort((a, b) {
      final areaA =
          ((a["x2"] as num).toDouble() - (a["x1"] as num).toDouble()) *
          ((a["y2"] as num).toDouble() - (a["y1"] as num).toDouble());

      final areaB =
          ((b["x2"] as num).toDouble() - (b["x1"] as num).toDouble()) *
          ((b["y2"] as num).toDouble() - (b["y1"] as num).toDouble());

      return areaB.compareTo(areaA);
    });

    String finalMessage = "";

    for (final first in boxes.take(5)) {
      final x1 = (first["x1"] as num).toDouble();
      final x2 = (first["x2"] as num).toDouble();
      final y1 = (first["y1"] as num).toDouble();
      final y2 = (first["y2"] as num).toDouble();

      final centerX = (x1 + x2) / 2;

      String direction;

      if (centerX < 320 * 0.33) {
        direction = "على يسارك";
      } else if (centerX > 320 * 0.66) {
        direction = "على يمينك";
      } else {
        direction = "أمامك";
      }

      final width = x2 - x1;
      final height = y2 - y1;

      final area = width * height;

      String distance;

      if (area > 25000) {
        distance = "قريب جدًا";
      } else if (area > 15000) {
        distance = "قريب";
      } else if (area > 7000) {
        distance = "متوسط";
      } else {
        distance = "بعيد";
      }

      final className = first["className"].toString();
      final arabicName = _translate(className);

      finalMessage += "$direction $arabicName $distance، ";
    }

    // لا تعيد نفس الرسالة
    if (finalMessage != lastEspmessage) {
      lastEspmessage = finalMessage;

      print("NEW MESSAGE = $finalMessage");

      if (!assistantBusy && !isSpeaking) {
        assistantBusy = true;

        await tts.speak(finalMessage);

        assistantBusy = false;
      }
    }
  }

  Future<void> testEspPrediction() async {
    final frame = await getEspFrame();

    if (frame == null) {
      print("No frame received");
      return;
    }

    final results = await objectModel.predict(frame);

    final boxes = results["boxes"] as List;

    print("Boxes Count = ${boxes.length}");

    for (var box in boxes) {
      print(box);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
              children: [
                // ESP32-CAM Stream

                // Loading Indicator while WebView loads
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 20),
                      Text(
                        "جاري تحميل البث...",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ],
                  ),
                ),

                // =========================
                // CAMERA VIEW - Hidden (keeping for capture functionality)
                // =========================
                if (!useEspCamera)
                  RepaintBoundary(
                    key: _cameraKey,
                    child: YOLOView(
                      modelPath: _modelPath!,
                      task: YOLOTask.detect,
                      useGpu: false,

                      onResult: (results) async {
                        if (detectingPlace) return;
                        if (assistantBusy) return;
                        if (results.isEmpty) return;

                        results = results
                            .where((r) => r.confidence > 0.5)
                            .toList();

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

                        final distanceInfo = _calculateDistance(
                          area,
                          screenArea,
                        );
                        distance = distanceInfo['category'];
                        final estimatedDist =
                            distanceInfo['distance'] as double;
                        final percentage = distanceInfo['percentage'] as double;

                        // تحديث المتغيرات لعرض المسافة
                        setState(() {
                          _currentDistance = estimatedDist;
                          _currentDistanceCategory = distance;
                          _distancePercentage = percentage;
                        });

                        if (area > screenArea * 0.40) {
                          danger = true;
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
                          String distanceMessage = _getDistanceMessage(
                            estimatedDist,
                          );
                          message =
                              "$direction $name، $distanceMessage، قريب جدًا";
                        } else {
                          // إضافة المسافة بالصوت بشكل تفصيلي
                          String distanceMessage = _getDistanceMessage(
                            estimatedDist,
                          );
                          message = "$direction $name، $distanceMessage";
                        }

                        if (_lastSpokenMessage == message &&
                            DateTime.now()
                                    .difference(_lastMessageTime)
                                    .inSeconds <
                                4) {
                          return;
                        }

                        setState(() {
                          _lastSpokenMessage = message;
                        });

                        assistantBusy = true;
                        isSpeaking = true;

                        lastSpeakTime = DateTime.now();

                        try {
                          if (danger) {
                            if (await Vibration.hasVibrator() ?? false) {
                              Vibration.vibrate(duration: 700);
                            }
                          }

                          await tts.speak(message);

                          _lastMessageTime = DateTime.now();
                        } finally {
                          isSpeaking = false;
                          assistantBusy = false;
                        }
                      },
                    ),
                  ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,

                    // ⭐ سحب للأعلى
                    onPanUpdate: (details) async {
                      if (details.delta.dy < -15) {
                        print("DEBUG: swipe up → currency");
                        await _detectCurrency();
                      }
                    },

                    // ⭐ دبل تاب → OCR
                    onDoubleTap: () async {
                      print("DEBUG: double tap detected");
                      await _readTextFromCamera();
                    },

                    // ⭐ لونغ برس → مكان
                    onLongPress: () async {
                      print("DEBUG: long press detected");
                      await _detectPlace();
                    },

                    child: Container(color: Colors.transparent),
                  ),
                ),

                // =========================
                // TOP STATUS BAR
                // =========================
                Positioned(
                  top: 50,
                  left: 20,
                  right: 20,

                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),

                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),

                      borderRadius: BorderRadius.circular(20),

                      border: Border.all(color: Colors.white24),
                    ),

                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,

                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,

                              decoration: BoxDecoration(
                                color: isSpeaking ? Colors.red : Colors.green,

                                shape: BoxShape.circle,
                              ),
                            ),

                            const SizedBox(width: 10),

                            Text(
                              isSpeaking ? "يتحدث" : "جاهز",

                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        const Text(
                          "وضع التنقل",

                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // =========================
                // MIC INDICATOR
                // =========================
                if (sttInstance.isListening)
                  Positioned(
                    bottom: 160,
                    left: 0,
                    right: 0,

                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),

                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.8),

                          shape: BoxShape.circle,
                        ),

                        child: const Icon(
                          Icons.mic,
                          color: Colors.white,
                          size: 45,
                        ),
                      ),
                    ),
                  ),

                // =========================
                // DISTANCE METER INDICATOR
                // =========================
                if (_currentDistance > 0)
                  Positioned(
                    right: 20,
                    top: 200,
                    width: 80,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _distancePercentage > 0.75
                              ? Colors.red
                              : _distancePercentage > 0.4
                              ? Colors.orange
                              : Colors.green,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // أيقونة المسافة
                          Icon(
                            _distancePercentage > 0.75
                                ? Icons.location_on_outlined
                                : Icons.trending_down,
                            color: _distancePercentage > 0.75
                                ? Colors.red
                                : _distancePercentage > 0.4
                                ? Colors.orange
                                : Colors.green,
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          // مؤشر المسافة البصري
                          SizedBox(
                            width: 48,
                            height: 4,
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    width: 48 * _distancePercentage,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: _distancePercentage > 0.75
                                          ? Colors.red
                                          : _distancePercentage > 0.4
                                          ? Colors.orange
                                          : Colors.green,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // نص المسافة
                          Text(
                            '${_currentDistance.toStringAsFixed(0)} سم',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentDistanceCategory,
                            style: TextStyle(
                              color: _distancePercentage > 0.75
                                  ? Colors.red
                                  : _distancePercentage > 0.4
                                  ? Colors.orange
                                  : Colors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                // =========================
                // DETECTION CARD
                // =========================
                Positioned(
                  bottom: 40,
                  left: 20,
                  right: 20,

                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),

                    padding: const EdgeInsets.all(20),

                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),

                      borderRadius: BorderRadius.circular(24),

                      border: Border.all(color: Colors.white24),
                    ),

                    child: Column(
                      mainAxisSize: MainAxisSize.min,

                      children: [
                        const Text(
                          "آخر تنبيه",

                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          _lastSpokenMessage.isEmpty
                              ? "بانتظار الكشف..."
                              : _lastSpokenMessage,

                          textAlign: TextAlign.center,

                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        // عرض المسافة بشكل إضافي
                        if (_currentDistance > 0) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _distancePercentage > 0.75
                                  ? Colors.red.withOpacity(0.3)
                                  : _distancePercentage > 0.4
                                  ? Colors.orange.withOpacity(0.3)
                                  : Colors.green.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'المسافة التقريبية: ${_currentDistance.toStringAsFixed(0)} سم ($_currentDistanceCategory)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _distancePercentage > 0.75
                                    ? Colors.red
                                    : _distancePercentage > 0.4
                                    ? Colors.orange
                                    : Colors.green,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    // إيقاف الـ Timer أولاً
    espTimer?.cancel();

    // إيقاف التعرف على الصوت
    try {
      sttInstance.stop();
    } catch (e) {
      debugPrint('Error stopping STT: $e');
    }

    // إيقاف text-to-speech
    try {
      tts.stop();
    } catch (e) {
      debugPrint('Error stopping TTS: $e');
    }

    super.dispose();
  }
}
