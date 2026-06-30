import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ember/features/reader/reader_settings.dart';
import 'package:ember/theme/app_colors.dart';

/// The "Aa" reading-controls bottom sheet: theme, font size, typeface, and line
/// spacing. Edits are reported live via [onChanged] so the page updates instantly.
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final ReaderSettings settings;
  final ValueChanged<ReaderSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 5,
              margin: const EdgeInsets.only(top: 4, bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Text(
            'Reading',
            style: GoogleFonts.fraunces(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 14),

          // ── Theme ──────────────────────────────────────────────────────
          const _CtlLabel('Theme'),
          Row(
            children: [
              for (final theme in ReaderTheme.values) ...[
                if (theme.index > 0) const SizedBox(width: 10),
                Expanded(
                  child: _ThemeChip(
                    theme: theme,
                    selected: settings.theme == theme,
                    onTap: () => onChanged(settings.copyWith(theme: theme)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),

          // ── Font size ──────────────────────────────────────────────────
          const _CtlLabel('Font size'),
          _Stepper(
            value: '${settings.fontSize.round()} pt',
            onMinus: settings.fontSize > kMinFontSize
                ? () => onChanged(
                    settings.copyWith(fontSize: settings.fontSize - 1))
                : null,
            onPlus: settings.fontSize < kMaxFontSize
                ? () => onChanged(
                    settings.copyWith(fontSize: settings.fontSize + 1))
                : null,
          ),
          const SizedBox(height: 18),

          // ── Typeface ───────────────────────────────────────────────────
          const _CtlLabel('Typeface'),
          Row(
            children: [
              for (final face in ReaderTypeface.values) ...[
                if (face.index > 0) const SizedBox(width: 8),
                Expanded(
                  child: _FontChip(
                    face: face,
                    selected: settings.typeface == face,
                    onTap: () => onChanged(settings.copyWith(typeface: face)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),

          // ── Line spacing ───────────────────────────────────────────────
          const _CtlLabel('Line spacing'),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              activeTrackColor: AppColors.ember,
              inactiveTrackColor: AppColors.line,
              thumbColor: AppColors.ember,
              overlayColor: AppColors.ember.withValues(alpha: 0.15),
            ),
            child: Slider(
              min: kMinLineSpacing,
              max: kMaxLineSpacing,
              value: settings.lineSpacing,
              onChanged: (v) => onChanged(settings.copyWith(lineSpacing: v)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CtlLabel extends StatelessWidget {
  const _CtlLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.12 * 11,
          color: AppColors.inkFaint,
        ),
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final ReaderTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.ember : AppColors.line,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Container(
              height: 22,
              decoration: BoxDecoration(
                color: theme.bg,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppColors.line),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              theme.label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.ink : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, this.onMinus, this.onPlus});

  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card2,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StepperButton(label: 'A−', onTap: onMinus),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          _StepperButton(label: 'A+', onTap: onPlus),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        elevation: 1,
        shadowColor: const Color(0x22281E12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 42,
            height: 38,
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.fraunces(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FontChip extends StatelessWidget {
  const _FontChip({
    required this.face,
    required this.selected,
    required this.onTap,
  });

  final ReaderTypeface face;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.ember : AppColors.line,
            width: 2,
          ),
        ),
        child: Text(
          face.label,
          // Preview the chip in its own typeface.
          style: face.textStyle(
            fontSize: 14,
            height: 1,
            color: selected ? AppColors.ink : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}
