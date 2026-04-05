// import 'package:flutter/material.dart';
// import 'package:ultralytics_yolo/ultralytics_yolo.dart';

// class BoxPainter extends CustomPainter {
//   final List<YOLOResult> detections;
//   final Size previewSize;

//   BoxPainter(this.detections, this.previewSize);

//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..color = Colors.greenAccent
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 3;

//     final scaleX = size.width / previewSize.height;
//     final scaleY = size.height / previewSize.width;

//     for (final d in detections) {
//       final rect = d.boundingBox;

//       final left = rect.left * scaleX;
//       final top = rect.top * scaleY;
//       final right = rect.right * scaleX;
//       final bottom = rect.bottom * scaleY;

//       final scaledRect = Rect.fromLTRB(left, top, right, bottom);
//       canvas.drawRect(scaledRect, paint);

//       final textPainter = TextPainter(
//         text: TextSpan(
//           text: '${d.className} ${(d.confidence * 100).toStringAsFixed(0)}%',
//           style: const TextStyle(
//             color: Colors.white,
//             backgroundColor: Colors.green,
//             fontSize: 14,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         textDirection: TextDirection.ltr,
//       )..layout();

//       textPainter.paint(canvas, Offset(left, top - 20));
//     }
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
// }
