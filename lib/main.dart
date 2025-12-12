import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geo_rastreo/views/LoginView.dart';
import 'package:geo_rastreo/views/MapsView.dart';
import 'package:geo_rastreo/viewmodels/login_viewmodel.dart';
import 'package:geo_rastreo/services/auth_service.dart';


void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoginViewModel()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geo Rastreo App',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        useMaterial3: true,
      ),
      home: const AuthChecker(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthChecker extends StatefulWidget {
  const AuthChecker({super.key});

  @override
  State<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  final AuthService _authService = AuthService();
  bool _isChecking = true;
  bool _hasSession = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    print('🔍 Verificando sesión al iniciar app...');
    final session = await _authService.getUserSession();
    
    if (mounted) {
      setState(() {
        _hasSession = session != null && session.sesionActiva == '1';
        _isChecking = false;
      });
      
      if (_hasSession) {
        print('✓ Sesión válida encontrada - Navegando a MapsView');
      } else {
        print('✗ No hay sesión válida - Mostrando LoginView');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFF69D32),
          ),
        ),
      );
    }

    return _hasSession ? const MapsView() : const LoginView();
  }
}