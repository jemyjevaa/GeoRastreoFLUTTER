class ResponseOperator {
  final String respuesta;
  final List<OperatorData> datosUnidadOperador;

  ResponseOperator({
    required this.respuesta,
    required this.datosUnidadOperador,
  });

  factory ResponseOperator.fromJson(Map<String, dynamic> json) {
    return ResponseOperator(
      respuesta: json['respuesta'] ?? '',
      datosUnidadOperador: (json['datos de Unidad - Operador'] as List?)
              ?.map((i) => OperatorData.fromJson(i))
              .toList() ??
          [],
    );
  }
}

class OperatorData {
  final String sucursal;
  final String fechaAsignacionUnidad;
  final String operador;
  final String supervisor;
  final String unidad;
  final String telefono;
  final String puestoOperador;
  final String idOperador;

  OperatorData({
    required this.sucursal,
    required this.fechaAsignacionUnidad,
    required this.operador,
    required this.supervisor,
    required this.unidad,
    required this.telefono,
    required this.puestoOperador,
    required this.idOperador,
  });

  factory OperatorData.fromJson(Map<String, dynamic> json) {
    return OperatorData(
      sucursal: json['sucursal'] ?? '',
      fechaAsignacionUnidad: json['Fecha_Asignacion_Unidad'] ?? '',
      operador: json['Operador'] ?? '',
      supervisor: json['Supervisor'] ?? '',
      unidad: json['Unidad'] ?? '',
      telefono: json['Telefono'] ?? '',
      puestoOperador: json['Puesto_Operador'] ?? '',
      idOperador: json['ID_Operador'] ?? '',
    );
  }
}
