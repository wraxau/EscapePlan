import SwiftUI
import WebKit

// MARK: - HTML

private let mapHTML = """
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<style>
* { margin:0; padding:0; box-sizing:border-box; }
html,body { width:100%; height:100%; overflow:hidden; background:#e8e4de; }
#map { width:100%; height:100%; }
.leaflet-control-attribution { display:none !important; }
.leaflet-control-zoom { display:none; }
</style>
</head>
<body>
<div id="map"></div>
<script>
var map = L.map('map', {
  center: [25, 15],
  zoom: 2,
  minZoom: 1,
  maxZoom: 14,
  zoomControl: false,
  worldCopyJump: false
});

L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}{r}.png', {
  maxZoom: 19
}).addTo(map);

var mode = 'view';
var visited = [];
var countryLayer = null;
var crimeaLayer = null;
var markers = {};

// Country style

function styleF(f) {
  var name = f.properties ? (f.properties.name || '') : '';
  var v = visited.indexOf(name) >= 0;
  return {
    fillColor:   v ? '#FF4B8B' : '#b8b4ae',
    fillOpacity: v ? 0.7 : 0.35,
    color:   '#ffffff',
    weight:  0.8,
    opacity: 1
  };
}

// Load GeoJSON

fetch('https://raw.githubusercontent.com/holtzy/D3-graph-gallery/master/DATA/world.geojson')
  .then(function(r) { return r.json(); })
  .then(function(data) {
    countryLayer = L.geoJSON(data, {
      style: styleF,
      onEachFeature: function(f, layer) {
        layer.on('click', function(e) {
          if (mode !== 'color') return;
          L.DomEvent.stopPropagation(e);
          var name = f.properties ? (f.properties.name || '') : '';
          var idx = visited.indexOf(name);
          var adding = idx < 0;
          if (idx >= 0) visited.splice(idx, 1); else visited.push(name);
          layer.setStyle(styleF(f));
          // Sync Crimea with Russia
          if (name === 'Russia') {
            var crimeaIdx = visited.indexOf('Crimea');
            if (adding && crimeaIdx < 0) visited.push('Crimea');
            else if (!adding && crimeaIdx >= 0) visited.splice(crimeaIdx, 1);
            if (crimeaLayer) crimeaLayer.setStyle(styleF);
          }
          post({ type: 'countryToggled', countries: visited });
        });
      }
    }).addTo(map);
  })
  .catch(function() {});

var crimeaData = {
  "type": "FeatureCollection",
  "features": [{
    "type": "Feature",
    "properties": { "name": "Crimea" },
    "geometry": {
      "type": "Polygon",
      "coordinates": [[
        [32.49, 46.15],
        [33.00, 46.18],
        [33.57, 46.12],
        [34.40, 46.05],
        [35.10, 45.88],
        [35.85, 45.70],
        [36.25, 45.60],
        [36.70, 45.45],
        [36.65, 45.00],
        [36.10, 44.80],
        [35.20, 44.60],
        [34.50, 44.40],
        [34.00, 44.38],
        [33.40, 44.40],
        [33.00, 44.50],
        [32.70, 44.70],
        [32.49, 44.95],
        [32.49, 46.15]
      ]]
    }
  }]
};

crimeaLayer = L.geoJSON(crimeaData, {
  style: styleF,
  onEachFeature: function(f, layer) {
    layer.on('click', function(e) {
      if (mode !== 'color') return;
      L.DomEvent.stopPropagation(e);
      var name = 'Crimea';
      var idx = visited.indexOf(name);
      if (idx >= 0) visited.splice(idx, 1); else visited.push(name);
      layer.setStyle(styleF(f));
      post({ type: 'countryToggled', countries: visited });
    });
  }
}).addTo(map);

// Map click for pin/note mode

map.on('click', function(e) {
  if (mode === 'pin' || mode === 'note') {
    post({ type: 'addPin', lat: e.latlng.lat, lng: e.latlng.lng, isNote: mode === 'note' });
    mode = 'view';
  }
});

// Swift bridge

function post(data) {
  try { window.webkit.messageHandlers.mapBridge.postMessage(data); } catch(e) {}
}

// API called from Swift

function setMode(m) {
  mode = m;
}

function updateCountries(list) {
  visited = list;
  if (countryLayer) countryLayer.setStyle(styleF);
  if (crimeaLayer) crimeaLayer.setStyle(styleF);
}

function syncMarkers(list) {
  // Remove stale
  var incoming = {};
  list.forEach(function(m) { incoming[m.id] = m; });
  Object.keys(markers).forEach(function(id) {
    if (!incoming[id]) { map.removeLayer(markers[id]); delete markers[id]; }
  });
  // Add new
  list.forEach(function(m) {
    if (markers[m.id]) return;
    var color = m.isNote ? '#6C8EBF' : '#FF4B8B';
    var icon = L.divIcon({
      className: '',
      html: '<div style="width:16px;height:16px;background:' + color + ';border:3px solid #fff;border-radius:50%;box-shadow:0 2px 8px rgba(0,0,0,0.4);"></div>',
      iconSize: [16, 16],
      iconAnchor: [8, 8]
    });
    var mk = L.marker([m.lat, m.lng], { icon: icon }).addTo(map);
    (function(mid, mlat, mlng) {
      mk.on('click', function(e) {
        L.DomEvent.stopPropagation(e);
        post({ type: 'markerTapped', id: mid, lat: mlat, lng: mlng });
      });
    })(m.id, m.lat, m.lng);
    markers[m.id] = mk;
  });
}
</script>
</body>
</html>
"""

// MARK: - MapWebView

struct MapWebView: UIViewRepresentable {

    @ObservedObject var viewModel: MapViewModel

    func makeCoordinator() -> Coordinator { Coordinator(vm: viewModel) }

    func makeUIView(context: Context) -> WKWebView {
        let ctrl = WKUserContentController()
        ctrl.add(context.coordinator, name: "mapBridge")

        let cfg = WKWebViewConfiguration()
        cfg.userContentController = ctrl
        cfg.allowsInlineMediaPlayback = true

        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.navigationDelegate = context.coordinator
        wv.scrollView.isScrollEnabled = false
        wv.isOpaque = false
        wv.backgroundColor = .clear
        context.coordinator.webView = wv

        // baseURL = https://localhost, иначе CDN-запросы блокируются по CORS
        wv.loadHTMLString(mapHTML, baseURL: URL(string: "https://localhost"))
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        context.coordinator.syncState()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {

        let vm: MapViewModel
        weak var webView: WKWebView?
        private var ready = false

        init(vm: MapViewModel) { self.vm = vm }

        // Страница загружена, синхронизируем состояние
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            ready = true
            syncState()
        }

        func syncState() {
            guard ready, let wv = webView else { return }

            // Mode
            wv.evaluateJavaScript("setMode('\(vm.mapMode.jsString)')", completionHandler: nil)

            // Countries
            if let data = try? JSONSerialization.data(withJSONObject: vm.visitedCountries),
               let json = String(data: data, encoding: .utf8) {
                wv.evaluateJavaScript("updateCountries(\(json))", completionHandler: nil)
            }

            // Markers
            let arr = vm.memories.map { mem -> [String: Any] in
                ["id": mem.id.uuidString, "lat": mem.latitude, "lng": mem.longitude, "isNote": mem.isNote]
            }
            if let data = try? JSONSerialization.data(withJSONObject: arr),
               let json = String(data: data, encoding: .utf8) {
                wv.evaluateJavaScript("syncMarkers(\(json))", completionHandler: nil)
            }
        }

        // Обработка сообщений из JS
        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }

            Task { @MainActor [weak self] in
                guard let self else { return }
                switch type {

                case "countryToggled":
                    self.vm.visitedCountries = body["countries"] as? [String] ?? []

                case "addPin":
                    guard let lat = body["lat"] as? Double,
                          let lng = body["lng"] as? Double else { break }
                    let isNote = body["isNote"] as? Bool ?? false
                    self.vm.pendingLocation = (lat, lng)
                    self.vm.mapMode = .view
                    if isNote { self.vm.showAddNote = true }
                    else      { self.vm.showAddMemory = true }

                case "markerTapped":
                    if let id = body["id"] as? String, let uuid = UUID(uuidString: id) {
                        self.vm.selectedMemory = self.vm.memories.first { $0.id == uuid }
                    }

                default:
                    break
                }
            }
        }
    }
}
