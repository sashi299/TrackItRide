import 'dart:ui';
import 'package:flutter/material.dart';
import '../shared/theme.dart';

/// A modern floating glassmorphism HUD widget displaying live distance, ETA,
/// and destination stop details over the map.
class LiveEtaHud extends StatelessWidget {
  final String destinationName;
  final String distanceText;
  final String etaText;
  final VoidCallback? onTap;
  final Color accentColor;
  final bool isRoadRoute;

  const LiveEtaHud({
    super.key,
    required this.destinationName,
    required this.distanceText,
    required this.etaText,
    this.onTap,
    this.accentColor = AppTheme.primaryColor,
    this.isRoadRoute = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F0F172A),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Destination info
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.near_me_rounded,
                    size: 16,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              destinationName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.text,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                          if (isRoadRoute) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.route_rounded, size: 11, color: AppTheme.success),
                          ],
                        ],
                      ),
                      const Text(
                        'Tap to center',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.muted,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Vertical divider
                Container(
                  height: 24,
                  width: 1,
                  color: AppTheme.border,
                ),
                const SizedBox(width: 10),
                // Live Distance & ETA
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.straighten_rounded, size: 12, color: AppTheme.muted),
                        const SizedBox(width: 3),
                        Text(
                          distanceText,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.text,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_filled_rounded, size: 10, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            etaText,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
