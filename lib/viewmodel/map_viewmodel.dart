
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/route_model.dart';
import '../service/SocketServ.dart';

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
      } else {
        // Manejar el error de una forma más visible para el usuario si es necesario
        debugPrint('Error fetching routes: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching routes: $e');
    } finally {
      _isLoadingRoutes = false;

      notifyListeners();
    }
  }

  void searchRoutes(String query) {
    _searchQuery = query;
    _filteredRoutes = _allRoutes
        .where((route) =>
            route.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
    notifyListeners();
  }

  void toggleRouteSelection(RouteModel route) {
    if (_selectedRoutes.contains(route)) {
      _selectedRoutes.remove(route);
    } else {
      _selectedRoutes.add(route);
    }
    notifyListeners();
  }

  void toggleSelectAll() {
    if (_selectedRoutes.length == _allRoutes.length) {
      _selectedRoutes.clear();
    } else {
      _selectedRoutes.clear();
      _selectedRoutes.addAll(_allRoutes);
    }
    notifyListeners();
  }

  bool isRouteSelected(RouteModel route) {
    return _selectedRoutes.contains(route);
  }


  /// Intance socket
  void initSocket() {

    final socket = SocketServ.instance;

    socket.onUnitUpdate = (data) {
      // print("WS DATA => $data");
      _updateUnitPosition(data);
    };

    socket.connect();
  }

  Future<void> _updateUnitPosition(Map<String, dynamic> data) async {

    if( selectedRoutesCount == 0 ) return;

    if (!data.containsKey('positions')) {
      return;
    }

    final positions = data['positions'];
    if (positions is! List || positions.isEmpty) {
      return;
    }

    final pos = positions.first;

    _selectedRoutes.forEach((unit) {
      print("${unit.id} ${pos['deviceId'].toInt()}");
    });

  }

}
