import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/language_provider.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLang;
    final isArabic = lang == 'ar';

    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2541),
        elevation: 0,
        title: Text(
          isArabic ? 'سياسة الخصوصية' : 'Privacy Policy',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFD4AF37)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isArabic ? '📋 سياسة الخصوصية' : '📋 Privacy Policy',
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildSection(
                isArabic ? '1. المعلومات التي نجمعها' : '1. Information We Collect',
                isArabic
                    ? 'لا نجمع أي معلومات شخصية من المستخدمين. التطبيق لا يطلب أو يخزن اسمك، بريدك الإلكتروني، رقم هاتفك، أو أي بيانات تعريف شخصية.'
                    : 'We do not collect any personal information from users. The app does not request or store your name, email, phone number, or any personally identifiable data.',
              ),
              _buildSection(
                isArabic ? '2. استخدام البيانات' : '2. Data Usage',
                isArabic
                    ? 'يستخدم التطبيق اتصال الإنترنت لجلب أوقات الصلاة، القرآن الكريم، والأحاديث النبوية من مصادر موثوقة (AlAdhan API، AlQuran API، Dorar Hadith API). يتم تخزين بعض الإعدادات المحلية فقط على جهازك.'
                    : 'The app uses internet connection to fetch prayer times, the Holy Quran, and Hadith from trusted sources (AlAdhan API, AlQuran API, Dorar Hadith API). Only local settings are stored on your device.',
              ),
              _buildSection(
                isArabic ? '3. التخزين المحلي' : '3. Local Storage',
                isArabic
                    ? 'يتم تخزين الإعدادات التالية محلياً على جهازك فقط:\n- الموقع المفضل (المدينة، البلد)\n- اللغة المفضلة\n- المؤذن المفضل\n- إعدادات الصوت والإشعارات\n- عدد التسبيح\n\nلا يتم مشاركة هذه البيانات مع أي طرف ثالث.'
                    : 'The following settings are stored locally on your device only:\n- Preferred location (city, country)\n- Preferred language\n- Preferred Muezzin\n- Sound and notification settings\n- Tasbih count\n\nThis data is not shared with any third party.',
              ),
              _buildSection(
                isArabic ? '4. مشاركة البيانات' : '4. Data Sharing',
                isArabic
                    ? 'لا نشارك أي بيانات مع أطراف ثالثة. لا يتم بيع أو تبادل أو تأجير معلومات المستخدمين.'
                    : 'We do not share any data with third parties. User information is not sold, exchanged, or rented.',
              ),
              _buildSection(
                isArabic ? '5. الأمان' : '5. Security',
                isArabic
                    ? 'نحن نلتزم بحماية خصوصيتك. يتم استخدام إجراءات أمنية معيارية لحماية بياناتك المخزنة محلياً على جهازك.'
                    : 'We are committed to protecting your privacy. Standard security measures are used to protect your data stored locally on your device.',
              ),
              _buildSection(
                isArabic ? '6. التغييرات على سياسة الخصوصية' : '6. Changes to Privacy Policy',
                isArabic
                    ? 'قد يتم تحديث سياسة الخصوصية من وقت لآخر. سيتم إعلامك بأي تغييرات من خلال تحديث التطبيق.'
                    : 'The privacy policy may be updated from time to time. You will be notified of any changes through app updates.',
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2541).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      isArabic
                          ? '📧 للاستفسارات: support@noor-al-haramain.com'
                          : '📧 For inquiries: support@noor-al-haramain.com',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isArabic
                          ? '© 2024 نور الحرمين. جميع الحقوق محفوظة.'
                          : '© 2024 Noor Al-Haramain. All rights reserved.',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFD4AF37),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const Divider(color: Colors.grey, height: 16),
        ],
      ),
    );
  }
}
