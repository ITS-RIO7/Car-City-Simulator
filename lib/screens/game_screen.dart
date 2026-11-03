import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/sim.dart';
import '../models.dart';
import '../services/storage.dart';
import 'widgets.dart';

/// Shown in the HUD so the installed build is never in doubt.
const String kAppVersion = '1.0.5';

/// The run itself: ticker-driven simulation, 3D canvas, HUD and touch controls.
class GameScreen extends StatefulWidget {
  final AppState state;
  final Track track;
  final GameMode mode;

  const GameScreen({
    super.key,
    required this.state,
    required this.track,
    required this.mode,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late DriftSim _sim;
  late Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  Duration _last = Duration.zero;
  bool _paused = false;
  bool _resultShown = false;
  bool _diag = false;

  // Control state, set by the on-screen buttons.
  double _steer = 0;
  double _throttle = 0;
  double _brake = 0;
  bool _nos = false;

  @override
  void initState() {
    super.initState();
    _sim = DriftSim(
      track: widget.track,
      car: widget.state.selectedCar,
      mode: widget.mode,
    )..cameraMode = widget.state.cameraMode;
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (_paused) {
      _last = elapsed;
      return;
    }
    final dt = _last == Duration.zero
        ? 0.016
        : (elapsed - _last).inMicroseconds / 1000000.0;
    _last = elapsed;

    _sim.setControls(
      steerInput:
          (_steer * widget.state.steeringSensitivity).clamp(-1.0, 1.0).toDouble(),
      throttleInput: _throttle,
      brakeAmount: _brake,
      nos: _nos,
    );
    _sim.update(dt);
    _frame.value++;

    if (_sim.isOver && !_resultShown) {
      _resultShown = true;
      _ticker.stop();
      _showResult();
    }
  }

  void _restart() {
    setState(() {
      _sim = DriftSim(
        track: widget.track,
        car: widget.state.selectedCar,
        mode: widget.mode,
      )..cameraMode = widget.state.cameraMode;
      _resultShown = false;
      _paused = false;
      _last = Duration.zero;
      _steer = 0;
      _throttle = 0;
      _brake = 0;
      _nos = false;
    });
    _ticker.start();
  }

  void _showResult() {
    final hud = _sim.hud;
    final coins = (hud.score ~/ 100).clamp(0, 9999).toInt();
    widget.state.addCoins(coins);
    widget.state.addRecord(RunRecord(
      mode: widget.mode,
      trackId: widget.track.id,
      score: hud.score,
      laps: hud.laps,
      seconds: hud.timeLeft ?? 0,
      at: DateTime.now(),
    ));

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ResultDialog(
        hud: hud,
        coins: coins,
        onRestart: () {
          Navigator.of(context).pop();
          _restart();
        },
        onQuit: () {
          Navigator.of(context).pop();
          Navigator.of(context).maybePop();
        },
      ),
    );
  }

  void _togglePause() {
    if (_resultShown) return;
    setState(() => _paused = !_paused);
    if (_paused) {
      showDialog<void>(
        context: context,
        builder: (context) => _PauseDialog(
          onResume: () {
            Navigator.of(context).pop();
            setState(() => _paused = false);
          },
          onRestart: () {
            Navigator.of(context).pop();
            _restart();
          },
          onQuit: () {
            Navigator.of(context).pop();
            Navigator.of(context).maybePop();
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leftHanded = widget.state.leftHanded;
    return Scaffold(
      backgroundColor: const Color(0xFF05060A),
      body: AnimatedBuilder(
        animation: _frame,
        builder: (context, _) {
          final hud = _sim.hud;
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              RepaintBoundary(
                child: CustomPaint(
                  painter: _SimPainter(_sim),
                  isComplex: true,
                  willChange: true,
                ),
              ),
              _Hud(
                hud: hud,
                track: widget.track,
                sim: _sim,
                onPause: _togglePause,
                diag: _diag,
                onToggleDiag: () => setState(() => _diag = !_diag),
              ),
              _Controls(
                leftHanded: leftHanded,
                onSteer: (v) => _steer = v,
                onThrottle: (v) => _throttle = v,
                onBrake: (v) => _brake = v,
                onNos: (v) => _nos = v,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SimPainter extends CustomPainter {
  final DriftSim sim;

  _SimPainter(this.sim);

  @override
  void paint(Canvas canvas, Size size) {
    sim.render(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _SimPainter old) => true;
}

/// Score, multiplier, timer, speed and the mini map.
class _Hud extends StatelessWidget {
  final HudState hud;
  final Track track;
  final DriftSim sim;
  final VoidCallback onPause;
  final bool diag;
  final VoidCallback onToggleDiag;

  const _Hud({
    required this.hud,
    required this.track,
    required this.sim,
    required this.onPause,
    required this.diag,
    required this.onToggleDiag,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: <Widget>[
            // Score block, top left.
            Align(
              alignment: Alignment.topLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        '${hud.score}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      if (hud.multiplier > 1) ...<Widget>[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: const Color(0xFFFF007F)
                                .withValues(alpha: 0.25),
                            border: Border.all(
                              color: const Color(0xFFFF007F),
                            ),
                          ),
                          child: Text(
                            'x${hud.multiplier}',
                            style: const TextStyle(
                              color: Color(0xFFFF007F),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SCORE',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 9,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (hud.drifting) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      'DRIFT ${hud.driftAngleDeg.toStringAsFixed(0)}°',
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Timer / laps, top centre.
            Align(
              alignment: Alignment.topCenter,
              child: Column(
                children: <Widget>[
                  Text(
                    hud.timeLeft == null
                        ? '∞'
                        : hud.timeLeft!.toStringAsFixed(1),
                    style: TextStyle(
                      color: (hud.timeLeft ?? 99) < 10
                          ? const Color(0xFFFF2A55)
                          : Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  if (hud.targetLaps > 0)
                    Text(
                      'LAP ${hud.laps}/${hud.targetLaps}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (hud.lastApex.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'APEX',
                        style: TextStyle(
                          color: const Color(0xFFFFD54F)
                              .withValues(alpha: 0.9),
                          fontSize: 10,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Pause, top right.
            Align(
              alignment: Alignment.topRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  GestureDetector(
                    onTap: onToggleDiag,
                    child: _SpeedReadout(speed: hud.speedKph),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        onPressed: onPause,
                        icon: const Icon(Icons.pause_circle_filled,
                            color: Colors.white70, size: 34),
                      ),
                      Text(
                        'v$kAppVersion',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 9,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (diag)
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 96),
                  child: Text(
                    'angle ${(sim.angle * 180 / 3.14159).toStringAsFixed(1)}°\n'
                    'steer ${sim.steer.toStringAsFixed(3)}  '
                    'vLong ${sim.vel.x.toStringAsFixed(0)}\n'
                    'speed ${sim.speed.toStringAsFixed(1)}  v$kAppVersion',
                    style: const TextStyle(
                      color: Color(0xFF7CF5A0),
                      fontSize: 11,
                      height: 1.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),

            // Mini map, bottom centre.
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: 150,
                height: 96,
                child: CustomPaint(
                  painter: _MiniMap(
                    track: track,
                    x: sim.pos.x,
                    y: sim.pos.y,
                  ),
                ),
              ),
            ),

            // NOS bar, bottom right.
            Align(
              alignment: Alignment.bottomRight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    'NOS',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 9,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 120,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: hud.nos.clamp(0.0, 1.0).toDouble(),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: const Color(0xFF00E5FF),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedReadout extends StatelessWidget {
  final double speed;

  const _SpeedReadout({required this.speed});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Text(
          speed.toStringAsFixed(0),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          'KM/H',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 8,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MiniMap extends CustomPainter {
  final Track track;
  final double x;
  final double y;

  _MiniMap({required this.track, required this.x, required this.y});

  @override
  void paint(Canvas canvas, Size size) {
    final loop = track.loop;
    if (loop.length < 2) return;

    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in loop) {
      minX = math.min(minX, p.x);
      minY = math.min(minY, p.y);
      maxX = math.max(maxX, p.x);
      maxY = math.max(maxY, p.y);
    }
    final spanX = (maxX - minX).clamp(1.0, double.infinity).toDouble();
    final spanY = (maxY - minY).clamp(1.0, double.infinity).toDouble();
    final scale = math.min(size.width / spanX, size.height / spanY) * 0.9;
    final ox = (size.width - spanX * scale) / 2;
    final oy = (size.height - spanY * scale) / 2;

    Offset at(TP p) => Offset(ox + (p.x - minX) * scale, oy + (p.y - minY) * scale);

    final path = Path()..moveTo(at(loop.first).dx, at(loop.first).dy);
    for (final p in loop.skip(1)) {
      final o = at(p);
      path.lineTo(o.dx, o.dy);
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.black.withValues(alpha: 0.55),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFF6D00),
    );
    canvas.drawCircle(
      at(TP(x, y)),
      3.5,
      Paint()..color = const Color(0xFF00E5FF),
    );
  }

  @override
  bool shouldRepaint(covariant _MiniMap old) =>
      old.x != x || old.y != y || old.track.id != track.id;
}

/// Hold buttons for steering, throttle, brake and NOS.
class _Controls extends StatelessWidget {
  final bool leftHanded;
  final ValueChanged<double> onSteer;
  final ValueChanged<double> onThrottle;
  final ValueChanged<double> onBrake;
  final ValueChanged<bool> onNos;

  const _Controls({
    required this.leftHanded,
    required this.onSteer,
    required this.onThrottle,
    required this.onBrake,
    required this.onNos,
  });

  @override
  Widget build(BuildContext context) {
    final steerPad = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _HoldButton(
          icon: Icons.keyboard_arrow_left,
          color: const Color(0xFF00E5FF),
          onDown: () => onSteer(-1),
          onUp: () => onSteer(0),
        ),
        const SizedBox(width: 12),
        _HoldButton(
          icon: Icons.keyboard_arrow_right,
          color: const Color(0xFF00E5FF),
          onDown: () => onSteer(1),
          onUp: () => onSteer(0),
        ),
      ],
    );

    final pedalPad = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _HoldButton(
          label: 'NOS',
          color: const Color(0xFFA855F7),
          onDown: () => onNos(true),
          onUp: () => onNos(false),
        ),
        const SizedBox(width: 12),
        _HoldButton(
          label: 'BRAKE',
          color: const Color(0xFFFF2A55),
          onDown: () => onBrake(1),
          onUp: () => onBrake(0),
        ),
        const SizedBox(width: 12),
        _HoldButton(
          label: 'GAS',
          color: const Color(0xFF00E676),
          big: true,
          onDown: () => onThrottle(1),
          onUp: () => onThrottle(0),
        ),
      ],
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: leftHanded
                ? <Widget>[pedalPad, steerPad]
                : <Widget>[steerPad, pedalPad],
          ),
        ),
      ),
    );
  }
}

class _HoldButton extends StatefulWidget {
  final IconData? icon;
  final String? label;
  final Color color;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final bool big;

  const _HoldButton({
    this.icon,
    this.label,
    required this.color,
    required this.onDown,
    required this.onUp,
    this.big = false,
  });

  @override
  State<_HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<_HoldButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
    if (v) {
      widget.onDown();
    } else {
      widget.onUp();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.big ? 84.0 : 68.0;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: _down ? 0.35 : 0.14),
          border: Border.all(
            color: widget.color.withValues(alpha: _down ? 1.0 : 0.55),
            width: 2,
          ),
          boxShadow: <BoxShadow>[
            if (_down)
              BoxShadow(
                color: widget.color.withValues(alpha: 0.45),
                blurRadius: 18,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Center(
          child: widget.icon != null
              ? Icon(widget.icon, color: widget.color, size: 34)
              : Text(
                  widget.label ?? '',
                  style: TextStyle(
                    color: widget.color,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
        ),
      ),
    );
  }
}

class _PauseDialog extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;

  const _PauseDialog({
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'PAUSED',
      children: <Widget>[
        NeonButton(
          label: 'RESUME',
          icon: Icons.play_arrow,
          color: const Color(0xFF00E676),
          onTap: onResume,
        ),
        const SizedBox(height: 12),
        NeonButton(
          label: 'RESTART',
          icon: Icons.refresh,
          color: const Color(0xFF00E5FF),
          onTap: onRestart,
        ),
        const SizedBox(height: 12),
        NeonButton(
          label: 'QUIT RUN',
          icon: Icons.exit_to_app,
          color: const Color(0xFFFF2A55),
          onTap: onQuit,
        ),
      ],
    );
  }
}

class _ResultDialog extends StatelessWidget {
  final HudState hud;
  final int coins;
  final VoidCallback onRestart;
  final VoidCallback onQuit;

  const _ResultDialog({
    required this.hud,
    required this.coins,
    required this.onRestart,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'RUN COMPLETE',
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _Stat('SCORE', '${hud.score}'),
            _Stat('LAPS', '${hud.laps}'),
            _Stat('COINS', '+$coins'),
          ],
        ),
        const SizedBox(height: 22),
        NeonButton(
          label: 'RUN AGAIN',
          icon: Icons.refresh,
          color: const Color(0xFF00E5FF),
          onTap: onRestart,
        ),
        const SizedBox(height: 12),
        NeonButton(
          label: 'BACK TO MENU',
          icon: Icons.home,
          color: const Color(0xFFFF6D00),
          onTap: onQuit,
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 9,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Sheet extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Sheet({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 120, vertical: 40),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF0C0F18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Colors.black54, blurRadius: 40),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}
