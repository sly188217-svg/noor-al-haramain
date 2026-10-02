import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../core/services/premium_service.dart';

/// ═══════════════════════════════════════════════════════════
/// 💎 شاشة Premium — 3 ميزات فقط
/// ✅ المساعد الذكي (3 مجاناً)
/// ✅ التصحيح الذكي (تصحيحان مجاناً)
/// ✅ اقرأ معي (3 مرات مجاناً)
/// ═══════════════════════════════════════════════════════════
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  Offerings? _offerings;
  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _hasError = false;

  static const Color _primary = Color(0xFFE53935);
  static const Color _primaryDark = Color(0xFFB71C1C);
  static const Color _bg = Color(0xFF0A1929);
  static const Color _surface = Color(0xFF132F4C);

  // ═══════════════════════════════════════════════════════════
  // 🎯 الميزات المدفوعة
  // ═══════════════════════════════════════════════════════════
  static const List<Map<String, String>> _premiumFeatures = [
    {
      'icon': '🤖',
      'title': 'المساعد الذكي "المرشد"',
      'desc': '3 أسئلة مجاناً → بلا حدود',
    },
    {
      'icon': '🎙️',
      'title': 'التصحيح الذكي',
      'desc': 'تصحيحان مجاناً → بلا حدود',
    },
    {
      'icon': '📖',
      'title': 'اقرأ معي',
      'desc': '3 مرات مجاناً → بلا حدود',
    },
  ];

  static const List<Map<String, String>> _freeFeatures = [
    {'icon': '🕌', 'title': 'مواقيت الصلاة'},
    {'icon': '🔔', 'title': 'الأذان والإقامة'},
    {'icon': '📿', 'title': 'الأذكار والأدعية'},
    {'icon': '📖', 'title': 'المصحف الشريف'},
    {'icon': '📚', 'title': 'المكتبة'},
    {'icon': '🧭', 'title': 'القبلة'},
    {'icon': '📺', 'title': 'البث المباشر'},
    {'icon': '📿', 'title': 'السبحة'},
  ];

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final offerings = await PremiumService.getOfferings();

    if (mounted) {
      setState(() {
        _offerings = offerings;
        _isLoading = false;
        _hasError = offerings == null || offerings.current == null;
      });
    }
  }

  Future<void> _purchase(Package package) async {
    setState(() => _isPurchasing = true);

    final result = await PremiumService.purchase(package);

    if (mounted) {
      setState(() => _isPurchasing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );

      if (result.success) {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context, true);
      }
    }
  }

  Future<void> _restore() async {
    setState(() => _isPurchasing = true);

    final result = await PremiumService.restorePurchases();

    if (mounted) {
      setState(() => _isPurchasing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.orange,
        ),
      );

      if (result.success) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: const Text(
          '💎 الاشتراك المميز',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'استعادة',
            onPressed: _isPurchasing ? null : _restore,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _hasError
              ? _buildErrorState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildPremiumFeatures(),
                      const SizedBox(height: 20),
                      if (_offerings?.current != null) ...[
                        if (_offerings!.current!.monthly != null)
                          _buildPackageCard(
                            package: _offerings!.current!.monthly!,
                            title: 'اشتراك شهري',
                            subtitle: 'ألغِ في أي وقت',
                          ),
                        const SizedBox(height: 12),
                        if (_offerings!.current!.annual != null)
                          _buildPackageCard(
                            package: _offerings!.current!.annual!,
                            title: 'اشتراك سنوي',
                            subtitle: 'وفّر 36%',
                            isBestValue: true,
                          ),
                      ],
                      const SizedBox(height: 24),
                      _buildFreeFeatures(),
                      const SizedBox(height: 20),
                      TextButton.icon(
                        onPressed: _isPurchasing ? null : _restore,
                        icon: const Icon(Icons.restore, color: _primary),
                        label: const Text(
                          'استعادة الاشتراك',
                          style: TextStyle(color: _primary),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'يمكنك إلغاء الاشتراك في أي وقت من إعدادات متجر التطبيقات',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary, _primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 3,
          ),
        ],
      ),
      child: const Column(
        children: [
          Icon(Icons.workspace_premium, color: Colors.white, size: 64),
          SizedBox(height: 12),
          Text(
            'نور الحرمين Premium',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'افتح 3 ميزات ذكية متقدمة',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeatures() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_surface, _surface.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primary.withValues(alpha: 0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.star, color: _primary, size: 24),
              SizedBox(width: 8),
              Text(
                '💎 ميزات Premium',
                style: TextStyle(
                  color: _primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._premiumFeatures.map((f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Text(f['icon']!,
                          style: const TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f['title']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            f['desc']!,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 22),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildPackageCard({
    required Package package,
    required String title,
    required String subtitle,
    bool isBestValue = false,
  }) {
    final price = package.storeProduct.priceString;

    return GestureDetector(
      onTap: _isPurchasing ? null : () => _purchase(package),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: isBestValue
              ? LinearGradient(
                  colors: [_primary, _primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isBestValue ? null : _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _primary,
            width: isBestValue ? 3 : 2,
          ),
          boxShadow: isBestValue
              ? [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isBestValue) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'الأفضل',
                            style: TextStyle(
                              color: Color(0xFFE53935),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isBestValue ? Colors.white70 : Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isPurchasing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFreeFeatures() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.card_giftcard, color: Colors.green, size: 22),
              SizedBox(width: 8),
              Text(
                '🎁 مجاني دائماً',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _freeFeatures.map((f) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _bg.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(f['icon']!, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      f['title']!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.orange, size: 64),
            const SizedBox(height: 16),
            const Text(
              '⚠️ تعذر تحميل خيارات الاشتراك',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'تأكد من اتصالك بالإنترنت',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadOfferings,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
