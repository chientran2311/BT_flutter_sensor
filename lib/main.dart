import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:light_sensor/light_sensor.dart';

void main() {
  runApp(const SensorProExplorer());
}

class SensorProExplorer extends StatelessWidget {
  const SensorProExplorer({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sensor Pro Explorer',
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
      home: const MainHomePage(),
    );
  }
}

class MainHomePage extends StatefulWidget {
  const MainHomePage({super.key});

  @override
  State<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends State<MainHomePage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("SENSOR PRO EXPLORER"),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.vibration), text: "Motion"),
              Tab(icon: Icon(Icons.explore), text: "Explorer"),
              Tab(icon: Icon(Icons.light_mode), text: "Light"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            MotionTrackerTab(),
            ExplorerToolTab(),
            LightMeterTab(),
          ],
        ),
      ),
    );
  }
}

// --- TAB 1: MOTION TRACKER ---
class MotionTrackerTab extends StatefulWidget {
  const MotionTrackerTab({super.key});

  @override
  State<MotionTrackerTab> createState() => _MotionTrackerTabState();
}

class _MotionTrackerTabState extends State<MotionTrackerTab> {
  int _shakeCount = 0;
  static const double _shakeThreshold = 15.0;
  DateTime _lastShakeTime = DateTime.now();
  Color _bgColor = Colors.blueGrey;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bgColor,
      child: StreamBuilder<UserAccelerometerEvent>(
        stream: userAccelerometerEventStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final event = snapshot.data!;
          // Nguyên lý: MEMS sử dụng khối lượng địa chấn (seismic mass) treo trên lò xo.
          // Thuật toán: a = sqrt(x² + y² + z²) để tính độ lớn gia tốc tổng hợp.
          double acceleration = sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));

          if (acceleration > _shakeThreshold) {
            final now = DateTime.now();
            // Debounce 500ms để tránh ghi nhận sai các dao động dư thừa
            if (now.difference(_lastShakeTime).inMilliseconds > 500) {
              _lastShakeTime = now;
              _shakeCount++;
              _bgColor = Colors.primaries[Random().nextInt(Colors.primaries.length)];
            }
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("GIA TỐC KẾ (ACCELEROMETER)", style: TextStyle(color: Colors.white70)),
              Text("$_shakeCount", style: const TextStyle(fontSize: 120, fontWeight: FontWeight.bold, color: Colors.white)),
              const Text("SHAKES DETECTED", style: TextStyle(color: Colors.white, letterSpacing: 4)),
              const SizedBox(height: 20),
              Text("Current: ${acceleration.toStringAsFixed(2)} m/s²", style: const TextStyle(color: Colors.white60)),
            ],
          );
        },
      ),
    );
  }
}

// --- TAB 2: EXPLORER TOOL (GPS & COMPASS) ---
class ExplorerToolTab extends StatefulWidget {
  const ExplorerToolTab({super.key});

  @override
  State<ExplorerToolTab> createState() => _ExplorerToolTabState();
}

class _ExplorerToolTabState extends State<ExplorerToolTab> {
  String _gpsData = "Đang tìm tín hiệu vệ tinh...";

  @override
  void initState() {
    super.initState();
    _initGPS();
  }

  Future<void> _initGPS() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _gpsData = "LAT: ${pos.latitude.toStringAsFixed(4)}\nLONG: ${pos.longitude.toStringAsFixed(4)}\nALT: ${pos.altitude.toStringAsFixed(1)}m";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(_gpsData, style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 20)),
          ),
          const Divider(color: Colors.greenAccent),
          Expanded(
            child: StreamBuilder<MagnetometerEvent>(
              stream: magnetometerEventStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final event = snapshot.data!;
                // Nguyên lý: Hiệu ứng Hall (Hall Effect) cảm nhận từ trường Trái Đất.
                // Tính góc Azimuth bằng hàm atan2
                double heading = atan2(event.y, event.x);
                double degrees = (heading * 180 / pi);
                if (degrees < 0) degrees += 360;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("${degrees.toStringAsFixed(0)}°", style: const TextStyle(color: Colors.white, fontSize: 60, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Transform.rotate(
                      angle: -heading, // Bù trừ góc xoay điện thoại
                      child: const Icon(Icons.navigation, size: 200, color: Colors.redAccent),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- TAB 3: LIGHT METER ---
class LightMeterTab extends StatefulWidget {
  const LightMeterTab({super.key});

  @override
  State<LightMeterTab> createState() => _LightMeterTabState();
}

class _LightMeterTabState extends State<LightMeterTab> {
  int _lux = 0;

  String _getStatus(int lux) {
    if (lux < 10) return "TỐI OM";
    if (lux < 500) return "SÁNG VỪA";
    return "RẤT SÁNG";
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: LightSensor.luxStream(),
      builder: (context, snapshot) {
        if (snapshot.hasData) _lux = snapshot.data!;
        
        final isDark = _lux < 50;
        final color = isDark ? Colors.white : Colors.black;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          color: isDark ? Colors.black87 : Colors.white,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lightbulb, size: 120, color: isDark ? Colors.grey : Colors.orange),
                Text("$_lux LUX", style: TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: color)),
                Text(_getStatus(_lux), style: TextStyle(fontSize: 24, color: color.withOpacity(0.7))),
                const SizedBox(height: 40),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    "Nguyên lý: Photodiode chuyển đổi Photon thành dòng điện.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}