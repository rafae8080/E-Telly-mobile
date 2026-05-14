// import 'package:flutter/material.dart';

// class WalkieTalkieIcon extends StatelessWidget {
//   final double size;
//   final Color color;
  
//   const WalkieTalkieIcon({
//     super.key,
//     this.size = 28,
//     this.color = Colors.white,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return CustomPaint(
//       size: Size(size, size),
//       painter: WalkieTalkieIconPainter(color: color),
//     );
//   }
// }

// class WalkieTalkieIconPainter extends CustomPainter {
//   final Color color;
  
//   WalkieTalkieIconPainter({required this.color});
  
//   @override
//   void paint(Canvas canvas, Size size) {
//     final width = size.width;
//     final height = size.height;
    
//     final paint = Paint()
//       ..color = color
//       ..style = PaintingStyle.fill;
    
//     // Main body
//     canvas.drawRRect(
//       RRect.fromRectAndRadius(
//         Rect.fromLTWH(width * 0.2, height * 0.25, width * 0.6, height * 0.6),
//         Radius.circular(width * 0.1),
//       ),
//       paint,
//     );
    
//     // Antenna
//     canvas.drawRect(
//       Rect.fromLTWH(width * 0.45, height * 0.1, width * 0.1, height * 0.15),
//       paint,
//     );
    
//     // Antenna tip
//     canvas.drawCircle(
//       Offset(width * 0.5, height * 0.09),
//       width * 0.07,
//       paint,
//     );
    
//     // Speaker grille (horizontal lines)
//     final grillePaint = Paint()
//       ..color = Colors.white.withOpacity(0.5)
//       ..style = PaintingStyle.fill;
    
//     for (int i = 0; i < 3; i++) {
//       canvas.drawRect(
//         Rect.fromLTWH(
//           width * 0.3,
//           height * 0.4 + i * (height * 0.05),
//           width * 0.4,
//           height * 0.02,
//         ),
//         grillePaint,
//       );
//     }
    
//     // LED indicator
//     canvas.drawCircle(
//       Offset(width * 0.7, height * 0.45),
//       width * 0.05,
//       Paint()..color = Colors.green,
//     );
    
//     // PTT button outline
//     canvas.drawRRect(
//       RRect.fromRectAndRadius(
//         Rect.fromLTWH(width * 0.3, height * 0.65, width * 0.4, height * 0.15),
//         Radius.circular(width * 0.05),
//       ),
//       Paint()
//         ..color = Colors.white.withOpacity(0.3)
//         ..style = PaintingStyle.stroke
//         ..strokeWidth = width * 0.02,
//     );
    
//     // PTT text
//     final textPainter = TextPainter(
//       text: TextSpan(
//         text: 'PTT',
//         style: TextStyle(
//           color: Colors.white.withOpacity(0.7),
//           fontSize: width * 0.08,
//           fontWeight: FontWeight.bold,
//         ),
//       ),
//       textDirection: TextDirection.ltr,
//     );
//     textPainter.layout();
//     textPainter.paint(
//       canvas,
//       Offset(width * 0.43, height * 0.685),
//     );
//   }
  
//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
// }