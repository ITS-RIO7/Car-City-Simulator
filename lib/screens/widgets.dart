import 'package:flutter/material.dart';

/// Shared neon look: dark backdrop with a colour wash and a faint grid, used by
/// every menu screen so the whole app reads as one piece.
class NeonBackground extends StatelessWidget {
  final Widget child;
  final Color accent;

  const NeonBackground({
    super.key,
    required this.child,
    this.accent = const Color(0xFF00E5FF),
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xFF080A12),
            Color.lerp(const Color(0xFF0D1020), accent, 0.12)!,
            const Color(0xFF05060A),
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: <Color>[
                  accent.withValues(alpha: 0.22),
                  accent.withValues(alpha: 0.0),
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -60,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: <Color>[
                  const Color(0xFFFF007F).withValues(alpha: 0.18),
                  const Color(0xFFFF007F).withValues(alpha: 0.0),
                ]),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Chunky neon button used across the menus.
class NeonButton extends StatelessWidget {
  final String label;
  final String? sublabel;
  final IconData? icon;
  final Color color;
  final VoidCallback? onTap;
  final double height;

  const NeonButton({
    super.key,
    required this.label,
    this.sublabel,
    this.icon,
    this.color = const Color(0xFF00E5FF),
    this.onTap,
    this.height = 64,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.65), width: 1.5),
              gradient: LinearGradient(
                colors: <Color>[
                  color.withValues(alpha: 0.20),
                  color.withValues(alpha: 0.04),
                ],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, color: color, size: 26),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      if (sublabel != null)
                        Text(
                          sublabel!,
                          style: TextStyle(
                            color: color.withValues(alpha: 0.85),
                            fontSize: 12,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small pill showing the player's coin balance.
class CoinBadge extends StatelessWidget {
  final int coins;

  const CoinBadge({super.key, required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: const Color(0xFFFFD54F).withValues(alpha: 0.12),
        border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.monetization_on, color: Color(0xFFFFD54F), size: 18),
          const SizedBox(width: 8),
          Text(
            '$coins',
            style: const TextStyle(
              color: Color(0xFFFFD54F),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Back arrow styled for the dark theme.
class NeonBack extends StatelessWidget {
  const NeonBack({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
      onPressed: () => Navigator.of(context).maybePop(),
    );
  }
}
