import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<bool> login(String email, String password, {bool mantenerSesion = false}) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      // 1. Extraer dominio y mapear a servicio
      final serviceName = _extractServiceName(email);
      if (serviceName == null) {
        _errorMessage = 'Correo electrónico inválido';
        _setLoading(false);
        return false;
      }

      // 2. Discovery: Buscar URL del servidor
      final serverUrl = await _authService.findServerUrl(serviceName);
      if (serverUrl == null) {
        _errorMessage = 'Servidor no encontrado para este dominio';
        _setLoading(false);
        return false;
      }

      // 3. Session: Login con mantenerSesion
      final session = await _authService.login(
        serverUrl, 
        email, 
        password,
        mantenerSesion: mantenerSesion,
      );
      if (session != null) {
        _setLoading(false);
        return true;
      } else {
        _errorMessage = 'Credenciales incorrectas';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error de conexión: $e';
      _setLoading(false);
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String? _extractServiceName(String email) {
    try {
      final parts = email.split('@');
      if (parts.length != 2) return null;
      
      final domain = parts[1].toLowerCase();
      
      // Mapeo simple de dominios a servicios
      // geovoy.com -> busmen (según ejemplo)
      // Puedes agregar más mapeos aquí
      if (domain.contains('geovoy.com')) {
        return 'busmen';
      }
      
      // Fallback: usar la parte del dominio antes del punto
      // ej: empresa.com -> empresa
      return domain.split('.')[0];
    } catch (e) {
      return null;
    }
  }
}
