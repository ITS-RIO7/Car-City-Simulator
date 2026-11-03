import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/menu.dart';
import 'services/storage.dart';

/// Drift Horizon — a Flutter port of the Kotlin/Compose original.
///
/// The game is landscape-only, like the Android build it replaces.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const DriftHorizonApp());
}

class DriftHorizonApp extends StatefulWidget {
  const DriftHorizonApp({super.key});

  @override
  State<DriftHorizonApp> createState() => _DriftHorizonAppState();
}

class _DriftHorizonAppState extends State<DriftHorizonApp> {
  final AppState _state = AppState();

  @override
  void initState() {
    super.initState();
    _state.load();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drift Horizon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF00E5FF),
        scaffoldBackgroundColor: const Color(0xFF05060A),
        fontFamily: 'Roboto',
      ),
      home: AnimatedBuilder(
        animation: _state,
        builder: (context, _) {
          if (!_state.loaded) {
            return const Scaffold(
              backgroundColor: Color(0xFF05060A),
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF00E5FF),
                ),
              ),
            );
          }
          return HomeScreen(state: _state);
        },
      ),
    );
  }
}
