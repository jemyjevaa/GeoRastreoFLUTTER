class ReaderEvent {
  final String unidad;
  final String noEmpleado;
  final String type;
  final String fecha;
  final int segundos;

  ReaderEvent({
    required this.unidad,
    required this.noEmpleado,
    required this.type,
    required this.fecha,
    required this.segundos,
  });

  factory ReaderEvent.fromJson(Map<String, dynamic> json) {
    return ReaderEvent(
      unidad: json['Unidad'] ?? '',
      noEmpleado: json['NoEmpleado'] ?? '',
      type: json['Type'] ?? '',
      fecha: json['Fecha'] ?? '',
      segundos: json['segundos'] ?? 0,
    );
  }
}

class ReaderEventsResponse {
  final String respuesta;
  final List<ReaderEvent> datos;

  ReaderEventsResponse({
    required this.respuesta,
    required this.datos,
  });

  factory ReaderEventsResponse.fromJson(Map<String, dynamic> json) {
    var list = json['datos'] as List? ?? [];
    List<ReaderEvent> eventsList = list.map((i) => ReaderEvent.fromJson(i)).toList();

    return ReaderEventsResponse(
      respuesta: json['respuesta'] ?? '',
      datos: eventsList,
    );
  }
}
