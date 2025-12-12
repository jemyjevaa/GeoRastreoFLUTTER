import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_session.dart';

class AuthService {
  final _storage = const FlutterSecureStorage();
  final Dio _dio = Dio();

  // API 1: Discovery
  Future<String?> findServerUrl(String serviceName) async {
    try {
      final response = await _dio.get('https://status.geovoy.com/api/datosservidores');
      
      if (response.statusCode == 200) {
        // Construir las claves de búsqueda
        final claveGPS = "gps$serviceName";
        final claveWSS = "gpswss$serviceName";
        
        print('Buscando servidor para: $serviceName');
        print('Clave GPS: $claveGPS');
        
        // Manejar ambos formatos de respuesta
        List<dynamic> servidores;
        if (response.data is Map && response.data['datos'] != null) {
          servidores = response.data['datos'] as List;
        } else if (response.data is List) {
          servidores = response.data;
        } else {
          print('Formato de respuesta inesperado: ${response.data}');
          return null;
        }
        
        print('Total de servidores encontrados: ${servidores.length}');
        
        // Buscar en la lista por clave
        String? urlGPS;
        String? urlWSS;
        
        for (var servidor in servidores) {
          final clave = servidor['clave'];
          final url = servidor['url'];
          
          if (clave == claveGPS) {
            urlGPS = url;
            print('✓ Servidor GPS encontrado: $url');
          }
          if (clave == claveWSS) {
            urlWSS = url;
            print('✓ Servidor WSS encontrado: $url');
          }
        }
        
        if (urlGPS == null) {
          print('✗ No se encontró servidor para la clave: $claveGPS');
          print('Claves disponibles:');
          for (var servidor in servidores) {
            print('  - ${servidor['clave']}');
          }
        }
        
        return urlGPS;
      }
      return null;
    } catch (e) {
      print('Error en findServerUrl: $e');
      return null;
    }
  }

  // API 2: Session (with proper encoding and cookie handling)
  Future<UserSession?> login(
    String baseUrl, 
    String email, 
    String password,
    {bool mantenerSesion = false}
  ) async {
    try {
      // Construir URL correctamente
      final url = baseUrl.endsWith('/') ? '${baseUrl}api/session' : '$baseUrl/api/session';
      
      print('Intentando login en: $url');
      
      // Paso 1: Enviar con application/x-www-form-urlencoded
      final response = await _dio.post(
        url,
        data: {
          'email': email,
          'password': password,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode == 200) {
        // Paso 2: Capturar la cookie de sesión
        final cookies = response.headers['set-cookie'];
        String? sessionToken;
        
        if (cookies != null && cookies.isNotEmpty) {
          final cookieString = cookies.first;
          await _storage.write(key: 'session_cookie', value: cookieString);
          
          // Extraer JSESSIONID de la cookie
          final jsessionMatch = RegExp(r'JSESSIONID=([^;]+)').firstMatch(cookieString);
          if (jsessionMatch != null) {
            sessionToken = jsessionMatch.group(1);
            print('✓ Token de sesión extraído: ${sessionToken?.substring(0, 20)}...');
          }
        }

        // Paso 3: Parsear la respuesta con manejo de errores
        try {
          // El token viene de la cookie, no del JSON
          final session = UserSession.fromJson(
            response.data,
            cookieToken: sessionToken ?? '',
          );
          
          // Validar que tengamos un token
          if (session.token.isEmpty) {
            print('✗ No se pudo extraer el token de la cookie');
            return null;
          }
          
          print('✓ Usuario autenticado: ${session.email}');

          // Paso 4: Calcular BasicAuthorization
          final credentials = '$email:$password';
          final basicAuth = base64Encode(utf8.encode(credentials));

          // Crear el objeto completo con los campos adicionales
          final sessionCompleta = session.copyWith(
            basicAuthorization: basicAuth,
            sesionActiva: mantenerSesion ? '1' : '0',
          );

          // Paso 5: Guardar todo
          await _storage.write(
            key: 'user_session', 
            value: jsonEncode(sessionCompleta.toJson())
          );
          await _storage.write(key: 'auth_token', value: session.token);
          
          print('✓ Sesión guardada:');
          print('  - Email: ${sessionCompleta.email}');
          print('  - Mantener sesión: ${mantenerSesion ? "SÍ" : "NO"}');
          print('  - sesionActiva: ${sessionCompleta.sesionActiva}');
          
          return sessionCompleta;
        } catch (e) {
          print('Error parseando usuario: $e');
          print('JSON recibido: ${response.data}');
          return null;
        }
      }
      return null;
    } catch (e) {
      print('Error en login: $e');
      return null;
    }
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  Future<String?> getCookie() async {
    return await _storage.read(key: 'session_cookie');
  }
  
  Future<UserSession?> getUserSession() async {
    try {
      final sessionJson = await _storage.read(key: 'user_session');
      print('📖 Leyendo sesión guardada...');
      
      if (sessionJson != null) {
        final Map<String, dynamic> data = jsonDecode(sessionJson);
        print('✓ Sesión encontrada: ${data['email']}');
        print('✓ Sesión activa: ${data['sesionActiva']}');
        
        // Reconstruir UserSession desde el JSON completo guardado
        return UserSession(
          id: data['id'],
          email: data['email'],
          name: data['name'],
          login: data['login'],
          administrator: data['administrator'],
          token: data['token'] ?? '',
          basicAuthorization: data['basicAuthorization'],
          sesionActiva: data['sesionActiva'],
        );
      }
      
      print('✗ No se encontró sesión guardada');
      return null;
    } catch (e) {
      print('Error leyendo sesión: $e');
      return null;
    }
  }
  
  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'session_cookie');
    await _storage.delete(key: 'user_session');
  }
}
