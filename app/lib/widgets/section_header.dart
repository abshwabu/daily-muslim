import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? eyebrow;
  final Widget? trailing;
  final VoidCallback? onTrailingTap;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.trailing,
    this.onTrailingTap,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!.toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                      color: const Color(0xFF546356),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF31332E),
                    letterSpacing: -0.5,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF5E6059),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailingTap,
              behavior: HitTestBehavior.opaque,
              child: trailing!,
            ),
        ],
      ),
    );
  }
}
