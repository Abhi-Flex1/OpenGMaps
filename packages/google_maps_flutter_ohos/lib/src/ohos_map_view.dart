// Copyright 2026 The OpenGMaps Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import 'map_bridge.dart';
import 'map_html.dart';
import 'translation.dart';

/// Flutter widget hosting one OHOS map: the Maps JavaScript API in the
/// native OHOS WebView, driven by [OhosMapSession].
///
/// Used only by [GoogleMapsFlutterOhos.buildViewWithConfiguration]; apps
/// keep using the stock `GoogleMap` widget.
class OhosMapView extends StatefulWidget {
  const OhosMapView({
    super.key,
    required this.session,
    required this.apiKey,
    required this.initialCamera,
    required this.initialOptions,
    required this.initialObjects,
    required this.initialManagers,
    required this.useAdvancedMarkers,
    required this.myLocationButton,
    required this.onViewCreated,
    this.gestureRecognizers = const <Factory<OneSequenceGestureRecognizer>>{},
  });

  final OhosMapSession session;
  final String apiKey;
  final CameraPosition initialCamera;
  final Map<String, Object?> initialOptions;
  final MapObjects initialObjects;
  final Set<ClusterManager> initialManagers;
  final bool useAdvancedMarkers;

  /// Non-null when `myLocationButtonEnabled` — renders the recenter button.
  final AsyncCallback? myLocationButton;
  final PlatformViewCreatedCallback onViewCreated;
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;

  @override
  State<OhosMapView> createState() => _OhosMapViewState();
}

class _OhosMapViewState extends State<OhosMapView> {
  bool _created = false;

  @override
  Widget build(BuildContext context) {
    if (widget.apiKey.isEmpty) return const _KeyRequiredView();
    return Stack(
      children: [
        InAppWebView(
          initialData: InAppWebViewInitialData(
            data: OhosMapHtml.build(
              apiKey: widget.apiKey,
              lat: widget.initialCamera.target.latitude,
              lng: widget.initialCamera.target.longitude,
              zoom: widget.initialCamera.zoom,
              tilt: widget.initialCamera.tilt,
              bearing: widget.initialCamera.bearing,
              options: widget.initialOptions,
            ),
            mimeType: 'text/html',
            encoding: 'utf-8',
            baseUrl: WebUri('https://maps.google.com/'),
          ),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            domStorageEnabled: true,
            supportZoom: false,
            builtInZoomControls: false,
            displayZoomControls: false,
            mediaPlaybackRequiresUserGesture: false,
            javaScriptCanOpenWindowsAutomatically: true,
          ),
          onWebViewCreated: _onWebViewCreated,
        ),
        ValueListenableBuilder<String?>(
          valueListenable: widget.session.errorNotice,
          builder: (BuildContext context, String? message, _) {
            if (message == null) return const SizedBox.shrink();
            // Below the app search bar (which sits at the top) so the
            // message stays readable; tap dismisses.
            return Positioned(
              top: 116,
              left: 12,
              right: 12,
              child: SafeArea(
                bottom: false,
                child: GestureDetector(
                  onTap: () => widget.session.errorNotice.value = null,
                  child: Material(
                    color: const Color(0xFFB3261E),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Text(
                        message,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (widget.myLocationButton != null)
          Positioned(
            // Above the app bottom bar so it is never covered by it.
            right: 12,
            bottom: 100,
            child: FloatingActionButton.small(
              heroTag: 'ohos-map-mylocation-${widget.session.mapId}',
              backgroundColor: Colors.white,
              onPressed: widget.myLocationButton,
              child: const Icon(Icons.my_location, color: Color(0xFF1A73E8)),
            ),
          ),
      ],
    );
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    if (_created) return;
    _created = true;
    final OhosMapSession session = widget.session;
    session.web = controller;
    controller.addJavaScriptHandler(
      handlerName: 'ohosReady',
      callback: (_) async {
        session.onJsReady();
        session.eval('OhosMaps.flush();');
        await _applyInitialObjects();
        widget.onViewCreated(session.mapId);
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'ohosEvent',
      callback: (List<dynamic> args) {
        if (args.isNotEmpty && args.first is Map) {
          session.onEvent(
              Map<Object?, Object?>.from(args.first as Map));
        }
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'ohosRequest',
      callback: (List<dynamic> args) {
        if (args.isNotEmpty && args.first is Map) {
          session.onRequestResponse(
              Map<Object?, Object?>.from(args.first as Map));
        }
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'ohosTile',
      callback: (List<dynamic> args) async {
        if (args.isNotEmpty && args.first is Map) {
          await session.onTileRequest(
              Map<Object?, Object?>.from(args.first as Map));
        }
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'ohosError',
      callback: (List<dynamic> args) {
        session.onMapError(
            args.isEmpty ? 'Google Maps failed to load.' : '${args.first}');
      },
    );
  }

  /// Applies the `buildViewWithConfiguration` object sets once the JS
  /// bridge is ready (icons resolve in Dart first).
  Future<void> _applyInitialObjects() async {
    final OhosMapSession session = widget.session;
    final MapObjects objects = widget.initialObjects;
    if (widget.initialManagers.isNotEmpty) {
      session.eval('OhosMaps.setClusterManagers(${jsonEncode(widget.initialManagers.map((ClusterManager e) => e.clusterManagerId.value).toList())});');
    }
    if (objects.markers.isNotEmpty) {
      final List<Map<String, Object?>> add = [];
      for (final Marker m in objects.markers) {
        add.add(ohosMarkerJson(
          m,
          await session.icons.resolve(m.icon),
          advanced: widget.useAdvancedMarkers,
        ));
      }
      session.eval('OhosMaps.setMarkers(${jsonEncode({'add': add})});');
    }
    _applySyncList(
        session,
        'OhosMaps.setPolylines',
        objects.polylines.map(ohosPolylineJson).toList());
    _applySyncList(
        session,
        'OhosMaps.setPolygons',
        objects.polygons.map(ohosPolygonJson).toList());
    _applySyncList(session, 'OhosMaps.setCircles',
        objects.circles.map(ohosCircleJson).toList());
    _applySyncList(session, 'OhosMaps.setHeatmaps',
        objects.heatmaps.map(ohosHeatmapJson).toList());
    if (objects.tileOverlays.isNotEmpty) {
      for (final TileOverlay t in objects.tileOverlays) {
        session.tileOverlays[t.tileOverlayId.value] = t;
      }
      session.eval('OhosMaps.setTileOverlays(${jsonEncode(objects.tileOverlays.map(ohosTileOverlayJson).toList())});');
    }
    if (objects.groundOverlays.isNotEmpty) {
      final List<Map<String, Object?>> add = [];
      for (final GroundOverlay g in objects.groundOverlays) {
        add.add(ohosGroundOverlayJson(
            g, await session.icons.resolve(g.image)));
      }
      session.eval('OhosMaps.setGroundOverlays(${jsonEncode({'add': add})});');
    }
  }

  void _applySyncList(
      OhosMapSession session, String fn, List<Map<String, Object?>> add) {
    if (add.isEmpty) return;
    session.eval('$fn(${jsonEncode({'add': add})});');
  }
}

class _KeyRequiredView extends StatelessWidget {
  const _KeyRequiredView();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF1F3F4),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.key_outlined, size: 44, color: Color(0xFF5F6368)),
              SizedBox(height: 14),
              Text(
                'Google Maps API key required',
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Set GoogleMapsFlutterOhos.apiKeyOverride or re-run with '
                '--dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY.',
                style:
                    TextStyle(fontSize: 13, color: Color(0xFF5F6368)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
