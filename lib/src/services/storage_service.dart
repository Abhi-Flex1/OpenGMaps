// Copyright 2026 The OpenGMaps Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license.
library;

/// Tiny string key-value store backed by OHOS user preferences
/// (`io.opengmaps/storage`, see `EntryAbility.ets`).
///
/// Falls back to an in-memory map when no native host answers (widget
/// tests, other platforms), so callers never branch on platform.
import 'package:flutter/services.dart';

class PreferencesStorage {
  PreferencesStorage._();
  static final PreferencesStorage instance = PreferencesStorage._();

  static const MethodChannel _channel =
      MethodChannel('io.opengmaps/storage');

  final Map<String, String> _memory = {};
  bool _native = true;

  Future<String?> getString(String key) async {
    if (_native) {
      try {
        return await _channel.invokeMethod<String>('getString', {'key': key});
      } on MissingPluginException {
        _native = false;
      } catch (_) {
        return _memory[key];
      }
    }
    return _memory[key];
  }

  Future<void> setString(String key, String value) async {
    if (_native) {
      try {
        await _channel.invokeMethod<bool>(
            'setString', {'key': key, 'value': value});
        return;
      } on MissingPluginException {
        _native = false;
      } catch (_) {
        // Fall through to memory so a transient native failure
        // never loses the write for this session.
      }
    }
    _memory[key] = value;
  }

  Future<void> remove(String key) async {
    if (_native) {
      try {
        await _channel.invokeMethod<bool>('remove', {'key': key});
        return;
      } on MissingPluginException {
        _native = false;
      } catch (_) {
        // Fall through to memory.
      }
    }
    _memory.remove(key);
  }
}
