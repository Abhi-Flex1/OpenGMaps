// Copyright 2026 The OpenGMaps Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license.
library;

/// Saved pins + recent searches, persisted across restarts in OHOS user
/// preferences (via [PreferencesStorage]).
///
/// Only places actually returned by the Places API are stored — nothing is
/// pre-seeded.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'google_places_service.dart';
import 'storage_service.dart';

class SavedPin {
  const SavedPin({
    required this.name,
    required this.address,
    required this.latLng,
    this.placeId = '',
  });

  factory SavedPin.fromDetails(PlaceDetails d) => SavedPin(
        name: d.name,
        address: d.address,
        latLng: d.latLng,
        placeId: d.placeId,
      );

  factory SavedPin.fromJson(Map<String, dynamic> json) {
    final List<Object?> ll = List<Object?>.from(json['latLng'] as List);
    return SavedPin(
      name: (json['name'] ?? '') as String,
      address: (json['address'] ?? '') as String,
      latLng: LatLng(
        (ll[0] as num).toDouble(),
        (ll[1] as num).toDouble(),
      ),
      placeId: (json['placeId'] ?? '') as String,
    );
  }

  final String name;
  final String address;
  final LatLng latLng;
  final String placeId;

  Map<String, Object?> toJson() => {
        'name': name,
        'address': address,
        'latLng': [latLng.latitude, latLng.longitude],
        'placeId': placeId,
      };

  String get id =>
      placeId.isNotEmpty
          ? 'pid:$placeId'
          : '$name|${latLng.latitude}|${latLng.longitude}';
}

class SavedPlacesService extends ChangeNotifier {
  SavedPlacesService._();
  static final SavedPlacesService instance = SavedPlacesService._();

  static const String _pinsKey = 'saved_pins_v1';
  static const String _searchesKey = 'recent_searches_v1';

  final PreferencesStorage _storage = PreferencesStorage.instance;

  final Map<String, SavedPin> _saved = {};
  final List<String> _recentSearches = [];
  bool _loaded = false;

  List<SavedPin> get saved => List.unmodifiable(_saved.values);
  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  /// Loads persisted state. Safe to call repeatedly; callers keep working
  /// (empty) until the first load notifies.
  Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final String? pinsRaw = await _storage.getString(_pinsKey);
      if (pinsRaw != null && pinsRaw.isNotEmpty) {
        final List<Object?> list =
            List<Object?>.from(jsonDecode(pinsRaw) as List);
        for (final Object? e in list) {
          try {
            final SavedPin pin =
                SavedPin.fromJson(Map<String, dynamic>.from(e as Map));
            if (pin.name.isNotEmpty) _saved[pin.id] = pin;
          } catch (_) {
            // Skip one corrupt entry, keep the rest.
          }
        }
      }
      final String? searchesRaw = await _storage.getString(_searchesKey);
      if (searchesRaw != null && searchesRaw.isNotEmpty) {
        final List<Object?> list =
            List<Object?>.from(jsonDecode(searchesRaw) as List);
        _recentSearches
          ..clear()
          ..addAll(list.map((Object? e) => '$e').where(
              (String q) => q.trim().isNotEmpty));
      }
      notifyListeners();
    } catch (_) {
      // Corrupt store: start clean rather than crash the tab.
      _saved.clear();
      _recentSearches.clear();
      notifyListeners();
    }
  }

  bool isSaved(SavedPin p) => _saved.containsKey(p.id);

  void toggle(SavedPin p) {
    if (_saved.containsKey(p.id)) {
      _saved.remove(p.id);
    } else {
      _saved[p.id] = p;
    }
    notifyListeners();
    unawaited(_persistPins());
  }

  void addSearch(String query) {
    final String q = query.trim();
    if (q.isEmpty) return;
    _recentSearches.remove(q);
    _recentSearches.insert(0, q);
    if (_recentSearches.length > 8) _recentSearches.removeLast();
    notifyListeners();
    unawaited(_persistSearches());
  }

  Future<void> _persistPins() async {
    try {
      await _storage.setString(
        _pinsKey,
        jsonEncode(_saved.values.map((SavedPin p) => p.toJson()).toList()),
      );
    } catch (_) {
      // Persistence is best-effort; in-memory state stays authoritative.
    }
  }

  Future<void> _persistSearches() async {
    try {
      await _storage.setString(_searchesKey, jsonEncode(_recentSearches));
    } catch (_) {
      // Best-effort, see above.
    }
  }
}
