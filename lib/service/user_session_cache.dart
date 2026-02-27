import 'package:shared_preferences/shared_preferences.dart';

class UserSessionCache {
  static final UserSessionCache _instance = UserSessionCache._internal();
  SharedPreferences? _prefs;

  factory UserSessionCache() {
    return _instance;
  }

  UserSessionCache._internal();

  // Inicializar SharedPreferences una sola vez (ejecutar al iniciar la app)
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  bool get isLogin => _prefs?.getBool('isLogin') ?? false;
  set isLogin(bool value) => _prefs?.setBool('isLogin', value);


  // region persist data user


  String? get pwdEncode => _prefs?.getString('pwdEncode');
  set pwdEncode(String? value) => _prefs?.setString('pwdEncode', value ?? '');


  
  // endregion persist data user
  
  

  // Limpiar datos
  Future<void> clear() async {
    isLogin = false;
    pwdEncode = null;
  }
}