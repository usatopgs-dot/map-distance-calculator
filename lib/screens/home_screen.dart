import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/route_model.dart';

// Waypoint colors - same as original app
const List<Color> kColors = [
  Color(0xFF2563EB),
  Color(0xFFDC2626),
  Color(0xFF16A34A),
  Color(0xFFEA580C),
  Color(0xFF7C3AED),
  Color(0xFF0891B2),
  Color(0xFFB45309),
];

enum MapMode { addPoints, area }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late TabController _tabController;

  MapMode _mode = MapMode.addPoints;
  List<Waypoint> _waypoints = [];
  List<Waypoint> _areaPoints = [];
  Position? _myPosition;
  String _gpsStatus = 'Detecting your location...';
  bool _gpsSuccess = false;
  RouteStats _stats = const RouteStats();
  List<SavedRoute> _savedRoutes = [];
  String _shareUrl = '';
  bool _copied = false;

  // FAQ state
  int? _openFaq;
  static const _faqs = [
    ['How does the map distance calculator work?', 'Tap anywhere on the map to place waypoints. The tool calculates straight-line distance using the Haversine formula, which accounts for Earth\'s curvature.'],
    ['Is this app free?', 'Yes, completely free. No sign-up, no login required.'],
    ['How accurate is the distance?', 'Uses Haversine formula with GPS coordinates for very accurate straight-line (as-the-crow-flies) distances.'],
    ['Can I measure area?', 'Yes! Switch to Area mode and tap to place polygon points. The app calculates enclosed area in km².'],
    ['How do I save and share my route?', 'Tap Save to store your route, then tap Share to generate a shareable link.'],
    ['What travel modes are supported?', 'Car (80 km/h), Walking (5 km/h), and Cycling (20 km/h) estimates.'],
    ['Can I drag waypoints?', 'Yes! Every waypoint marker is draggable to update the route in real time.'],
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSavedRoutes();
    _initGps();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initGps() async {
    final status = await Permission.location.request();
    if (!status.isGranted) {
      setState(() => _gpsStatus = 'Location denied — enable in settings');
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _myPosition = pos;
        _gpsStatus = 'Location found — ±${pos.accuracy.round()}m accuracy';
        _gpsSuccess = true;
      });
      _mapController.move(LatLng(pos.latitude, pos.longitude), 13);
    } catch (e) {
      setState(() => _gpsStatus = 'Location unavailable');
    }
  }

  Future<void> _loadSavedRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('savedRoutes') ?? [];
    setState(() {
      _savedRoutes = raw
          .map((s) => SavedRoute.fromJson(jsonDecode(s)))
          .toList()
          .reversed
          .take(5)
          .toList();
    });
  }

  void _onMapTap(TapPosition tapPos, LatLng latlng) {
    if (_mode == MapMode.addPoints) {
      _addPoint(latlng);
    } else {
      _addAreaPoint(latlng);
    }
  }

  void _addPoint(LatLng latlng) {
    setState(() {
      _waypoints.add(Waypoint(
        lat: latlng.latitude,
        lng: latlng.longitude,
        index: _waypoints.length,
      ));
      _recalcStats();
    });
  }

  void _addAreaPoint(LatLng latlng) {
    setState(() {
      _areaPoints.add(Waypoint(
        lat: latlng.latitude,
        lng: latlng.longitude,
        index: _areaPoints.length,
      ));
      _recalcStats();
    });
  }

  void _recalcStats() {
    double total = 0;
    for (int i = 1; i < _waypoints.length; i++) {
      total += haversineDistance(
        _waypoints[i - 1].lat, _waypoints[i - 1].lng,
        _waypoints[i].lat, _waypoints[i].lng,
      );
    }
    double? area;
    if (_areaPoints.length >= 3) {
      area = calculatePolygonArea(_areaPoints);
    }
    setState(() {
      _stats = RouteStats(
        distanceKm: total,
        distanceMiles: total * 0.621371,
        pointCount: _waypoints.length,
        areaSqKm: area,
      );
    });
  }

  void _removePoint(int index) {
    setState(() {
      _waypoints.removeAt(index);
      _waypoints = _waypoints
          .asMap()
          .entries
          .map((e) => e.value.copyWith(index: e.key))
          .toList();
      _recalcStats();
    });
  }

  void _clearAll() {
    setState(() {
      _waypoints = [];
      _areaPoints = [];
      _stats = const RouteStats();
      _shareUrl = '';
    });
  }

  Future<void> _saveRoute() async {
    if (_waypoints.isEmpty) {
      _showSnack('Add some waypoints first!');
      return;
    }
    final now = DateTime.now();
    final route = SavedRoute(
      id: now.millisecondsSinceEpoch.toString(),
      name: 'Route ${_savedRoutes.length + 1} (${_waypoints.length} pts)',
      waypoints: List.from(_waypoints),
      distanceKm: double.parse(_stats.distanceKm.toStringAsFixed(2)),
      date: '${now.day}/${now.month}/${now.year}',
    );
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('savedRoutes') ?? [];
    raw.add(jsonEncode(route.toJson()));
    await prefs.setStringList('savedRoutes', raw);
    _showSnack('Route saved!');
    _loadSavedRoutes();
  }

  void _shareRoute() {
    if (_waypoints.isEmpty) {
      _showSnack('Add some waypoints first!');
      return;
    }
    final pts = _waypoints.map((w) => '${w.lat},${w.lng}').join('|');
    final url = 'https://mapdistancecalculator.com/?pts=$pts';
    setState(() => _shareUrl = url);
    Share.share('Check my route on Map Distance Calculator: $url');
    _tabController.animateTo(3);
  }

  void _copyShare() {
    Clipboard.setData(ClipboardData(text: _shareUrl));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _loadRoute(SavedRoute route) {
    setState(() {
      _waypoints = List.from(route.waypoints);
      _recalcStats();
    });
    if (route.waypoints.isNotEmpty) {
      _mapController.move(
        LatLng(route.waypoints.first.lat, route.waypoints.first.lng),
        12,
      );
    }
    _tabController.animateTo(0);
    _showSnack('Route loaded!');
  }

  void _goToMyLoc() {
    if (_myPosition != null) {
      _mapController.move(
        LatLng(_myPosition!.latitude, _myPosition!.longitude),
        14,
      );
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Widget _markerWidget(int num, Color color) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Center(
        child: Text(
          '$num',
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.place, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            const Text('Map Distance Calculator'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showAbout,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildGpsBar(),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.38,
            child: _buildMap(),
          ),
          _buildToolbar(),
          _buildTabs(),
        ],
      ),
    );
  }

  Widget _buildGpsBar() {
    final bg = _gpsSuccess ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE);
    final fg = _gpsSuccess ? const Color(0xFF15803D) : const Color(0xFF1E40AF);
    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Row(
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(_gpsStatus, style: TextStyle(fontSize: 12, color: fg))),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(20.5937, 78.9629),
        initialZoom: 5,
        onTap: _onMapTap,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.mapcalculator.app',
        ),
        if (_waypoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _waypoints.map((w) => LatLng(w.lat, w.lng)).toList(),
                color: const Color(0xFF2563EB),
                strokeWidth: 3.0,
                isDotted: true,
              ),
            ],
          ),
        if (_areaPoints.length >= 3)
          PolygonLayer(
            polygons: [
              Polygon(
                points: _areaPoints.map((w) => LatLng(w.lat, w.lng)).toList(),
                color: const Color(0xFFEA580C).withOpacity(0.15),
                borderColor: const Color(0xFFEA580C),
                borderStrokeWidth: 2,
                isDotted: true,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (_myPosition != null)
              Marker(
                point: LatLng(_myPosition!.latitude, _myPosition!.longitude),
                width: 20, height: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.5), blurRadius: 8)],
                  ),
                ),
              ),
            ..._waypoints.asMap().entries.map((e) => Marker(
              point: LatLng(e.value.lat, e.value.lng),
              width: 28, height: 28,
              child: GestureDetector(
                onTap: () => _showWaypointOptions(e.key),
                child: _markerWidget(e.key + 1, kColors[e.key % kColors.length]),
              ),
            )),
            ..._areaPoints.map((w) => Marker(
              point: LatLng(w.lat, w.lng),
              width: 12, height: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _toolBtn('📍 Me', _myPosition != null, _goToMyLoc, active: _myPosition != null),
            const SizedBox(width: 6),
            _toolBtn('+ Points', true, () => setState(() => _mode = MapMode.addPoints), active: _mode == MapMode.addPoints),
            const SizedBox(width: 6),
            _toolBtn('Area', true, () => setState(() => _mode = MapMode.area), active: _mode == MapMode.area),
            Container(width: 1, height: 24, color: const Color(0xFFE5E7EB), margin: const EdgeInsets.symmetric(horizontal: 8)),
            _toolBtn('Save', true, _saveRoute),
            const SizedBox(width: 6),
            _toolBtn('Share', true, _shareRoute),
            const SizedBox(width: 6),
            _toolBtn('Clear', true, _showClearConfirm, danger: true),
          ],
        ),
      ),
    );
  }

  Widget _toolBtn(String label, bool enabled, VoidCallback onTap, {bool active = false, bool danger = false}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEFF6FF) : danger ? const Color(0xFFFEF2F2) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? const Color(0xFFBFDBFE) : danger ? const Color(0xFFFECACA) : const Color(0xFFE5E7EB)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active ? const Color(0xFF2563EB) : danger ? const Color(0xFFDC2626) : enabled ? const Color(0xFF374151) : const Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Expanded(
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF2563EB),
            unselectedLabelColor: const Color(0xFF9CA3AF),
            indicatorColor: const Color(0xFF2563EB),
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            tabs: const [Tab(text: 'Stats'), Tab(text: 'Elevation'), Tab(text: 'History'), Tab(text: 'Share')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildStatsTab(), _buildElevationTab(), _buildHistoryTab(), _buildShareTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 7,
            mainAxisSpacing: 7,
            childAspectRatio: 1.3,
            children: [
              _statCard('Distance', '${_stats.distanceKm.toStringAsFixed(2)}', 'km'),
              _statCard('Miles', '${_stats.distanceMiles.toStringAsFixed(2)}', 'mi'),
              _statCard('Points', '${_stats.pointCount}', ''),
              _statCard('Area', _stats.areaSqKm != null ? _stats.areaSqKm!.toStringAsFixed(2) : '—', 'km²'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _travelCard('🚗', 'Car', _stats.carTime, '80 km/h')),
              const SizedBox(width: 8),
              Expanded(child: _travelCard('🚶', 'Walk', _stats.walkTime, '5 km/h')),
              const SizedBox(width: 8),
              Expanded(child: _travelCard('🚴', 'Bike', _stats.bikeTime, '20 km/h')),
            ],
          ),
          const SizedBox(height: 12),
          const Text('WAYPOINTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF), letterSpacing: 0.7)),
          const SizedBox(height: 7),
          if (_waypoints.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('Tap on the map to add waypoints', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)))))
          else
            ..._waypoints.asMap().entries.map((e) {
              final i = e.key;
              final w = e.value;
              double? seg;
              if (i > 0) seg = haversineDistance(_waypoints[i-1].lat, _waypoints[i-1].lng, w.lat, w.lng);
              return Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(color: kColors[i % kColors.length], shape: BoxShape.circle),
                      child: Center(child: Text('${i+1}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${w.lat.toStringAsFixed(4)}°, ${w.lng.toStringAsFixed(4)}°', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)))),
                    Text(seg != null ? '${seg.toStringAsFixed(2)} km' : 'Start', style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                    const SizedBox(width: 6),
                    GestureDetector(onTap: () => _removePoint(i), child: const Icon(Icons.close, size: 14, color: Color(0xFF9CA3AF))),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, String unit) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 3),
          RichText(text: TextSpan(children: [
            TextSpan(text: value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
            if (unit.isNotEmpty) TextSpan(text: ' $unit', style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280))),
          ])),
        ],
      ),
    );
  }

  Widget _travelCard(String emoji, String mode, String time, String speed) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 3),
          Text(mode, style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
          Text(time, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
          Text(speed, style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }

  Widget _buildElevationTab() {
    if (_waypoints.length < 2) {
      return const Center(child: Text('Add 2+ waypoints to see elevation chart', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))));
    }
    final elevData = _waypoints.asMap().entries.map((e) {
      final w = e.value;
      final seed = (sin(w.lat * 12.9898 + w.lng * 78.233) * 43758.5453).abs() % 1;
      return (50 + seed * 800 + sin(e.key * 1.7) * 80).round();
    }).toList();
    final minElev = elevData.reduce(min);
    final maxElev = elevData.reduce(max);
    final gain = elevData.asMap().entries.fold(0, (g, e) {
      if (e.key > 0 && e.value > elevData[e.key - 1]) return g + e.value - elevData[e.key - 1];
      return g;
    });
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ELEVATION PROFILE (SIMULATED)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF), letterSpacing: 0.7)),
          const SizedBox(height: 10),
          SizedBox(height: 120, child: CustomPaint(painter: ElevationPainter(elevData, kColors), size: Size.infinite)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _statCard('Min Elev', '$minElev', 'm')),
            const SizedBox(width: 7),
            Expanded(child: _statCard('Max Elev', '$maxElev', 'm')),
            const SizedBox(width: 7),
            Expanded(child: _statCard('Total Gain', '+$gain', 'm')),
          ]),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SAVED ROUTES (LAST 5)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF), letterSpacing: 0.7)),
          const SizedBox(height: 8),
          if (_savedRoutes.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No saved routes — tap Save to store a route', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)))))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _savedRoutes.length,
                itemBuilder: (ctx, i) {
                  final r = _savedRoutes[i];
                  return GestureDetector(
                    onTap: () => _loadRoute(r),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                          const SizedBox(height: 3),
                          Text('${r.waypoints.length} points · ${r.distanceKm} km · ${r.date}', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShareTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SHARE YOUR ROUTE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF), letterSpacing: 0.7)),
          const SizedBox(height: 8),
          const Text('Add waypoints and tap the Share button above to generate a shareable link.', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(height: 10),
          if (_shareUrl.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No route to share yet', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)))))
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Expanded(child: Text(_shareUrl, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _copyShare,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                    child: Text(_copied ? 'Copied!' : 'Copy', style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          const Divider(height: 30),
          const Text('FAQ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: _faqs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final isOpen = _openFaq == i;
                return Column(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _openFaq = isOpen ? null : i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Expanded(child: Text(_faqs[i][0], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)))),
                            Icon(isOpen ? Icons.remove : Icons.add, size: 18, color: isOpen ? const Color(0xFF2563EB) : const Color(0xFF9CA3AF)),
                          ],
                        ),
                      ),
                    ),
                    if (isOpen)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_faqs[i][1], style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.6)),
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

  void _showWaypointOptions(int index) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Color(0xFFDC2626)),
              title: Text('Remove waypoint ${index + 1}'),
              onTap: () { Navigator.pop(ctx); _removePoint(index); },
            ),
            ListTile(leading: const Icon(Icons.close), title: const Text('Cancel'), onTap: () => Navigator.pop(ctx)),
          ],
        ),
      ),
    );
  }

  void _showClearConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all?'),
        content: const Text('This will remove all waypoints and area markers.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); _clearAll(); },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Map Distance Calculator',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2025 Map Distance Calculator\nMap data © OpenStreetMap contributors',
      children: [
        const SizedBox(height: 10),
        const Text('Free tool to measure distances, calculate travel time, measure area, and share routes on a real map.'),
      ],
    );
  }
}

// Custom painter for elevation chart
class ElevationPainter extends CustomPainter {
  final List<int> data;
  final List<Color> colors;

  const ElevationPainter(this.data, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final minV = data.reduce(min).toDouble();
    final maxV = data.reduce(max).toDouble();
    final range = maxV - minV == 0 ? 1.0 : maxV - minV;
    const pad = 24.0;

    List<Offset> pts = [];
    for (int i = 0; i < data.length; i++) {
      final x = pad + i * (size.width - pad * 2) / (data.length - 1);
      final y = size.height - pad - (data[i] - minV) / range * (size.height - pad * 2);
      pts.add(Offset(x, y));
    }

    final fillPath = ui.Path()..moveTo(pts.first.dx, size.height - pad);
    for (final p in pts) fillPath.lineTo(p.dx, p.dy);
    fillPath.lineTo(pts.last.dx, size.height - pad);
    fillPath.close();
    canvas.drawPath(fillPath, Paint()..color = const Color(0xFF2563EB).withOpacity(0.1));

    final linePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final linePath = ui.Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts) linePath.lineTo(p.dx, p.dy);
    canvas.drawPath(linePath, linePaint);

    for (int i = 0; i < pts.length; i++) {
      final p = pts[i];
      canvas.drawCircle(p, 5, Paint()..color = colors[i % colors.length]);
      canvas.drawCircle(p, 5, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
      final tp = TextPainter(
        text: TextSpan(text: '${data[i]}m', style: const TextStyle(color: Colors.black54, fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - 18));
    }
  }

  @override
  bool shouldRepaint(ElevationPainter old) => old.data != data;
}
