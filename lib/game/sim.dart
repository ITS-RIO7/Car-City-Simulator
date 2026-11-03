import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../models.dart';
import 'render.dart';

/// Live numbers the HUD shows. Rebuilt every frame from [DriftSim].
class HudState {
  final int score;
  final int multiplier;
  final double? timeLeft;
  final double speedKph;
  final bool drifting;
  final double nos;
  final int laps;
  final int targetLaps;
  final String lastApex;
  final double driftAngleDeg;

  const HudState({
    required this.score,
    required this.multiplier,
    required this.timeLeft,
    required this.speedKph,
    required this.drifting,
    required this.nos,
    required this.laps,
    required this.targetLaps,
    required this.lastApex,
    required this.driftAngleDeg,
  });
}

class _Smoke {
  vm.Vector3 p;
  double age = 0;
  double life;
  double size;
  Color color;
  _Smoke(this.p, this.size, this.color) : life = 1.0 + math.Random().nextDouble() * 0.5;
}

/// The whole game: world meshes, car physics, drift scoring and drawing.
///
/// Physics constants are the Kotlin DriftPhysicsEngine values, in the same
/// world units (the car is 54 long, top speed ~500/s).
class DriftSim {
  DriftSim({required this.track, required this.car, required this.mode}) {
    _buildWorld();
    _carMesh = _buildCar();
    pos = vm.Vector2(track.startX, track.startY);
    angle = track.startAngleDeg * math.pi / 180;
    timeLeft = mode.timeLimitSec;
    _checkpoints = track.loop;
  }

  final Track track;
  final CarModel car;
  final GameMode mode;

  // ---- physics state
  vm.Vector2 pos = vm.Vector2.zero();
  vm.Vector2 vel = vm.Vector2.zero();
  double angle = 0;
  double steer = 0;
  double _steerInput = 0;
  double throttle = 0;
  double brakeInput = 0;
  double nosAmount = 1.0;
  bool nosActive = false;
  bool isOver = false;

  // ---- scoring
  int score = 0;
  int multiplier = 1;
  double combo = 0;
  double comboTimer = 0;
  double driftAngle = 0;
  double yawRate = 0;
  double maxYawSeen = 0;
  double speed = 0;
  String lastApex = '';
  double apexFlash = 0;

  // ---- run state
  double? timeLeft;
  int laps = 0;
  int _nextCheckpoint = 1;
  List<TP> _checkpoints = const <TP>[];

  // ---- tuning (Kotlin DriftPhysicsEngine constants)
  static const double carLength = 54;
  static const double carWidth = 28;
  static const double carRadius = 26;
  static const double _minDriftSpeed = 55;

  /// Effective distance between the axles, and the lateral acceleration the
  /// tyres can hold. Together these set the turning circle: the car is 54 long,
  /// and this wheelbase gives a 120-unit radius at full lock - about two and a
  /// half car lengths. A short wheelbase here is what made the car pivot in a
  /// circle smaller than itself and look like it was spinning.
  static const double _wheelBase = 110.0;
  static const double _maxLateralAccel = 150.0;

  /// Below this forward speed the car cannot rotate at all.
  static const double _minRollSpeed = 12.0;

  /// Absolute ceiling on yaw rate, as a last line of defence.
  static const double _maxYawRate = 1.2;
  static const double _driftThresholdAngle = 14 * math.pi / 180;

  // ---- world
  final List<Mesh3D> _world = <Mesh3D>[];
  final List<Mesh3D> _ground = <Mesh3D>[];
  final List<Mesh3D> _apexMarkers = <Mesh3D>[];
  late final Mesh3D _carMesh;
  final List<_Smoke> _smoke = <_Smoke>[];
  double _smokeTimer = 0;
  double _wheelSpin = 0;

  final Camera3D camera = Camera3D();

  HudState get hud => HudState(
        score: score,
        multiplier: multiplier,
        timeLeft: timeLeft,
        speedKph: speed * 0.62,
        drifting: driftAngle > _driftThresholdAngle && speed > _minDriftSpeed,
        nos: nosAmount,
        laps: laps,
        targetLaps: mode.targetLaps,
        lastApex: lastApex,
        driftAngleDeg: driftAngle * 180 / math.pi,
      );

  // ---------------------------------------------------------------- world
  void _buildWorld() {
    final loop = track.loop;
    final half = track.roadWidth / 2;

    final road = <Face>[];
    final kerbIn = <Face>[];
    final kerbOut = <Face>[];
    final dash = <Face>[];
    final barrierIn = <Face>[];
    final barrierOut = <Face>[];

    final roadColor = const Color(0xFF232936);
    final kerbColor = const Color(0xFFE0244B);
    final kerbAlt = const Color(0xFFF2F2F2);
    final dashColor = const Color(0x66FFFFFF);
    final barrierColor = const Color(0xFF7A4A12);

    for (var i = 0; i < loop.length; i++) {
      final a = loop[i];
      final b = loop[(i + 1) % loop.length];
      final dx = b.x - a.x;
      final dy = b.y - a.y;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len < 1) continue;
      final nx = -dy / len;
      final ny = dx / len;

      // Subdivide long segments so the road follows the curve smoothly.
      final steps = (len / 60).ceil().clamp(1, 12).toInt();
      for (var s = 0; s < steps; s++) {
        final t0 = s / steps;
        final t1 = (s + 1) / steps;
        final x0 = a.x + dx * t0, y0 = a.y + dy * t0;
        final x1 = a.x + dx * t1, y1 = a.y + dy * t1;

        vm.Vector3 v(double x, double y, double o, [double h = 0]) =>
            vm.Vector3(x + nx * o, h, y + ny * o);

        // Road surface (facing +Y).
        road.add(Face([
          v(x0, y0, -half),
          v(x1, y1, -half),
          v(x1, y1, half),
          v(x0, y0, half),
        ], roadColor));

        // Kerbs, alternating colour like a real apex kerb.
        final kc = (i + s) % 2 == 0 ? kerbColor : kerbAlt;
        kerbIn.add(Face([
          v(x0, y0, -half - 8),
          v(x1, y1, -half - 8),
          v(x1, y1, -half),
          v(x0, y0, -half),
        ], kc));
        kerbOut.add(Face([
          v(x0, y0, half),
          v(x1, y1, half),
          v(x1, y1, half + 8),
          v(x0, y0, half + 8),
        ], kc));

        // Centre dashes.
        if (s % 2 == 0) {
          dash.add(Face([
            v(x0, y0, -1.5, 0.4),
            v(x1, y1, -1.5, 0.4),
            v(x1, y1, 1.5, 0.4),
            v(x0, y0, 1.5, 0.4),
          ], dashColor));
        }

        // Glowing barriers on both edges.
        for (final side in <double>[-1, 1]) {
          final o = side * (half + 10);
          final wall = side < 0 ? barrierIn : barrierOut;
          final bottom = v(x0, y0, o, 0);
          final bottom2 = v(x1, y1, o, 0);
          final top = v(x0, y0, o, 9);
          final top2 = v(x1, y1, o, 9);
          wall.add(Face(
            side < 0
                ? [bottom, bottom2, top2, top]
                : [bottom2, bottom, top, top2],
            barrierColor,
          ));
          // Bright cap so the barrier reads as neon at speed.
          wall.add(Face(
            side < 0
                ? [top, top2, v(x1, y1, o, 12), v(x0, y0, o, 12)]
                : [top2, top, v(x0, y0, o, 12), v(x1, y1, o, 12)],
            const Color(0xFFFF9100),
          ));
        }
      }
    }

    _ground.add(Mesh3D(<Face>[
      Face([
        vm.Vector3(-400, 0, -400),
        vm.Vector3(-400, 0, track.worldHeight + 400),
        vm.Vector3(track.worldWidth + 400, 0, track.worldHeight + 400),
        vm.Vector3(track.worldWidth + 400, 0, -400),
      ], const Color(0xFF0B0D12)),
    ]));

    _world.add(Mesh3D(road));
    _world.add(Mesh3D(kerbIn));
    _world.add(Mesh3D(kerbOut));
    _world.add(Mesh3D(dash));
    _world.add(Mesh3D(barrierIn));
    _world.add(Mesh3D(barrierOut));

    _buildCity(loop, half);
    _buildApexMarkers();
  }

  /// A neon skyline ringed outside the circuit, plus street lamps.
  void _buildCity(List<TP> loop, double half) {
    final rng = math.Random(42);
    final faces = <Face>[];
    final lamps = <Face>[];
    final neon = <Color>[
      const Color(0xFF00E5FF),
      const Color(0xFFFF007F),
      const Color(0xFFA855F7),
      const Color(0xFFFF6D00),
      const Color(0xFFFFD54F),
    ];

    for (var i = 0; i < loop.length; i++) {
      final a = loop[i];
      final b = loop[(i + 1) % loop.length];
      final dx = b.x - a.x;
      final dy = b.y - a.y;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len < 1) continue;
      final nx = -dy / len;
      final ny = dx / len;
      final blocks = (len / 190).floor();

      for (var k = 0; k < blocks; k++) {
        final t = (k + 0.5) / blocks;
        final cx = a.x + dx * t;
        final cy = a.y + dy * t;

        for (final side in <double>[-1, 1]) {
          final dist = half + 110 + rng.nextDouble() * 130;
          final bx = cx + nx * side * dist;
          final by = cy + ny * side * dist;
          if (bx < -100 ||
              by < -100 ||
              bx > track.worldWidth + 100 ||
              by > track.worldHeight + 100) {
            continue;
          }
          final w = 70 + rng.nextDouble() * 70;
          final d = 70 + rng.nextDouble() * 70;
          final h = 110 + rng.nextDouble() * 240;
          final facade = Color.lerp(
            const Color(0xFF1B2030),
            const Color(0xFF2B3348),
            rng.nextDouble(),
          )!;

          faces.addAll(box(
            vm.Vector3(bx - w / 2, 0, by - d / 2),
            vm.Vector3(bx + w / 2, h, by + d / 2),
            facade,
          ).faces);

          // Rooftop neon band on the face pointing at the track.
          final signColor = neon[rng.nextInt(neon.length)];
          final ox = bx - nx * side * (w / 2 + 0.6);
          final oy = by - ny * side * (d / 2 + 0.6);
          faces.add(Face([
            vm.Vector3(ox - ny * w * 0.4, h * 0.82, oy + nx * d * 0.4),
            vm.Vector3(ox - ny * w * 0.4, h * 0.90, oy + nx * d * 0.4),
            vm.Vector3(ox + ny * w * 0.4, h * 0.90, oy - nx * d * 0.4),
            vm.Vector3(ox + ny * w * 0.4, h * 0.82, oy - nx * d * 0.4),
          ], signColor));
        }

        // Street lamp on the outer edge.
        final lx = cx + nx * (half + 34);
        final ly = cy + ny * (half + 34);
        lamps.addAll(box(
          vm.Vector3(lx - 2, 0, ly - 2),
          vm.Vector3(lx + 2, 42, ly + 2),
          const Color(0xFF2A2F3A),
        ).faces);
        lamps.addAll(box(
          vm.Vector3(lx - 9, 40, ly - 3),
          vm.Vector3(lx + 9, 44, ly + 3),
          const Color(0xFFFFF59D),
        ).faces);
      }
    }
    _world.add(Mesh3D(faces));
    _world.add(Mesh3D(lamps));
  }

  void _buildApexMarkers() {
    for (final c in track.clippingPoints) {
      final faces = <Face>[];
      const segs = 14;
      for (var i = 0; i < segs; i++) {
        final a0 = i / segs * math.pi * 2;
        final a1 = (i + 1) / segs * math.pi * 2;
        faces.add(Face([
          vm.Vector3(c.x + math.cos(a0) * c.radius, 0.6, c.y + math.sin(a0) * c.radius),
          vm.Vector3(c.x + math.cos(a1) * c.radius, 0.6, c.y + math.sin(a1) * c.radius),
          vm.Vector3(c.x + math.cos(a1) * (c.radius - 10), 0.6,
              c.y + math.sin(a1) * (c.radius - 10)),
          vm.Vector3(c.x + math.cos(a0) * (c.radius - 10), 0.6,
              c.y + math.sin(a0) * (c.radius - 10)),
        ], const Color(0x3300E5FF)));
      }
      _apexMarkers.add(Mesh3D(faces));
    }
  }

  Mesh3D _buildCar() {
    final l = carLength;
    final w = carWidth;
    final half = l / 2;
    final hw = w / 2;
    final paint = car.bodyColor;
    final glass = const Color(0xFF141A24);
    final tyre = const Color(0xFF0C0D10);
    final rim = const Color(0xFFC6CBD2);
    final accent = car.accentColor;

    final faces = <Face>[];
    const y0 = 6.0;
    final yBelt = y0 + 16;
    final yRoof = y0 + 26;

    faces.add(Face([
      vm.Vector3(-hw, y0, -half),
      vm.Vector3(hw, y0, -half),
      vm.Vector3(hw, y0, half),
      vm.Vector3(-hw, y0, half),
    ], paint));
    faces.add(Face([
      vm.Vector3(-hw * 0.9, yBelt, half * 0.95),
      vm.Vector3(hw * 0.9, yBelt, half * 0.95),
      vm.Vector3(hw * 0.9, yBelt, -half * 0.95),
      vm.Vector3(-hw * 0.9, yBelt, -half * 0.95),
    ], paint));
    for (final s in <double>[-1, 1]) {
      faces.add(Face([
        vm.Vector3(s * hw, y0, s * half),
        vm.Vector3(s * hw, y0, -s * half),
        vm.Vector3(s * hw * 0.9, yBelt, -s * half * 0.95),
        vm.Vector3(s * hw * 0.9, yBelt, s * half * 0.95),
      ], paint));
    }
    // Nose and tail.
    faces.add(Face([
      vm.Vector3(-hw, y0, half),
      vm.Vector3(hw, y0, half),
      vm.Vector3(hw * 0.9, yBelt, half * 0.95),
      vm.Vector3(-hw * 0.9, yBelt, half * 0.95),
    ], accent));
    faces.add(Face([
      vm.Vector3(hw, y0, -half),
      vm.Vector3(-hw, y0, -half),
      vm.Vector3(-hw * 0.9, yBelt, -half * 0.95),
      vm.Vector3(hw * 0.9, yBelt, -half * 0.95),
    ], accent));

    // Greenhouse.
    final cabF = half * 0.34;
    final cabB = -half * 0.42;
    final roofHw = hw * 0.74;
    faces.add(Face([
      vm.Vector3(-hw * 0.86, yBelt, cabF),
      vm.Vector3(hw * 0.86, yBelt, cabF),
      vm.Vector3(roofHw, yRoof, half * 0.06),
      vm.Vector3(-roofHw, yRoof, half * 0.06),
    ], glass));
    faces.add(Face([
      vm.Vector3(hw * 0.86, yBelt, cabB),
      vm.Vector3(-hw * 0.86, yBelt, cabB),
      vm.Vector3(-roofHw, yRoof, -half * 0.24),
      vm.Vector3(roofHw, yRoof, -half * 0.24),
    ], glass));
    for (final s in <double>[-1, 1]) {
      faces.add(Face([
        vm.Vector3(s * hw * 0.86, yBelt, cabB),
        vm.Vector3(s * hw * 0.86, yBelt, cabF),
        vm.Vector3(s * roofHw, yRoof, half * 0.06),
        vm.Vector3(s * roofHw, yRoof, -half * 0.24),
      ], glass));
    }
    faces.add(Face([
      vm.Vector3(-roofHw, yRoof, half * 0.06),
      vm.Vector3(roofHw, yRoof, half * 0.06),
      vm.Vector3(roofHw, yRoof, -half * 0.24),
      vm.Vector3(-roofHw, yRoof, -half * 0.24),
    ], paint));

    // Lights.
    faces.add(Face([
      vm.Vector3(-hw * 0.8, y0 + 5, half + 0.6),
      vm.Vector3(-hw * 0.2, y0 + 5, half + 0.6),
      vm.Vector3(-hw * 0.2, y0 + 11, half + 0.6),
      vm.Vector3(-hw * 0.8, y0 + 11, half + 0.6),
    ], const Color(0xFFFFF6D0)));
    faces.add(Face([
      vm.Vector3(hw * 0.2, y0 + 5, half + 0.6),
      vm.Vector3(hw * 0.8, y0 + 5, half + 0.6),
      vm.Vector3(hw * 0.8, y0 + 11, half + 0.6),
      vm.Vector3(hw * 0.2, y0 + 11, half + 0.6),
    ], const Color(0xFFFFF6D0)));
    for (final s in <double>[-1, 1]) {
      faces.add(Face([
        vm.Vector3(s * hw * 0.85, y0 + 6, -half - 0.6),
        vm.Vector3(s * hw * 0.35, y0 + 6, -half - 0.6),
        vm.Vector3(s * hw * 0.35, y0 + 12, -half - 0.6),
        vm.Vector3(s * hw * 0.85, y0 + 12, -half - 0.6),
      ], const Color(0xFFFF2A3D)));
    }

    // Wheels.
    for (final sx in <double>[-1, 1]) {
      for (final sz in <double>[-1, 1]) {
        final cx = sx * hw;
        final cz = sz * half * 0.62;
        faces.addAll(box(
          vm.Vector3(cx - 4, 0, cz - 10),
          vm.Vector3(cx + 4, 18, cz + 10),
          tyre,
        ).faces);
        faces.addAll(box(
          vm.Vector3(cx + sx * 3.5, 4, cz - 6),
          vm.Vector3(cx + sx * 5, 14, cz + 6),
          rim,
        ).faces);
      }
    }
    return Mesh3D(faces);
  }

  // ------------------------------------------------------------- physics
  void setControls({
    required double steerInput,
    required double throttleInput,
    required double brakeAmount,
    required bool nos,
  }) {
    _steerInput = steerInput.clamp(-1.0, 1.0).toDouble();
    throttle = throttleInput;
    brakeInput = brakeAmount;
    nosActive = nos;
  }

  void update(double dt) {
    if (isOver) return;
    dt = dt.clamp(0.0, 0.05).toDouble();

    if (timeLeft != null) {
      timeLeft = timeLeft! - dt;
      if (timeLeft! <= 0) {
        timeLeft = 0;
        isOver = true;
        _finalise();
        return;
      }
    }

    // Steering eases toward the requested angle. An exponential decay keeps
    // the feel identical at 30 and 60 FPS.
    final maxSteer = 0.58 * car.handling;
    final steerTarget = _steerInput * maxSteer;
    steer += (steerTarget - steer) * (1 - math.exp(-14 * dt));

    final cosA = math.cos(angle);
    final sinA = math.sin(angle);

    var vLong = vel.x * cosA + vel.y * sinA;
    var vLat = -vel.x * sinA + vel.y * cosA;

    // Longitudinal forces.
    final engine = car.acceleration;
    vLong += throttle * engine * dt;
    vLong -= brakeInput * 450 * dt;
    vLong -= vLong * 0.85 * dt;
    vLong -= 0.0012 * vLong * vLong.abs() * dt;

    // NOS.
    if (nosActive && nosAmount > 0) {
      vLong += car.acceleration * 1.6 * dt;
      nosAmount = (nosAmount - dt / car.nitroDurationSec).clamp(0.0, 1.0).toDouble();
    } else {
      nosAmount = (nosAmount + dt * 0.08).clamp(0.0, 1.0).toDouble();
    }

    final top = car.topSpeed * (nosActive ? 1.15 : 1.0);
    if (vLong > top) vLong = top;
    if (vLong < -top * 0.3) vLong = -top * 0.3;

    // Lateral grip: sideways speed bleeds off, but slowly enough to slide.
    final grip = 5.5 * car.gripBalance * (1.0 - 0.10 * car.driftFactor);
    vLat -= vLat * grip * dt;

    speed = math.sqrt(vLong * vLong + vLat * vLat);

    // Recompose the world velocity using the heading the components were
    // measured against. Rotating them by the new angle would drag the velocity
    // round with the nose and make the car pivot on the spot.
    final c2 = math.cos(angle);
    final s2 = math.sin(angle);
    vel = vm.Vector2(vLong * c2 - vLat * s2, vLong * s2 + vLat * c2);

    // Yaw from a bicycle model: the steering angle gives the geometric turn
    // rate, and the tyre grip budget caps it. That cap is what stops a car at
    // speed from pirouetting the way an unbounded yaw rate did.
    // Nothing rotates unless the car is genuinely rolling forwards. This is what
    // stops a parked car from pirouetting on the spot.
    final angleBefore = angle;
    if (vLong > _minRollSpeed) {
      final yawGeom = vLong * math.tan(steer) / _wheelBase;
      final yawMax = _maxLateralAccel / vLong;
      final yawNow = yawGeom.clamp(-yawMax, yawMax).toDouble();
      angle += yawNow * dt;

      // Self-aligning torque: the nose eases back toward the direction of
      // travel, so a slide can always be caught instead of spinning forever.
      final travel = math.atan2(vel.y, vel.x);
      var diff = travel - angle;
      diff = (diff + math.pi) % (2 * math.pi) - math.pi;
      angle += (diff * 1.0).clamp(-0.9, 0.9).toDouble() * dt;
    }

    // Hard ceiling on how far the car can rotate in one step. Whatever the
    // model computes, the body can never whip round: at 1.2 rad/s a full turn
    // takes 5.2 seconds.
    final delta = angle - angleBefore;
    final limit = _maxYawRate * dt;
    if (delta.abs() > limit) {
      angle = angleBefore + (delta < 0 ? -limit : limit);
    }
    yawRate = dt > 0 ? (angle - angleBefore) / dt : 0;
    if (yawRate.abs() > maxYawSeen.abs()) maxYawSeen = yawRate;

    pos += vel * dt;

    _keepOnRoad();
    _updateScoring(dt);
    _updateSmoke(dt);
    _updateCamera();
  }

  /// Keeps the car inside the road corridor and bleeds off the speed that
  /// pushed it into the barrier.
  void _keepOnRoad() {
    final loop = track.loop;
    var best = double.infinity;
    var bestX = 0.0;
    var bestY = 0.0;

    for (var i = 0; i < loop.length; i++) {
      final a = loop[i];
      final b = loop[(i + 1) % loop.length];
      final dx = b.x - a.x;
      final dy = b.y - a.y;
      final len2 = dx * dx + dy * dy;
      if (len2 < 1e-6) continue;
      var t = ((pos.x - a.x) * dx + (pos.y - a.y) * dy) / len2;
      t = t.clamp(0.0, 1.0).toDouble();
      final px = a.x + dx * t;
      final py = a.y + dy * t;
      final d = (pos.x - px) * (pos.x - px) + (pos.y - py) * (pos.y - py);
      if (d < best) {
        best = d;
        bestX = px;
        bestY = py;
      }
    }

    final dist = math.sqrt(best);
    final limit = track.roadWidth / 2 - carRadius;
    if (dist > limit) {
      final nx = (pos.x - bestX) / (dist == 0 ? 1 : dist);
      final ny = (pos.y - bestY) / (dist == 0 ? 1 : dist);
      pos.x = bestX + nx * limit;
      pos.y = bestY + ny * limit;
      // Slide along the barrier instead of bouncing back.
      final vn = vel.x * nx + vel.y * ny;
      if (vn > 0) {
        vel.x -= vn * nx;
        vel.y -= vn * ny;
      }
      vel *= 0.86;
    }
  }

  void _updateScoring(double dt) {
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    final vLat = -vel.x * sinA + vel.y * cosA;
    final vLong = vel.x * cosA + vel.y * sinA;
    driftAngle = vLong.abs() < 1 ? 0 : math.atan2(vLat.abs(), vLong.abs()).abs();

    final drifting = speed > _minDriftSpeed && driftAngle > _driftThresholdAngle;

    if (drifting) {
      combo += speed * driftAngle * dt * 0.55 * car.driftFactor;
      comboTimer = 1.6;
      multiplier = (1 + combo ~/ 450).clamp(1, 20).toInt();
      score += (speed * driftAngle * dt * 2.2).round();
    } else {
      comboTimer -= dt;
      if (comboTimer <= 0 && combo > 0) {
        combo = 0;
        multiplier = 1;
      }
    }

    // Clipping apexes.
    for (final c in track.clippingPoints) {
      final dx = pos.x - c.x;
      final dy = pos.y - c.y;
      if (dx * dx + dy * dy < c.radius * c.radius) {
        if (lastApex != c.id) {
          lastApex = c.id;
          apexFlash = 1.4;
          score += 250 * multiplier;
        }
      }
    }
    if (apexFlash > 0) apexFlash -= dt;

    // Laps / checkpoints.
    if (_checkpoints.length > 1) {
      final cp = _checkpoints[_nextCheckpoint % _checkpoints.length];
      final dx = pos.x - cp.x;
      final dy = pos.y - cp.y;
      if (dx * dx + dy * dy < 260 * 260) {
        _nextCheckpoint++;
        if (_nextCheckpoint % _checkpoints.length == 1) laps++;
        if (mode.targetLaps > 0 && laps >= mode.targetLaps) {
          isOver = true;
          _finalise();
        }
      }
    }
  }

  void _finalise() {
    if (mode.targetLaps > 0 && timeLeft != null) {
      // Every 1,000 drift points takes a second off the lap time.
      timeLeft = timeLeft! + (score ~/ 1000).toDouble();
    }
  }

  void _updateSmoke(double dt) {
    final drifting = driftAngle > _driftThresholdAngle && speed > _minDriftSpeed;
    if (drifting) {
      _smokeTimer -= dt;
      if (_smokeTimer <= 0) {
        _smokeTimer = 0.03;
        final cosA = math.cos(angle);
        final sinA = math.sin(angle);
        for (final s in <double>[-1, 1]) {
          final bx = pos.x - cosA * carLength * 0.42 + (-sinA) * s * carWidth * 0.5;
          final by = pos.y - sinA * carLength * 0.42 + cosA * s * carWidth * 0.5;
          _smoke.add(_Smoke(
            vm.Vector3(bx, 6, by),
            8 + math.Random().nextDouble() * 8,
            car.smokeColor,
          ));
        }
      }
    }
    for (final p in _smoke) {
      p.age += dt;
      p.p.y += dt * 14;
      p.size += dt * 26;
    }
    _smoke.removeWhere((p) => p.age > p.life);
    if (_smoke.length > 160) _smoke.removeRange(0, _smoke.length - 160);
    _wheelSpin += speed * dt * 0.05;
  }

  void _updateCamera() {
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    final speedT = (speed / car.topSpeed).clamp(0.0, 1.0).toDouble();

    switch (cameraMode) {
      case CameraMode.chase:
        final back = 150.0 + speedT * 30;
        camera.position = vm.Vector3(
          pos.x - cosA * back,
          62 + speedT * 8,
          pos.y - sinA * back,
        );
        camera.target = vm.Vector3(pos.x + cosA * 60, 20, pos.y + sinA * 60);
        camera.fov = 62 * math.pi / 180;
        break;
      case CameraMode.hood:
        camera.position = vm.Vector3(
          pos.x + cosA * 6,
          34,
          pos.y + sinA * 6,
        );
        camera.target = vm.Vector3(pos.x + cosA * 260, 26, pos.y + sinA * 260);
        camera.fov = 70 * math.pi / 180;
        break;
      case CameraMode.topDown:
        camera.position = vm.Vector3(pos.x, 460, pos.y - 1);
        camera.target = vm.Vector3(pos.x, 0, pos.y);
        camera.fov = 55 * math.pi / 180;
        break;
      case CameraMode.bumper:
        camera.position = vm.Vector3(
          pos.x + cosA * (carLength * 0.52),
          16,
          pos.y + sinA * (carLength * 0.52),
        );
        camera.target = vm.Vector3(pos.x + cosA * 300, 12, pos.y + sinA * 300);
        camera.fov = 78 * math.pi / 180;
        break;
      case CameraMode.driftAction:
        camera.position = vm.Vector3(
          pos.x - cosA * 110 - sinA * 120,
          70,
          pos.y - sinA * 110 + cosA * 120,
        );
        camera.target = vm.Vector3(pos.x, 20, pos.y);
        camera.fov = 58 * math.pi / 180;
        break;
    }
  }

  CameraMode cameraMode = CameraMode.chase;

  // -------------------------------------------------------------- render
  void render(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF080A12), Color(0xFF1A1030), Color(0xFF05060A)],
        ).createShader(rect),
    );

    final aspect = size.height <= 0 ? 1.0 : size.width / size.height;
    camera.update(aspect);

    renderFlat(canvas, size, camera, _ground);
    renderMeshes(canvas, size, camera, _world, cullRadius: 1600);

    for (final m in _apexMarkers) {
      renderMeshes(canvas, size, camera, <Mesh3D>[m], cullRadius: 900);
    }

    _drawSmoke(canvas, size);

    renderMeshes(
      canvas,
      size,
      camera,
      <Mesh3D>[_carMesh.placed(vm.Vector3(pos.x, 0, pos.y), math.pi / 2 - angle)],
      cullRadius: 3000,
    );
  }

  void _drawSmoke(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in _smoke) {
      final c = camera.vp.transform(vm.Vector4(p.p.x, p.p.y, p.p.z, 1.0));
      if (c.w <= 1) continue;
      final sx = ((c.x / c.w) * 0.5 + 0.5) * size.width;
      final sy = (1.0 - ((c.y / c.w) * 0.5 + 0.5)) * size.height;
      final t = (p.age / p.life).clamp(0.0, 1.0).toDouble();
      final r = (p.size * 40 / c.w) * (0.6 + t);
      paint.color = p.color.withValues(alpha: (0.55 * (1 - t)).clamp(0.0, 1.0).toDouble());
      canvas.drawCircle(Offset(sx, sy), r.clamp(1.0, 90.0).toDouble(), paint);
    }
  }
}
