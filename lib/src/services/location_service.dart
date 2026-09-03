/// Device location via the native OHOS Location Kit bridge.
///
/// Native side: `ohos/entry/.../EntryAbility.ets` exposes channel
/// `io.opengmaps/location` with `checkLocationPermission`,
/// `requestLocationPermission` and `getCurrentLocation` (Location Kit
/// `getCurrentLocation`, `FIRST_FIX`, 5s timeout).
///
/// There is deliberately no IP-location fallback: an IP address is not the
/// device location and must never be presented as one.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum LocationPermissionStatus { unknown, granted, denied }

class LocationService extends ChangeNotifier {
  LocationService._();

  static final LocationService instance = LocationService._();

  static const MethodChannel _channel =
      MethodChannel('io.opengmaps/location');

  LatLng? _currentLocation;
  LatLng? get currentLocation => _currentLocation;

  double? _accuracyMeters;
  double? get accuracyMeters => _accuracyMeters;

  double _bearing = 0;
  double get currentBearing => _bearing;

  LocationPermissionStatus _permission = LocationPermissionStatus.unknown;
  LocationPermissionStatus get permission => _permission;

  bool _isLocating = false;
  bool get isLocating => _isLocating;

  String? _locationError;
  String? get locationError => _locationError;

  Timer? _trackingTimer;
  Future<LatLng?>? _inflight;
  bool _reading = false;

  /// One-shot fix: checks permission, requests if unknown, reads Location Kit.
  /// Safe to call repeatedly — concurrent callers share the in-flight fix.
  Future<LatLng?> initLiveLocation() {
    final pending = _inflight;
    if (pending != null) return pending;
    final task = _resolve();
    _inflight = task;
    return task.whenComplete(() {
      if (identical(_inflight, task)) _inflight = null;
    });
  }

  Future<LatLng?> _resolve() async {
    _isLocating = true;
    _locationError = null;
    notifyListeners();
    try {
      final granted = await ensurePermission();
      if (!granted) {
        _permission = LocationPermissionStatus.denied;
        _locationError = 'Location permission was denied';
        return null;
      }
      final fix = await _readFix();
      if (fix == null) {
        _locationError = 'Location Kit returned no valid fix';
        return null;
      }
      return fix;
    } on PlatformException catch (e) {
      _locationError =
          e.message ?? 'Location permission or GPS fix unavailable';
      return null;
    } catch (e) {
      _locationError = 'Location unavailable: $e';
      return null;
    } finally {
      _isLocating = false;
      notifyListeners();
    }
  }

  /// Returns true when OHOS granted LOCATION (or approximate) permission.
  Future<bool> ensurePermission() async {
    if (_permission == LocationPermissionStatus.granted) return true;
    try {
      final checked =
          await _channel.invokeMethod<bool>('checkLocationPermission');
      if (checked == true) {
        _permission = LocationPermissionStatus.granted;
        return true;
      }
    } on MissingPluginException {
      // Unit/widget tests: no native host. Treat as denied without noise.
      _permission = LocationPermissionStatus.denied;
      return false;
    } catch (_) {
      // Fall through to an explicit request below.
    }
    try {
      final granted = await _channel
          .invokeMethod<bool>('requestLocationPermission');
      _permission = granted == true
          ? LocationPermissionStatus.granted
          : LocationPermissionStatus.denied;
      return granted == true;
    } on MissingPluginException {
      _permission = LocationPermissionStatus.denied;
      return false;
    }
  }

  Future<LatLng?> _readFix() async {
    if (_reading) return _currentLocation;
    _reading = true;
    try {
      final result = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getCurrentLocation');
      final lat = (result?['latitude'] as num?)?.toDouble();
      final lng = (result?['longitude'] as num?)?.toDouble();
      if (lat == null ||
          lng == null ||
          lat < -90 ||
          lat > 90 ||
          lng < -180 ||
          lng > 180) {
        return null;
      }
      final bearing = (result?['bearing'] as num?)?.toDouble();
      final accuracy = (result?['accuracy'] as num?)?.toDouble();
      _currentLocation = LatLng(lat, lng);
      if (bearing != null && bearing.isFinite) _bearing = bearing;
      if (accuracy != null && accuracy.isFinite) _accuracyMeters = accuracy;
      _locationError = null;
      return _currentLocation;
    } finally {
      _reading = false;
    }
  }

  /// Poll Location Kit every 8s (called after first fix / recenter).
  void startTracking() {
    _trackingTimer ??= Timer.periodic(const Duration(seconds: 8), (_) async {
      if (_permission != LocationPermissionStatus.granted) return;
      final fix = await _readFix();
      if (fix != null) notifyListeners();
    });
  }

  void stopTracking() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
  }

  /// Manual override (debug / tests / preview).
  void setUserLocation(LatLng location, [double bearing = 0]) {
    _currentLocation = location;
    _bearing = bearing;
    _locationError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}
