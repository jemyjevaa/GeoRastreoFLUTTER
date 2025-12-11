import 'dart:convert';

class UserSession {
  final int? id;
  final String? email;
  final String? name;
  final String? login;
  final bool? administrator;
  final String token;
  final String? basicAuthorization;
  final String? sesionActiva;

  UserSession({
    this.id,
    this.email,
    this.name,
    this.login,
    this.administrator,
    required this.token,
    this.basicAuthorization,
    this.sesionActiva,
  });

  factory UserSession.fromJson(Map<String, dynamic> json, {String? cookieToken}) {
    return UserSession(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      login: json['login'],
      administrator: json['administrator'],
      // El token viene de la cookie, no del JSON
      token: cookieToken ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'login': login,
      'administrator': administrator,
      'token': token,
      'basicAuthorization': basicAuthorization,
      'sesionActiva': sesionActiva,
    };
  }

  UserSession copyWith({
    int? id,
    String? email,
    String? name,
    String? login,
    bool? administrator,
    String? token,
    String? basicAuthorization,
    String? sesionActiva,
  }) {
    return UserSession(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      login: login ?? this.login,
      administrator: administrator ?? this.administrator,
      token: token ?? this.token,
      basicAuthorization: basicAuthorization ?? this.basicAuthorization,
      sesionActiva: sesionActiva ?? this.sesionActiva,
    );
  }
}
