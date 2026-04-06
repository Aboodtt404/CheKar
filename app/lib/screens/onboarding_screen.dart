import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/chekar_logo.dart';
import '../widgets/noise_background.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _isFocused = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final valid = await api.validateApiKey(code);

      if (!mounted) return;

      if (valid) {
        final storage = ref.read(storageServiceProvider);
        await storage.saveApiKey(code);
        api.setApiKey(code);
        if (mounted) context.go('/home');
      } else {
        setState(() {
          _error = 'كود غلط، جرب تاني';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'مش قادر يتصل بالسيرفر';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: CheKarColors.darkDeep,
        body: NoiseBackground(
          child: Stack(
            children: [
              // Car photo background
              Positioned.fill(
                child: Image.asset(
                  'assets/images/mechanic_bg.jpg',
                  fit: BoxFit.cover,
                ),
              ),
              // Multi-layer dark overlay for depth
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        CheKarColors.darkDeep.withOpacity(0.75),
                        CheKarColors.darkDeep.withOpacity(0.92),
                        CheKarColors.darkDeep,
                      ],
                      stops: const [0.0, 0.5, 0.85],
                    ),
                  ),
                ),
              ),

              // Radial orange glow — top right
              Positioned(
                top: -100,
                right: -60,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, __) => Container(
                    width: 380,
                    height: 380,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          CheKarColors.orange.withOpacity(0.12 + 0.04 * _pulseController.value),
                          CheKarColors.orange.withOpacity(0.04),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              // Secondary glow — bottom left
              Positioned(
                bottom: -80,
                left: -60,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        CheKarColors.orange.withOpacity(0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Large background Arabic tagline
              Positioned(
                top: MediaQuery.of(context).size.height * 0.08,
                left: -20,
                right: -20,
                child: Text(
                  'افحص عربيتك\nبالذكاء الاصطناعي',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: Colors.white.withOpacity(0.025),
                    height: 1.2,
                  ),
                ),
              ),

              // Main content
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        const CheKarLogo(fontSize: 42),

                        const SizedBox(height: 12),

                        // Tagline
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: CheKarColors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: CheKarColors.orange.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            'فحص عربيات بالذكاء الاصطناعي',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: CheKarColors.orangeLight,
                            ),
                          ),
                        ),

                        const SizedBox(height: 36),

                        // Explainer text
                        Text(
                          'صور العربية...\nهنفحصها بالذكاء الاصطناعي...\nهتعرف حالتها في دقيقة',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.45),
                            height: 1.9,
                          ),
                        ),

                        const SizedBox(height: 48),

                        // Invite code field with glow on focus
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _isFocused
                                ? [
                                    BoxShadow(
                                      color: CheKarColors.orange.withOpacity(0.15),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Focus(
                            onFocusChange: (focused) => setState(() => _isFocused = focused),
                            child: TextField(
                              controller: _controller,
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.right,
                              keyboardType: TextInputType.visiblePassword,
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: CheKarColors.darkSurface,
                                hintText: 'ادخل كود الدعوة',
                                hintStyle: GoogleFonts.cairo(
                                  color: Colors.white.withOpacity(0.25),
                                  fontSize: 15,
                                ),
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.only(right: 12, left: 4),
                                  child: Icon(
                                    Iconsax.key_square,
                                    color: _isFocused
                                        ? CheKarColors.orange
                                        : Colors.white.withOpacity(0.2),
                                    size: 20,
                                  ),
                                ),
                                prefixIconConstraints: const BoxConstraints(minWidth: 48),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: CheKarColors.borderSubtle),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: CheKarColors.borderSubtle),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: CheKarColors.orange, width: 1.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
                              ),
                              onSubmitted: (_) => _submit(),
                            ),
                          ),
                        ),

                        // Error message
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: CheKarColors.scoreBad.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: CheKarColors.scoreBad.withOpacity(0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Iconsax.danger, size: 16, color: CheKarColors.scoreBad),
                                  const SizedBox(width: 8),
                                  Text(
                                    _error!,
                                    style: GoogleFonts.cairo(
                                      color: CheKarColors.scoreBad,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 20),

                        // Start button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CheKarColors.orange,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: CheKarColors.orange.withOpacity(0.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    'ابدأ',
                                    style: GoogleFonts.cairo(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
