import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  List<YOLOResult> _results = [];

  String? _modelPath;
  bool _loading = true;

  // الصوت
  final FlutterTts tts = FlutterTts();
  bool isSpeaking = false;

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
    _loadModel();

    // إعدادات الصوت
    tts.setLanguage("ar");
    tts.setSpeechRate(0.5);
    tts.setPitch(1.0);
    tts.awaitSpeakCompletion(true);
  }

  Future<void> _loadModel() async {
    try {
      final assetPath = await _resolveModelPath();
      final path = await _materializeAssetToFile(assetPath);

      setState(() {
        _modelPath = path;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading model: $e');
    }
  }

  Future<String> _resolveModelPath() async {
    for (final path in _candidateModelPaths) {
      try {
        await rootBundle.load(path);
        return path;
      } catch (_) {}
    }

    throw StateError(
      'No .tflite model found. Tried:\n- ${_candidateModelPaths.join('\n- ')}',
    );
  }

  Future<String> _materializeAssetToFile(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final dir = await getTemporaryDirectory();
    final fileName = assetPath.split('/').last;
    final file = File('${dir.path}/$fileName');

    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );

    return file.path;
  }

  // ترجمة أسماء الكائنات
  String _translate(String label) {
    switch (label) {
      case "person":
        return "شخص";
      case "car":
        return "سيارة";
      case "chair":
        return "كرسي";
      case "dog":
        return "كلب";
      case "cat":
        return "قطة";
      case "bottle":
        return "زجاجة";
      case "cup":
        return "فنجان";
      case "laptop":
        return "لابتوب";
      case "phone":
        return "هاتف";
      default:
        return label;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("نظام الرؤية الذكي"),
        backgroundColor: Colors.amber,
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                YOLOView(
                  modelPath: _modelPath!,
                  useGpu: false,
                  task: YOLOTask.detect,
                  onResult: (results) async {
                    if (!mounted || _loading) return;

                    setState(() {
                      _results = results;
                    });

                    if (results.isNotEmpty && !isSpeaking) {
                      isSpeaking = true;

                      Map<String, List<String>> detected = {};

                      final screenWidth = MediaQuery.of(context).size.width;
                      final screenHeight = MediaQuery.of(context).size.height;
                      final screenArea = screenWidth * screenHeight;

                      for (var r in results) {
                        final rect = r.boundingBox;

                        // الاتجاه
                        final centerX = rect.center.dx;
                        String direction;
                        if (centerX < screenWidth * 0.33) {
                          direction = "على اليسار";
                        } else if (centerX > screenWidth * 0.66) {
                          direction = "على اليمين";
                        } else {
                          direction = "أمامك";
                        }

                        // المسافة
                        final width = rect.width;
                        final height = rect.height;
                        final area = width * height;

                        String distance;
                        if (area > screenArea * 0.25) {
                          distance = "قريب";
                        } else if (area > screenArea * 0.10) {
                          distance = "متوسط";
                        } else {
                          distance = "بعيد";
                        }

                        final name = _translate(r.className);

                        detected.putIfAbsent(name, () => []);
                        detected[name]!.add("$direction و $distance");
                      }

                      // تركيب الجملة
                      List<String> parts = [];

                      detected.forEach((name, dirs) {
                        final count = dirs.length;

                        String countText;
                        if (count == 1) {
                          countText = "$name واحد";
                        } else if (count == 2) {
                          countText = "$name اثنان";
                        } else {
                          countText = "$count $name";
                        }

                        String directionDistance;
                        if (dirs.toSet().length == 1) {
                          directionDistance = dirs.first;
                        } else {
                          directionDistance = "في عدة اتجاهات ومسافات";
                        }

                        parts.add("$countText $directionDistance");
                      });

                      final sentence = parts.join(" و ");

                      await tts.speak("تم اكتشاف $sentence");

                      await Future.delayed(const Duration(seconds: 2));
                      isSpeaking = false;
                    }
                  },
                ),

                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Detections: ${_results.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
