import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/semilla_reward_service.dart';
import '../../../config/injection/injection.dart';
import '../widgets/moneda_icon.dart'
    show SemillaIcon, semillaAsset, semillaCara2Asset;

/// Envuelve la app y muestra el modal animado de "ganaste semilla" cuando
/// [SemillaRewardService] emite una recompensa. Se autocierra a los 2 segundos.
class SemillaRewardHost extends StatefulWidget {
  const SemillaRewardHost({super.key, required this.child});

  final Widget child;

  @override
  State<SemillaRewardHost> createState() => _SemillaRewardHostState();
}

class _SemillaRewardHostState extends State<SemillaRewardHost> {
  SemillaReward? _reward;
  Timer? _timer;
  StreamSubscription<SemillaReward>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = sl<SemillaRewardService>().rewards.listen((reward) {
      if (!mounted) return;
      _timer?.cancel();
      setState(() => _reward = reward);
      _timer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _reward = null);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reward = _reward;
    return Stack(
      children: [
        widget.child,
        if (reward != null)
          Positioned.fill(
            child: _SemillaRewardOverlay(
              key: ValueKey(reward.amount.toString() + (reward.label ?? '')),
              reward: reward,
            ),
          ),
      ],
    );
  }
}

class _SemillaRewardOverlay extends StatefulWidget {
  const _SemillaRewardOverlay({super.key, required this.reward});

  final SemillaReward reward;

  @override
  State<_SemillaRewardOverlay> createState() => _SemillaRewardOverlayState();
}

class _SemillaRewardOverlayState extends State<_SemillaRewardOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            // Giro de casino: 3 vueltas completas sobre el eje Y.
            final angle = t * math.pi * 6;
            final showFront = (angle / math.pi).floor().isEven;
            // Pop-in con rebote suave y leve desvanecido al final.
            final pop = (t < 0.18 ? Curves.easeOutBack.transform(t / 0.18) : 1.0);
            final fade = t > 0.85 ? (1 - (t - 0.85) / 0.15) : 1.0;
            final opacity = fade.clamp(0.0, 1.0);

            return Opacity(
              opacity: opacity,
              child: Container(
                color: Colors.black.withValues(alpha: 0.55 * opacity),
                child: Center(
                  child: Transform.scale(
                    scale: 0.85 + 0.15 * pop,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CoinSpin(angle: angle, showFront: showFront),
                        const SizedBox(height: 26),
                        _RewardAmount(reward: widget.reward),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CoinSpin extends StatelessWidget {
  const _CoinSpin({required this.angle, required this.showFront});

  final double angle;
  final bool showFront;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo dorado estilo casino.
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFE3AB5B).withValues(alpha: 0.55),
                  const Color(0xFFE3AB5B).withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateY(angle),
            child: Image.asset(
              showFront ? semillaAsset : semillaCara2Asset,
              width: 150,
              height: 150,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, _, __) => const Icon(
                Icons.paid_rounded,
                size: 140,
                color: Color(0xFFE3AB5B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardAmount extends StatelessWidget {
  const _RewardAmount({required this.reward});

  final SemillaReward reward;

  @override
  Widget build(BuildContext context) {
    final esSemilla = reward.unit == 'semillas';
    final unidad = esSemilla ? 'semillas' : reward.unit;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          reward.label ?? (esSemilla ? '¡Ganaste semillas!' : '¡Recompensa!'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFE3AB5B),
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF100E22).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE3AB5B), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE3AB5B).withValues(alpha: 0.35),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (esSemilla) ...[
                const SemillaIcon(size: 26),
                const SizedBox(width: 10),
              ],
              Text(
                '+${reward.amount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 30,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                unidad,
                style: const TextStyle(
                  color: Color(0xFFA8AAA2),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
