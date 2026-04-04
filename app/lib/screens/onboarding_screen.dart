import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/chekar_logo.dart';
import '../widgets/noise_background.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
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
    } catch (_) {
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
        backgroundColor: CheKarColors.dark,
        body: NoiseBackground(
          child: Stack(
            children: [
              // Car photo background with dark overlay
              Positioned.fill(
                child: Image.asset(
                  'assets/images/mechanic_bg.jpg',
                  fit: BoxFit.cover,
                ),
              ),
              // Dark overlay (88% opacity)
              Positioned.fill(
                child: Container(
                  color: CheKarColors.dark.withOpacity(0.88),
                ),
              ),

              // Asymmetric orange radial glow — offset top-right
              Positioned(
                top: -120,
                right: -80,
                child: Container(
                  width: 420,
                  height: 420,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        CheKarColors.orange.withOpacity(0.18),
                        CheKarColors.orange.withOpacity(0.06),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),

              // Large background Arabic tagline — design element only
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
                    color: Colors.white.withOpacity(0.03),
                    height: 1.2,
                  ),
                ),
              ),

              // Main content
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      // Logo
                      const CheKarLogo(fontSize: 40),

                      const SizedBox(height: 32),

                      // Explainer text
                      Text(
                        'صور العربية...\nهنفحصها بالذكاء الاصطناعي...\nهتعرف حالتها في دقيقة',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFA8A29E),
                          height: 1.9,
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Invite code field
                      TextField(
                        controller: _controller,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        keyboardType: TextInputType.visiblePassword,
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF272738),
                          hintText: 'ادخل كود الدعوة',
                          hintStyle: GoogleFonts.cairo(
                            color: const Color(0xFF78716C),
                            fontSize: 15,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF3A3A4D)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF3A3A4D)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: CheKarColors.orange, width: 1.5),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFDC2626)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        ),
                        onSubmitted: (_) => _submit(),
                      ),

                      // Error message
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                              color: const Color(0xFFDC2626),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Start button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CheKarColors.orange,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: CheKarColors.orange.withOpacity(0.6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
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
