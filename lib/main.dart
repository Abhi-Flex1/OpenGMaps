/// OpenGMaps — stock `google_maps_flutter` on OpenHarmony.
///
/// The `GoogleMap` widget below is the unmodified upstream widget. On OHOS
/// it is rendered by `google_maps_flutter_ohos`
/// (`packages/google_maps_flutter_ohos`, registered in [main]), which
/// translates the whole stock surface to the official Maps JavaScript API
/// in the native OHOS WebView. Place data, geocoding and routes come from
/// the keyed Places / Geocoding / Directions REST clients.
///
/// Key (never committed):
/// `flutter run --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY`
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_ohos/google_maps_flutter_ohos.dart';

import 'src/config/google_maps_config.dart';
import 'src/services/google_directions_service.dart';
import 'src/services/google_geocoding_service.dart';
import 'src/services/google_places_service.dart';
import 'src/services/location_service.dart';
import 'src/services/saved_places_service.dart';
import 'src/theme/google_maps_theme.dart';
import 'src/utils/geo.dart';
import 'src/widgets/google_brand_icons.dart';

void main() {
  GoogleMapsFlutterOhos.register();
  // Dedicated Maps JavaScript key via --dart-define=OGM_MAPS_KEY.
  // Falls back to GOOGLE_MAPS_API_KEY when empty (single-key setup).
  const mapsKey = String.fromEnvironment('OGM_MAPS_KEY', defaultValue: '');
  if (mapsKey.isNotEmpty) GoogleMapsFlutterOhos.apiKeyOverride = mapsKey;
  runApp(const OpenGMapsApp());
}

class OpenGMapsApp extends StatelessWidget {
  const OpenGMapsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenGMaps',
      debugShowCheckedModeBanner: false,
      theme: GoogleMapsTheme.light(),
      darkTheme: GoogleMapsTheme.dark(),
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const CameraPosition _defaultCamera = CameraPosition(
    target: LatLng(48.85837, 2.29448),
    zoom: 12,
  );

  final Completer<GoogleMapController> _controller = Completer();
  GoogleMapController? _map;
  StreamSubscription<OhosPoiTap>? _poiSub;

  final _searchCtrl = TextEditingController();
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();

  final _places = GooglePlacesService.instance;
  // Dedicated service keys via --dart-define=OGM_GEO_KEY / OGM_DIRS_KEY.
  // Empty falls back to GoogleMapsConfig.apiKey (GOOGLE_MAPS_API_KEY),
  // so single-key setups keep working unchanged.
  static const _geoKey = String.fromEnvironment('OGM_GEO_KEY', defaultValue: '');
  static const _dirsKey =
      String.fromEnvironment('OGM_DIRS_KEY', defaultValue: '');
  final _geo = GoogleGeocodingService(apiKey: _geoKey.isEmpty ? null : _geoKey);
  final _dirs =
      GoogleDirectionsService(apiKey: _dirsKey.isEmpty ? null : _dirsKey);
  final _loc = LocationService.instance;
  final _saved = SavedPlacesService.instance;

  MapType _mapType = MapType.normal;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  bool _searching = false;
  List<PlacePrediction> _predictions = [];
  Timer? _debounce;

  SavedPin? _selected;
  PlaceDetails? _detail;

  bool _resolving = false;
  bool _dirLoading = false;
  String? _dirError;
  DirectionRoute? _route;
  TravelMode _mode = TravelMode.driving;

  int _tab = 0;
  int _reqToken = 0;

  @override
  void initState() {
    super.initState();
    _loc.addListener(_onLoc);
    _saved.addListener(_onSvc);
    _saved.init();
    _loc.initLiveLocation().then((LatLng? fix) {
      if (fix != null && mounted) {
        _map?.animateCamera(CameraUpdate.newLatLngZoom(fix, 15));
        _loc.startTracking();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _originCtrl.dispose();
    _destCtrl.dispose();
    _loc.removeListener(_onLoc);
    _saved.removeListener(_onSvc);
    _loc.stopTracking();
    _poiSub?.cancel();
    _map?.dispose();
    super.dispose();
  }

  void _onLoc() {
    if (mounted) setState(() {});
  }

  void _onSvc() {
    if (mounted) setState(() {});
  }

  Future<void> _animate(CameraUpdate update) async {
    try {
      await (_map?.animateCamera(update));
    } catch (_) {
      // Map not ready yet (e.g. key view) — state already holds the data.
    }
  }

  // -- errors --------------------------------------------------------------

  void _fail(Object e) {
    if (!mounted) return;
    final String message = e is MissingGoogleMapsKey
        ? 'Set GOOGLE_MAPS_API_KEY via --dart-define to use Google data.'
        : e is GoogleMapsApiException
            ? 'Google ${e.status}${e.message.isEmpty ? '' : ': ${e.message}'}'
            : 'Something went wrong: $e';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // -- search ---------------------------------------------------------------

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    final String q = v.trim();
    if (q.isEmpty) {
      setState(() => _predictions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final int token = ++_reqToken;
      setState(() => _searching = true);
      try {
        final List<PlacePrediction> preds =
            await _places.autocomplete(q, near: _loc.currentLocation);
        if (!mounted || token != _reqToken) return;
        setState(() {
          _predictions = preds;
          _searching = false;
        });
      } catch (e) {
        if (!mounted || token != _reqToken) return;
        setState(() => _searching = false);
        _fail(e);
      }
    });
  }

  Future<void> _submitSearch(String v) async {
    final String q = v.trim();
    if (q.isEmpty) return;
    final int token = ++_reqToken;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _predictions = [];
    });
    try {
      final List<PlaceDetails> hits =
          await _places.searchText(q, near: _loc.currentLocation);
      if (!mounted || token != _reqToken) return;
      setState(() => _searching = false);
      if (hits.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google found nothing for that search')),
        );
        return;
      }
      _saved.addSearch(q);
      _showPlace(hits.first);
    } catch (e) {
      if (!mounted || token != _reqToken) return;
      setState(() => _searching = false);
      _fail(e);
    }
  }

  Future<void> _pickPrediction(PlacePrediction p) async {
    final int token = ++_reqToken;
    FocusScope.of(context).unfocus();
    setState(() {
      _predictions = [];
      _searchCtrl.text = p.description;
      _resolving = true;
    });
    try {
      final PlaceDetails? d = await _places.fetchDetails(p.placeId);
      if (!mounted || token != _reqToken) return;
      setState(() => _resolving = false);
      if (d == null) return;
      _saved.addSearch(p.description);
      _showPlace(d);
    } catch (e) {
      if (!mounted || token != _reqToken) return;
      setState(() => _resolving = false);
      _fail(e);
    }
  }

  void _showPlace(PlaceDetails d) {
    final SavedPin pin = SavedPin.fromDetails(d);
    setState(() {
      _selected = pin;
      _detail = d;
      _route = null;
      _polylines = {};
      _markers = {
        Marker(
          markerId: MarkerId(pin.id),
          position: pin.latLng,
          infoWindow: InfoWindow(title: pin.name, snippet: pin.address),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure),
        ),
      };
    });
    _animate(CameraUpdate.newLatLngZoom(pin.latLng, 16));
  }

  // -- map taps ---------------------------------------------------------------

  /// A Google place icon was tapped: fetch the full place card by id.
  /// Falls back to coordinate reverse-geocoding when Details fails.
  Future<void> _onPoiTap(OhosPoiTap e) async {
    FocusScope.of(context).unfocus();
    final int token = ++_reqToken;
    setState(() {
      _resolving = true;
      _selected = null;
      _detail = null;
    });
    try {
      final PlaceDetails? d = await _places.fetchDetails(e.placeId);
      if (!mounted || token != _reqToken) return;
      if (d == null) {
        setState(() => _resolving = false);
        _onMapTap(e.position);
        return;
      }
      setState(() => _resolving = false);
      _showPlace(d);
    } catch (_) {
      if (!mounted || token != _reqToken) return;
      setState(() => _resolving = false);
      _onMapTap(e.position);
    }
  }

  Future<void> _onMapTap(LatLng ll) async {
    FocusScope.of(context).unfocus();
    final int token = ++_reqToken;
    setState(() {
      _resolving = true;
      _selected = null;
      _detail = null;
    });
    try {
      final List<GeocodedAddress> hits = await _geo.reverse(ll);
      if (!mounted || token != _reqToken) return;
      setState(() => _resolving = false);
      if (hits.isEmpty) {
        final SavedPin pin = SavedPin(
          name:
              '${ll.latitude.toStringAsFixed(5)}, ${ll.longitude.toStringAsFixed(5)}',
          address: 'No named place found here',
          latLng: ll,
        );
        setState(() {
          _selected = pin;
          _detail = null;
          _markers = {
            Marker(
              markerId: const MarkerId('tap'),
              position: ll,
              infoWindow: InfoWindow(title: pin.name),
            ),
          };
        });
        return;
      }
      final GeocodedAddress top = hits.first;
      PlaceDetails? full;
      try {
        if (top.placeId.isNotEmpty) {
          full = await _places.fetchDetails(top.placeId);
        }
      } catch (_) {
        full = null;
      }
      if (!mounted || token != _reqToken) return;
      if (full != null) {
        _showPlace(full);
      } else {
        final String name = top.formatted.split(',').first.trim();
        final SavedPin pin = SavedPin(
          name: name.isEmpty ? top.formatted : name,
          address: top.formatted,
          latLng: top.latLng,
          placeId: top.placeId,
        );
        setState(() {
          _selected = pin;
          _detail = null;
          _markers = {
            Marker(
              markerId: MarkerId(pin.id),
              position: pin.latLng,
              infoWindow:
                  InfoWindow(title: pin.name, snippet: pin.address),
            ),
          };
        });
        _animate(CameraUpdate.newLatLngZoom(pin.latLng, 15));
      }
    } catch (e) {
      if (!mounted || token != _reqToken) return;
      setState(() => _resolving = false);
      _fail(e);
    }
  }

  // -- directions ---------------------------------------------------------------

  Future<void> _runDirections() async {
    var origin = _originCtrl.text.trim();
    final String dest = _destCtrl.text.trim();
    if (dest.isEmpty || _dirLoading) return;
    if (origin.isEmpty) {
      final LatLng? l = _loc.currentLocation;
      if (l == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Waiting for location… try again.')),
        );
        return;
      }
      origin = l.asParam;
      _originCtrl.text = origin;
    }
    final int token = ++_reqToken;
    FocusScope.of(context).unfocus();
    setState(() {
      _dirLoading = true;
      _dirError = null;
    });
    try {
      final DirectionRoute? r = await _dirs.getRoute(
        origin: origin,
        destination: dest,
        mode: _mode,
      );
      if (!mounted || token != _reqToken) return;
      setState(() => _dirLoading = false);
      if (r == null) {
        setState(() => _dirError = 'Google found no route for that pair');
        return;
      }
      setState(() {
        _route = r;
        _selected = null;
        _detail = null;
        _markers = {
          Marker(
            markerId: const MarkerId('origin'),
            position: r.startLatLng,
            infoWindow: const InfoWindow(title: 'Origin'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen),
          ),
          Marker(
            markerId: const MarkerId('destination'),
            position: r.endLatLng,
            infoWindow: const InfoWindow(title: 'Destination'),
          ),
        };
        _polylines = r.points.length >= 2
            ? {
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: r.points,
                  color: const Color(0xFF4285F4),
                  width: 6,
                ),
              }
            : {};
      });
      _animate(CameraUpdate.newLatLngBounds(_boundsOf(r), 64));
    } catch (e) {
      if (!mounted || token != _reqToken) return;
      setState(() => _dirLoading = false);
      if (e is MissingGoogleMapsKey || e is GoogleMapsApiException) {
        setState(() => _dirError = e is MissingGoogleMapsKey
            ? 'Set GOOGLE_MAPS_API_KEY to resolve routes.'
            : (e as GoogleMapsApiException).toString());
      } else {
        _fail(e);
      }
    }
  }

  LatLngBounds _boundsOf(DirectionRoute r) {
    final List<LatLng> pts = [
      r.startLatLng,
      r.endLatLng,
      ...r.points,
    ];
    var minLat = pts.first.latitude;
    var maxLat = pts.first.latitude;
    var minLng = pts.first.longitude;
    var maxLng = pts.first.longitude;
    for (final LatLng p in pts.skip(1)) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    if (minLat == maxLat) {
      minLat -= 0.01;
      maxLat += 0.01;
    }
    if (minLng == maxLng) {
      minLng -= 0.01;
      maxLng += 0.01;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _openGoogleDirections() {
    final String origin = _originCtrl.text.trim().isEmpty
        ? (_loc.currentLocation == null
            ? ''
            : _loc.currentLocation!.asParam)
        : _originCtrl.text.trim();
    final String dest = _destCtrl.text.trim();
    if (origin.isEmpty || dest.isEmpty) return;
    final String url =
        GoogleDirectionsService.universalUrl(origin, dest, _mode);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Google Maps directions',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(url)),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  supportZoom: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- misc UI -------------------------------------------------------------------

  void _showLayers() {
    const Map<MapType, String> labels = {
      MapType.normal: 'Default',
      MapType.satellite: 'Satellite',
      MapType.hybrid: 'Hybrid',
      MapType.terrain: 'Terrain',
    };
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: GoogleMapsColors.divider,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            const Text('Map type',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: labels.entries
                  .map((MapEntry<MapType, String> e) => ChoiceChip(
                        selected: _mapType == e.key,
                        label: Text(e.value),
                        onSelected: (_) {
                          setState(() => _mapType = e.key);
                          Navigator.pop(context);
                        },
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: _defaultCamera,
              markers: _markers,
              polylines: _polylines,
              mapType: _mapType,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              compassEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              onMapCreated: (GoogleMapController controller) {
                _map = controller;
                if (!_controller.isCompleted) {
                  _controller.complete(controller);
                }
                // Place-icon taps (OHOS backport extension): resolve the
                // full place card instead of bare coordinates.
                _poiSub?.cancel();
                _poiSub = GoogleMapsFlutterOhos.poiTaps(controller.mapId)
                    .listen(_onPoiTap);
                final LatLng? fix = _loc.currentLocation;
                if (fix != null) {
                  _animate(CameraUpdate.newLatLngZoom(fix, 15));
                }
              },
              onTap: _onMapTap,
            ),
          ),

          if (!GoogleMapsConfig.hasKey)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _KeyBanner(),
                ),
              ),
            ),

          if (_tab == 0)
            Positioned(
              top: GoogleMapsConfig.hasKey ? 0 : 56,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    children: [
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x24000000),
                                blurRadius: 12,
                                offset: Offset(0, 3))
                          ],
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 14),
                            const GoogleGLogo(size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Search Google',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                textInputAction: TextInputAction.search,
                                onChanged: _onSearchChanged,
                                onSubmitted: _submitSearch,
                              ),
                            ),
                            if (_searching)
                              const Padding(
                                padding:
                                    EdgeInsets.symmetric(horizontal: 12),
                                child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.search,
                                    color: GoogleMapsColors.googleBlue),
                                onPressed: () =>
                                    _submitSearch(_searchCtrl.text),
                              ),
                          ],
                        ),
                      ),
                      if (_predictions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x22000000),
                                  blurRadius: 12,
                                  offset: Offset(0, 4))
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: _predictions
                                .take(5)
                                .map((PlacePrediction p) => ListTile(
                                      dense: true,
                                      leading: const Icon(
                                          Icons.place_outlined,
                                          color: GoogleMapsColors
                                              .textSecondary),
                                      title: Text(p.mainText,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis),
                                      subtitle: p.secondaryText.isEmpty
                                          ? null
                                          : Text(p.secondaryText,
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis),
                                      onTap: () => _pickPrediction(p),
                                    ))
                                .toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          if (_tab == 0)
            Positioned(
              right: 16,
              top: MediaQuery.of(context).size.height * 0.3,
              child: FloatingActionButton.small(
                heroTag: 'layers',
                backgroundColor: Colors.white,
                onPressed: _showLayers,
                child: const Icon(Icons.layers_outlined,
                    color: Colors.black87),
              ),
            ),

          const Positioned(
            left: 12,
            bottom: 88,
            child: _Attribution(),
          ),

          if (_tab == 0 && _selected != null)
            _placeSheet(_selected!, _detail),
          if (_tab == 1) _directionsPanel(),
          if (_resolving)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 170,
              child: Center(
                child: _ResolvingChip(),
              ),
            ),
          if (_tab == 2) _savedPanel(),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 16,
                          offset: Offset(0, 4))
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _navBtn(0, Icons.explore, 'Explore'),
                      _navBtn(1, Icons.directions, 'Go'),
                      _navBtn(2, Icons.bookmark_border, 'Saved'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navBtn(int idx, IconData icon, String label) {
    final bool sel = _tab == idx;
    return TextButton.icon(
      onPressed: () => setState(() => _tab = idx),
      icon: Icon(icon,
          color: sel
              ? GoogleMapsColors.googleBlue
              : GoogleMapsColors.textSecondary),
      label: Text(label,
          style: TextStyle(
              color: sel
                  ? GoogleMapsColors.googleBlue
                  : GoogleMapsColors.textSecondary,
              fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
    );
  }

  Widget _placeSheet(SavedPin p, PlaceDetails? d) {
    final bool saved = _saved.isSaved(p);
    return DraggableScrollableSheet(
      initialChildSize: 0.34,
      minChildSize: 0.12,
      maxChildSize: 0.85,
      builder: (context, sc) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: GoogleMapsColors.divider,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 12),
            Text(p.name,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700)),
            if (d != null && d.types.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                Chip(label: Text(_prettyType(d.types.first))),
                if (d.openNow != null)
                  Chip(
                      label:
                          Text(d.openNow! ? 'Open now' : 'Closed')),
              ]),
            ],
            if (d != null && d.rating != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(d.rating!.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  ...List.generate(
                      5,
                      (i) => Icon(
                          i < d.rating!.round()
                              ? Icons.star
                              : Icons.star_border,
                          size: 16,
                          color: const Color(0xFFFBBC05))),
                  if (d.ratingCount > 0) ...[
                    const SizedBox(width: 6),
                    Text('(${d.ratingCount})',
                        style: const TextStyle(
                            fontSize: 12,
                            color: GoogleMapsColors.textSecondary)),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 6),
            Text(p.address,
                maxLines: 3,
                style: const TextStyle(
                    fontSize: 13, color: GoogleMapsColors.textSecondary)),
            Text(
                '${p.latLng.latitude.toStringAsFixed(5)}, ${p.latLng.longitude.toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 11, color: Colors.black45)),
            if (d != null && d.website.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.public,
                    color: GoogleMapsColors.googleBlue, size: 20),
                title: Text(d.website,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: GoogleMapsColors.googleBlue)),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _destCtrl.text = p.name;
                      final LatLng? l = _loc.currentLocation;
                      _originCtrl.text =
                          l == null ? '' : l.asParam;
                      setState(() => _tab = 1);
                    },
                    icon: const Icon(Icons.directions,
                        size: 18, color: Colors.white),
                    label: const Text('Directions'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _saved.toggle(p),
                  icon: Icon(saved
                      ? Icons.bookmark
                      : Icons.bookmark_border),
                  label: Text(saved ? 'Saved' : 'Save'),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _selected = null;
                    _detail = null;
                    _markers = {};
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _prettyType(String raw) {
    final List<String> words = raw.replaceAll('_', ' ').split(' ');
    return words
        .map((String w) =>
            w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Widget _directionsPanel() {
    final DirectionRoute? r = _route;
    return DraggableScrollableSheet(
      initialChildSize: 0.48,
      minChildSize: 0.2,
      maxChildSize: 0.9,
      builder: (context, sc) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: GoogleMapsColors.divider,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 12),
            const Text('Directions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
                'Official Directions API route, turn-by-turn opens in Google Maps.',
                style: TextStyle(
                    fontSize: 12, color: GoogleMapsColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: _originCtrl,
              decoration: InputDecoration(
                hintText: 'Origin (blank = my location)',
                prefixIcon: const Icon(Icons.my_location),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _destCtrl,
              decoration: InputDecoration(
                hintText: 'Destination',
                prefixIcon: const Icon(Icons.place_outlined),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                isDense: true,
              ),
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _runDirections(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: TravelMode.values
                  .map((TravelMode m) => ChoiceChip(
                        selected: _mode == m,
                        label: Text(m.label),
                        onSelected: (_) => setState(() => _mode = m),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _dirLoading ? null : _runDirections,
              icon: const Icon(Icons.directions,
                  size: 18, color: Colors.white),
              label: Text(_dirLoading ? 'Resolving…' : 'Show route'),
            ),
            if (_dirError != null) ...[
              const SizedBox(height: 8),
              Text(_dirError!,
                  style: const TextStyle(
                      color: GoogleMapsColors.googleRed, fontSize: 13)),
            ],
            if (r != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: GoogleMapsColors.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${r.distanceText} · ${r.durationText}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(r.startAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12)),
                    const Text('↓',
                        style: TextStyle(
                            fontSize: 12,
                            color: GoogleMapsColors.textSecondary)),
                    Text(r.endAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _openGoogleDirections,
                icon: const Icon(Icons.navigation,
                    color: GoogleMapsColors.googleBlue),
                label: const Text('Navigate in Google Maps'),
              ),
              if (r.steps.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...r.steps.take(12).map((DirectionStep s) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.turn_right,
                          size: 18,
                          color: GoogleMapsColors.textSecondary),
                      title: Text(s.instruction,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13)),
                      trailing: Text(s.distanceText,
                          style: const TextStyle(
                              fontSize: 12,
                              color:
                                  GoogleMapsColors.textSecondary)),
                    )),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _savedPanel() {
    final List<SavedPin> items = _saved.saved;
    return DraggableScrollableSheet(
      initialChildSize: 0.44,
      minChildSize: 0.2,
      maxChildSize: 0.85,
      builder: (context, sc) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: GoogleMapsColors.divider,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 12),
            const Text('Saved',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Text('Nothing saved yet. Search Google, tap Save.',
                  style: TextStyle(
                      fontSize: 13, color: GoogleMapsColors.textSecondary))
            else
              ...items.map((SavedPin p) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.bookmark,
                        color: GoogleMapsColors.googleBlue),
                    title: Text(p.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(p.address,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _saved.toggle(p),
                    ),
                    onTap: () {
                      _searchCtrl.text = p.name;
                      setState(() => _tab = 0);
                      _submitSearch(p.name);
                    },
                  )),
            if (_saved.recentSearches.isNotEmpty) ...[
              const Divider(height: 24),
              const Text('Recent searches',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ..._saved.recentSearches.map((String q) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history,
                        color: GoogleMapsColors.textSecondary),
                    title: Text(q),
                    onTap: () {
                      _searchCtrl.text = q;
                      setState(() => _tab = 0);
                      _submitSearch(q);
                    },
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _KeyBanner extends StatelessWidget {
  const _KeyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF7E0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFBBC05)),
      ),
      child: const Row(
        children: [
          Icon(Icons.key_outlined, size: 18, color: Color(0xFF5F6368)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No GOOGLE_MAPS_API_KEY — map and Google data unlock after re-running with --dart-define.',
              style: TextStyle(fontSize: 12, color: Color(0xFF5F6368)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Map data © Google',
        style: TextStyle(fontSize: 10, color: Colors.black54),
      ),
    );
  }
}

class _ResolvingChip extends StatelessWidget {
  const _ResolvingChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 10),
          Text('Asking Google…',
              style: TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }
}
