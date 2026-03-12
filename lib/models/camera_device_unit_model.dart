class CameraDeviceUnitModel {
  final bool respuesta;
  final List<CameraDeviceMessage> mensaje;

  CameraDeviceUnitModel({
    required this.respuesta,
    required this.mensaje,
  });

  factory CameraDeviceUnitModel.fromJson(Map<String, dynamic> json) {
    return CameraDeviceUnitModel(
      respuesta: json['respuesta'] ?? false,
      mensaje: json['mensaje'] != null
          ? List<CameraDeviceMessage>.from(
              json['mensaje'].map((x) => CameraDeviceMessage.fromJson(x)))
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
        "respuesta": respuesta,
        "mensaje": List<dynamic>.from(mensaje.map((x) => x.toJson())),
      };
}

class CameraDeviceMessage {
  final String carLicence;
  final String deviceID;

  CameraDeviceMessage({
    required this.carLicence,
    required this.deviceID,
  });

  factory CameraDeviceMessage.fromJson(Map<String, dynamic> json) {
    return CameraDeviceMessage(
      carLicence: json['CarLicence'] ?? "",
      deviceID: json['DeviceID'] ?? "",
    );
  }

  Map<String, dynamic> toJson() => {
        "CarLicence": carLicence,
        "DeviceID": deviceID,
      };
}
