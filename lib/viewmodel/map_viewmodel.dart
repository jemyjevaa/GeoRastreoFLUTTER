
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/route_model.dart';
import '../service/RequestServ.dart';
import '../service/SocketServ.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapViewModel extends ChangeNotifier {
  // Colores (pueden moverse a un archivo de temas si se prefiere)
  final Color colorAmarillo = const Color(0xFFF69D32);
  final Color colorAzulFuerte = const Color(0xFF14143A);

  // Estado
  List<RouteModel> _allRoutes = [];
  List<RouteModel> _filteredRoutes = [];
  final List<RouteModel> _selectedRoutes = [];
  bool _isLoadingRoutes = false;
  String _searchQuery = '';

  /// MAP
  GoogleMapController? _mapController;
  BitmapDescriptor? _unitIconOn;
  BitmapDescriptor? _unitIconOff;

  // Método correcto para onMapCreated
  void onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }
  GoogleMapController? get mapController => _mapController;
  
  final Set<Marker> _markers = {};
  Set<Marker> get markers => _markers;

  // Getters públicos para que la UI acceda al estado
  List<RouteModel> get filteredRoutes => _filteredRoutes;
  List<RouteModel> get selectedRoutes => _selectedRoutes;
  bool get isLoadingRoutes => _isLoadingRoutes;
  int get totalRoutesCount => _allRoutes.length;
  int get selectedRoutesCount => _selectedRoutes.length;

  // Cookie (considera un manejo más seguro para esto, como almacenamiento seguro)
  final String _cookie = "JSESSIONID=node07741a99m8jq11isjf5hdfnvoa22686.node0";

  // Lógica de negocio
  Future<void> fetchRoutes() async {
    if (_allRoutes.isNotEmpty) return; // No volver a cargar si ya las tenemos

    _isLoadingRoutes = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('https://rastreobusmen.geovoy.com/api/devices'),
        headers: {'Cookie': _cookie},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _allRoutes = data.map((json) => RouteModel.fromJson(json)).toList();
        _filteredRoutes = List.from(_allRoutes);
        initSocket();
        _loadCustomMarkerIcons();
      } else {
        // Manejar el error de una forma más visible para el usuario si es necesario
        debugPrint('Error fetching routes: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching routes: $e'); // 1848 2411
    } finally {
      _isLoadingRoutes = false;

      notifyListeners();
    }
  }

  Future<void> _loadCustomMarkerIcons() async {
    _unitIconOn = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/images/icons/bus_Motion_True.png',
    );
    _unitIconOff = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/images/icons/bus_Motion_False.png',
    );
  }

  void searchRoutes(String query) {
    _searchQuery = query;
    _filteredRoutes = _allRoutes
        .where((route) =>
            route.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
    notifyListeners();
  }

  Future<void> toggleRouteSelection(RouteModel route) async {
    if (_selectedRoutes.contains(route)) {
      _selectedRoutes.remove(route);
      _markers.removeWhere((m) => m.markerId.value == route.id.toString());
    } else {
      Map<String, dynamic>? things = await RequestServ.instance.fetchByUnit(cookie: _cookie, deviceId: route.id);
      var result = await RequestServ.instance.fetchStatusDevice(cookie: _cookie, deviceId: route.id);
      // print("=> ${result["status"].toString().toUpperCase()}");
      route.lat = things!["latitude"];
      route.lng = things["longitude"];
      route.status = result["status"].toString().toUpperCase() == "ONLINE";
      _selectedRoutes.add(route);
      _addOrUpdateMarker(route);
    }
    _updateCameraBounds();
    notifyListeners();
  }

  void toggleSelectAll() {
    if (_selectedRoutes.length == _allRoutes.length) {
      _selectedRoutes.clear();
      _markers.clear();
    } else {
      _selectedRoutes.clear();
      _selectedRoutes.addAll(_allRoutes);
    }
    _updateCameraBounds();
    notifyListeners();
  }

  bool isRouteSelected(RouteModel route) {
    return _selectedRoutes.contains(route);
  }

  /// Intance socket
  void initSocket() {
    final socket = SocketServ.instance;
    socket.onUnitUpdate = (data) {
      _updateUnitPosition(data);
    };
    socket.connect();
  }

  void _addOrUpdateMarker(RouteModel unit) {
    print("ADD OR UPDATE MARKER => ${unit.status}");
    final marker = Marker(
      markerId: MarkerId(unit.id.toString()),
      position: LatLng(unit.lat, unit.lng),
      infoWindow: InfoWindow(title: unit.name),
      icon: unit.status ? _unitIconOn! : _unitIconOff!,
    );
    _markers.removeWhere((m) => m.markerId.value == unit.id.toString());
    _markers.add(marker);
  }

  Future<void> _updateUnitPosition(Map<String, dynamic> data) async {
    if (selectedRoutesCount == 0) return;
    if (!data.containsKey('positions')) return;

    final positions = data['positions'];
    if (positions is! List || positions.isEmpty) return;

    final pos = positions.first;
    final deviceId = pos['deviceId'] as int;

    _selectedRoutes.forEach((unit) {
      if (unit.id == deviceId){

      };
    });

    final index = _selectedRoutes.indexWhere((unit) => unit.id == deviceId);

    if (index != -1) {
      final unit = _selectedRoutes[index];
      unit.lat = pos['latitude'] as double;
      unit.lng = pos['longitude'] as double;
      print(pos["status"]);
      // unit.status = pos["status"] == ""

      _addOrUpdateMarker(unit);
      _updateCameraBounds();
      notifyListeners();
    }
  }

  void _updateCameraBounds() {
    if (_mapController == null || _selectedRoutes.isEmpty) return;

    if (_selectedRoutes.length == 1) {
      final unit = _selectedRoutes.first;
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(LatLng(unit.lat, unit.lng), 15));
    } else {
      double minLat = _selectedRoutes.first.lat;
      double maxLat = _selectedRoutes.first.lat;
      double minLng = _selectedRoutes.first.lng;
      double maxLng = _selectedRoutes.first.lng;

      for (var unit in _selectedRoutes) {
        if (unit.lat < minLat) minLat = unit.lat;
        if (unit.lat > maxLat) maxLat = unit.lat;
        if (unit.lng < minLng) minLng = unit.lng;
        if (unit.lng > maxLng) maxLng = unit.lng;
      }

      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }
}
