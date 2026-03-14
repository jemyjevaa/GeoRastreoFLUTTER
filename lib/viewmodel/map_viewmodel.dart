import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geo_rastreo/service/user_session_cache.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/route_model.dart';
import '../models/group_model.dart';
import '../service/RequestServ.dart';
import '../service/SocketServ.dart';
import '../models/interactive_route_model.dart';
import '../models/operator_model.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import '../views/reader_events_bottom_sheet.dart';

class MapViewModel extends ChangeNotifier {
  // Estado
  final Color colorAmarillo = const Color(0xFFF69D32);
  final Color colorAzulFuerte = const Color(0xFF14143A);
  
  // Constantes de ubicación
  static const LatLng _mexicoCenter = LatLng(23.6345, -102.5528);
  
  // Caché de imágenes para optimizar rendimiento de marcadores
  final Map<String, ui.Image> _baseImageCache = {};

  List<RouteModel> _allRoutes = [];
  List<GroupModel> _allGroups = [];
  List<RouteModel> _filteredRoutes = [];
  final List<RouteModel> _selectedRoutes = [];
  final List<int> _loadingRoutes = [];
  String _groupSearchQuery = '';
  bool isSelectAll = false;

  GoogleMapController? _mapController;
  bool _isLoadingRoutes = false;
  String _searchQuery = '';
  int? _selectedGroupId;
  bool? _statusFilter;          // null=todos, true=online, false=offline
  bool _statusFilterUnknown = false;  // true = filtrar desconocidos
  bool _isBottomSheetOpen = false;
  final Set<Polyline> _polylines = {};
  bool _isReplaying = false;
  List<Map<String, dynamic>> _historyData = [];
  int _currentStepIndex = 0;
  bool _isPlaying = false;
  int? _replayedDeviceId;
  double _playbackSpeed = 1.0;
  Timer? _playbackTimer;
  Set<Marker> _arrowMarkers = {};
  bool _isFollowActive = true;
  BitmapDescriptor? _arrowIcon;
  Marker? _interactiveStopMarker;
  Set<Marker> _nearestOperatorMarkers = {};
  bool _showInteractiveUI = false;

  bool get isLoadingRoutes => _isLoadingRoutes;
  bool get isBottomSheetOpen => _isBottomSheetOpen;
  Set<Polyline> get polylines => _polylines;
  bool get isReplaying => _isReplaying;
  bool get isPlaying => _isPlaying;
  bool get isFollowActive => _isFollowActive;
  bool get showInteractiveUI => _showInteractiveUI;

  void setShowInteractiveUI(bool value) {
    _showInteractiveUI = value;
    if (!value) {
      _interactiveStopMarker = null;
      _nearestOperatorMarkers.clear();
    }
    notifyListeners();
  }
  int get currentStepIndex => _currentStepIndex;
  int get totalSteps => _historyData.length;
  double get playbackSpeed => _playbackSpeed;
  String get currentTimestamp {
    if (_historyData.isEmpty || _currentStepIndex >= _historyData.length) return "";
    final date = DateTime.parse(_historyData[_currentStepIndex]['deviceTime'] ?? DateTime.now().toIso8601String());
    return DateFormat("HH:mm:ss").format(date.toLocal());
  }
  int? get selectedGroupId => _selectedGroupId;
  List<GroupModel> get allGroups => _allGroups;
  bool? get statusFilter => _statusFilter;
  bool get statusFilterUnknown => _statusFilterUnknown;
  List<GroupModel> get filteredGroups {
    if (_groupSearchQuery.isEmpty) return _allGroups;
    return _allGroups.where((g) => g.name.toLowerCase().contains(_groupSearchQuery.toLowerCase())).toList();
  }

  // Counts
  int get onlineCount => _allRoutes.where((r) => r.statusText.toString().toLowerCase() == "online").length;
  int get offlineCount => _allRoutes.where((r) => r.statusText.toString().toLowerCase() == "offline").length;
  int get unknownCount => _allRoutes.where((r) => r.statusText.toString().toLowerCase() == "unknown").length;

  List<RouteModel> get selectedRoutes => _selectedRoutes;
  List<RouteModel> get filteredRoutes => _filteredRoutes;
  int get totalRoutesCount => _allRoutes.length;
  int get selectedRoutesCount => _selectedRoutes.length;

  GoogleMapController? get mapController => _mapController;

  final Set<Marker> _markers = {};

  final Map<int, Timer> _animationTimers = {};

  void toggleBottomSheet() {
    _isBottomSheetOpen = !_isBottomSheetOpen;
    if (!_isBottomSheetOpen) {
      _searchQuery = '';
    } else {
      _applyFilters();
    }
    notifyListeners();
  }

  bool isRouteSelected(RouteModel route) {
    return _selectedRoutes.contains(route);
  }

  bool isRouteLoading(RouteModel route) => _loadingRoutes.contains(route.id);

  void onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void searchRoutes(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void filterByGroup(int? groupId) {
    _selectedGroupId = groupId;
    _applyFilters();
  }

  void filterByStatus(bool? status, {bool unknown = false}) {
    if (unknown) {
      _statusFilter = null;
      _statusFilterUnknown = true;
    } else {
      _statusFilter = status;
      _statusFilterUnknown = false;
    }
    _applyFilters();
  }

  void clearStatusFilter() {
    _statusFilter = null;
    _statusFilterUnknown = false;
    _applyFilters();
  }

  void searchGroups(String query) {
    _groupSearchQuery = query;
    notifyListeners();
  }

  void _applyFilters() {
    final filtered = _allRoutes
        .where((route) {
          final matchesSearch = route.name.toLowerCase().contains(_searchQuery.toLowerCase());
          final matchesGroup = _selectedGroupId == null || route.groupId == _selectedGroupId;
          bool matchesStatus;
          if (_statusFilterUnknown) {
            matchesStatus = route.status == null;
          } else if (_statusFilter == null) {
            matchesStatus = true;
          } else {
            matchesStatus = route.status == _statusFilter;
          }
          return matchesSearch && matchesGroup && matchesStatus;
        })
        .toList();

    // ORDENAR: Seleccionados primero
    filtered.sort((a, b) {
      final aSelected = _selectedRoutes.contains(a);
      final bSelected = _selectedRoutes.contains(b);
      if (aSelected != bSelected) {
        return aSelected ? -1 : 1;
      }
      return 0;
    });

    _filteredRoutes = filtered;
    
    // Sincronizamos marcadores con el filtro actual
    _updateMarkersFromFiltered();
    
    notifyListeners();
  }

  // Sincroniza marcadores con la lista filtrada y seleccionada
  void _updateMarkersFromFiltered() async {
    if (_selectedRoutes.isEmpty) {
      _markers.clear();
      notifyListeners();
      return;
    }

    final filteredSelected = _filteredRoutes.where((r) => _selectedRoutes.contains(r)).toList();
    final filteredSelectedIds = filteredSelected.map((r) => r.id.toString()).toSet();

    // Eliminar marcadores que no están en el filtro actual
    _markers.removeWhere((m) => 
      m.markerId.value != "replay_marker" && 
      !filteredSelectedIds.contains(m.markerId.value)
    );

    // Añadir marcadores faltantes en paralelo para mayor velocidad
    List<Future<void>> markerFutures = [];
    for (var route in filteredSelected) {
      bool alreadyExists = _markers.any((m) => m.markerId.value == route.id.toString());
      if (!alreadyExists && route.lat != 0 && route.lng != 0) {
        markerFutures.add(_addOrUpdateMarker(route));
      }
    }
    
    if (markerFutures.isNotEmpty) {
      await Future.wait(markerFutures);
      notifyListeners();
    }
  }

  String getGroupName(int groupId) {
    try {
      return _allGroups.firstWhere((g) => g.id == groupId).name;
    } catch (_) {
      return "Empresa no asignada";
    }
  }

  // Metodología unificada para obtener datos reales de la unidad
  Future<void> _fetchUnitDetails(RouteModel route) async {
    try {
      final results = await Future.wait([
        RequestServ.instance.fetchByUnit(deviceId: route.id),
        RequestServ.instance.fetchStatusDevice(deviceId: route.id),
      ]);

      if (results[0] != null) {
        route.lat = (results[0]!["latitude"] as num).toDouble();
        route.lng = (results[0]!["longitude"] as num).toDouble();
      }
      if (results[1] != null) {
        route.status = results[1]!["status"].toString().toUpperCase() == "ONLINE";
      }
    } catch (e) {
      debugPrint("Error al obtener detalles para ${route.name}: $e");
    }
  }

  Future<void> toggleSelectAll() async {
    if (_selectedRoutes.length == _allRoutes.length || isSelectAll) {
      _selectedRoutes.clear();
      _markers.clear();
      _animationTimers.forEach((_, timer) => timer.cancel());
      _animationTimers.clear();
      isSelectAll = false;
      notifyListeners();
    } else {
      _isLoadingRoutes = true;
      notifyListeners();
      
      isSelectAll = true;
      
      // Determinar qué rutas procesar
      List<RouteModel> targetRoutes = _selectedGroupId == null 
          ? List.from(_allRoutes) 
          : _allRoutes.where((r) => r.groupId == _selectedGroupId).toList();

      // Metodología adaptada: Recorrer obteniendo posiciones reales en paralelo
      await Future.wait(targetRoutes.map((route) => _fetchUnitDetails(route)));

      _selectedRoutes.clear();
      // Solo añadir las que tengan posición válida (evitar 0,0)
      for (var route in targetRoutes) {
        if (route.lat != 0 && route.lng != 0) {
          _selectedRoutes.add(route);
        }
      }

      _isLoadingRoutes = false;
      _updateCameraBounds(force: true);
    }
    _applyFilters();
  }

  void initSocket() {
    final socket = SocketServ.instance;
    socket.onUnitUpdate = (data) {
      _updateUnitPosition(data);
    };
    socket.connect();
  }

  void _updateCameraBounds({bool force = false}) {
    if (_mapController == null || _selectedRoutes.isEmpty) return;

    final validRoutes = _selectedRoutes.where((r) => r.lat != 0 && r.lng != 0).toList();

    if (validRoutes.isEmpty) {
      if (force) {
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(_mexicoCenter, 5.0));
      }
      return;
    }

    // Permitir movimiento libre si hay más de una unidad, a menos que se fuerce (ej. al seleccionar todo)
    if (!force && validRoutes.length > 1) {
      return;
    }

    double positionCam = Platform.isAndroid ? 15.9 : 15.0;

    if (validRoutes.length == 1) {
      final unit = validRoutes.first;
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(LatLng(unit.lat, unit.lng), positionCam));
    } else if (force) {
      double minLat = validRoutes.first.lat;
      double maxLat = validRoutes.first.lat;
      double minLng = validRoutes.first.lng;
      double maxLng = validRoutes.first.lng;

      for (var unit in validRoutes) {
        if (unit.lat < minLat) minLat = unit.lat;
        if (unit.lat > maxLat) maxLat = unit.lat;
        if (unit.lng < minLng) minLng = unit.lng;
        if (unit.lng > maxLng) maxLng = unit.lng;
      }

      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  Future<void> fetchRoutes() async {
    if (_allRoutes.isNotEmpty) return;

    _isLoadingRoutes = true;
    notifyListeners();

    try {
      final String? basicAuth = UserSessionCache().pwdEncode;
      
      if (basicAuth == null || basicAuth.isEmpty) {
        _isLoadingRoutes = false;
        notifyListeners();
        return;
      }

      final responses = await Future.wait([
        http.get(Uri.parse('https://rastreobusmen.geovoy.com/api/groups'), headers: {'Authorization': basicAuth}),
        http.get(Uri.parse('https://rastreobusmen.geovoy.com/api/devices'), headers: {'Authorization': basicAuth}),
      ]);

      if (responses[0].statusCode == 200) {
        final List<dynamic> data = json.decode(responses[0].body);
        _allGroups = data.map((json) => GroupModel.fromJson(json)).toList();
        initSocket();
      }

      if (responses[1].statusCode == 200) {
        final List<dynamic> data = json.decode(responses[1].body);
        _allRoutes = data.map((json) => RouteModel.fromJson(json)).toList();
        _filteredRoutes = List.from(_allRoutes);
      }
    } catch (e) {
      debugPrint('Error fetching routes: $e');
    } finally {
      _isLoadingRoutes = false;
      notifyListeners();
    }
  }

  Future<void> toggleRouteSelection(RouteModel route) async {
    if (_selectedRoutes.contains(route)) {
      _selectedRoutes.remove(route);
      _markers.removeWhere((m) => m.markerId.value == route.id.toString());
      _animationTimers[route.id]?.cancel();
      _animationTimers.remove(route.id);
      
      if (_selectedRoutes.length == 1) {
        _updateCameraBounds(force: true);
      }

      Fluttertoast.showToast(msg: "Unidad removida del mapa", toastLength: Toast.LENGTH_SHORT);
      _applyFilters();
    } else {
      _loadingRoutes.add(route.id);
      notifyListeners();

      try {
        // Metodología unificada: Obtener posición real
        await _fetchUnitDetails(route);

        if (route.lat != 0 && route.lng != 0) {
          _selectedRoutes.add(route);
          await _addOrUpdateMarker(route);
        } else {
          Fluttertoast.showToast(msg: "Unidad sin coordenadas válidas");
        }
      } catch (e) {
        debugPrint('Failed to fetch route details: $e');
      } finally {
        _loadingRoutes.remove(route.id);
        if (_selectedRoutes.length == 1) {
           _updateCameraBounds(force: true);
        }
        _applyFilters();
      }
    }
  }

  BuildContext? _currentContext;
  void updateContext(BuildContext context) {
    _currentContext = context;
  }

  void _updateMarker(RouteModel unit, BitmapDescriptor icon, {LatLng? position}) {
    final pos = position ?? LatLng(unit.lat, unit.lng);
    
    // NUNCA mostrar si la posición es 0,0
    if (pos.latitude == 0 && pos.longitude == 0) return;

    final marker = Marker(
      markerId: MarkerId(unit.id.toString()),
      position: pos,
      infoWindow: InfoWindow(title: unit.name),
      icon: icon,
      anchor: const Offset(0.5, 1.0),
      onTap: () {
        if (_currentContext != null) {
          showReaderEvents(unit, _currentContext!);
        }
      },
    );
    _markers.removeWhere((m) => m.markerId.value == unit.id.toString());
    _markers.add(marker);
  }

  Future<void> _addOrUpdateMarker(RouteModel unit, {LatLng? position}) async {
    if (unit.lat == 0 && unit.lng == 0 && position == null) return;
    final BitmapDescriptor icon = await _createCustomMarker(unit.name, unit.status ?? false);
    _updateMarker(unit, icon, position: position);
  }

  Future<void> _updateUnitPosition(Map<String, dynamic> data) async {
    if (selectedRoutesCount == 0 || !data.containsKey('positions')) return;

    final positions = data['positions'];
    if (positions is! List || positions.isEmpty) return;

    final pos = positions.first;
    final deviceId = pos['deviceId'] as int;

    final index = _selectedRoutes.indexWhere((unit) => unit.id == deviceId);

    if (index != -1) {
      final unit = _selectedRoutes[index];
      final newLatLng = LatLng((pos['latitude'] as num).toDouble(), (pos['longitude'] as num).toDouble());
      
      // Evitar saltos a 0,0 desde el socket
      if (newLatLng.latitude == 0 && newLatLng.longitude == 0) return;

      final oldLatLng = LatLng(unit.lat, unit.lng);
      unit.status = pos["attributes"]['ignition'].toString().toUpperCase() == "TRUE" &&
          pos["attributes"]['motion'].toString().toUpperCase() == "TRUE";

      if (_animationTimers.containsKey(deviceId)) {
        _animationTimers[deviceId]!.cancel();
      }

      final BitmapDescriptor icon = await _createCustomMarker(unit.name, unit.status ?? false);

      const animationDuration = Duration(seconds: 2);
      const framesPerSecond = 30;
      final totalFrames = animationDuration.inSeconds * framesPerSecond;
      var currentFrame = 0;

      final latTween = Tween(begin: oldLatLng.latitude, end: newLatLng.latitude);
      final lngTween = Tween(begin: oldLatLng.longitude, end: newLatLng.longitude);

      _animationTimers[deviceId] = Timer.periodic(const Duration(milliseconds: 33), (timer) {
        currentFrame++;
        final t = currentFrame / totalFrames;
        final animatedLatLng = LatLng(latTween.transform(t), lngTween.transform(t));

        _updateMarker(unit, icon, position: animatedLatLng);
        notifyListeners();

        if (currentFrame >= totalFrames) {
          timer.cancel();
          _animationTimers.remove(deviceId);
          unit.lat = newLatLng.latitude;
          unit.lng = newLatLng.longitude;
          _updateMarker(unit, icon, position: newLatLng);
          _updateCameraBounds(force: false);
          notifyListeners();
        }
      });
    }
  }

  Future<BitmapDescriptor> _createCustomMarker(String text, bool isOnline) async {
    final double iconWidth = Platform.isAndroid ? 45.0 : 70.0;
    const double padding = 1.0;

    final TextPainter textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: Platform.isAndroid ? 12 : 18, color: Colors.black),
      ),
    );
    textPainter.layout(maxWidth: iconWidth * 1.5);

    String textIcon = text.toUpperCase();
    final String imagePath = switch (textIcon) {
      String s when s.startsWith("CMS") => isOnline ? 'assets/images/icons/van_Motion_True.png' : 'assets/images/icons/van_Motion_False.png',
      String s when s.startsWith("B") => isOnline ? 'assets/images/icons/bus_Motion_True.png' : 'assets/images/icons/bus_Motion_False.png',
      _ => isOnline ? 'assets/images/icons/car_Motion_True.png' : 'assets/images/icons/car_Motion_False.png',
    };

    // OPTIMIZACIÓN: Caché de la imagen base para evitar decodificación repetitiva
    ui.Image baseImage;
    if (_baseImageCache.containsKey(imagePath)) {
      baseImage = _baseImageCache[imagePath]!;
    } else {
      final ByteData data = await rootBundle.load(imagePath);
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: iconWidth.toInt(),
      );
      final ui.FrameInfo fi = await codec.getNextFrame();
      baseImage = fi.image;
      _baseImageCache[imagePath] = baseImage;
    }

    final double canvasWidth = (textPainter.width > baseImage.width) ? textPainter.width : baseImage.width.toDouble();
    final double canvasHeight = textPainter.height + baseImage.height + padding;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder, Rect.fromLTWH(0, 0, canvasWidth, canvasHeight));

    textPainter.paint(canvas, Offset((canvasWidth - textPainter.width) / 2, 0));
    canvas.drawImage(baseImage, Offset((canvasWidth - baseImage.width) / 2, textPainter.height + padding), Paint());

    final ui.Image finalImage = await pictureRecorder.endRecording().toImage(canvasWidth.toInt(), canvasHeight.toInt());
    final ByteData? byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData != null ? BitmapDescriptor.bytes(byteData.buffer.asUint8List()) : BitmapDescriptor.defaultMarker;
  }

  Future<void> showReaderEvents(RouteModel route, BuildContext context) async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final to = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final formatter = DateFormat("yyyy-MM-dd HH:mm");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChangeNotifierProvider.value(
        value: this,
        child: ReaderEventsBottomSheet(
          route: route,
          groupName: getGroupName(route.groupId),
          fechaInicio: formatter.format(from),
          fechaFin: formatter.format(to),
        ),
      ),
    );
  }

  Future<void> startReplay(int deviceId, DateTime from, DateTime to) async {
    _isReplaying = true;
    _replayedDeviceId = deviceId;
    _polylines.clear();
    notifyListeners();

    final formatter = DateFormat("yyyy-MM-ddTHH:mm:ss.SSS'Z'");
    try {
      final history = await RequestServ.instance.fetchHistory(
        deviceId: deviceId,
        from: formatter.format(from.toUtc()),
        to: formatter.format(to.toUtc()),
      );

      if (history == null || history.isEmpty) {
        _isReplaying = false;
        notifyListeners();
        Fluttertoast.showToast(msg: "No se encontró historial");
        return;
      }

      final points = history.map((pos) => LatLng((pos['latitude'] as num).toDouble(), (pos['longitude'] as num).toDouble())).toList();
      _polylines.add(Polyline(polylineId: PolylineId(deviceId.toString()), points: points, color: colorAmarillo, width: 4));

      if (_mapController != null) {
        double minLat = points.map((p) => p.latitude).reduce(math.min);
        double maxLat = points.map((p) => p.latitude).reduce(math.max);
        double minLng = points.map((p) => p.longitude).reduce(math.min);
        double maxLng = points.map((p) => p.longitude).reduce(math.max);
        _mapController!.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)), 50));
      }

      _historyData = history;
      _currentStepIndex = 0;
      _isPlaying = true;
      _generateArrows(points);
      _startPlaybackTimer();
      _updateReplayMarker();
    } catch (e) {
      _isReplaying = false;
    }
    notifyListeners();
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(Duration(milliseconds: (1000 / _playbackSpeed).toInt()), (timer) {
      if (_currentStepIndex < _historyData.length - 1) {
        _currentStepIndex++;
        _updateReplayMarker();
        notifyListeners();
      } else {
        _isPlaying = false;
        timer.cancel();
        notifyListeners();
      }
    });
  }

  void togglePlayPause() {
    _isPlaying = !_isPlaying;
    if (_isPlaying) {
      if (_currentStepIndex >= _historyData.length - 1) _currentStepIndex = 0;
      _startPlaybackTimer();
    } else {
      _playbackTimer?.cancel();
    }
    notifyListeners();
  }

  void seekTo(double value) {
    _currentStepIndex = value.toInt();
    _updateReplayMarker();
    notifyListeners();
  }

  void setPlaybackSpeed(double speed) {
    _playbackSpeed = speed;
    if (_isPlaying) _startPlaybackTimer();
    notifyListeners();
  }

  void toggleFollow() {
    _isFollowActive = !_isFollowActive;
    if (_isFollowActive && _historyData.isNotEmpty) _centerCameraOnCurrentStep();
    notifyListeners();
  }

  void _centerCameraOnCurrentStep() {
    if (_mapController == null || _historyData.isEmpty || _currentStepIndex >= _historyData.length) return;
    final pos = _historyData[_currentStepIndex];
    _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng((pos['latitude'] as num).toDouble(), (pos['longitude'] as num).toDouble())));
  }

  void _updateReplayMarker() async {
    if (_historyData.isEmpty || _currentStepIndex >= _historyData.length) return;
    final pos = _historyData[_currentStepIndex];
    final lat = (pos['latitude'] as num).toDouble();
    final lng = (pos['longitude'] as num).toDouble();
    if (lat == 0 || lng == 0) return;

    final route = _selectedRoutes.firstWhere((r) => r.id == pos['deviceId'], orElse: () => _selectedRoutes.first);
    final icon = await _createCustomMarker(route.name, true);
    
    _markers.removeWhere((m) => m.markerId.value == "replay_marker");
    _markers.add(Marker(markerId: const MarkerId("replay_marker"), position: LatLng(lat, lng), icon: icon, anchor: const Offset(0.5, 1.0), zIndex: 2));

    if (_isFollowActive) _centerCameraOnCurrentStep();
  }

  Future<BitmapDescriptor> _createArrowIcon() async {
    if (_arrowIcon != null) return _arrowIcon!;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 40.0;
    final paint = Paint()..color = colorAmarillo..style = PaintingStyle.fill;
    final path = Path()..moveTo(size/2, 0)..lineTo(size, size)..lineTo(size/2, size*0.7)..lineTo(0, size)..close();
    canvas.drawPath(path, paint);
    final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    _arrowIcon = BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
    return _arrowIcon!;
  }

  void _generateArrows(List<LatLng> points) async {
    _arrowMarkers.clear();
    if (points.length < 2) return;
    final icon = await _createArrowIcon();
    for (int i = 0; i < points.length - 1; i += 15) {
      final bearing = _calculateBearing(points[i], points[i+1]);
      final pos = _historyData[i];
      _arrowMarkers.add(Marker(
        markerId: MarkerId("arrow_$i"),
        position: points[i],
        icon: icon,
        rotation: bearing,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        infoWindow: InfoWindow(title: "Velocidad: ${((pos['speed'] as num? ?? 0.0) * 1.852).toStringAsFixed(1)} km/h"),
      ));
    }
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * (math.pi / 180.0);
    final lon1 = start.longitude * (math.pi / 180.0);
    final lat2 = end.latitude * (math.pi / 180.0);
    final lon2 = end.longitude * (math.pi / 180.0);
    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * (180.0 / math.pi) + 360.0) % 360.0;
  }

  @override
  Set<Marker> get markers => {
        ..._markers,
        ..._arrowMarkers,
        if (_interactiveStopMarker != null) _interactiveStopMarker!,
        ..._nearestOperatorMarkers,
      };

  void setInteractiveMarkers(InteractiveRouteModel route, List<OperatorModel> operators) async {
    _showInteractiveUI = true;
    // 1. Create custom markers
    final stopIcon = await _createCircularMarker(Icons.location_on, Colors.blueAccent, "Parada");
    final operatorIcon = await _createCircularMarker(Icons.person, const Color(0xFFF69D32), "Operador");

    // 2. Add Stop Marker
    _interactiveStopMarker = Marker(
      markerId: const MarkerId("selected_interactive_stop"),
      position: LatLng(route.latitud, route.longitud),
      infoWindow: InfoWindow(title: "Parada: ${route.nombreParada}"),
      icon: stopIcon,
    );

    // 3. Add Operator Markers
    _nearestOperatorMarkers.clear();
    for (var op in operators) {
      _nearestOperatorMarkers.add(
        Marker(
          markerId: MarkerId("operator_${op.operador}"),
          position: LatLng(op.latitude, op.longitude),
          icon: operatorIcon,
          onTap: () {
            if (_currentContext != null) {
              _showOperatorDetail(op, _currentContext!);
            }
          },
        ),
      );
    }

    // 4. Move Camera to Stop
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(route.latitud, route.longitud), 15),
      );
    }

    notifyListeners();
  }

  Future<BitmapDescriptor> _createCircularMarker(IconData icon, Color color, String label) async {
    const double size = 60.0;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = color;
    final double radius = size / 2;

    // Draw background circle
    canvas.drawCircle(Offset(radius, radius), radius, paint);
    
    // Draw Border
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;
    canvas.drawCircle(Offset(radius, radius), radius - 3, borderPaint);

    // Draw Icon
    TextPainter textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: 35.0,
        fontFamily: icon.fontFamily,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(radius - textPainter.width / 2, radius - textPainter.height / 2),
    );

    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  void _showOperatorDetail(OperatorModel op, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [Colors.white, Colors.grey[50]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF69D32).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, size: 40, color: Color(0xFFF69D32)),
              ),
              const SizedBox(height: 20),
              Text(
                op.operador,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF14143A)),
              ),
              const SizedBox(height: 10),
              Text(
                op.puesto,
                style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(),
              ),
              _buildModernInfoRow(Icons.supervisor_account, "Supervisor", op.supervisor),
              const SizedBox(height: 12),
              _buildModernInfoRow(Icons.phone, "Teléfono", op.telCel),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14143A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("Cerrar", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFFF69D32)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF14143A))),
          ],
        ),
      ],
    );
  }

  void stopReplay() {
    final formerId = _replayedDeviceId;
    _isReplaying = false;
    _isPlaying = false;
    _playbackTimer?.cancel();
    _polylines.clear();
    _arrowMarkers.clear();
    _markers.removeWhere((m) => m.markerId.value == "replay_marker");
    _replayedDeviceId = null;
    if (formerId != null && _mapController != null) {
      try {
        final route = _allRoutes.firstWhere((r) => r.id == formerId);
        _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(route.lat, route.lng)));
      } catch (_) {}
    }
    notifyListeners();
  }
}
