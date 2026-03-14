class InteractiveRouteModel {
  final String empresa;
  final String nombreRuta;
  final String nombreParada;
  final double latitud;
  final double longitud;

  InteractiveRouteModel({
    required this.empresa,
    required this.nombreRuta,
    required this.nombreParada,
    required this.latitud,
    required this.longitud,
  });

  factory InteractiveRouteModel.fromJson(Map<String, dynamic> json) {
    return InteractiveRouteModel(
      empresa: json['empresa'] ?? '',
      nombreRuta: json['nombre_ruta'] ?? '',
      nombreParada: json['nombre_parada'] ?? '',
      latitud: double.tryParse(json['latitud'].toString()) ?? 0.0,
      longitud: double.tryParse(json['longitud'].toString()) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'empresa': empresa,
      'nombre_ruta': nombreRuta,
      'nombre_parada': nombreParada,
      'latitud': latitud,
      'longitud': longitud,
    };
  }
}
