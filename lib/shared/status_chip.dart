import 'package:flutter/material.dart';
import 'theme.dart';

enum StatusChipType { live, select, taken, yours, delayed, offline }

class StatusChip extends StatelessWidget {
  final String? label;
  final StatusChipType type;

  const StatusChip({
    super.key,
    this.label,
    this.type = StatusChipType.live,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String text;
    bool showDot = false;

    switch (type) {
      case StatusChipType.live:
        bg = AppTheme.successBg;
        fg = AppTheme.success;
        text = label ?? 'LIVE';
        showDot = true;
        break;
      case StatusChipType.select:
        bg = AppTheme.infoBg;
        fg = AppTheme.info;
        text = label ?? 'Select';
        break;
      case StatusChipType.taken:
        bg = AppTheme.surfaceSubtle;
        fg = AppTheme.muted;
        text = label ?? 'Taken';
        break;
      case StatusChipType.yours:
        bg = AppTheme.successBg;
        fg = AppTheme.success;
        text = label ?? 'Yours';
        break;
      case StatusChipType.delayed:
        bg = AppTheme.warningBg;
        fg = AppTheme.warning;
        text = label ?? 'Delayed';
        showDot = true;
        break;
      case StatusChipType.offline:
        bg = AppTheme.errorBg;
        fg = AppTheme.error;
        text = label ?? 'Signal Lost';
        showDot = true;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: fg,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}
