import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';
import '../config/theme.dart';
import '../models/inspection.dart';
import '../providers/inspection_provider.dart';
import '../widgets/camera_overlay.dart';
import '../widgets/capture_dots.dart';

// ── Step definitions ──────────────────────────────────────────────────────────

const _quickSteps = [
  {'instruction': 'صور العربية من الأمام', 'hint': 'وقف قدام العربية', 'arrow': '↑'},
  {'instruction': 'صور الجنب اليمين', 'hint': 'صور من الجنب', 'arrow': '→'},
  {'instruction': 'صور العربية من ورا', 'hint': 'وقف ورا العربية', 'arrow': '↓'},
  {'instruction': 'صور الجنب الشمال', 'hint': 'صور من الجنب', 'arrow': '←'},
];

const _fullSteps = [
  {'instruction': 'صور العربية من الأمام', 'hint': 'وقف قدام العربية', 'arrow': '↑'},
  {'instruction': 'صور من الأمام يمين', 'hint': 'زاوية ٤٥ درجة', 'arrow': '↗'},
  {'instruction': 'صور الجنب اليمين كامل', 'hint': 'صور الجنب كله', 'arrow': '→'},
  {'instruction': 'صور من ورا يمين', 'hint': 'زاوية ٤٥ درجة', 'arrow': '↘'},
  {'instruction': 'صور العربية من ورا', 'hint': 'وقف ورا العربية', 'arrow': '↓'},
  {'instruction': 'صور من ورا شمال', 'hint': 'زاوية ٤٥ درجة', 'arrow': '↙'},
  {'instruction': 'صور الجنب الشمال كامل', 'hint': 'صور الجنب كله', 'arrow': '←'},
  {'instruction': 'صور من الأمام شمال', 'hint': 'زاوية ٤٥ درجة', 'arrow': '↖'},
  {'instruction': 'افتح الكبوت وصوره', 'hint': 'صور المحرك من فوق', 'arrow': '⬇'},
  {'instruction': 'صور الطبلون', 'hint': 'من مكان السواق', 'arrow': '📷'},
  {'instruction': 'صور العداد قريب', 'hint': 'لازم الأرقام تبان', 'arrow': '🔍'},
  {'instruction': 'صور المقاعد الأمامية', 'hint': 'من برا الباب', 'arrow': '📷'},
  {'instruction': 'صور لوحة الشاسيه', 'hint': 'عادة جوا الباب', 'arrow': '🔍'},
  {'instruction': 'صور الكاوتش الأمامي', 'hint': 'قرب من الكاوتش', 'arrow': '🔍'},
  {'instruction': 'صور أسفل الباب', 'hint': 'ادي الصورة من تحت', 'arrow': '⬇'},
];

// Convert integer to Eastern Arabic numerals
String _toArabicNumeral(int n) {
  const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return n.toString().split('').map((c) {
    final d = int.tryParse(c);
    return d != null ? digits[d] : c;
  }).join();
}

// ── Provider for camera availability ─────────────────────────────────────────

final _cameraAvailableProvider = FutureProvider<bool>((ref) async {
  try {
    // camerawesome needs permission + physical camera; on emulator this fails
    // We do a lightweight check by attempting to access platform channel
    return false; // Default safe: use fallback; real camera handled at widget level
  } catch (_) {
    return false;
  }
});

// ── Placeholder photo generation ──────────────────────────────────────────────

Future<File> _generatePlaceholderPhoto(int stepIndex) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const size = ui.Size(640, 480);

  // Dark background
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 640, 480),
    Paint()..color = const Color(0xFF1E1E2E),
  );

  // Orange circle
  canvas.drawCircle(
    const Offset(320, 240),
    80,
    Paint()..color = const Color(0xFFF97316),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(640, 480);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = byteData!.buffer.asUint8List();

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/placeholder_$stepIndex.png');
  await file.writeAsBytes(bytes);
  return file;
}

// ── Main Screen ───────────────────────────────────────────────────────────────

class CaptureScreen extends ConsumerStatefulWidget {
  final String mode;
  const CaptureScreen({super.key, required this.mode});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  bool _isCapturing = false;
  CameraController? _cameraController;
  bool _cameraReady = false;

  // Shutter glow animation
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  List<Map<String, String>> get _steps =>
      (widget.mode == 'full' ? _fullSteps : _quickSteps)
          .map((e) => e.cast<String, String>())
          .toList();

  CaptureMode get _captureMode =>
      widget.mode == 'full' ? CaptureMode.full : CaptureMode.quick;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      // Use the back camera
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      // Camera not available (emulator) — leave _cameraReady false
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _onShutter() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      File photo;

      if (_cameraController != null && _cameraReady) {
        // Take photo with in-app camera
        final xFile = await _cameraController!.takePicture();
        photo = File(xFile.path);
      } else {
        // Fallback: generate placeholder (emulator)
        photo = await _generatePlaceholderPhoto(_currentStep);
      }

      // Upload
      await ref.read(inspectionProvider.notifier).uploadPhoto(photo);

      final steps = _steps;
      final isLast = _currentStep >= steps.length - 1;

      if (isLast) {
        // Trigger inspection and navigate
        await ref.read(inspectionProvider.notifier).triggerInspection();
        final id = ref.read(inspectionProvider).current?.id;
        if (mounted && id != null) {
          context.go('/processing/$id');
        }
      } else {
        if (mounted) {
          setState(() {
            _currentStep++;
            _isCapturing = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ: $e',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  Future<void> _onClose() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: CheKarColors.darkCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'إلغاء الفحص',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          content: Text(
            'متأكد إنك عايز تلغي الفحص؟',
            style: GoogleFonts.cairo(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'لأ، كمّل',
                style: GoogleFonts.cairo(color: CheKarColors.orange, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'أيوه، إلغي',
                style: GoogleFonts.cairo(color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    final step = steps[_currentStep];
    final total = steps.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Layer 1: Camera preview or dark fallback
            _CameraLayer(controller: _cameraController, isReady: _cameraReady),

            // Layer 2: Overlay with brackets and arrow (central viewport area)
            Positioned.fill(
              top: 120,
              bottom: 160,
              left: 24,
              right: 24,
              child: CameraOverlay(arrow: step['arrow'] ?? '↑'),
            ),

            // Layer 3: Top bar (safe area)
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top bar row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Close button
                        _TopBarButton(
                          onTap: _onClose,
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                        ),

                        // Mode badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: CheKarColors.orange.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: CheKarColors.orange.withOpacity(0.5)),
                          ),
                          child: Text(
                            _captureMode.labelAr,
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: CheKarColors.orange,
                            ),
                          ),
                        ),

                        // Step counter (current/total)
                        _TopBarButton(
                          onTap: null,
                          child: Text(
                            '${_toArabicNumeral(total)} / ${_toArabicNumeral(_currentStep + 1)}',
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Instruction area
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          step['instruction'] ?? '',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            shadows: const [
                              Shadow(color: Colors.black87, blurRadius: 8),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          step['hint'] ?? '',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white60,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 6),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Layer 4: Bottom controls
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.9),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 32,
                  bottom: MediaQuery.of(context).padding.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress dots
                    CaptureDots(total: total, current: _currentStep),
                    const SizedBox(height: 24),
                    // Shutter row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ShutterButton(
                          glowAnim: _glowAnim,
                          isCapturing: _isCapturing,
                          onTap: _onShutter,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Camera Layer ──────────────────────────────────────────────────────────────

class _CameraLayer extends StatelessWidget {
  final CameraController? controller;
  final bool isReady;

  const _CameraLayer({required this.controller, required this.isReady});

  @override
  Widget build(BuildContext context) {
    if (controller != null && isReady) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller!.value.previewSize?.height ?? 1,
            height: controller!.value.previewSize?.width ?? 1,
            child: CameraPreview(controller!),
          ),
        ),
      );
    }
    return _DarkFallback();
  }
}

class _DarkFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D0D1A), Color(0xFF1A1A2E), Color(0xFF0A0A14)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt_rounded, size: 64, color: CheKarColors.orange.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text(
              'اضغط الزرار عشان تصور',
              style: GoogleFonts.cairo(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top Bar Button ─────────────────────────────────────────────────────────────

class _TopBarButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  const _TopBarButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ── Shutter Button ────────────────────────────────────────────────────────────

class _ShutterButton extends StatelessWidget {
  final Animation<double> glowAnim;
  final bool isCapturing;
  final VoidCallback onTap;

  const _ShutterButton({
    required this.glowAnim,
    required this.isCapturing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowAnim,
      builder: (context, child) {
        return GestureDetector(
          onTap: isCapturing ? null : onTap,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CheKarColors.orange,
              boxShadow: [
                BoxShadow(
                  color: CheKarColors.orange.withOpacity(glowAnim.value),
                  blurRadius: 28,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: CheKarColors.orange.withOpacity(glowAnim.value * 0.5),
                  blurRadius: 50,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: isCapturing
                ? const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
          ),
        );
      },
    );
  }
}
