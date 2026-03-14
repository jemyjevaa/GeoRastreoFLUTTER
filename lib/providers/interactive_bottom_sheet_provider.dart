import 'dart:math';
import 'package:flutter/material.dart';
import '../models/interactive_route_model.dart';
import '../models/operator_model.dart';
import '../services/transport_service.dart';

class InteractiveBottomSheetProvider with ChangeNotifier {
  final TransportService _transportService = TransportService();

  List<InteractiveRouteModel> _allRoutes = [];
  List<OperatorModel> _allOperators = [];
  
  List<String> _companies = [];
  List<InteractiveRouteModel> _filteredRoutes = [];
  List<OperatorModel> _nearestOperators = [];

  String? _selectedCompany;
  InteractiveRouteModel? _selectedRoute;
  double _radius = 10.0; // Default 10km
  bool _isLoading = false;

  List<OperatorModel> _operatorsWithoutCoords = [];
  String _companySearchQuery = '';
  String _routeSearchQuery = '';

  List<InteractiveRouteModel> get allRoutes => _allRoutes;
  List<String> get companies => _companies.where((c) => c.toLowerCase().contains(_companySearchQuery.toLowerCase())).toList();
  
  List<InteractiveRouteModel> get filteredRoutes {
    var routes = _filteredRoutes;
    if (_routeSearchQuery.isNotEmpty) {
      routes = routes.where((r) => r.nombreRuta.toLowerCase().contains(_routeSearchQuery.toLowerCase())).toList();
    }
    return routes;
  }
  
  List<OperatorModel> get nearestOperators => _nearestOperators;
  List<OperatorModel> get operatorsWithoutCoords => _operatorsWithoutCoords;
  
  String? get selectedCompany => _selectedCompany;
  InteractiveRouteModel? get selectedRoute => _selectedRoute;
  double get radius => _radius;
  bool get isLoading => _isLoading;

  void setRadius(double value) {
    _radius = value;
    _calculateNearestOperators();
    notifyListeners();
  }

  void setCompanySearch(String query) {
    _companySearchQuery = query;
    notifyListeners();
  }

  void setRouteSearch(String query) {
    _routeSearchQuery = query;
    notifyListeners();
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _allRoutes = await _transportService.getRoutesWithFirstStop();
      _allOperators = await _transportService.getOperators();
      
      _companies = _allRoutes.map((r) => r.empresa).toSet().toList()..sort();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  void selectCompany(String company) {
    _selectedCompany = company;
    _selectedRoute = null;
    _companySearchQuery = '';
    _routeSearchQuery = '';
    _filteredRoutes = _allRoutes.where((r) => r.empresa == company).toList();
    _nearestOperators = [];
    _operatorsWithoutCoords = [];
    notifyListeners();
  }

  void selectRoute(InteractiveRouteModel route) {
    _selectedRoute = route;
    _routeSearchQuery = '';
    _calculateNearestOperators();
    notifyListeners();
  }

  void _calculateNearestOperators() {
    if (_selectedRoute == null) return;

    _nearestOperators = [];
    _operatorsWithoutCoords = [];
    List<Map<String, dynamic>> distList = [];

    for (var op in _allOperators) {
      if (op.latitude == 0 && op.longitude == 0) {
        _operatorsWithoutCoords.add(op);
        continue;
      }

      double distance = _haversine(
        _selectedRoute!.latitud,
        _selectedRoute!.longitud,
        op.latitude,
        op.longitude,
      );
      if (distance <= _radius) {
        distList.add({'operator': op, 'distance': distance});
      }
    }

    // Sort by distance
    distList.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
    
    _nearestOperators = distList.map((e) => e['operator'] as OperatorModel).toList();
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371; // Radius of Earth in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }
}
