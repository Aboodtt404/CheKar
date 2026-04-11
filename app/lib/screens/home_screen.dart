import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
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

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onNewInspection;
  const _Header({required this.onNewInspection});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [CheKarColors.darkDeep, CheKarColors.dark],
        ),
      ),
      child: Stack(
        children: [
          // Decorative gradient orb — top right
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    CheKarColors.orange.withOpacity(0.12),
                    CheKarColors.orange.withOpacity(0.03),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Subtle grid pattern overlay
          Positioned.fill(
            child: CustomPaint(painter: _GridPatternPainter()),
          ),
          // Orange glow at the bottom edge
          Positioned(
            bottom: -1,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: CheKarColors.orange.withOpacity(0.25),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          // Content
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top bar: logo + avatar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const CheKarLogo(fontSize: 22),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: CheKarColors.darkElevated,
                          border: Border.all(
                            color: CheKarColors.borderSubtle,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(Iconsax.profile_circle, color: Colors.white38, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Hero CTA button
                  _NewInspectionButton(onTap: onNewInspection),
                  const SizedBox(height: 12),
                  // OBD scan button
                  _ObdScanButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── OBD Scan Button ─────────────────────────────────────────────────────────

class _ObdScanButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/obd-standalone'),
      child: Container(
        decoration: BoxDecoration(
          color: CheKarColors.darkElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CheKarColors.borderSubtle),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: CheKarColors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Iconsax.cpu, color: CheKarColors.orange, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'فحص OBD',
                    style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  Text(
                    'افحص كمبيوتر العربية بجهاز OBD',
                    style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white38),
                  ),
                ],
              ),
            ),
            Icon(Iconsax.arrow_left_2, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── New Inspection CTA ──────────────────────────────────────────────────────

class _NewInspectionButton extends StatefulWidget {
  final VoidCallback onTap;
  const _NewInspectionButton({required this.onTap});

  @override
  State<_NewInspectionButton> createState() => _NewInspectionButtonState();
}

class _NewInspectionButtonState extends State<_NewInspectionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFB923C), CheKarColors.orange, Color(0xFFEA580C)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: CheKarColors.orange.withOpacity(0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: CheKarColors.orange.withOpacity(0.15),
                  blurRadius: 48,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Shimmer sweep
                Positioned.fill(child: _buildShimmer()),
                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Row(
                    children: [
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
                            const SizedBox(height: 6),
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
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: const Icon(Iconsax.camera, color: Colors.white, size: 26),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmer() {
    final value = _shimmerController.value;
    return ShaderMask(
      shaderCallback: (rect) {
        return LinearGradient(
          begin: Alignment(-1.0 + 3.0 * value, -0.3),
          end: Alignment(-0.5 + 3.0 * value, 0.3),
          colors: [
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.0),
          ],
        ).createShader(rect);
      },
      blendMode: BlendMode.srcOver,
      child: Container(color: Colors.transparent),
    );
  }
}

// ── History Section ─────────────────────────────────────────────────────────

class _HistorySection extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  const _HistorySection({required this.history});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
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
                Text(
                  '${history.length}',
                  style: GoogleFonts.saira(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CheKarColors.textMuted,
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

// ── Empty State ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: CheKarColors.orange.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Iconsax.car,
              size: 36,
              color: CheKarColors.orange.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'لسه مفيش فحوصات',
            style: GoogleFonts.cairo(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: CheKarColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
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

// ── History Card ─────────────────────────────────────────────────────────────

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

    final gradeColor = grade != null
        ? (CheKarColors.gradeColors[grade] ?? CheKarColors.textMuted)
        : (score != null ? CheKarColors.scoreColor(score) : CheKarColors.textMuted);

    String statusLabel = '';
    IconData statusIcon = Iconsax.tick_circle;
    if (status == 'completed') {
      statusLabel = 'مكتمل';
      statusIcon = Iconsax.tick_circle;
    } else if (status == 'processing') {
      statusLabel = 'جاري الفحص';
      statusIcon = Iconsax.timer_1;
    } else if (status == 'failed') {
      statusLabel = 'فشل';
      statusIcon = Iconsax.close_circle;
    } else {
      statusLabel = status;
    }

    return GestureDetector(
      onTap: () => context.push('/report/$id'),
      onLongPress: () => _showDeleteDialog(context, id),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CheKarColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Colored accent strip
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: gradeColor,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Grade badge
              Container(
                width: 50,
                height: 50,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: gradeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: grade != null
                      ? Text(
                          grade,
                          style: GoogleFonts.saira(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: gradeColor,
                          ),
                        )
                      : score != null
                          ? Text(
                              '$score',
                              style: GoogleFonts.saira(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: gradeColor,
                              ),
                            )
                          : Icon(Iconsax.timer_1, color: gradeColor, size: 20),
                ),
              ),
              const SizedBox(width: 14),
              // Car info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        year.isNotEmpty ? '$carModel · $year' : carModel,
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: CheKarColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(statusIcon, size: 12, color: CheKarColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            '$statusLabel · $createdAt',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: CheKarColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Icon(Iconsax.arrow_left_2, color: CheKarColors.textMuted.withOpacity(0.5), size: 18),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: CheKarColors.darkCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('حذف الفحص؟', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: Colors.white)),
          content: Text('هيتحذف من السجل', style: GoogleFonts.cairo(color: Colors.white60)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('لا', style: GoogleFonts.cairo(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
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
                  (ctx as Element).findAncestorStateOfType<NavigatorState>()?.context.go('/home');
                }
              },
              child: Text('احذف', style: GoogleFonts.cairo(color: CheKarColors.scoreBad, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Decorative grid pattern ─────────────────────────────────────────────────

class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..strokeWidth = 0.5;

    const spacing = 40.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
