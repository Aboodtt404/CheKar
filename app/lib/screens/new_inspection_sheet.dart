import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../config/theme.dart';
import '../models/inspection.dart';
import '../providers/inspection_provider.dart';

class NewInspectionSheet extends ConsumerStatefulWidget {
  const NewInspectionSheet({super.key});

  @override
  ConsumerState<NewInspectionSheet> createState() => _NewInspectionSheetState();
}

class _NewInspectionSheetState extends ConsumerState<NewInspectionSheet> {
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _mileageController = TextEditingController();
  CaptureMode _selectedMode = CaptureMode.quick;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _modelController.dispose();
    _yearController.dispose();
    _mileageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final model = _modelController.text.trim();
    final yearText = _yearController.text.trim();
    final mileageText = _mileageController.text.trim();

    if (model.isEmpty || yearText.isEmpty || mileageText.isEmpty) {
      setState(() => _error = 'من فضلك اكمل كل البيانات');
      return;
    }

    final year = int.tryParse(yearText);
    final mileage = int.tryParse(mileageText);

    if (year == null || year < 1980 || year > 2030) {
      setState(() => _error = 'السنة مش صح');
      return;
    }
    if (mileage == null || mileage < 0) {
      setState(() => _error = 'الكيلومترات مش صح');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      await ref.read(inspectionProvider.notifier).createInspection(
        carModel: model,
        year: year,
        mileage: mileage,
      );

      if (mounted) {
        Navigator.of(context).pop();
        context.push('/capture/${_selectedMode.name}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [CheKarColors.darkCard, CheKarColors.darkDeep],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: CheKarColors.borderSubtle.withOpacity(0.5)),
          ),
        ),
        padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Title + icon
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: CheKarColors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Iconsax.car, color: CheKarColors.orange, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'فحص جديد',
                        style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      Text(
                        'بيانات العربية',
                        style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white38),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _SheetTextField(
                controller: _modelController,
                label: 'الموديل',
                hint: 'مثال: تويوتا كورولا',
                icon: Iconsax.car,
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _SheetTextField(
                      controller: _yearController,
                      label: 'السنة',
                      hint: '2020',
                      icon: Iconsax.calendar,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SheetTextField(
                      controller: _mileageController,
                      label: 'الكيلومترات',
                      hint: '85000',
                      icon: Iconsax.speedometer,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'نوع الفحص',
                style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white60),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ModeCard(
                      mode: CaptureMode.quick,
                      label: 'فحص سريع',
                      sublabel: '٨ صور خارجية',
                      icon: Iconsax.flash_1,
                      isSelected: _selectedMode == CaptureMode.quick,
                      onTap: () => setState(() => _selectedMode = CaptureMode.quick),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ModeCard(
                      mode: CaptureMode.full,
                      label: 'فحص شامل',
                      sublabel: '١٢ صورة شاملة',
                      icon: Iconsax.clipboard_tick,
                      isSelected: _selectedMode == CaptureMode.full,
                      onTap: () => setState(() => _selectedMode = CaptureMode.full),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: CheKarColors.scoreBad.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CheKarColors.scoreBad.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Iconsax.danger, size: 16, color: CheKarColors.scoreBad),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600, color: CheKarColors.scoreBad),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _isLoading ? null : _submit,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: _isLoading
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFFFB923C), CheKarColors.orange, Color(0xFFEA580C)],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                    color: _isLoading ? CheKarColors.darkElevated : null,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _isLoading
                        ? []
                        : [BoxShadow(color: CheKarColors.orange.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)))
                      : Text('يلا نبدأ', style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _SheetTextField({required this.controller, required this.label, required this.hint, required this.icon, required this.keyboardType, this.inputFormatters});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white54)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textDirection: TextDirection.rtl,
          style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.cairo(color: Colors.white24, fontSize: 14),
            filled: true,
            fillColor: CheKarColors.darkSurface,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(right: 10, left: 4),
              child: Icon(icon, color: Colors.white24, size: 18),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 42),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: CheKarColors.borderSubtle)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: CheKarColors.borderSubtle)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: CheKarColors.orange, width: 1.5)),
          ),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  final CaptureMode mode;
  final String label;
  final String sublabel;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeCard({required this.mode, required this.label, required this.sublabel, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? CheKarColors.orange.withOpacity(0.1) : CheKarColors.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? CheKarColors.orange : CheKarColors.borderSubtle, width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [BoxShadow(color: CheKarColors.orange.withOpacity(0.1), blurRadius: 12)] : [],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected ? CheKarColors.orange.withOpacity(0.15) : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 17, color: isSelected ? CheKarColors.orange : Colors.white38),
            ),
            const SizedBox(height: 10),
            Text(label, style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700, color: isSelected ? CheKarColors.orange : Colors.white)),
            const SizedBox(height: 2),
            Text(sublabel, style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w500, color: isSelected ? CheKarColors.orangeLight : Colors.white30)),
          ],
        ),
      ),
    );
  }
}
