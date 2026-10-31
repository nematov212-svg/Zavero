import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../services/api_client.dart';

class AdsManagementScreen extends StatefulWidget {
  const AdsManagementScreen({super.key});

  @override
  State<AdsManagementScreen> createState() => _AdsManagementScreenState();
}

class _AdsManagementScreenState extends State<AdsManagementScreen> {
  int _activeSlideIndex = 0;
  bool _loading = false;

  final List<Map<String, String>> _templates = [
    {
      'tag': 'ZAVERO MAXSUS TAKLIFI',
      'title': 'Issiq va Mazali Shaurma!',
      'description': "Har kuni yangi tayyorlangan, to'yimli va lazzatli taomlar.",
      'imageUrl': 'https://images.unsplash.com/photo-1626700051175-6818013e1d4f?w=1200&auto=format&fit=crop&q=80',
    },
    {
      'tag': 'MAXSUS AKSIYA',
      'title': '2 ta Burger oling — Kola bepul!',
      'description': 'Katta kompaniyalar va do‘stlar uchun ajoyib qulay taklif.',
      'imageUrl': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=1200&auto=format&fit=crop&q=80',
    },
    {
      'tag': 'TONGGI QAHVA',
      'title': 'Ertalabki Espresso & Kapuchino',
      'description': 'Kunni xushbo‘y, tetiklashtiruvchi qahva bilan boshlang.',
      'imageUrl': 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=1200&auto=format&fit=crop&q=80',
    },
    {
      'tag': 'MUZDEK ICHIMLIKLAR',
      'title': 'Yozgi Yangi Kokteyllar & Fresh',
      'description': 'Tabiiy mevalardan tayyorlangan chanqoqbosti ichimliklar.',
      'imageUrl': 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=1200&auto=format&fit=crop&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    setState(() => _loading = true);
    final appState = Provider.of<AppState>(context, listen: false);
    try {
      final banners = await appState.cloudService.getPromoBanners();
      if (mounted && banners.isNotEmpty) {
        setState(() {
          appState.promoBanners = banners;
          if (_activeSlideIndex >= banners.length) {
            _activeSlideIndex = 0;
          }
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _showAddEditBannerDialog({Map<String, dynamic>? initialBanner, int? index}) {
    final appState = Provider.of<AppState>(context, listen: false);
    final tagCtrl = TextEditingController(text: initialBanner?['tag']?.toString() ?? 'ZAVERO MAXSUS TAKLIFI');
    final titleCtrl = TextEditingController(text: initialBanner?['title']?.toString() ?? '');
    final descCtrl = TextEditingController(text: initialBanner?['description']?.toString() ?? '');
    final imgCtrl = TextEditingController(text: initialBanner?['imageUrl']?.toString() ?? '');
    bool isUploading = false;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final previewBg = ApiClient().resolveImageUrl(imgCtrl.text.trim());

          return Dialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: 580,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE25C1D).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.campaign_rounded, color: Color(0xFFE25C1D), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                initialBanner == null ? "Yangi reklama qo'shish" : 'Reklamani tahrirlash',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'QR Menyu yuqorisidagi maxsus taklif bannerini sozlash',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // LIVE MINI-PREVIEW
                    Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFF1E293B),
                        image: previewBg.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(previewBg),
                                fit: BoxFit.cover,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withValues(alpha: 0.8),
                              Colors.black.withValues(alpha: 0.35),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD97706).withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_fire_department_rounded, size: 12, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    tagCtrl.text.isEmpty ? 'ZAVERO MAXSUS TAKLIFI' : tagCtrl.text,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              titleCtrl.text.isEmpty ? 'Aksiya sarlavhasi...' : titleCtrl.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              descCtrl.text.isEmpty ? 'Taklif tavsifi va batafsil ma‘lumot...' : descCtrl.text,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Nishon / Tag
                    Text(
                      'Nishon (Badge / Tag)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: tagCtrl,
                      decoration: InputDecoration(
                        hintText: 'Masalan: ZAVERO MAXSUS TAKLIFI',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        isDense: true,
                      ),
                      onChanged: (_) => setDlgState(() {}),
                    ),

                    const SizedBox(height: 14),

                    // Sarlavha / Title
                    Text(
                      'Sarlavha (Katta harflar bilan)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        hintText: 'Masalan: Issiq va Mazali Shaurma!',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        isDense: true,
                      ),
                      onChanged: (_) => setDlgState(() {}),
                    ),

                    const SizedBox(height: 14),

                    // Tavsif / Description
                    Text(
                      'Tavsif (Qisqacha izoh)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: "Masalan: Har kuni yangi tayyorlangan, to'yimli va lazzatli taomlar.",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        isDense: true,
                      ),
                      onChanged: (_) => setDlgState(() {}),
                    ),

                    const SizedBox(height: 14),

                    // Rasm URL yoki Rasm Yuklash
                    Text(
                      'Banner rasmi (URL yoki fayl yuklash)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: imgCtrl,
                            decoration: InputDecoration(
                              hintText: 'https://... yoki fayl tanlang',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              isDense: true,
                            ),
                            onChanged: (_) => setDlgState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: isUploading
                              ? null
                              : () async {
                                  setDlgState(() => isUploading = true);
                                  try {
                                    final uploaded = await pickAndUploadImageFromGallery();
                                    if (uploaded != null && uploaded.isNotEmpty) {
                                      imgCtrl.text = uploaded;
                                      setDlgState(() {});
                                    }
                                  } catch (e) {
                                    if (dialogCtx.mounted) {
                                      ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                        SnackBar(content: Text('Rasm yuklashda xatolik: $e')),
                                      );
                                    }
                                  } finally {
                                    setDlgState(() => isUploading = false);
                                  }
                                },
                          icon: isUploading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.upload_file_rounded, size: 18),
                          label: const Text('Rasm tanlash'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Tayyor andozalar (Templates)
                    Text(
                      'Tayyor andozalardan tanlash:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _templates.map((tpl) {
                        return ActionChip(
                          avatar: const Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFFE25C1D)),
                          label: Text(tpl['title']!),
                          labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                          onPressed: () {
                            tagCtrl.text = tpl['tag']!;
                            titleCtrl.text = tpl['title']!;
                            descCtrl.text = tpl['description']!;
                            imgCtrl.text = tpl['imageUrl']!;
                            setDlgState(() {});
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                          child: const Text('Bekor qilish'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final title = titleCtrl.text.trim();
                                  final desc = descCtrl.text.trim();
                                  final tag = tagCtrl.text.trim();
                                  final img = imgCtrl.text.trim();

                                  if (title.isEmpty && img.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Sarlavha yoki rasm URL kiritilishi shart')),
                                    );
                                    return;
                                  }

                                  setDlgState(() => isSaving = true);
                                  final currentList = List<Map<String, dynamic>>.from(appState.promoBanners);

                                  if (initialBanner != null && index != null) {
                                    // Edit
                                    currentList[index] = {
                                      ...initialBanner,
                                      'tag': tag.isNotEmpty ? tag : 'ZAVERO MAXSUS TAKLIFI',
                                      'title': title,
                                      'description': desc,
                                      'imageUrl': img,
                                    };
                                  } else {
                                    // Add
                                    currentList.insert(0, {
                                      'id': 'bnr_${DateTime.now().millisecondsSinceEpoch}',
                                      'tag': tag.isNotEmpty ? tag : 'ZAVERO MAXSUS TAKLIFI',
                                      'title': title,
                                      'description': desc,
                                      'imageUrl': img,
                                      'createdAt': DateTime.now().toIso8601String(),
                                    });
                                  }

                                  await appState.savePromoBanners(currentList);
                                  if (dialogCtx.mounted) {
                                    Navigator.pop(dialogCtx);
                                  }
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Reklama muvaffaqiyatli saqlandi! QR Menyu darhol yangilandi.'),
                                        backgroundColor: Color(0xFF10B981),
                                      ),
                                    );
                                    setState(() {});
                                  }
                                },
                          icon: isSaving
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_rounded, size: 18),
                          label: Text(initialBanner == null ? "Qo'shish" : 'Saqlash'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE25C1D),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteBanner(int index) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reklamani o'chirish"),
        content: const Text("Haqiqatan ham ushbu reklama bannerini o'chirmoqchimisiz? QR menyuda ko'rinmaydi."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor qilish')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("O'chirish"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final currentList = List<Map<String, dynamic>>.from(appState.promoBanners);
      if (index >= 0 && index < currentList.length) {
        currentList.removeAt(index);
        await appState.savePromoBanners(currentList);
        if (mounted) {
          setState(() {
            if (_activeSlideIndex >= currentList.length) {
              _activeSlideIndex = (currentList.length - 1).clamp(0, 999);
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Reklama o'chirildi va QR Menyu real-time yangilandi!"),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
    }
  }

  Future<void> _loadDefaultTemplates() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final List<Map<String, dynamic>> defaultList = _templates.map((tpl) {
      return {
        'id': 'bnr_${DateTime.now().millisecondsSinceEpoch}_${tpl['title'].hashCode}',
        'tag': tpl['tag'],
        'title': tpl['title'],
        'description': tpl['description'],
        'imageUrl': tpl['imageUrl'],
        'createdAt': DateTime.now().toIso8601String(),
      };
    }).toList();

    await appState.savePromoBanners(defaultList);
    if (mounted) {
      setState(() => _activeSlideIndex = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Standart reklamalar yuklandi va QR Menyu yangilandi!"),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  void _openQrMenu() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final cafeId = appState.currentCafeId;
    final uri = Uri.parse('https://zavero-backend-production-7dc9.up.railway.app/menu?cafeId=$cafeId');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final banners = appState.promoBanners;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeBanner = (banners.isNotEmpty && _activeSlideIndex < banners.length)
        ? banners[_activeSlideIndex]
        : (banners.isNotEmpty ? banners.first : null);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Reklama qo'yish",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              "QR Menyu bannerlari va aksiyalar boshqaruvi",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: "QR Menyuni brauzerda ochish",
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: _openQrMenu,
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text("Reklama qo'shish"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE25C1D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: () => _showAddEditBannerDialog(),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // JONLI KO'RINISh KARTASI (3-rasmdagi QR Menyu Banneri)
                      _buildLivePreviewCard(activeBanner, banners, isDark),

                      const SizedBox(height: 28),

                      // Sarlavha va boshqaruv paneli
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Faol reklamalar (${banners.length})',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Ushbu bannerlar mijozlarning QR menyusida avtomatik almashib turadi',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          if (banners.isEmpty)
                            OutlinedButton.icon(
                              onPressed: _loadDefaultTemplates,
                              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                              label: const Text('Standart reklamalarni yuklash'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFE25C1D),
                                side: const BorderSide(color: Color(0xFFE25C1D)),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // REKLAMALAR RO'YXATI
                      if (banners.isEmpty)
                        _buildEmptyState(isDark)
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: banners.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            return _buildBannerItemCard(banners[i], i, isDark);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  /// 3-RASMDAGI QR MENYU BANNERINI 100% TAKRORLOVCHI JONLI KO'RINISh
  Widget _buildLivePreviewCard(Map<String, dynamic>? banner, List<Map<String, dynamic>> banners, bool isDark) {
    final previewBg = banner != null
        ? ApiClient().resolveImageUrl(banner['imageUrl']?.toString() ?? '')
        : 'https://images.unsplash.com/photo-1626700051175-6818013e1d4f?w=1200&auto=format&fit=crop&q=80';

    final tag = banner?['tag']?.toString() ?? 'ZAVERO MAXSUS TAKLIFI';
    final title = banner?['title']?.toString() ?? 'Zavero Fast';
    final desc = banner?['description']?.toString() ?? 'Zavero';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_android_rounded, color: Color(0xFFE25C1D), size: 20),
              const SizedBox(width: 8),
              Text(
                'Mijozning QR Menyu telefondagi jonli ko‘rinishi (3-rasm)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(radius: 3.5, backgroundColor: Color(0xFF10B981)),
                    SizedBox(width: 6),
                    Text(
                      'Real-time sinxronizatsiya faol',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 3-rasmdagi Banner Card
          Container(
            width: double.infinity,
            height: 170,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: const Color(0xFF1E293B),
              image: previewBg.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(previewBg),
                      fit: BoxFit.cover,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Dark gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.black.withValues(alpha: 0.85),
                          Colors.black.withValues(alpha: 0.5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Content Left
                Positioned(
                  left: 20,
                  top: 20,
                  bottom: 20,
                  right: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Tag badge (yellow/amber pill)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.5), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department_rounded, size: 13, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              tag.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Slide Dots (Bottom right - Image 3)
                if (banners.isNotEmpty)
                  Positioned(
                    bottom: 16,
                    right: 20,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(banners.length, (idx) {
                        final isActive = idx == _activeSlideIndex;
                        return InkWell(
                          onTap: () => setState(() => _activeSlideIndex = idx),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.only(left: 6),
                            width: isActive ? 22 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFFF59E0B) : Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                // Arrows
                if (banners.length > 1) ...[
                  Positioned(
                    left: 6,
                    top: 65,
                    child: IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28),
                      onPressed: () {
                        setState(() {
                          _activeSlideIndex = (_activeSlideIndex - 1 + banners.length) % banners.length;
                        });
                      },
                    ),
                  ),
                  Positioned(
                    right: 6,
                    top: 65,
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 28),
                      onPressed: () {
                        setState(() {
                          _activeSlideIndex = (_activeSlideIndex + 1) % banners.length;
                        });
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Reklama Kartochkasi
  Widget _buildBannerItemCard(Map<String, dynamic> item, int index, bool isDark) {
    final imgUrl = ApiClient().resolveImageUrl(item['imageUrl']?.toString() ?? '');
    final tag = item['tag']?.toString() ?? 'ZAVERO MAXSUS TAKLIFI';
    final title = item['title']?.toString() ?? 'Sarlavhasiz';
    final desc = item['description']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _activeSlideIndex == index
              ? const Color(0xFFE25C1D)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: _activeSlideIndex == index ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Index
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#${index + 1}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),

          const SizedBox(width: 14),

          // Image preview thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 80,
              height: 52,
              color: const Color(0xFF334155),
              child: imgUrl.isNotEmpty
                  ? Image.network(
                      imgUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 20),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.campaign_rounded, color: Colors.white54, size: 24),
                    ),
            ),
          ),

          const SizedBox(width: 16),

          // Text details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: Color(0xFFD97706),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (_activeSlideIndex == index) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE25C1D).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "Hozir ko'rilmoqda",
                          style: TextStyle(
                            color: Color(0xFFE25C1D),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Actions
          IconButton(
            tooltip: "Jonli ko'rish",
            icon: const Icon(Icons.visibility_rounded, color: Color(0xFF3B82F6), size: 20),
            onPressed: () => setState(() => _activeSlideIndex = index),
          ),
          IconButton(
            tooltip: 'Tahrirlash',
            icon: const Icon(Icons.edit_rounded, color: Color(0xFF64748B), size: 20),
            onPressed: () => _showAddEditBannerDialog(initialBanner: item, index: index),
          ),
          IconButton(
            tooltip: "O'chirish",
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
            onPressed: () => _deleteBanner(index),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE25C1D).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.campaign_outlined, size: 40, color: Color(0xFFE25C1D)),
          ),
          const SizedBox(height: 16),
          Text(
            "Hozircha reklamalar qo'shilmagan",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Mijozlar QR menyuni ochganda maxsus chegirmalar va tavsiya taomlarni ko'rishlari uchun reklama qo'shing.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showAddEditBannerDialog(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("Yangi reklama qo'shish"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE25C1D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _loadDefaultTemplates,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text('Standart reklamalarni yuklash'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF3B82F6),
                  side: const BorderSide(color: Color(0xFF3B82F6)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
