import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'open_gmaps_types.dart';
import 'open_gmaps_controller.dart';
import '../harmony/harmony_colors.dart';

/// Pure-Dart tile map for OpenHarmony — no native SDK required.
/// Renders OSM/Google tiles via Image.network in a pannable grid.
///
/// This is the OHOS backport: on Android/iOS the app uses google_maps_flutter;
/// on OHOS it uses this widget with identical API.
class OhosTileMap extends StatefulWidget {
  const OhosTileMap({
    super.key,
    required this.initialPosition,
    required this.markers,
    required this.mapType,
    this.onCameraMove,
    this.onTap,
    this.controller,
  });

  final OpenCameraPosition initialPosition;
  final Set<OpenMarker> markers;
  final OpenMapType mapType;
  final ValueChanged<OpenCameraPosition>? onCameraMove;
  final ValueChanged<OpenLatLng>? onTap;
  final OhosTileController? controller;

  @override
  State<OhosTileMap> createState() => _OhosTileMapState();
}

class _OhosTileMapState extends State<OhosTileMap> {
  late OpenLatLng _center;
  late double _zoom;
  late OhosTileController _ctrl;

  @override
  void initState() {
    super.initState();
    _center = widget.initialPosition.target;
    _zoom = widget.initialPosition.zoom;
    _ctrl = widget.controller ?? OhosTileController(initialPosition: widget.initialPosition);
    _ctrl.addListener(_onCtrl);
  }

  void _onCtrl() {
    setState(() {
      _center = _ctrl.position.target;
      _zoom = _ctrl.position.zoom;
    });
    widget.onCameraMove?.call(OpenCameraPosition(target: _center, zoom: _zoom));
  }

  @override
  void didUpdateWidget(covariant OhosTileMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPosition.target != oldWidget.initialPosition.target ||
        widget.initialPosition.zoom != oldWidget.initialPosition.zoom) {
      // external update
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  // Mercator helpers
  double _lngToX(double lng) => (lng + 180) / 360;
  double _latToY(double lat) {
    final rad = lat * math.pi / 180;
    return (1 - math.log(math.tan(rad) + 1 / math.cos(rad)) / math.pi) / 2;
  }

  OpenLatLng _xYToLatLng(double x, double y) {
    final lng = x * 360 - 180;
    final n = math.pi - 2 * math.pi * y;
    final lat = 180 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
    return OpenLatLng(lat, lng);
  }

  String _tileUrl(int x, int y, int z) {
    // Proper Google Maps raster tiles for OHOS — no API key required for mt endpoint.
    // lyrs=m: roadmap, s: satellite, y: hybrid, p: terrain
    String lyrs;
    switch (widget.mapType) {
      case OpenMapType.satellite:
        lyrs = 's';
        break;
      case OpenMapType.hybrid:
        lyrs = 'y';
        break;
      case OpenMapType.terrain:
        lyrs = 'p';
        break;
      case OpenMapType.normal:
      default:
        lyrs = 'm';
        break;
    }
    final sub = (x + y) % 4;
    return 'https://mt$sub.google.com/vt/lyrs=$lyrs&hl=en&x=$x&y=$y&z=$z&s=Ga';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final z = _zoom.clamp(1, 19).round();
      final tileCount = math.pow(2, z).toDouble();
      final centerX = _lngToX(_center.longitude) * tileCount;
      final centerY = _latToY(_center.latitude) * tileCount;

      // number of tiles to cover viewport + 1 buffer
      const tileSize = 256.0;
      final cols = (w / tileSize).ceil() + 2;
      final rows = (h / tileSize).ceil() + 2;
      final startX = (centerX - cols / 2).floor();
      final startY = (centerY - rows / 2).floor();

      return GestureDetector(
        onPanUpdate: (d) {
          final dx = d.delta.dx;
          final dy = d.delta.dy;
          // move center opposite to drag
          final newX = centerX - dx / tileSize;
          final newY = centerY - dy / tileSize;
          final nx = (newX / tileCount).clamp(0.0, 1.0);
          final ny = (newY / tileCount).clamp(0.0, 1.0);
          final ll = _xYToLatLng(nx, ny);
          setState(() => _center = ll);
          widget.onCameraMove?.call(OpenCameraPosition(target: _center, zoom: _zoom));
          widget.onTap?.call(_center);
        },
        onTapUp: (d) {
          // approximate tap to latlng
          final tapX = d.localPosition.dx;
          final tapY = d.localPosition.dy;
          final offsetX = (tapX - w / 2) / tileSize;
          final offsetY = (tapY - h / 2) / tileSize;
          final tx = (centerX + offsetX) / tileCount;
          final ty = (centerY + offsetY) / tileCount;
          final ll = _xYToLatLng(tx.clamp(0, 1), ty.clamp(0, 1));
          widget.onTap?.call(ll);
        },
        child: Stack(
          children: [
            // tile grid
            Positioned.fill(
              child: Stack(
                children: [
                  for (int dx = 0; dx < cols; dx++)
                    for (int dy = 0; dy < rows; dy++)
                      Builder(builder: (_) {
                        final x = startX + dx;
                        final y = startY + dy;
                        if (x < 0 || y < 0 || x >= tileCount || y >= tileCount) return const SizedBox();
                        final left = (x - centerX) * tileSize + w / 2;
                        final top = (y - centerY) * tileSize + h / 2;
                        return Positioned(
                          left: left,
                          top: top,
                          width: tileSize,
                          height: tileSize,
                          child: Image.network(
                            _tileUrl(x, y, z),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: HmosColors.surfaceVariant, child: const Icon(Icons.map, color: HmosColors.textTertiary)),
                            // cache
                          ),
                        );
                      }),
                ],
              ),
            ),
            // markers
            ...widget.markers.map((m) {
              final mx = _lngToX(m.position.longitude) * tileCount;
              final my = _latToY(m.position.latitude) * tileCount;
              final left = (mx - centerX) * tileSize + w / 2;
              final top = (my - centerY) * tileSize + h / 2;
              return Positioned(
                left: left - 18,
                top: top - 36,
                child: GestureDetector(
                  onTap: m.onTap,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: HmosColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)],
                        ),
                        child: Text(m.title ?? m.markerId, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 2),
                      const Icon(Icons.location_on, color: HmosColors.primary, size: 36),
                    ],
                  ),
                ),
              );
            }),
            // center dot for debugging (optional)
            // Positioned at center for reference
            // zoom controls overlay is outside
          ],
        ),
      );
    });
  }
}
