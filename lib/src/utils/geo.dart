// Copyright 2026 The OpenGMaps Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license.
library;

/// Small geographic helpers over the stock `google_maps_flutter` types.
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// `lat,lng` pair for Google REST query params.
extension LatLngParam on LatLng {
  String get asParam => '$latitude,$longitude';
}
