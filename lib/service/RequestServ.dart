import 'dart:convert';
import 'package:http/http.dart' as http;

class RequestServ {
  // static const String baseUrlAdm = "";
  static const String baseUrlNor = "https://rastreobusmen.geovoy.com/";

  static const String urlDevice = "api/devices";

  static const String _apiUser = 'apinstaladores@geovoy.com';
  static const String _apiPass = 'Instaladores*9';

  // Singleton pattern
  RequestServ._privateConstructor();
  static final RequestServ instance = RequestServ._privateConstructor();
  final String basicAuth =
      'Basic ${base64Encode(utf8.encode('$_apiUser:$_apiPass'))}';

  Future<String?> handlingRequest({
    required String urlParam,
    Map<String, dynamic>? params,
    String method = "GET",
    bool asJson = false,
  }) async {
    try {
      // Decide base URL
      // bool isNormUrl = urlParam == urlValidateUser ||
      //     urlParam == urlGetRoute ||
      //     urlParam == urlStopInRoute ||
      //     urlParam == urlUnitAsiggned;

      final base = baseUrlNor; //isNormUrl ? baseUrlNor : baseUrlAdm;
      String fullUrl = base + urlParam;

      http.Response response;

      if (method.toUpperCase() == 'GET' && params != null && params.isNotEmpty) {
        final uri = Uri.parse(fullUrl).replace(queryParameters: params);
        response = await http.get(uri).timeout(const Duration(seconds: 10));
      } else {

        dynamic body;
        Map<String, String>? headers;

        if (params != null) {
          if (asJson) {
            body = jsonEncode(params);
            headers = {'Content-Type': 'application/json'};
          } else {
            body = params.map((k, v) => MapEntry(k, v.toString()));
            headers = {'Content-Type': 'application/x-www-form-urlencoded'};
          }
        }

        Uri uri = Uri.parse(fullUrl);

        switch (method.toUpperCase()) {
          case 'POST':
            response = await http
                .post(uri, body: body, headers: headers)
                .timeout(const Duration(seconds: 10));
            break;
          case 'PUT':
            response = await http
                .put(uri, body: body, headers: headers)
                .timeout(const Duration(seconds: 10));
            break;
          case 'PATCH':
            response = await http
                .patch(uri, body: body, headers: headers)
                .timeout(const Duration(seconds: 10));
            break;
          case 'DELETE':
            response = await http
                .delete(uri, body: body, headers: headers)
                .timeout(const Duration(seconds: 10));
            break;
          default:
            throw UnsupportedError("HTTP method $method no soportado");
        }
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.body;
      } else {
        print("HTTP error: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error en handlingRequest: $e");
      return null;
    }
  }

  /// Función genérica para parsear JSON a objeto
  Future<T?> handlingRequestParsed<T>(
      {required String urlParam,
        Map<String, dynamic>? params,
        String method = "GET",
        bool asJson = false,
        required T Function(dynamic json) fromJson}) async {
    final responseString = await handlingRequest(
        urlParam: urlParam, params: params, method: method, asJson: asJson);

    if (responseString == null) return null;

    try {
      final jsonMap = jsonDecode(responseString);
      return fromJson(jsonMap);
    } catch (e) {
      print("Error parseando JSON: $e");
      return null;
    }
  }

  Future<String?> sessionGeovoySistem() async {
    try {
      var client = http.Client();
      var response = await client.post(
        Uri.parse("https://rastreobusmen.geovoy.com/api/session"),
        body: {
          "email": "usuariosapp",
          "password": "usuarios0904",
        },
      );

      if (response.statusCode != 200) {
        print("Error: ${response.statusCode}");
        return null;
      }

      String? rawCookie = response.headers['set-cookie'];

      if (rawCookie != null) {
        String? parsedCookie = rawCookie.split(";").first;
        UserSession.token = parsedCookie;

        return parsedCookie;
      }

      return null;

    } catch (e) {
      print("Error sessionGeovoySistem: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchByUnit({
    required String cookie,
    required int deviceId,
  }) async {
    try {
      final url = Uri.parse("https://rastreobusmen.geovoy.com/api/positions");

      final response = await http.get(
        url,
        // headers: {"Cookie": cookie},
        headers: {"Authorization": basicAuth},
      );

      if (response.statusCode != 200) {
        print("HTTP error: ${response.statusCode}");
        return null;
      }

      final List<dynamic> jsonList = jsonDecode(response.body);

      final pos = jsonList.cast<Map<String, dynamic>>().firstWhere(
            (p) => p["deviceId"] == deviceId,
        orElse: () => {},
      );

      if (pos.isEmpty) {
        print("No se encontró posición para deviceId $deviceId");
        return null;
      }

      return pos;

    } catch (e) {
      print("Error fetchByUnit: $e");
      return null;
    }
  }

  Future<dynamic> fetchStatusDevice({ required String cookie, required int deviceId }) async {
    try {
      final url = Uri.parse("https://rastreobusmen.geovoy.com/api/devices/$deviceId");

      final response = await http.get(
        url,
        // headers: {"Cookie": cookie},
        headers: {"Authorization": basicAuth},
      );

      if (response.statusCode != 200) {
        print("HTTP error: ${response.statusCode}");
        return null;
      }

      final jsonBody = jsonDecode(response.body);

      return jsonBody;

    } catch (e) {
      print("Error fetchStatusForUnit: $e");
      return null;
    }
  }



}

class UserSession {
  static String? token;
}
