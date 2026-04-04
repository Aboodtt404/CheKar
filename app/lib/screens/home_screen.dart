import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/chekar_logo.dart';
import 'new_inspection_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.read(storageServiceProvider);
    final rawHistory = storage.inspectionHistory;
    final history = rawHistory
        .map((s) {
          try {
            return jsonDecode(s) as Map<String, dynamic>;
          } catch (_) {
            return null;
          }
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: CheKarColors.background,
        body: Column(
          children: [
            _Header(onNewInspection: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const NewInspectionSheet(),
              );
            }),
            Expanded(child: _HistorySection(history: history)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onNewInspection;
  const _Header({required this.onNewInspection});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: CheKarColors.dark,
      ),
      child: Stack(
        children: [
          // Orange glow at the bottom of the header
          Positioned(
            bottom: -20,
            left: 0,
            right: 0,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: CheKarColors.orange.withOpacity(0.18),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top bar: logo + avatar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const CheKarLogo(fontSize: 20),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: CheKarColors.darkCard,
                          border: Border.all(color: CheKarColors.orange, width: 2),
                        ),
                        child: const Icon(Icons.person_rounded, color: Colors.white54, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Hero button
                  _NewInspectionButton(onTap: onNewInspection),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewInspectionButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NewInspectionButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFB923C), CheKarColors.orange, Color(0xFFEA580C)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: CheKarColors.orange.withOpacity(0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        child: Row(
          children: [
            // Text side (RTL: starts on the right)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'فحص جديد',
                    style: GoogleFonts.cairo(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'صور العربية واعرف حالتها بالذكاء الاصطناعي',
                    style: GoogleFonts.cairo(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.85),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Camera icon on the left (RTL layout)
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('📷', style: TextStyle(fontSize: 26)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  const _HistorySection({required this.history});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الفحوصات السابقة',
                style: GoogleFonts.cairo(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: CheKarColors.textPrimary,
                ),
              ),
              if (history.isNotEmpty)
                GestureDetector(
                  onTap: () {}, // future: full history screen
                  child: Text(
                    'عرض الكل',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: CheKarColors.orange,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: history.isEmpty
              ? _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _HistoryCard(item: history[i]),
                ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔍', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            'لسه مفيش فحوصات',
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: CheKarColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ابدأ فحصك الأول بالضغط على فحص جديد',
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: CheKarColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _HistoryCard({required this.item});

  String _formatDate(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = item['id'] as String? ?? '';
    final carModel = item['car_model'] as String? ?? 'عربية';
    final year = item['year']?.toString() ?? '';
    final grade = item['grade'] as String?;
    final score = (item['trust_score'] as num?)?.toInt();
    final status = item['status'] as String? ?? 'completed';
    final createdAt = _formatDate(item['created_at'] as String?);

    const gradeColors = {
      'A': Color(0xFF16A34A),
      'B': Color(0xFFEAB308),
      'C': Color(0xFFF97316),
      'D': Color(0xFFDC2626),
      'F': Color(0xFF7F1D1D),
    };
    final scoreColor = grade != null
        ? (gradeColors[grade] ?? CheKarColors.textMuted)
        : (score != null ? CheKarColors.scoreColor(score) : CheKarColors.textMuted);

    String modeLabel = '';
    if (status == 'completed') {
      modeLabel = 'مكتمل';
    } else if (status == 'processing') {
      modeLabel = 'جاري الفحص';
    } else if (status == 'failed') {
      modeLabel = 'فشل الفحص';
    } else {
      modeLabel = status;
    }

    return GestureDetector(
      onTap: () => context.push('/report/$id'),
      onLongPress: () {
        showDialog(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text('حذف الفحص؟', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
              content: Text('هيتحذف من السجل', style: GoogleFonts.cairo()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('لا', style: GoogleFonts.cairo()),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    // Remove this item from history
                    final prefs = await SharedPreferences.getInstance();
                    final list = prefs.getStringList('inspection_history') ?? [];
                    list.removeWhere((s) {
                      try {
                        final m = jsonDecode(s) as Map<String, dynamic>;
                        return m['id'] == id;
                      } catch (_) { return false; }
                    });
                    await prefs.setStringList('inspection_history', list);
                    if (ctx.mounted) {
                      // Force rebuild by navigating to home again
                      (ctx as Element).findAncestorStateOfType<NavigatorState>()?.context.go('/home');
                    }
                  },
                  child: Text('احذف', style: GoogleFonts.cairo(color: CheKarColors.scoreBad, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF5F5F4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Grade / score badge — angular (borderRadius 6)
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: scoreColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: scoreColor.withOpacity(0.35), width: 1.5),
              ),
              child: Center(
                child: grade != null
                    ? Text(
                        grade,
                        style: GoogleFonts.saira(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: scoreColor,
                        ),
                      )
                    : score != null
                        ? Text(
                            '$score',
                            style: GoogleFonts.saira(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: scoreColor,
                            ),
                          )
                        : Icon(Icons.hourglass_top_rounded, color: scoreColor, size: 20),
              ),
            ),
            const SizedBox(width: 14),
            // Car info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    year.isNotEmpty ? '$carModel · $year' : carModel,
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: CheKarColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$createdAt · $modeLabel',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: CheKarColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            // Left-arrow chevron
            const Icon(Icons.chevron_left_rounded, color: CheKarColors.textMuted, size: 22),
          ],
        ),
      ),
    );
  }
}
