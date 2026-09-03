// Copyright 2026 The OpenGMaps Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license.

// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';

/// Builds the HTML/JS bootstrap for one OHOS map instance.
///
/// The JS side (`window.OhosMaps`) implements the whole
/// `google_maps_flutter` surface: camera ops, markers (incl. clustering +
/// info windows + dragging), polylines, polygons, circles, heatmaps, tile
/// overlays (tiles fetched from Dart), ground overlays, styling, projections
/// and every map event. Dart calls in via `evaluateJavascript`, JS calls out
/// via the `ohosEvent` / `ohosRequest` / `ohosTile` / `ohosError` handlers.
class OhosMapHtml {
  OhosMapHtml._();

  static String build({
    required String apiKey,
    required double lat,
    required double lng,
    required double zoom,
    required double tilt,
    required double bearing,
    required Map<String, Object?> options,
  }) {
    final String initJson = jsonEncode({
      'lat': lat,
      'lng': lng,
      'zoom': zoom,
      'tilt': tilt,
      'bearing': bearing,
      'options': options,
    });
    final String key = jsonEncode(apiKey);
    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<style>
html,body,#map{height:100%;margin:0;padding:0;background:#e8ecef}
#map{position:absolute;inset:0}
.ohos-tile-img{transition:opacity .25s ease}
</style>
</head>
<body>
<div id="map"></div>
<script>
(function(){
'use strict';
var INIT = $initJson;
var API_KEY = $key;
var stash = [];
function emit(ev){
  try {
    if (window.flutter_inappwebview) {
      window.flutter_inappwebview.callHandler('ohosEvent', ev);
    } else { stash.push(ev); }
  } catch (e) { stash.push(ev); }
}
function fail(message){
  try {
    if (window.flutter_inappwebview) {
      window.flutter_inappwebview.callHandler('ohosError', message);
    } else { stash.push({type:'mapError', message:String(message)}); }
  } catch (e) {}
}
window.gm_authFailure = function(){
  fail('Google Maps auth failed: invalid API key or Maps JavaScript API not enabled.');
};

var map = null;
var markers = {};
var markerToId = new Map();
var polylines = {};
var polygons = {};
var circles = {};
var heatmaps = {};
var tileOverlays = {};
var tileCache = {};
var tileWaiters = {};
var tileSeq = 0;
var groundOverlays = {};
var clusterers = {};
var markerCluster = {}; // markerId -> managerId
var infoWin = null;
var infoWinMarkerId = null;
var trafficLayer = null;
var userDot = null;
var userAcc = null;
var trackCamera = true;
var animHandle = 0;
var moveThrottle = 0;
var longPressTimer = null;
var downPos = null;

function css(color){
  if (color == null) return '#000000';
  var a = ((color >>> 24) & 255) / 255;
  var r = (color >> 16) & 255, g = (color >> 8) & 255, b = color & 255;
  if (a >= 0.999) return 'rgb(' + r + ',' + g + ',' + b + ')';
  return 'rgba(' + r + ',' + g + ',' + b + ',' + a.toFixed(3) + ')';
}
function opacityOf(color){
  if (color == null) return 1;
  return (((color >>> 24) & 255) / 255);
}
function hueColor(h){
  h = ((h % 360) + 360) % 360;
  var s = 0.85, v = 0.92, c = v * s;
  var x = c * (1 - Math.abs(((h / 60) % 2) - 1));
  var m = v - c, r = 0, g = 0, b = 0;
  if (h < 60) { r = c; g = x; } else if (h < 120) { r = x; g = c; }
  else if (h < 180) { g = c; b = x; } else if (h < 240) { g = x; b = c; }
  else if (h < 300) { r = x; b = c; } else { r = c; b = x; }
  r = Math.round((r + m) * 255); g = Math.round((g + m) * 255); b = Math.round((b + m) * 255);
  return 'rgb(' + r + ',' + g + ',' + b + ')';
}
function pinSvg(color){
  var svg = '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="64" viewBox="0 0 48 64">' +
    '<path d="M24 2C13 2 4 11 4 22c0 14 20 40 20 40s20-26 20-40C44 11 35 2 24 2z" fill="' + color + '"/>' +
    '<circle cx="24" cy="22" r="8" fill="white"/></svg>';
  return 'data:image/svg+xml;charset=UTF-8,' + encodeURIComponent(svg);
}
function iconFor(iconJson, anchor){
  if (!iconJson || iconJson.kind === 'default') {
    var color = (iconJson && iconJson.hue != null) ? hueColor(iconJson.hue) : '#EA4335';
    var url = pinSvg(color);
    return { url: url, scaledSize: new google.maps.Size(32, 43), anchor: new google.maps.Point(16, 41) };
  }
  if (iconJson.kind === 'url') {
    var out = { url: iconJson.url };
    if (iconJson.width != null && iconJson.height != null) {
      out.scaledSize = new google.maps.Size(iconJson.width, iconJson.height);
      out.anchor = new google.maps.Point(
        (anchor ? anchor[0] : 0.5) * iconJson.width,
        (anchor ? anchor[1] : 1.0) * iconJson.height);
    }
    return out;
  }
  if (iconJson.kind === 'pin') {
    try {
      var pin = new google.maps.marker.PinElement({
        background: iconJson.background || '#EA4335',
        borderColor: iconJson.border || '#ffffff',
        glyphColor: '#ffffff'
      });
      var g = iconJson.glyph;
      if (g && g.kind === 'text') {
        pin = new google.maps.marker.PinElement({
          background: iconJson.background || '#EA4335',
          borderColor: iconJson.border || '#ffffff',
          glyph: g.text || '',
          glyphColor: g.textColor || '#ffffff'
        });
      } else if (g && g.kind === 'circle') {
        var dot = document.createElement('div');
        dot.style.width = '12px'; dot.style.height = '12px';
        dot.style.borderRadius = '50%';
        dot.style.background = g.color || '#ffffff';
        pin = new google.maps.marker.PinElement({
          background: iconJson.background || '#EA4335',
          borderColor: iconJson.border || '#ffffff',
          glyph: dot
        });
      }
      return { element: pin.element };
    } catch (e) { return { url: pinSvg(iconJson.background || '#EA4335'), scaledSize: new google.maps.Size(32, 43) }; }
  }
  return null;
}
function cameraJson(){
  var c = map.getCenter();
  return { lat: c.lat(), lng: c.lng(), zoom: map.getZoom(), tilt: map.getTilt() || 0, bearing: map.getHeading() || 0 };
}
function sendCameraMove(){
  if (!trackCamera) return;
  var now = Date.now();
  if (now - moveThrottle < 120) return;
  moveThrottle = now;
  emit({ type: 'cameraMove', camera: cameraJson() });
}
function ll(o){ return new google.maps.LatLng(o[0], o[1]); }
function llList(a){ return (a || []).map(ll); }

// ---- Mercator helpers (focus-stable zoomBy without projection races) ----
function worldOf(lat, lng, zoom){
  var s = Math.sin(lat * Math.PI / 180);
  s = Math.min(Math.max(s, -0.9999), 0.9999);
  var x = (lng + 180) / 360;
  var y = 0.5 - Math.log((1 + s) / (1 - s)) / (4 * Math.PI);
  var scale = 256 * Math.pow(2, zoom);
  return { x: x * scale, y: y * scale };
}
function latLngOf(x, y, zoom){
  var scale = 256 * Math.pow(2, zoom);
  var lng = (x / scale) * 360 - 180;
  var n = Math.PI - 2 * Math.PI * (y / scale);
  var lat = 180 / Math.PI * Math.atan(0.5 * (Math.exp(n) - Math.exp(-n)));
  return { lat: lat, lng: lng };
}
function pxToLL(px, py, zoom){
  var c = map.getCenter();
  var cw = worldOf(c.lat(), c.lng(), zoom);
  var w = document.getElementById('map').offsetWidth;
  var h = document.getElementById('map').offsetHeight;
  return latLngOf(cw.x + (px - w / 2), cw.y + (py - h / 2), zoom);
}
function applyCam(target, zoom, tilt, heading, animate, durationMs){
  cancelAnimationFrame(animHandle);
  if (!animate) {
    if (target) map.setCenter(target);
    if (zoom != null) map.setZoom(zoom);
    if (tilt != null) { try { map.setTilt(tilt); } catch (e) {} }
    if (heading != null) { try { map.setHeading(heading); } catch (e) {} }
    return;
  }
  var c0 = map.getCenter();
  var start = { lat: c0.lat(), lng: c0.lng(), zoom: map.getZoom(),
    tilt: map.getTilt() || 0, heading: map.getHeading() || 0 };
  var end = {
    lat: target ? target.lat : start.lat,
    lng: target ? target.lng : start.lng,
    zoom: zoom != null ? zoom : start.zoom,
    tilt: tilt != null ? tilt : start.tilt,
    heading: heading != null ? heading : start.heading
  };
  var t0 = performance.now();
  var dur = durationMs != null ? durationMs : 800;
  function ease(t){ return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2; }
  function frame(now){
    var t = Math.min(1, (now - t0) / dur);
    var e = ease(t);
    map.setCenter({ lat: start.lat + (end.lat - start.lat) * e,
      lng: start.lng + (end.lng - start.lng) * e });
    map.setZoom(start.zoom + (end.zoom - start.zoom) * e);
    try {
      map.setTilt(start.tilt + (end.tilt - start.tilt) * e);
      map.setHeading(start.heading + (end.heading - start.heading) * e);
    } catch (err) {}
    if (t < 1) animHandle = requestAnimationFrame(frame);
  }
  emit({ type: 'cameraMoveStarted' });
  animHandle = requestAnimationFrame(frame);
}

// ---- markers ----
function ensureInfoWin(){
  if (infoWin) return infoWin;
  infoWin = new google.maps.InfoWindow();
  infoWin.addListener('domready', function(){
    var el = document.querySelector('.ohos-iw');
    if (el && !el.__ohosBound) {
      el.__ohosBound = true;
      el.addEventListener('click', function(){
        if (infoWinMarkerId != null) emit({ type: 'infoWindowTap', id: infoWinMarkerId });
      });
    }
  });
  infoWin.addListener('closeclick', function(){ infoWinMarkerId = null; });
  return infoWin;
}
function infoContent(m){
  var t = m.title || '', s = m.snippet || '';
  var html = '<div class="ohos-iw" style="font-family:Roboto,Arial,sans-serif;max-width:220px;cursor:pointer">' +
    (t ? '<div style="font-size:14px;font-weight:600;color:#202124">' + escapeHtml(t) + '</div>' : '') +
    (s ? '<div style="font-size:12px;color:#5f6368;margin-top:2px">' + escapeHtml(s) + '</div>' : '') + '</div>';
  return html;
}
function escapeHtml(x){
  return String(x).replace(/&/g, '&amp;').replace(/</g, '&lt;')
    .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}
function openInfo(id){
  var rec = markers[id];
  if (!rec) return;
  var m = rec.data;
  if (!m.title && !m.snippet) return;
  var iw = ensureInfoWin();
  iw.setContent(infoContent(m));
  if (rec.adv) iw.open({ map: map, anchor: rec.adv });
  else iw.open(map, rec.marker);
  infoWinMarkerId = id;
}
function makeMarker(m){
  var pos = { lat: m.lat, lng: m.lng };
  var icon = iconFor(m.icon, m.anchor);
  var isAdv = !!m.advanced;
  var marker = null, adv = null;
  if (isAdv) {
    try {
      var opts = { position: pos, map: null, title: m.title || '' };
      if (icon && icon.element) opts.content = icon.element;
      adv = new google.maps.marker.AdvancedMarkerElement(opts);
    } catch (e) { isAdv = false; }
  }
  if (!isAdv) {
    var mo = { position: pos, title: m.title || '', draggable: !!m.draggable,
      visible: m.visible !== false, clickable: true, zIndex: m.zIndex || 0 };
    if (icon && icon.url) {
      mo.icon = { url: icon.url };
      if (icon.scaledSize) mo.icon.scaledSize = icon.scaledSize;
      if (icon.anchor) mo.icon.anchor = icon.anchor;
    }
    if (m.opacity != null) mo.opacity = m.opacity;
    marker = new google.maps.Marker(mo);
  }
  var rec = { data: m, marker: marker, adv: adv };
  function fire(type, extra){
    var e = { type: type, id: m.id };
    if (extra) for (var k in extra) e[k] = extra[k];
    emit(e);
  }
  function posOf(src){
    var p = src.getPosition ? src.getPosition() : (src.position);
    return { lat: p.lat(), lng: p.lng() };
  }
  if (marker) {
    marker.addListener('click', function(){
      fire('markerTap');
      if (m.title || m.snippet) openInfo(m.id);
    });
    if (m.draggable) {
      marker.addListener('dragstart', function(){ var p = posOf(marker); fire('markerDragStart', p); });
      marker.addListener('drag', function(){ var p = posOf(marker); fire('markerDrag', p); });
      marker.addListener('dragend', function(){
        var p = posOf(marker);
        rec.data.lat = p.lat; rec.data.lng = p.lng;
        fire('markerDragEnd', p);
      });
    }
    markerToId.set(marker, m.id);
  } else if (adv) {
    adv.addListener('click', function(){
      fire('markerTap');
      if (m.title || m.snippet) openInfo(m.id);
    });
  }
  return rec;
}
function placeMarker(id){
  var rec = markers[id];
  if (!rec) return;
  var mgr = markerCluster[id];
  if (mgr && clusterers[mgr]) {
    if (rec.marker) rec.marker.setMap(null);
    if (rec.adv) rec.adv.map = null;
    clusterers[mgr].dirty = true;
  } else {
    if (rec.marker) rec.marker.setMap(rec.data.visible === false ? null : map);
    if (rec.adv) rec.adv.map = (rec.data.visible === false ? null : map);
  }
}
function refreshClusters(){
  Object.keys(clusterers).forEach(function(mgr){
    var c = clusterers[mgr];
    if (!c.dirty) return;
    c.dirty = false;
    var list = [];
    Object.keys(markers).forEach(function(id){
      if (markerCluster[id] === mgr) {
        var rec = markers[id];
        if (rec.marker && rec.data.visible !== false) list.push(rec.marker);
      }
    });
    try {
      c.clusterer.clearMarkers();
      c.clusterer.addMarkers(list);
    } catch (e) {}
  });
}
function setMarkers(diff){
  (diff.remove || []).forEach(function(id){
    var rec = markers[id];
    if (rec) {
      if (rec.marker) { rec.marker.setMap(null); markerToId.delete(rec.marker); }
      if (rec.adv) rec.adv.map = null;
      delete markers[id];
    }
    delete markerCluster[id];
  });
  (diff.add || []).concat(diff.change || []).forEach(function(m){
    var old = markers[m.id];
    if (old) {
      if (old.marker) { old.marker.setMap(null); markerToId.delete(old.marker); }
      if (old.adv) old.adv.map = null;
    }
    markers[m.id] = makeMarker(m);
    if (m.cluster) markerCluster[m.id] = m.cluster;
    else delete markerCluster[m.id];
  });
  Object.keys(markers).forEach(placeMarker);
  refreshClusters();
}

// ---- polylines / polygons / circles ----
function patternIcons(patterns, color, width){
  if (!patterns || !patterns.length) return undefined;
  var dash = null, gap = null, dot = false;
  patterns.forEach(function(p){
    if (p[0] === 'dash') dash = p[1];
    else if (p[0] === 'gap') gap = p[1];
    else if (p[0] === 'dot') dot = true;
  });
  if (dot) {
    return [{ icon: { path: google.maps.SymbolPath.CIRCLE, scale: Math.max(1, width / 2),
      strokeOpacity: 0, fillColor: color, fillOpacity: 1 }, offset: '0', repeat: (width + 4) + 'px' }];
  }
  if (dash != null) {
    var rep = dash + (gap != null ? gap : dash);
    return [{ icon: { path: 'M 0,-1 0,1', strokeOpacity: 1, strokeColor: color, strokeWeight: width },
      offset: '0', repeat: rep + 'px' }];
  }
  return undefined;
}
function setPolylines(diff){
  (diff.remove || []).forEach(function(id){ if (polylines[id]) { polylines[id].setMap(null); delete polylines[id]; } });
  (diff.add || []).concat(diff.change || []).forEach(function(p){
    if (polylines[p.id]) polylines[p.id].setMap(null);
    var col = css(p.color);
    var line = new google.maps.Polyline({
      path: llList(p.points), strokeColor: col, strokeOpacity: opacityOf(p.color),
      strokeWeight: p.width || 10, visible: p.visible !== false,
      zIndex: p.zIndex || 0, geodesic: !!p.geodesic,
      clickable: !!p.clickable, map: (p.visible === false ? null : map)
    });
    var icons = patternIcons(p.patterns, col, p.width || 10);
    if (icons) line.setOptions({ icons: icons, strokeOpacity: (dashOnly(p) ? 0 : opacityOf(p.color)) });
    line.addListener('click', function(){ emit({ type: 'polylineTap', id: p.id }); });
    polylines[p.id] = line;
  });
}
function dashOnly(p){
  if (!p.patterns) return false;
  return p.patterns.some(function(x){ return x[0] === 'dash' || x[0] === 'dot' || x[0] === 'gap'; });
}
function setPolygons(diff){
  (diff.remove || []).forEach(function(id){ if (polygons[id]) { polygons[id].setMap(null); delete polygons[id]; } });
  (diff.add || []).concat(diff.change || []).forEach(function(p){
    if (polygons[p.id]) polygons[p.id].setMap(null);
    var paths = [llList(p.points)].concat((p.holes || []).map(llList));
    var poly = new google.maps.Polygon({
      paths: paths, fillColor: css(p.fillColor), fillOpacity: opacityOf(p.fillColor),
      strokeColor: css(p.strokeColor), strokeOpacity: opacityOf(p.strokeColor),
      strokeWeight: p.strokeWidth != null ? p.strokeWidth : 10,
      visible: p.visible !== false, zIndex: p.zIndex || 0, geodesic: !!p.geodesic,
      clickable: !!p.clickable, map: (p.visible === false ? null : map)
    });
    poly.addListener('click', function(){ emit({ type: 'polygonTap', id: p.id }); });
    polygons[p.id] = poly;
  });
}
function setCircles(diff){
  (diff.remove || []).forEach(function(id){ if (circles[id]) { circles[id].setMap(null); delete circles[id]; } });
  (diff.add || []).concat(diff.change || []).forEach(function(c){
    if (circles[c.id]) circles[c.id].setMap(null);
    var circ = new google.maps.Circle({
      center: { lat: c.lat, lng: c.lng }, radius: c.radius || 0,
      fillColor: css(c.fillColor), fillOpacity: opacityOf(c.fillColor),
      strokeColor: css(c.strokeColor), strokeOpacity: opacityOf(c.strokeColor),
      strokeWeight: c.strokeWidth != null ? c.strokeWidth : 10,
      visible: c.visible !== false, zIndex: c.zIndex || 0,
      clickable: !!c.clickable, map: (c.visible === false ? null : map)
    });
    circ.addListener('click', function(){ emit({ type: 'circleTap', id: c.id }); });
    circles[c.id] = circ;
  });
}

// ---- heatmaps ----
function sampleGradient(colors, starts, n){
  function hex(c){
    if (c[0] === '#') {
      var v = c.slice(1);
      if (v.length === 3) v = v[0]+v[0]+v[1]+v[1]+v[2]+v[2];
      var num = parseInt(v.slice(0, 6), 16);
      var a = v.length >= 8 ? parseInt(v.slice(6, 8), 16) / 255 : 1;
      return [(num >> 16) & 255, (num >> 8) & 255, num & 255, a];
    }
    return [0, 0, 0, 1];
  }
  var stops = colors.map(function(c, i){ return { at: starts[i], rgba: hex(c) }; });
  stops.sort(function(a, b){ return a.at - b.at; });
  var out = [];
  for (var i = 0; i < n; i++) {
    var t = i / (n - 1), a = stops[0], b = stops[stops.length - 1];
    for (var j = 0; j < stops.length - 1; j++) {
      if (t >= stops[j].at && t <= stops[j + 1].at) { a = stops[j]; b = stops[j + 1]; break; }
    }
    var span = Math.max(1e-6, b.at - a.at);
    var f = Math.min(1, Math.max(0, (t - a.at) / span));
    var r = Math.round(a.rgba[0] + (b.rgba[0] - a.rgba[0]) * f);
    var g = Math.round(a.rgba[1] + (b.rgba[1] - a.rgba[1]) * f);
    var bl = Math.round(a.rgba[2] + (b.rgba[2] - a.rgba[2]) * f);
    var al = a.rgba[3] + (b.rgba[3] - a.rgba[3]) * f;
    out.push('rgba(' + r + ',' + g + ',' + bl + ',' + al.toFixed(3) + ')');
  }
  return out;
}
function setHeatmaps(diff){
  (diff.remove || []).forEach(function(id){
    if (heatmaps[id]) { heatmaps[id].layer.setMap(null); delete heatmaps[id]; }
  });
  (diff.add || []).concat(diff.change || []).forEach(function(h){
    if (heatmaps[id0(h)]) heatmaps[id0(h)].layer.setMap(null);
    if (!google.maps.visualization) return;
    var data = (h.data || []).map(function(d){
      return { location: new google.maps.LatLng(d[0][0], d[0][1]), weight: d[1] };
    });
    var opts = { data: data, dissipating: h.dissipating !== false,
      opacity: h.opacity != null ? h.opacity : 0.7,
      radius: h.radius || 20 };
    if (h.maxIntensity != null) opts.maxIntensity = h.maxIntensity;
    if (h.gradient) opts.gradient = sampleGradient(h.gradient.colors, h.gradient.starts, 32);
    var layer = new google.maps.visualization.HeatmapLayer(opts);
    layer.setMap(map);
    var rec = { layer: layer, data: h, minZ: h.minZ || 0, maxZ: h.maxZ != null ? h.maxZ : 21 };
    heatmaps[h.id] = rec;
    applyHeatZoom(rec);
  });
  function id0(h){ return h.id; }
}
function applyHeatZoom(rec){
  var z = map.getZoom();
  rec.layer.setMap((z >= rec.minZ && z <= rec.maxZ) ? map : null);
}

// ---- tile overlays ----
function rebuildTiles(){
  var ids = Object.keys(tileOverlays).sort(function(a, b){
    return (tileOverlays[a].zIndex || 0) - (tileOverlays[b].zIndex || 0);
  });
  map.overlayMapTypes.clear();
  ids.forEach(function(id){
    var t = tileOverlays[id];
    if (t.visible === false) return;
    var layer = new google.maps.ImageMapType({
      tileSize: new google.maps.Size(t.tileSize || 256, t.tileSize || 256),
      opacity: 1 - (t.transparency || 0),
      name: id,
      getTile: function(coord, zoom, ownerDoc){ return makeTile(id, coord, zoom, ownerDoc); }
    });
    map.overlayMapTypes.push(layer);
  });
}
function makeTile(id, coord, zoom, ownerDoc){
  var key = coord.x + ':' + coord.y + ':' + zoom;
  var div = ownerDoc.createElement('div');
  var size = (tileOverlays[id] && tileOverlays[id].tileSize) || 256;
  div.style.width = size + 'px'; div.style.height = size + 'px';
  var cached = tileCache[id + '|' + key];
  if (cached) {
    var img = ownerDoc.createElement('img');
    img.className = 'ohos-tile-img';
    img.style.width = '100%'; img.style.height = '100%';
    if (tileOverlays[id] && tileOverlays[id].fadeIn !== false) {
      img.style.opacity = '0';
      img.onload = function(){ img.style.opacity = '1'; };
    }
    img.src = cached;
    div.appendChild(img);
    return div;
  }
  var token = 't' + (++tileSeq);
  tileWaiters[token] = { doc: null, divs: [div], id: id, key: key, zoom: zoom };
  try {
    window.flutter_inappwebview.callHandler(
      'ohosTile', { overlayId: id, x: coord.x, y: coord.y, zoom: zoom, token: token });
  } catch (e) {}
  return div;
}
window.__ohosTileResponse = function(token, dataUrl){
  var w = tileWaiters[token];
  if (!w) return;
  delete tileWaiters[token];
  if (!dataUrl) return;
  tileCache[w.id + '|' + w.key] = dataUrl;
  w.divs.forEach(function(div){
    if (!div.isConnected && !div.parentNode) return;
    var img = document.createElement('img');
    img.className = 'ohos-tile-img';
    img.style.width = '100%'; img.style.height = '100%';
    img.src = dataUrl;
    div.appendChild(img);
  });
};
function setTileOverlays(list){
  tileOverlays = {};
  (list || []).forEach(function(t){ tileOverlays[t.id] = t; });
  rebuildTiles();
}
function clearTileCache(id){
  Object.keys(tileCache).forEach(function(k){
    if (!id || k.indexOf(id + '|') === 0) delete tileCache[k];
  });
  if (!id) rebuildTiles();
}

// ---- ground overlays ----
function setGroundOverlays(diff){
  (diff.remove || []).forEach(function(id){
    if (groundOverlays[id]) { groundOverlays[id].setMap(null); delete groundOverlays[id]; }
  });
  (diff.add || []).concat(diff.change || []).forEach(function(g){
    if (groundOverlays[g.id]) groundOverlays[g.id].setMap(null);
    var bounds = null;
    if (g.bounds) {
      bounds = { south: g.bounds[0][0], west: g.bounds[0][1], north: g.bounds[1][0], east: g.bounds[1][1] };
    } else if (g.position && g.width != null && g.height != null) {
      var c = new google.maps.LatLng(g.position[0], g.position[1]);
      var sw = google.maps.geometry.spherical.computeOffset(
        google.maps.geometry.spherical.computeOffset(c, g.width / 2, 270), g.height / 2, 180);
      var ne = google.maps.geometry.spherical.computeOffset(
        google.maps.geometry.spherical.computeOffset(c, g.width / 2, 90), g.height / 2, 0);
      bounds = { south: sw.lat(), west: sw.lng(), north: ne.lat(), east: ne.lng() };
    } else { return; }
    var ov = new google.maps.GroundOverlay(g.url, bounds,
      { opacity: 1 - (g.transparency || 0), clickable: g.clickable !== false });
    ov.setMap(g.visible === false ? null : map);
    if (g.zIndex) { try { ov.setZIndex(g.zIndex); } catch (e) {} }
    ov.addListener('click', function(){ emit({ type: 'groundOverlayTap', id: g.id }); });
    groundOverlays[g.id] = ov;
  });
}

// ---- options ----
var hideAllStyle = [{ featureType: 'all', elementType: 'all', stylers: [{ visibility: 'off' }] }];
function applyOptions(o){
  if (!o) return;
  if (o.mapType != null) {
    map.setMapTypeId(o.mapType === 'none' ? 'roadmap' : o.mapType);
    if (o.mapType === 'none') map.setOptions({ styles: hideAllStyle });
    else if (o.styles !== undefined) map.setOptions({ styles: o.styles });
  } else if (o.styles !== undefined) {
    map.setOptions({ styles: o.styles });
  }
  if (o.minZoom != null || o.maxZoom != null)
    map.setOptions({ minZoom: o.minZoom, maxZoom: o.maxZoom });
  if (o.restriction !== undefined) map.setOptions({ restriction: o.restriction });
  if (o.zoomControl != null) map.setOptions({ zoomControl: o.zoomControl });
  if (o.scrollwheel != null) map.setOptions({ scrollwheel: o.scrollwheel });
  if (o.draggable != null) map.setOptions({ draggable: o.draggable });
  if (o.disableDoubleClickZoom != null) map.setOptions({ disableDoubleClickZoom: o.disableDoubleClickZoom });
  if (o.gestureHandling != null) map.setOptions({ gestureHandling: o.gestureHandling });
  if (o.tilt != null) { try { map.setTilt(o.tilt); } catch (e) {} }
  if (o.traffic !== undefined) {
    if (o.traffic && !trafficLayer) { trafficLayer = new google.maps.TrafficLayer(); trafficLayer.setMap(map); }
    if (!o.traffic && trafficLayer) { trafficLayer.setMap(null); trafficLayer = null; }
  }
  if (o.trackCamera != null) trackCamera = !!o.trackCamera;
}

// ---- requests (getters) ----
function respond(id, ok, value){
  try {
    window.flutter_inappwebview.callHandler(
      'ohosRequest', ok ? { id: id, value: value } : { id: id, error: String(value) });
  } catch (e) {}
}

// ---- public bridge ----
window.OhosMaps = {
  flush: function(){
    var q = stash; stash = [];
    q.forEach(function(ev){
      if (ev.type === 'mapError') fail(ev.message);
      else emit(ev);
    });
  },
  init: function(){},
  _ready: function(){
    try { window.flutter_inappwebview.callHandler('ohosReady'); } catch (e) {}
  },
  setOptions: applyOptions,
  setMarkers: setMarkers,
  setPolylines: setPolylines,
  setPolygons: setPolygons,
  setCircles: setCircles,
  setHeatmaps: setHeatmaps,
  setTileOverlays: setTileOverlays,
  setGroundOverlays: setGroundOverlays,
  clearTileCache: clearTileCache,
  setClusterManagers: function(ids){
    (ids || []).forEach(function(id){
      if (!clusterers[id]) {
        try {
          var Cls = window.markerClusterer && window.markerClusterer.MarkerClusterer;
          if (!Cls) return;
          var clusterer = new Cls({ map: map, markers: [] });
          clusterer.addListener('click', function(cluster){
            var mids = [];
            try {
              (cluster.markers || []).forEach(function(mk){
                var mid = markerToId.get(mk);
                if (mid) mids.push(mid);
              });
            } catch (e) {}
            var b = null, pos = { lat: 0, lng: 0 };
            try {
              if (cluster.bounds) {
                var bb = cluster.bounds;
                b = [[bb.getSouthWest().lat(), bb.getSouthWest().lng()],
                     [bb.getNorthEast().lat(), bb.getNorthEast().lng()]];
              }
              if (cluster.position) pos = { lat: cluster.position.lat(), lng: cluster.position.lng() };
            } catch (e) {}
            emit({ type: 'clusterTap', managerId: id, position: pos, bounds: b, markerIds: mids });
          });
          clusterers[id] = { clusterer: clusterer, dirty: true };
        } catch (e) {}
      }
    });
    Object.keys(clusterers).forEach(function(id){
      if ((ids || []).indexOf(id) < 0) {
        try { clusterers[id].clusterer.clearMarkers(); clusterers[id].clusterer.setMap(null); } catch (e) {}
        delete clusterers[id];
      }
    });
    Object.keys(markers).forEach(placeMarker);
    refreshClusters();
  },
  moveCamera: function(op){ applyCamOp(op, false, 0); },
  animateCamera: function(op, durationMs){ applyCamOp(op, true, durationMs); },
  showInfoWindow: function(id){ openInfo(id); },
  hideInfoWindow: function(id){
    if (infoWin && infoWinMarkerId === id) { infoWin.close(); infoWinMarkerId = null; }
  },
  isInfoWindowShown: function(id, reqId){ respond(reqId, true, infoWinMarkerId === id); },
  getVisibleRegion: function(reqId){
    var b = map.getBounds();
    if (!b) { respond(reqId, false, 'Map bounds unavailable yet'); return; }
    var sw = b.getSouthWest(), ne = b.getNorthEast();
    respond(reqId, true, [[sw.lat(), sw.lng()], [ne.lat(), ne.lng()]]);
  },
  getScreenCoordinate: function(lat, lng, reqId){
    try {
      var p = map.getProjection().fromLatLngToDivPixel(new google.maps.LatLng(lat, lng));
      respond(reqId, true, { x: Math.round(p.x), y: Math.round(p.y) });
    } catch (e) { respond(reqId, false, String(e)); }
  },
  getLatLng: function(x, y, reqId){
    try {
      var llp = map.getProjection().fromDivPixelToLatLng(new google.maps.Point(x, y));
      respond(reqId, true, [llp.lat(), llp.lng()]);
    } catch (e) { respond(reqId, false, String(e)); }
  },
  getZoom: function(reqId){ respond(reqId, true, map.getZoom()); },
  getCamera: function(reqId){ respond(reqId, true, cameraJson()); },
  setMyLocation: function(lat, lng){
    if (userDot) { userDot.setMap(null); userDot = null; }
    if (userAcc) { userAcc.setMap(null); userAcc = null; }
    if (lat == null || lng == null) return;
    var pos = { lat: lat, lng: lng };
    userAcc = new google.maps.Circle({ center: pos, radius: 60, map: map,
      fillColor: '#1A73E8', fillOpacity: 0.15,
      strokeColor: '#1A73E8', strokeOpacity: 0.3, strokeWeight: 1 });
    userDot = new google.maps.Marker({ position: pos, map: map, title: 'My location',
      clickable: false,
      icon: { path: google.maps.SymbolPath.CIRCLE, scale: 9,
        fillColor: '#1A73E8', fillOpacity: 1, strokeColor: '#ffffff', strokeWeight: 3 } });
  }
};
function applyCamOp(op, animate, durationMs){
  if (!op) return;
  emit({ type: 'cameraMoveStarted' });
  switch (op.kind) {
    case 'newCameraPosition': {
      var p = op.position;
      applyCam({ lat: p[0], lng: p[1] }, p[2], p[3], p[4], animate, durationMs);
      break;
    }
    case 'newLatLng':
      applyCam({ lat: op.lat, lng: op.lng }, null, null, null, animate, durationMs);
      break;
    case 'newLatLngZoom':
      applyCam({ lat: op.lat, lng: op.lng }, op.zoom, null, null, animate, durationMs);
      break;
    case 'newLatLngBounds': {
      cancelAnimationFrame(animHandle);
      map.fitBounds({ south: op.sw[0], west: op.sw[1], north: op.ne[0], east: op.ne[1] }, op.padding || 0);
      break;
    }
    case 'scrollBy':
      cancelAnimationFrame(animHandle);
      map.panBy(op.dx, op.dy);
      break;
    case 'zoomBy': {
      var z = map.getZoom() + op.amount;
      if (op.focus) {
        var f = pxToLL(op.focus[0], op.focus[1], map.getZoom());
        var w0 = worldOf(f.lat, f.lng, map.getZoom());
        var w1 = worldOf(f.lat, f.lng, z);
        var c = map.getCenter();
        var cw = worldOf(c.lat(), c.lng(), z);
        var div = document.getElementById('map');
        var want = { x: cw.x + ((w1.x - cw.x) - (op.focus[0] - div.offsetWidth / 2)),
                     y: cw.y + ((w1.y - cw.y) - (op.focus[1] - div.offsetHeight / 2)) };
        var nc = latLngOf(want.x, want.y, z);
        if (animate) applyCam({ lat: nc.lat, lng: nc.lng }, z, null, null, true, durationMs);
        else { map.setZoom(z); map.setCenter(nc); }
      } else if (animate) applyCam(null, z, null, null, true, durationMs);
      else map.setZoom(z);
      break;
    }
    case 'zoomIn': case 'zoomOut': {
      var dz = op.kind === 'zoomIn' ? 1 : -1;
      if (animate) applyCam(null, map.getZoom() + dz, null, null, true, durationMs);
      else map.setZoom(map.getZoom() + dz);
      break;
    }
    case 'zoomTo':
      if (animate) applyCam(null, op.zoom, null, null, true, durationMs);
      else map.setZoom(op.zoom);
      break;
  }
}
window.OhosMaps._init = function(){
  try {
    var o = INIT.options || {};
    map = new google.maps.Map(document.getElementById('map'), {
      center: { lat: INIT.lat, lng: INIT.lng },
      zoom: INIT.zoom,
      tilt: INIT.tilt || 0,
      heading: INIT.bearing || 0,
      mapTypeId: o.mapType && o.mapType !== 'none' ? o.mapType : 'roadmap',
      mapId: o.cloudMapId || undefined,
      minZoom: o.minZoom, maxZoom: o.maxZoom,
      restriction: o.restriction || undefined,
      zoomControl: o.zoomControl !== false,
      mapTypeControl: false, streetViewControl: false, fullscreenControl: false,
      rotateControl: false,
      scrollwheel: o.scrollwheel !== false,
      draggable: o.draggable !== false,
      disableDoubleClickZoom: !!o.disableDoubleClickZoom,
      gestureHandling: o.gestureHandling || 'greedy',
      clickableIcons: true
    });
    if (o.mapType === 'none') map.setOptions({ styles: hideAllStyle });
    else if (o.styles) map.setOptions({ styles: o.styles });
    if (o.tilt) { try { map.setTilt(o.tilt); } catch (e) {} }
    if (o.traffic) { trafficLayer = new google.maps.TrafficLayer(); trafficLayer.setMap(map); }
    if (o.trackCamera != null) trackCamera = !!o.trackCamera;
    map.addListener('click', function(e){
      // Place-icon taps carry a placeId (IconMouseEvent). Like the native
      // SDKs (Android onPoiClick / iOS didTapPOI), those are reported as
      // POI taps only — not as plain map taps.
      if (e.placeId) {
        emit({ type: 'poiTap', placeId: e.placeId,
          lat: e.latLng.lat(), lng: e.latLng.lng() });
      } else {
        emit({ type: 'mapTap', lat: e.latLng.lat(), lng: e.latLng.lng() });
      }
    });
    map.addListener('mousedown', function(e){
      downPos = { x: e.domEvent.clientX, y: e.domEvent.clientY, lat: e.latLng.lat(), lng: e.latLng.lng() };
      if (longPressTimer) clearTimeout(longPressTimer);
      longPressTimer = setTimeout(function(){
        if (downPos) emit({ type: 'mapLongPress', lat: downPos.lat, lng: downPos.lng });
        downPos = null;
      }, 550);
    });
    map.addListener('mousemove', function(e){
      if (downPos && e.domEvent) {
        var dx = e.domEvent.clientX - downPos.x, dy = e.domEvent.clientY - downPos.y;
        if (dx * dx + dy * dy > 100) { downPos = null; if (longPressTimer) clearTimeout(longPressTimer); }
      }
    });
    map.addListener('mouseup', function(){
      downPos = null; if (longPressTimer) clearTimeout(longPressTimer);
    });
    map.addListener('dragstart', function(){ emit({ type: 'cameraMoveStarted' }); });
    map.addListener('center_changed', sendCameraMove);
    map.addListener('zoom_changed', function(){
      sendCameraMove();
      Object.keys(heatmaps).forEach(function(id){ applyHeatZoom(heatmaps[id]); });
    });
    map.addListener('idle', function(){ emit({ type: 'cameraIdle' }); });
    try {
      var mc = document.createElement('script');
      mc.src = 'https://unpkg.com/@googlemaps/markerclusterer@2.5.3/dist/index.umd.min.js';
      mc.async = true;
      document.head.appendChild(mc);
    } catch (e) {}
    window.OhosMaps._ready();
  } catch (err) {
    fail(String(err && err.stack || err));
  }
};
var mapsScript = document.createElement('script');
mapsScript.src = 'https://maps.googleapis.com/maps/api/js?key=' + API_KEY +
  '&libraries=geometry,marker,visualization&v=weekly&callback=OhosMaps._init';
mapsScript.async = true;
mapsScript.defer = true;
mapsScript.onerror = function(){
  fail('Failed to load the Google Maps JavaScript API. Check network access and the API key.');
};
document.head.appendChild(mapsScript);
setTimeout(function(){
  if (!map) fail('Google Maps did not initialize in time. Check the API key and enabled APIs.');
}, 20000);
})();
</script>
</body>
</html>
''';
  }
}
