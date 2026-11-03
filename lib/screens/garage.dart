import 'package:flutter/material.dart';

import '../models.dart';
import '../services/storage.dart';
import 'widgets.dart';

/// Buy cars and spend coins on engine / drift kit / tyre / nitro upgrades.
class GarageScreen extends StatefulWidget {
  final AppState state;

  const GarageScreen({super.key, required this.state});

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final cars = CarModel.defaults;
    return Scaffold(
      body: NeonBackground(
        accent: const Color(0xFFFF6D00),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: widget.state,
            builder: (context, _) {
              final car = cars[_index];
              final tuned = car.withUpgrades(widget.state.upgradesFor(car.id));
              final owned = widget.state.isUnlocked(car.id);
              final selected = widget.state.selectedCarId == car.id;

              return Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const NeonBack(),
                      const Text(
                        'GARAGE',
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
                        child: CoinBadge(coins: widget.state.coins),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: <Widget>[
                              Expanded(
                                child: Center(
                                  child: AspectRatio(
                                    aspectRatio: 1.7,
                                    child: CustomPaint(
                                      painter: _BigCar(tuned),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 86,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: cars.length,
                                  itemBuilder: (context, i) {
                                    final c = cars[i];
                                    final isSel = i == _index;
                                    return GestureDetector(
                                      onTap: () => setState(() => _index = i),
                                      child: Container(
                                        width: 130,
                                        margin:
                                            const EdgeInsets.only(right: 10),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          color: Colors.white
                                              .withValues(alpha: isSel ? 0.10 : 0.03),
                                          border: Border.all(
                                            color: isSel
                                                ? const Color(0xFFFF6D00)
                                                : Colors.white
                                                    .withValues(alpha: 0.10),
                                            width: isSel ? 1.6 : 1,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: <Widget>[
                                            Text(
                                              c.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              widget.state.isUnlocked(c.id)
                                                  ? c.series
                                                  : '${c.basePrice} coins',
                                              style: TextStyle(
                                                color: widget.state
                                                        .isUnlocked(c.id)
                                                    ? Colors.white
                                                        .withValues(alpha: 0.4)
                                                    : const Color(0xFFFFD54F),
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(8, 0, 24, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  tuned.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                Text(
                                  tuned.series.toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFFFF6D00),
                                    fontSize: 11,
                                    letterSpacing: 2.2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  tuned.description,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    fontSize: 12,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _stat('TOP SPEED', tuned.topSpeed / 6, '${tuned.topSpeed.round()}'),
                                _stat('ACCELERATION', tuned.acceleration / 6,
                                    '${tuned.acceleration.round()}'),
                                _stat('HANDLING', tuned.handling / 1.6, tuned.handling.toStringAsFixed(2)),
                                _stat('DRIFT', tuned.driftFactor / 1.7, tuned.driftFactor.toStringAsFixed(2)),
                                const SizedBox(height: 18),
                                if (!owned)
                                  NeonButton(
                                    label: 'BUY  ${car.basePrice}',
                                    icon: Icons.shopping_cart,
                                    color: const Color(0xFFFFD54F),
                                    height: 52,
                                    onTap: widget.state.coins >= car.basePrice
                                        ? () {
                                            widget.state.buyCar(car);
                                            setState(() {});
                                          }
                                        : null,
                                  )
                                else if (!selected)
                                  NeonButton(
                                    label: 'SELECT',
                                    icon: Icons.check_circle,
                                    color: const Color(0xFF00E5FF),
                                    height: 52,
                                    onTap: () {
                                      widget.state.selectCar(car.id);
                                      setState(() {});
                                    },
                                  )
                                else
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      'SELECTED',
                                      style: TextStyle(
                                        color: Color(0xFF00E5FF),
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 2.4,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                const Text(
                                  'UPGRADES',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                    letterSpacing: 2.2,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _upgradeRow('ENGINE', 'engine', tuned, owned),
                                _upgradeRow('DRIFT KIT', 'driftKit', tuned, owned),
                                _upgradeRow('TYRES', 'tire', tuned, owned),
                                _upgradeRow('NITRO', 'nitro', tuned, owned),
                              ],
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

  Widget _stat(String label, double fraction, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.05, 1.0).toDouble(),
                minHeight: 7,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFFF6D00),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _upgradeRow(String label, String kind, CarModel car, bool owned) {
    final u = widget.state.upgradesFor(car.id);
    final level = switch (kind) {
      'engine' => u.engine,
      'driftKit' => u.driftKit,
      'tire' => u.tire,
      _ => u.nitro,
    };
    final cost = widget.state.upgradeCost(car.id, kind);
    final canBuy = owned && widget.state.coins >= cost && level < 10;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '$label  •  LV $level',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          TextButton(
            onPressed: canBuy
                ? () {
                    widget.state.buyUpgrade(car.id, kind);
                    setState(() {});
                  }
                : null,
            child: Text(
              level >= 10 ? 'MAX' : '$cost',
              style: TextStyle(
                color: canBuy ? const Color(0xFFFFD54F) : Colors.white24,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Larger side-on car drawing for the garage stage.
class _BigCar extends CustomPainter {
  final CarModel car;

  _BigCar(this.car);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawOval(
      Rect.fromLTWH(w * 0.10, h * 0.80, w * 0.80, h * 0.16),
      Paint()
        ..color = car.underglowColor.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );

    final shadow = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.50, w * 0.84, h * 0.30),
      Radius.circular(h * 0.12),
    );
    canvas.drawRRect(
      shadow.shift(Offset(0, h * 0.06)),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    final body = Path()
      ..moveTo(w * 0.08, h * 0.72)
      ..lineTo(w * 0.12, h * 0.50)
      ..lineTo(w * 0.30, h * 0.46)
      ..lineTo(w * 0.38, h * 0.30)
      ..lineTo(w * 0.66, h * 0.30)
      ..lineTo(w * 0.76, h * 0.46)
      ..lineTo(w * 0.92, h * 0.52)
      ..lineTo(w * 0.94, h * 0.72)
      ..close();
    canvas.drawPath(body, Paint()..color = car.bodyColor);

    final glass = Path()
      ..moveTo(w * 0.40, h * 0.34)
      ..lineTo(w * 0.64, h * 0.34)
      ..lineTo(w * 0.71, h * 0.46)
      ..lineTo(w * 0.34, h * 0.46)
      ..close();
    canvas.drawPath(glass, Paint()..color = const Color(0xFF0E1520));

    canvas.drawRect(
      Rect.fromLTWH(w * 0.12, h * 0.60, w * 0.82, h * 0.05),
      Paint()..color = car.accentColor.withValues(alpha: 0.9),
    );

    for (final dx in <double>[0.26, 0.76]) {
      canvas.drawCircle(
        Offset(w * dx, h * 0.76),
        h * 0.13,
        Paint()..color = const Color(0xFF0C0D10),
      );
      canvas.drawCircle(
        Offset(w * dx, h * 0.76),
        h * 0.06,
        Paint()..color = const Color(0xFFC6CBD2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BigCar old) => old.car.id != car.id;
}
