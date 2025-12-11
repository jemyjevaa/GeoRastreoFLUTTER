import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'RequestServ.dart';

import 'dart:convert';
import 'dart:io';

class SocketServ {
  static final SocketServ instance = SocketServ._();
  SocketServ._();

  WebSocket? _ws;
  String? _cookie;

  Function(Map<String, dynamic> data)? onUnitUpdate;

  Future<void> loadSession() async {
    final serv = RequestServ.instance;
    _cookie = await serv.sessionGeovoySistem();
  }

  Future<void> connect() async {
    if (_ws != null) return;

    if (_cookie == null) {
      await loadSession();
      if (_cookie == null) return;
    }

    final uri = Uri.parse("wss://rastreobusmen.geovoy.com/api/socket");

    try {
      print("Intentando conectar WebSocket...");

      _ws = await WebSocket.connect(
        uri.toString(),
        headers: {
          "Cookie": _cookie!,
        },
      );

      print("WEBSOCKET => CONECTADO");

      _ws!.listen(
            (message) {
          try {
            if (message == null || message.toString().trim().isEmpty) {
              print("WS => mensaje vacío o null");
              return;
            }

            final dynamic data = jsonDecode(message);

            if (!hasPositions(data)) {
              return;
            }


            if (data is! Map<String, dynamic>) {
              print("WS => mensaje no es un objeto Map, recibido: $data");
              return;
            }

            if (onUnitUpdate != null) {
              onUnitUpdate!(data);
            }
          } catch (e) {
            print("ERROR PARSEANDO JSON => $e");
            print("MENSAJE RECIBIDO => $message");
          }
        },

        onDone: () {
          print("WS DESCONECTADO");
          _ws = null;
          reconnect();
        },

        onError: (error) {
          print("ERROR EN WS => $error");
          _ws = null;
          reconnect();
        },
      );

    } catch (e) {
      print("ERROR AL CONECTAR WS => $e");
      reconnect();
    }
  }

  /// Intentos automáticos cada 3 segundos
  void reconnect() {
    Future.delayed(const Duration(seconds: 3), () {
      print("Reintentando conexión WebSocket...");
      connect();
    });
  }

  void disconnect() {
    print("Cerrando WebSocket...");
    _ws?.close();
    _ws = null;
  }

  bool hasPositions(Map<String, dynamic> data) {
    return data.containsKey('positions') &&
        data['positions'] is List &&
        (data['positions'] as List).isNotEmpty;
  }

}
