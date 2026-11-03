import 'package:flutter/material.dart';

import '../data/tracks_data.dart';
import '../models.dart';
import '../services/storage.dart';
import 'garage.dart';
import 'game_screen.dart';
import 'widgets.dart';

/// Title screen: play, garage, records, settings.
class HomeScreen extends StatelessWidget {
  final AppState state;

  const HomeScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBackground(
        child: SafeArea(
          child: AnimatedBuilder(
            animation: state,
            builder: (context, _) {
              final car = state.selectedCar;
              return Padding(
                padding: const EdgeInsets.fromLTRB(28, 18, 28, 18),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Text(
                            'CAR CITY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 46,
                              height: 0.92,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                            ),
                          ),
                          const Text(
                            'SIMULATOR',
                            style: TextStyle(
                              color: Color(0xFF00E5FF),
                              fontSize: 46,
                              height: 0.92,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 6,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'High-octane arcade drift racing through a neon city',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 13,
                              letterSpacing: 2.4,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: <Widget>[
                              CoinBadge(coins: state.coins),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  '${car.name}  •  ${car.series}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          NeonButton(
                            label: 'RACE',
                            sublabel: 'PICK A MODE AND A TRACK',
                            icon: Icons.flag,
                            color: const Color(0xFF00E5FF),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ModeSelectScreen(state: state),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: NeonButton(
                                  label: 'GARAGE',
                                  icon: Icons.garage,
                                  color: const Color(0xFFFF6D00),
                                  height: 56,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => GarageScreen(state: state),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: NeonButton(
                                  label: 'RECORDS',
                                  icon: Icons.emoji_events,
                                  color: const Color(0xFFFFD54F),
                                  height: 56,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => RecordsScreen(state: state),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: NeonButton(
                                  label: 'SETTINGS',
                                  icon: Icons.settings,
                                  color: const Color(0xFFA855F7),
                                  height: 56,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => SettingsScreen(state: state),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 26),
                    Expanded(
                      flex: 2,
                      child: _CarShowcase(car: car),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Simple painted silhouette of the selected car, so the menu reflects the
/// garage without needing a 3D preview pass.
class _CarShowcase extends StatelessWidget {
  final CarModel car;

  const _CarShowcase({required this.car});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 1.5,
        child: CustomPaint(painter: _CarSilhouette(car)),
      ),
    );
  }
}

class _CarSilhouette extends CustomPainter {
  final CarModel car;

  _CarSilhouette(this.car);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.06, h * 0.46, w * 0.88, h * 0.30),
      Radius.circular(h * 0.10),
    );
    canvas.drawRRect(
      body.shift(Offset(0, h * 0.05)),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );
    canvas.drawRRect(body, Paint()..color = car.bodyColor);

    final roof = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.26, h * 0.26, w * 0.48, h * 0.24),
      Radius.circular(h * 0.09),
    );
    canvas.drawRRect(roof, Paint()..color = car.accentColor);

    final glass = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.30, h * 0.30, w * 0.40, h * 0.16),
      Radius.circular(h * 0.05),
    );
    canvas.drawRRect(glass, Paint()..color = const Color(0xFF101722));

    for (final dx in <double>[0.22, 0.68]) {
      canvas.drawCircle(
        Offset(w * dx, h * 0.78),
        h * 0.11,
        Paint()..color = const Color(0xFF0C0D10),
      );
      canvas.drawCircle(
        Offset(w * dx, h * 0.78),
        h * 0.05,
        Paint()..color = const Color(0xFFC6CBD2),
      );
    }

    // Underglow.
    canvas.drawOval(
      Rect.fromLTWH(w * 0.10, h * 0.82, w * 0.80, h * 0.10),
      Paint()
        ..color = car.underglowColor.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
  }

  @override
  bool shouldRepaint(covariant _CarSilhouette old) => old.car.id != car.id;
}

/// Pick one of the three game modes.
class ModeSelectScreen extends StatelessWidget {
  final AppState state;

  const ModeSelectScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBackground(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  const NeonBack(),
                  const Text(
                    'SELECT MODE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: CoinBadge(coins: state.coins),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Row(
                    children: GameMode.values.map((mode) {
                      final accent = switch (mode) {
                        GameMode.driftAttack => const Color(0xFF00E5FF),
                        GameMode.tandemCircuit => const Color(0xFFFF6D00),
                        GameMode.freestyle => const Color(0xFFA855F7),
                      };
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => TrackSelectScreen(
                                  state: state,
                                  mode: mode,
                                ),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.55),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: <Color>[
                                    accent.withValues(alpha: 0.18),
                                    accent.withValues(alpha: 0.02),
                                  ],
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    mode.title.toUpperCase(),
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.6,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    mode.subtitle,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      letterSpacing: 1.8,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    mode.description,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.62),
                                      fontSize: 12,
                                      height: 1.45,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: <Widget>[
                                      Icon(Icons.play_arrow, color: accent, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        'SELECT TRACK',
                                        style: TextStyle(
                                          color: accent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.6,
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
                    }).toList(),
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

/// Pick one of the four circuits, then start the run.
class TrackSelectScreen extends StatelessWidget {
  final AppState state;
  final GameMode mode;

  const TrackSelectScreen({super.key, required this.state, required this.mode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBackground(
        accent: const Color(0xFFFF6D00),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  const NeonBack(),
                  Text(
                    mode.title.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Row(
                    children: kTracks.map((track) {
                      final best = state.bestScore(mode, track.id);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => GameScreen(
                                  state: state,
                                  track: track,
                                  mode: mode,
                                ),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFFF6D00)
                                      .withValues(alpha: 0.45),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: <Color>[
                                    const Color(0xFF141A2A),
                                    const Color(0xFF0A0D16),
                                  ],
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Expanded(
                                    child: CustomPaint(
                                      painter: _TrackPreview(track),
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    track.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  Text(
                                    track.location,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      fontSize: 10,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: <Widget>[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(6),
                                          color: const Color(0xFFFF6D00)
                                              .withValues(alpha: 0.18),
                                        ),
                                        child: Text(
                                          track.difficulty.toUpperCase(),
                                          style: const TextStyle(
                                            color: Color(0xFFFF6D00),
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (best > 0)
                                        Text(
                                          '$best',
                                          style: const TextStyle(
                                            color: Color(0xFF00E5FF),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
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
                    }).toList(),
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

/// Mini map of a circuit, drawn from its centre line.
class _TrackPreview extends CustomPainter {
  final Track track;

  _TrackPreview(this.track);

  @override
  void paint(Canvas canvas, Size size) {
    final loop = track.loop;
    if (loop.length < 2) return;

    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in loop) {
      minX = p.x < minX ? p.x : minX;
      minY = p.y < minY ? p.y : minY;
      maxX = p.x > maxX ? p.x : maxX;
      maxY = p.y > maxY ? p.y : maxY;
    }
    final spanX = (maxX - minX).clamp(1.0, double.infinity).toDouble();
    final spanY = (maxY - minY).clamp(1.0, double.infinity).toDouble();
    final scale = (size.width / spanX < size.height / spanY)
        ? size.width / spanX
        : size.height / spanY;
    final ox = (size.width - spanX * scale) / 2;
    final oy = (size.height - spanY * scale) / 2;

    Offset at(TP p) => Offset(
          ox + (p.x - minX) * scale,
          oy + (p.y - minY) * scale,
        );

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
        ..strokeWidth = 6
        ..color = const Color(0xFFFF6D00).withValues(alpha: 0.35),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF00E5FF),
    );
    for (final c in track.clippingPoints) {
      canvas.drawCircle(
        at(TP(c.x, c.y)),
        2.5,
        Paint()..color = const Color(0xFFFFD54F),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrackPreview old) => old.track.id != track.id;
}

/// Best runs, newest first.
class RecordsScreen extends StatelessWidget {
  final AppState state;

  const RecordsScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBackground(
        accent: const Color(0xFFFFD54F),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Row(
                children: const <Widget>[
                  NeonBack(),
                  Text(
                    'RECORDS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: state,
                  builder: (context, _) {
                    if (state.records.isEmpty) {
                      return Center(
                        child: Text(
                          'No runs yet — go set a record.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            letterSpacing: 1.4,
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      itemCount: state.records.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final r = state.records[i];
                        final track = kTracks.firstWhere(
                          (t) => t.id == r.trackId,
                          orElse: () => kTracks.first,
                        );
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white.withValues(alpha: 0.04),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Text(
                                '${r.score}',
                                style: const TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      '${r.mode.title}  •  ${track.name}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '${r.laps} laps  •  ${r.seconds.toStringAsFixed(1)}s  •  '
                                      '${r.at.day.toString().padLeft(2, '0')}/'
                                      '${r.at.month.toString().padLeft(2, '0')}/${r.at.year}',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.45),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Camera mode, steering sensitivity and layout.
class SettingsScreen extends StatelessWidget {
  final AppState state;

  const SettingsScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBackground(
        accent: const Color(0xFFA855F7),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: state,
            builder: (context, _) {
              return Column(
                children: <Widget>[
                  Row(
                    children: const <Widget>[
                      NeonBack(),
                      Text(
                        'SETTINGS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                      children: <Widget>[
                        const _SectionLabel('CAMERA'),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: CameraMode.values.map((m) {
                            final selected = state.cameraMode == m;
                            return ChoiceChip(
                              label: Text('${m.title}  ${m.subtitle}'),
                              selected: selected,
                              onSelected: (_) => state.setCameraMode(m),
                              selectedColor: const Color(0xFFA855F7)
                                  .withValues(alpha: 0.35),
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.05),
                              labelStyle: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.7),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                              side: BorderSide(
                                color: selected
                                    ? const Color(0xFFA855F7)
                                    : Colors.white.withValues(alpha: 0.12),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 26),
                        const _SectionLabel('STEERING SENSITIVITY'),
                        Slider(
                          value: state.steeringSensitivity,
                          min: 0.5,
                          max: 1.6,
                          divisions: 11,
                          activeColor: const Color(0xFF00E5FF),
                          label: state.steeringSensitivity.toStringAsFixed(1),
                          onChanged: state.setSensitivity,
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          value: state.leftHanded,
                          onChanged: state.setLeftHanded,
                          activeThumbColor: const Color(0xFF00E5FF),
                          title: const Text(
                            'Left-handed layout',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          subtitle: Text(
                            'Swap the steering pad to the left side',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 11,
                            ),
                          ),
                        ),
                        SwitchListTile(
                          value: state.sfxEnabled,
                          onChanged: state.setSfx,
                          activeThumbColor: const Color(0xFF00E5FF),
                          title: const Text(
                            'Engine and tyre sound',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          subtitle: Text(
                            'Procedural engine audio',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.2,
        ),
      ),
    );
  }
}
