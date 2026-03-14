import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/interactive_route_model.dart';
import '../models/operator_model.dart';

class TransportService {
  final String routesUrl = 'https://rutasbusmen.geovoy.com/api/obtenerRutasConPrimeraParada';
  final String operatorsUrl = 'https://busmenotify.geovoy.com/api/units_employes';

  Future<List<InteractiveRouteModel>> getRoutesWithFirstStop() async {
    try {
      final response = await http.get(Uri.parse(routesUrl));
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        final List<dynamic> data = jsonResponse['data'] ?? [];
        return data.map((json) => InteractiveRouteModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load routes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching routes: $e');
    }
  }

  Future<List<OperatorModel>> getOperators() async {
    try {
      final response = await http.get(Uri.parse(operatorsUrl));
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        final List<dynamic> data = jsonResponse['resultados'] ?? [];
        return data.map((json) => OperatorModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load operators: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching operators: $e');
    }
  }
}
