class ServerConfig {
  final String key;
  final String url;

  ServerConfig({required this.key, required this.url});

  factory ServerConfig.fromJson(Map<String, dynamic> json) {
    return ServerConfig(
      key: json['clave'] ?? '',
      url: json['url'] ?? '',
    );
  }
}
