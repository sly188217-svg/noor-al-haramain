import 'package:flutter/material.dart';

void main() {
  runApp(const IconPreviewApp());
}

class IconPreviewApp extends StatelessWidget {
  const IconPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0B132B), // نفس لون خلفية تطبيقك
        appBar: AppBar(
          title: const Text('معاينة الأزرار ثلاثية الأبعاد', style: TextStyle(fontFamily: 'Amiri')),
          backgroundColor: const Color(0xFF1C2541),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: [
                _buildIconPreview('assets/images/ui_buttons/qibla.png', 'القبلة'),
                _buildIconPreview('assets/images/ui_buttons/kids.png', 'أطفال'),
                _buildIconPreview('assets/images/ui_buttons/donate.png', 'تبرع'),
                _buildIconPreview('assets/images/ui_buttons/location.png', 'موقعي'),
                _buildIconPreview('assets/images/ui_buttons/settings.png', 'إعدادات'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconPreview(String path, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            color: const Color(0xFF1C2541),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF4A90E2).withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, 5),
              )
            ]
          ),
          padding: const EdgeInsets.all(15),
          // عرض الصورة
          child: Image.asset(
            path,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.red, size: 40),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label, 
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
        ),
      ],
    );
  }
}
