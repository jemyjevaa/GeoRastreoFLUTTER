class OperatorModel {
  final String operador;
  final String supervisor;
  final String puesto;
  final String telCel;
  final String coordenadas;

  OperatorModel({
    required this.operador,
    required this.supervisor,
    required this.puesto,
    required this.telCel,
    required this.coordenadas,
  });

  factory OperatorModel.fromJson(Map<String, dynamic> json) {
    return OperatorModel(
      operador: json['operador'] ?? '',
      supervisor: json['Supervisor'] ?? '',
      puesto: json['puesto'] ?? '',
      telCel: json['tel_cel'] ?? '',
      coordenadas: json['Coordenadas'] ?? '0.0,0.0',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'operador': operador,
      'Supervisor': supervisor,
      'puesto': puesto,
      'tel_cel': telCel,
      'Coordenadas': coordenadas,
    };
  }

  double get latitude {
    try {
      return double.parse(coordenadas.split(',')[0].trim());
    } catch (_) {
      return 0.0;
    }
  }

  double get longitude {
    try {
      return double.parse(coordenadas.split(',')[1].trim());
    } catch (_) {
      return 0.0;
    }
  }
}

class ResponseOperator {
  final String respuesta;
  final List<DatosUnidadOperador> datosUnidadOperador;

  ResponseOperator({
    required this.respuesta,
    required this.datosUnidadOperador,
  });

  factory ResponseOperator.fromJson(Map<String, dynamic> json) {
    return ResponseOperator(
      respuesta: json['respuesta'] ?? '',
      datosUnidadOperador: (json['datos_unidad_operador'] as List? ?? [])
          .map((i) => DatosUnidadOperador.fromJson(i))
          .toList(),
    );
  }
}

class DatosUnidadOperador {
  final String sucursal;
  final String fechaAsignacionUnidad;
  final String operador;
  final String supervisor;
  final String unidad;
  final String telefono;
  final String puestoOperador;

  DatosUnidadOperador({
    required this.sucursal,
    required this.fechaAsignacionUnidad,
    required this.operador,
    required this.supervisor,
    required this.unidad,
    required this.telefono,
    required this.puestoOperador,
  });

  factory DatosUnidadOperador.fromJson(Map<String, dynamic> json) {
    return DatosUnidadOperador(
      sucursal: json['sucursal'] ?? '',
      fechaAsignacionUnidad: json['fecha_asignacion_unidad'] ?? '',
      operador: json['operador'] ?? '',
      supervisor: json['supervisor'] ?? '',
      unidad: json['unidad'] ?? '',
      telefono: json['telefono'] ?? '',
      puestoOperador: json['puesto_operador'] ?? '',
    );
  }
}
