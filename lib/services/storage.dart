import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

/// All persistent player progress: coins, unlocks, upgrades, records and
/// settings. Mirrors the Kotlin GameStorage, but stored as one JSON blob so a
/// single key holds a consistent snapshot.
class AppState extends ChangeNotifier {
  static const _key = 'drift_horizon_state_v1';

  int coins = 1500;
  final Set<String> unlockedCars = <String>{'car_rod42', 'car_86'};
  String selectedCarId = 'car_rod42';
  final Map<String, CarUpgrades> upgrades = <String, CarUpgrades>{};
  final List<RunRecord> records = <RunRecord>[];

  CameraMode cameraMode = CameraMode.chase;
  double steeringSensitivity = 1.0;
  bool leftHanded = false;
  bool sfxEnabled = true;

  bool loaded = false;

  CarModel get selectedCar {
    final base = CarModel.defaults.firstWhere(
      (c) => c.id == selectedCarId,
      orElse: () => CarModel.defaults.first,
    );
    return base.withUpgrades(upgrades[base.id] ?? const CarUpgrades());
  }

  CarUpgrades upgradesFor(String id) => upgrades[id] ?? const CarUpgrades();

  bool isUnlocked(String id) => unlockedCars.contains(id);

  /// Best score for a mode/track pair, or 0.
  int bestScore(GameMode mode, String trackId) {
    var best = 0;
    for (final r in records) {
      if (r.mode == mode && r.trackId == trackId && r.score > best) {
        best = r.score;
      }
    }
    return best;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        coins = (j['coins'] as num?)?.toInt() ?? coins;
        selectedCarId = (j['selectedCarId'] as String?) ?? selectedCarId;
        final unlocked = (j['unlockedCars'] as List?)?.cast<String>();
        if (unlocked != null && unlocked.isNotEmpty) {
          unlockedCars
            ..clear()
            ..addAll(unlocked);
        }
        final ups = (j['upgrades'] as Map?)?.cast<String, dynamic>();
        if (ups != null) {
          upgrades.clear();
          ups.forEach((k, v) {
            upgrades[k] = CarUpgrades.fromJson((v as Map).cast<String, dynamic>());
          });
        }
        final recs = (j['records'] as List?) ?? const [];
        records
          ..clear()
          ..addAll(recs.map((e) => RunRecord.fromJson((e as Map).cast<String, dynamic>())));
        cameraMode = CameraMode.values.firstWhere(
          (m) => m.name == j['cameraMode'],
          orElse: () => cameraMode,
        );
        steeringSensitivity =
            (j['steeringSensitivity'] as num?)?.toDouble() ?? steeringSensitivity;
        leftHanded = (j['leftHanded'] as bool?) ?? leftHanded;
        sfxEnabled = (j['sfxEnabled'] as bool?) ?? sfxEnabled;
      }
    } catch (_) {
      // A corrupt blob should never block the game; defaults are fine.
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final j = <String, dynamic>{
      'coins': coins,
      'selectedCarId': selectedCarId,
      'unlockedCars': unlockedCars.toList(),
      'upgrades': upgrades.map((k, v) => MapEntry(k, v.toJson())),
      'records': records.map((r) => r.toJson()).toList(),
      'cameraMode': cameraMode.name,
      'steeringSensitivity': steeringSensitivity,
      'leftHanded': leftHanded,
      'sfxEnabled': sfxEnabled,
    };
    await prefs.setString(_key, jsonEncode(j));
  }

  bool buyCar(CarModel car) {
    if (unlockedCars.contains(car.id)) return true;
    if (coins < car.basePrice) return false;
    coins -= car.basePrice;
    unlockedCars.add(car.id);
    notifyListeners();
    save();
    return true;
  }

  void selectCar(String id) {
    if (!unlockedCars.contains(id)) return;
    selectedCarId = id;
    notifyListeners();
    save();
  }

  /// Upgrade costs climb with each level already bought.
  int upgradeCost(String carId, String kind) {
    final u = upgradesFor(carId);
    final level = switch (kind) {
      'engine' => u.engine,
      'driftKit' => u.driftKit,
      'tire' => u.tire,
      _ => u.nitro,
    };
    return 400 + level * 450;
  }

  bool buyUpgrade(String carId, String kind) {
    final cost = upgradeCost(carId, kind);
    if (coins < cost) return false;
    final u = upgradesFor(carId);
    coins -= cost;
    upgrades[carId] = switch (kind) {
      'engine' => u.copyWith(engine: u.engine + 1),
      'driftKit' => u.copyWith(driftKit: u.driftKit + 1),
      'tire' => u.copyWith(tire: u.tire + 1),
      _ => u.copyWith(nitro: u.nitro + 1),
    };
    notifyListeners();
    save();
    return true;
  }

  void addCoins(int amount) {
    coins += amount;
    notifyListeners();
    save();
  }

  void addRecord(RunRecord record) {
    records.insert(0, record);
    if (records.length > 60) records.removeRange(60, records.length);
    notifyListeners();
    save();
  }

  void setCameraMode(CameraMode mode) {
    cameraMode = mode;
    notifyListeners();
    save();
  }

  void setSensitivity(double v) {
    steeringSensitivity = v;
    notifyListeners();
    save();
  }

  void setLeftHanded(bool v) {
    leftHanded = v;
    notifyListeners();
    save();
  }

  void setSfx(bool v) {
    sfxEnabled = v;
    notifyListeners();
    save();
  }
}
