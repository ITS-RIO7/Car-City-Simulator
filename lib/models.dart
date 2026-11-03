import 'package:flutter/material.dart';

/// A point on a track. Named [TP] so the generated track data stays readable.
class TP {
  final double x;
  final double y;
  const TP(this.x, this.y);
}

/// A scored apex on the circuit.
class ClippingPoint {
  final String id;
  final double x;
  final double y;
  final double radius;
  final String name;

  const ClippingPoint(this.id, this.x, this.y, this.radius, this.name);
}

/// One circuit: centre line, the two road edges and its apex points.
///
/// Copied from the Kotlin original, including the "closing point" convention
/// where the first and last centre-line point are the same.
class Track {
  final String id;
  final String name;
  final String location;
  final String difficulty;
  final String description;
  final double roadWidth;
  final double startX;
  final double startY;
  final double startAngleDeg;
  final double worldWidth;
  final double worldHeight;
  final List<TP> center;
  final List<TP> inner;
  final List<TP> outer;
  final List<ClippingPoint> clippingPoints;

  const Track({
    required this.id,
    required this.name,
    required this.location,
    required this.difficulty,
    required this.description,
    required this.roadWidth,
    required this.startX,
    required this.startY,
    required this.startAngleDeg,
    required this.worldWidth,
    required this.worldHeight,
    required this.center,
    required this.inner,
    required this.outer,
    required this.clippingPoints,
  });

  /// Centre line with the duplicated closing point removed.
  List<TP> get loop {
    if (center.length > 2) {
      final a = center.first;
      final b = center.last;
      if ((a.x - b.x).abs() < 0.01 && (a.y - b.y).abs() < 0.01) {
        return center.sublist(0, center.length - 1);
      }
    }
    return center;
  }
}

/// The three ways to play, same titles and rules text as the Kotlin build.
enum GameMode { driftAttack, tandemCircuit, freestyle }

extension GameModeX on GameMode {
  String get title => switch (this) {
        GameMode.driftAttack => 'Drift Attack',
        GameMode.tandemCircuit => 'Tandem Circuit',
        GameMode.freestyle => 'Freestyle Practice',
      };

  String get subtitle => switch (this) {
        GameMode.driftAttack => '90s Score Rush',
        GameMode.tandemCircuit => '2 Fast Laps',
        GameMode.freestyle => 'Endless Slide',
      };

  String get description => switch (this) {
        GameMode.driftAttack =>
          'Chamber maximum angle, build huge combo multipliers, and hit clipping apexes before the clock runs out!',
        GameMode.tandemCircuit =>
          'Complete 2 high-octane laps as fast as possible. Every 1,000 drift points subtracts 1 second from your total time!',
        GameMode.freestyle =>
          'Infinite time with instant NOS refills to master counter-steering, weight transfer, and donut entries.',
      };

  /// Seconds on the clock, or null for an endless run.
  double? get timeLimitSec => switch (this) {
        GameMode.driftAttack => 90,
        GameMode.tandemCircuit => 180,
        GameMode.freestyle => null,
      };

  int get targetLaps => this == GameMode.tandemCircuit ? 2 : 0;
}

enum CameraMode { chase, hood, topDown, bumper, driftAction }

extension CameraModeX on CameraMode {
  String get title => switch (this) {
        CameraMode.chase => 'CHASE',
        CameraMode.hood => 'HOOD',
        CameraMode.topDown => 'DRONE',
        CameraMode.bumper => 'BUMPER',
        CameraMode.driftAction => 'ACTION',
      };

  String get subtitle => switch (this) {
        CameraMode.chase => 'DYNAMIC CAM',
        CameraMode.hood => 'COCKPIT CAM',
        CameraMode.topDown => 'AERIAL CAM',
        CameraMode.bumper => 'SPEED CAM',
        CameraMode.driftAction => 'DRIFT CAM',
      };

  CameraMode get next =>
      CameraMode.values[(index + 1) % CameraMode.values.length];
}

/// Upgrade levels bought in the garage.
class CarUpgrades {
  final int engine;
  final int driftKit;
  final int tire;
  final int nitro;

  const CarUpgrades({
    this.engine = 0,
    this.driftKit = 0,
    this.tire = 0,
    this.nitro = 0,
  });

  CarUpgrades copyWith({int? engine, int? driftKit, int? tire, int? nitro}) =>
      CarUpgrades(
        engine: engine ?? this.engine,
        driftKit: driftKit ?? this.driftKit,
        tire: tire ?? this.tire,
        nitro: nitro ?? this.nitro,
      );

  Map<String, dynamic> toJson() =>
      {'engine': engine, 'driftKit': driftKit, 'tire': tire, 'nitro': nitro};

  static CarUpgrades fromJson(Map<String, dynamic> j) => CarUpgrades(
        engine: (j['engine'] as num?)?.toInt() ?? 0,
        driftKit: (j['driftKit'] as num?)?.toInt() ?? 0,
        tire: (j['tire'] as num?)?.toInt() ?? 0,
        nitro: (j['nitro'] as num?)?.toInt() ?? 0,
      );
}

/// A car, with the same tuning maths as the Kotlin model.
class CarModel {
  final String id;
  final String name;
  final String series;
  final String description;
  final int basePrice;
  final Color bodyColor;
  final Color accentColor;
  final double baseTopSpeed;
  final double baseAcceleration;
  final double baseHandling;
  final double baseDriftFactor;
  final Color smokeColor;
  final Color underglowColor;
  final CarUpgrades upgrades;

  const CarModel({
    required this.id,
    required this.name,
    required this.series,
    required this.description,
    required this.basePrice,
    required this.bodyColor,
    required this.accentColor,
    required this.baseTopSpeed,
    required this.baseAcceleration,
    required this.baseHandling,
    required this.baseDriftFactor,
    required this.smokeColor,
    required this.underglowColor,
    this.upgrades = const CarUpgrades(),
  });

  double get topSpeed => baseTopSpeed * (1 + upgrades.engine * 0.08);
  double get acceleration => baseAcceleration * (1 + upgrades.engine * 0.10);
  double get handling => baseHandling * (1 + upgrades.driftKit * 0.08);
  double get driftFactor => baseDriftFactor * (1 + upgrades.driftKit * 0.12);
  double get gripBalance => 1 + upgrades.tire * 0.07;
  double get nitroDurationSec => 3.5 + upgrades.nitro * 1.0;

  CarModel withUpgrades(CarUpgrades u) => CarModel(
        id: id,
        name: name,
        series: series,
        description: description,
        basePrice: basePrice,
        bodyColor: bodyColor,
        accentColor: accentColor,
        baseTopSpeed: baseTopSpeed,
        baseAcceleration: baseAcceleration,
        baseHandling: baseHandling,
        baseDriftFactor: baseDriftFactor,
        smokeColor: smokeColor,
        underglowColor: underglowColor,
        upgrades: u,
      );

  static const List<CarModel> defaults = <CarModel>[
    CarModel(
      id: 'car_rod42',
      name: 'Aeroblade ROD #42',
      series: 'Rod City Hyper-Spec',
      description:
          'Flagship twin-turbo hyperdrift coupe with dual-tone sunset orange and cyan livery, sponsor decals and championship tuning.',
      basePrice: 0,
      bodyColor: Color(0xFFFF6D00),
      accentColor: Color(0xFF00B0FF),
      baseTopSpeed: 500,
      baseAcceleration: 440,
      baseHandling: 1.28,
      baseDriftFactor: 1.38,
      smokeColor: Color(0xFFE0F7FA),
      underglowColor: Color(0xFF00E5FF),
    ),
    CarModel(
      id: 'car_86',
      name: 'Hachi-86 FR',
      series: 'Touge Icon',
      description:
          'Lightweight rear-wheel-drive legend. Exceptional balance and forgiving drift transitions.',
      basePrice: 1200,
      bodyColor: Color(0xFFECEFF1),
      accentColor: Color(0xFF212121),
      baseTopSpeed: 390,
      baseAcceleration: 330,
      baseHandling: 1.05,
      baseDriftFactor: 1.05,
      smokeColor: Color(0xFF00F5FF),
      underglowColor: Color(0xFF00F5FF),
    ),
    CarModel(
      id: 'car_s15',
      name: 'Silvia S-Apex',
      series: 'D1 Spec',
      description:
          'Aggressive turbo coupe built for long, wide-angle high-speed slides and quick snap-backs.',
      basePrice: 3000,
      bodyColor: Color(0xFF00F5FF),
      accentColor: Color(0xFFFF6D00),
      baseTopSpeed: 450,
      baseAcceleration: 380,
      baseHandling: 1.18,
      baseDriftFactor: 1.25,
      smokeColor: Color(0xFFFF007F),
      underglowColor: Color(0xFFFF6D00),
    ),
    CarModel(
      id: 'car_rx7',
      name: 'Rotary RX-Spirit',
      series: 'Midnight Club',
      description:
          'High-revving twin turbo rotary powerhouse. Phenomenal mid-slide throttle control.',
      basePrice: 7500,
      bodyColor: Color(0xFFFFD600),
      accentColor: Color(0xFFFF1744),
      baseTopSpeed: 490,
      baseAcceleration: 420,
      baseHandling: 1.28,
      baseDriftFactor: 1.38,
      smokeColor: Color(0xFFFFD600),
      underglowColor: Color(0xFFFF1744),
    ),
    CarModel(
      id: 'car_gtr',
      name: 'Godzilla GT-R34',
      series: 'Track Dominator',
      description:
          'Unstoppable straightaway acceleration with massive momentum for high-speed wall scrapes.',
      basePrice: 14000,
      bodyColor: Color(0xFF1E88E5),
      accentColor: Color(0xFF00E676),
      baseTopSpeed: 540,
      baseAcceleration: 470,
      baseHandling: 1.15,
      baseDriftFactor: 1.30,
      smokeColor: Color(0xFF00E676),
      underglowColor: Color(0xFF1E88E5),
    ),
    CarModel(
      id: 'car_cyber',
      name: 'Viper 2077 Hyperdrift',
      series: 'Prototype X',
      description:
          'Futuristic electric drift hypercar featuring active torque-vectoring and instant NOS refill.',
      basePrice: 25000,
      bodyColor: Color(0xFFA855F7),
      accentColor: Color(0xFFFF007F),
      baseTopSpeed: 600,
      baseAcceleration: 540,
      baseHandling: 1.45,
      baseDriftFactor: 1.55,
      smokeColor: Color(0xFFFF1493),
      underglowColor: Color(0xFFFF007F),
    ),
  ];
}

/// One finished run, kept for the records screen.
class RunRecord {
  final GameMode mode;
  final String trackId;
  final int score;
  final int laps;
  final double seconds;
  final DateTime at;

  const RunRecord({
    required this.mode,
    required this.trackId,
    required this.score,
    required this.laps,
    required this.seconds,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'trackId': trackId,
        'score': score,
        'laps': laps,
        'seconds': seconds,
        'at': at.toIso8601String(),
      };

  static RunRecord fromJson(Map<String, dynamic> j) => RunRecord(
        mode: GameMode.values.firstWhere(
          (m) => m.name == j['mode'],
          orElse: () => GameMode.driftAttack,
        ),
        trackId: (j['trackId'] as String?) ?? 'track_rod_city',
        score: (j['score'] as num?)?.toInt() ?? 0,
        laps: (j['laps'] as num?)?.toInt() ?? 0,
        seconds: (j['seconds'] as num?)?.toDouble() ?? 0,
        at: DateTime.tryParse((j['at'] as String?) ?? '') ?? DateTime.now(),
      );
}
