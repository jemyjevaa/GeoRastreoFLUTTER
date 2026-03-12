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
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import '../views/reader_events_bottom_sheet.dart';

class MapViewModel extends ChangeNotifier {
  // Estado
  final Color colorAmarillo = const Color(0xFFF69D32);
  final Color colorAzulFuerte = const Color(0xFF14143A);
  
  List<RouteModel> _allRoutes = [];
  List<GroupModel> _allGroups = [];
  List<RouteModel> _filteredRoutes = [];
  final List<RouteModel> _selectedRoutes = [];
  final List<int> _loadingRoutes = [];
  String _groupSearchQuery = '';

  GoogleMapController? _mapController;
  bool _isLoadingRoutes = false;
  String _searchQuery = '';
  int? _selectedGroupId;
  // null = sin filtro, true = EN LINEA, false = FUERA DE LINEA, 'unknown' via separate field
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

  bool get isLoadingRoutes => _isLoadingRoutes;
  bool get isBottomSheetOpen => _isBottomSheetOpen;
  Set<Polyline> get polylines => _polylines;
  bool get isReplaying => _isReplaying;
  bool get isPlaying => _isPlaying;
  bool get isFollowActive => _isFollowActive;
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
      return 0; // Mantener el orden original para el resto
    });

    _filteredRoutes = filtered;
    notifyListeners();
  }

  String getGroupName(int groupId) {
    try {
      return _allGroups.firstWhere((g) => g.id == groupId).name;
    } catch (_) {
      return "Empresa no asignada";
    }
  }

  void toggleSelectAll() {
    if (_selectedRoutes.length == _allRoutes.length) {
      _selectedRoutes.clear();
      _markers.clear();
      _animationTimers.forEach((_, timer) => timer.cancel());
      _animationTimers.clear();
    } else {
      _selectedRoutes.clear();
      _selectedRoutes.addAll(_allRoutes);
    }
    _updateCameraBounds();
    _applyFilters();
  }

  void initSocket() {
    final socket = SocketServ.instance;
    socket.onUnitUpdate = (data) {
      _updateUnitPosition(data);
    };
    socket.connect();
  }

  void _updateCameraBounds() {
    if (_mapController == null || _selectedRoutes.isEmpty) return;

    if (_allRoutes.isNotEmpty && _selectedRoutes.length == _allRoutes.length) {
      return;
    }

    double positionCam = Platform.isAndroid ? 15.9 : 15.0;

    if (_selectedRoutes.length == 1) {
      final unit = _selectedRoutes.first;
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(LatLng(unit.lat, unit.lng), positionCam));
    } else {
      double minLat = _selectedRoutes.first.lat;
      double maxLat = _selectedRoutes.first.lat;
      double minLng = _selectedRoutes.first.lng;
      double maxLng = _selectedRoutes.first.lng;

      for (var unit in _selectedRoutes) {
        if (unit.lat < minLat) minLat = unit.lat;
        if (unit.lat > maxLat) maxLat = unit.lat;
        if (unit.lng < minLng) minLng = unit.lng;
        if (unit.lng > maxLng) maxLng = unit.lng;
      }

      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, positionCam));
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

      // region Groups _allGroups
      final responseGroups = await http.get(
        Uri.parse('https://rastreobusmen.geovoy.com/api/groups'),
        headers: {'Authorization': basicAuth},
      ).timeout(const Duration(seconds: 15));

      if (responseGroups.statusCode == 200) {
        final List<dynamic> data = json.decode(responseGroups.body);
        _allGroups = data.map((json) => GroupModel.fromJson(json)).toList();
        initSocket();
      } else {
        debugPrint('Error fetching groups: ${responseGroups.statusCode}');
      }
      // endregion Groups

      // region Device
      final responseDevice = await http.get(
        Uri.parse('https://rastreobusmen.geovoy.com/api/devices'),
        headers: {'Authorization': basicAuth},
      ).timeout(const Duration(seconds: 15));

      if (responseDevice.statusCode == 200) {
        final List<dynamic> data = json.decode(responseDevice.body);
        print("data => $data");
        _allRoutes = data.map((json) => RouteModel.fromJson(json)).toList();
        _filteredRoutes = List.from(_allRoutes);
      } else {
        debugPrint('Error fetching devices: ${responseDevice.statusCode}');
      }
      // endregion Device

    } catch (e) {
      debugPrint('Error fetching routes: $e');
    } finally {
      print("_allGroups => $_allGroups");
      print("_allRoutes => $_allRoutes");
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
      _updateCameraBounds();

      Fluttertoast.showToast(
        msg: "Unidad removida del mapa",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );

      _applyFilters();
    } else {
      _loadingRoutes.add(route.id);
      notifyListeners();

      try {
        Map<String, dynamic>? things = await RequestServ.instance.fetchByUnit(deviceId: route.id);
        var result = await RequestServ.instance.fetchStatusDevice(deviceId: route.id);
        if (things != null) {
          route.lat = (things["latitude"] as num).toDouble();
          route.lng = (things["longitude"] as num).toDouble();
        }
        if (result != null) {
          route.status = result["status"].toString().toUpperCase() == "ONLINE";
        }
        _selectedRoutes.add(route);
        await _addOrUpdateMarker(route);
      } catch (e) {
        debugPrint('Failed to fetch route details: $e');
      } finally {
        _loadingRoutes.remove(route.id);
        _updateCameraBounds();

        Fluttertoast.showToast(
          msg: "Unidad mostrada en el mapa",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );

        _applyFilters();
      }
    }
  }

  BuildContext? _currentContext;

  void updateContext(BuildContext context) {
    _currentContext = context;
  }

  void _updateMarker(RouteModel unit, BitmapDescriptor icon, {LatLng? position}) {
    final marker = Marker(
      markerId: MarkerId(unit.id.toString()),
      position: position ?? LatLng(unit.lat, unit.lng),
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
    final BitmapDescriptor icon = await _createCustomMarker(unit.name, unit.status ?? false);

    _updateMarker(unit, icon, position: position);
  }

  Future<void> _updateUnitPosition(Map<String, dynamic> data) async {
    if (selectedRoutesCount == 0) return;
    if (!data.containsKey('positions')) return;

    final positions = data['positions'];
    if (positions is! List || positions.isEmpty) return;

    final pos = positions.first;
    final deviceId = pos['deviceId'] as int;

    final index = _selectedRoutes.indexWhere((unit) => unit.id == deviceId);

    if (index != -1) {
      final unit = _selectedRoutes[index];
      final oldLatLng = LatLng(unit.lat, unit.lng);
      final newLatLng = LatLng((pos['latitude'] as num).toDouble(), (pos['longitude'] as num).toDouble());

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

        final animatedLatLng = LatLng(
          latTween.transform(t),
          lngTween.transform(t),
        );

        _updateMarker(unit, icon, position: animatedLatLng);
        notifyListeners();

        if (currentFrame >= totalFrames) {
          timer.cancel();
          _animationTimers.remove(deviceId);
          unit.lat = newLatLng.latitude;
          unit.lng = newLatLng.longitude;
          _updateMarker(unit, icon, position: newLatLng);
          _updateCameraBounds();
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
    );

    textPainter.text = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: Platform.isAndroid ? 12 : 18,
        color: Colors.black,
      ),
    );

    textPainter.layout(maxWidth: iconWidth * 1.5);

    String textIcon = text.toUpperCase();
    final String imagePath = switch (textIcon) {
      String s when s.startsWith("CMS") => isOnline
          ? 'assets/images/icons/van_Motion_True.png'
          : 'assets/images/icons/van_Motion_False.png',
      String s when s.startsWith("B") => isOnline
          ? 'assets/images/icons/bus_Motion_True.png'
          : 'assets/images/icons/bus_Motion_False.png',
      _ => isOnline
          ? 'assets/images/icons/car_Motion_True.png'
          : 'assets/images/icons/car_Motion_False.png',
    };

    final ByteData data = await rootBundle.load(imagePath);
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: iconWidth.toInt(),
    );
    final ui.FrameInfo fi = await codec.getNextFrame();
    final ui.Image image = fi.image;

    final double canvasWidth = (textPainter.width > image.width) ? textPainter.width : image.width.toDouble();
    final double canvasHeight = textPainter.height + image.height + padding;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder, Rect.fromLTWH(0, 0, canvasWidth, canvasHeight));

    final textOffset = Offset((canvasWidth - textPainter.width) / 2, 0);
    textPainter.paint(canvas, textOffset);

    final imageOffset = Offset((canvasWidth - image.width) / 2, textPainter.height + padding);
    canvas.drawImage(image, imageOffset, Paint());

    final ui.Image finalImage = await pictureRecorder.endRecording().toImage(
      canvasWidth.toInt(),
      canvasHeight.toInt(),
    );

    final ByteData? byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return BitmapDescriptor.defaultMarker;
    
    return BitmapDescriptor.bytes(byteData.buffer.asUint8List());
  }

  Future<void> showReaderEvents(RouteModel route, BuildContext context) async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final to = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final DateFormat formatter = DateFormat("yyyy-MM-dd HH:mm");
    final String fromStr = formatter.format(from);
    final String toStr = formatter.format(to);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChangeNotifierProvider.value(
        value: this,
        child: ReaderEventsBottomSheet(
          route: route,
          groupName: getGroupName(route.groupId),
          fechaInicio: fromStr,
          fechaFin: toStr,
        ),
      ),
    );
  }

  Future<void> startReplay(int deviceId, DateTime from, DateTime to) async {
    _isReplaying = true;
    _replayedDeviceId = deviceId;
    _polylines.clear();
    notifyListeners();

    final DateFormat formatter = DateFormat("yyyy-MM-ddTHH:mm:ss.SSS'Z'");
    final String fromStr = formatter.format(from.toUtc());
    final String toStr = formatter.format(to.toUtc());

    try {
      final history = await RequestServ.instance.fetchHistory(
        deviceId: deviceId,
        from: fromStr,
        to: toStr,
      );

      if (history == null || history.isEmpty) {
        _isReplaying = false;
        notifyListeners();
        Fluttertoast.showToast(msg: "No se encontró historial para este periodo");
        return;
      }

      final List<LatLng> points = history
          .map((pos) => LatLng(
                (pos['latitude'] as num).toDouble(),
                (pos['longitude'] as num).toDouble(),
              ))
          .toList();

      _polylines.add(Polyline(
        polylineId: PolylineId(deviceId.toString()),
        points: points,
        color: colorAmarillo,
        width: 4,
      ));

      // Fit camera to bounds
      if (_mapController != null) {
        double minLat = points.first.latitude;
        double maxLat = points.first.latitude;
        double minLng = points.first.longitude;
        double maxLng = points.first.longitude;

        for (var p in points) {
          if (p.latitude < minLat) minLat = p.latitude;
          if (p.latitude > maxLat) maxLat = p.latitude;
          if (p.longitude < minLng) minLng = p.longitude;
          if (p.longitude > maxLng) maxLng = p.longitude;
        }

        final bounds = LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        );

        _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
      }

      _historyData = history;
      _currentStepIndex = 0;
      _isPlaying = true;
      _generateArrows(points);
      _startPlaybackTimer();
      _updateReplayMarker();
      
      notifyListeners();
    } catch (e) {
      debugPrint("Error starting replay: $e");
      _isReplaying = false;
      notifyListeners();
    }
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    final interval = (1000 / _playbackSpeed).toInt();
    _playbackTimer = Timer.periodic(Duration(milliseconds: interval), (timer) {
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
      if (_currentStepIndex >= _historyData.length - 1) {
        _currentStepIndex = 0;
      }
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
    if (_isPlaying) {
      _startPlaybackTimer();
    }
    notifyListeners();
  }

  void toggleFollow() {
    _isFollowActive = !_isFollowActive;
    if (_isFollowActive && _historyData.isNotEmpty) {
      _centerCameraOnCurrentStep();
    }
    notifyListeners();
  }

  void _centerCameraOnCurrentStep() {
    if (_mapController == null || _historyData.isEmpty || _currentStepIndex >= _historyData.length) return;
    final pos = _historyData[_currentStepIndex];
    final lat = (pos['latitude'] as num).toDouble();
    final lng = (pos['longitude'] as num).toDouble();
    _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(lat, lng)));
  }

  void _updateReplayMarker() async {
    if (_historyData.isEmpty || _currentStepIndex >= _historyData.length) return;
    
    final pos = _historyData[_currentStepIndex];
    final lat = (pos['latitude'] as num).toDouble();
    final lng = (pos['longitude'] as num).toDouble();
    final deviceId = pos['deviceId'];
    
    // We reuse the existing marker logic but for the specific historical point
    final route = _selectedRoutes.firstWhere((r) => r.id == deviceId, orElse: () => _selectedRoutes.first);
    
    final BitmapDescriptor icon = await _createCustomMarker(route.name, true);
    
    final marker = Marker(
      markerId: MarkerId("replay_marker"),
      position: LatLng(lat, lng),
      icon: icon,
      anchor: const Offset(0.5, 1.0),
      zIndex: 2,
    );
    
    _markers.removeWhere((m) => m.markerId.value == "replay_marker");
    _markers.add(marker);

    if (_isFollowActive) {
      _centerCameraOnCurrentStep();
    }
  }

  Future<BitmapDescriptor> _createArrowIcon() async {
    if (_arrowIcon != null) return _arrowIcon!;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 40.0;
    final Paint paint = Paint()
      ..color = colorAmarillo
      ..style = PaintingStyle.fill;

    final Path path = Path();
    path.moveTo(size / 2, 0); // Tip
    path.lineTo(size, size); // Bottom right
    path.lineTo(size / 2, size * 0.7); // Bottom middle (indent)
    path.lineTo(0, size); // Bottom left
    path.close();

    canvas.drawPath(path, paint);

    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    _arrowIcon = BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
    return _arrowIcon!;
  }

  void _generateArrows(List<LatLng> points) async {
    _arrowMarkers.clear();
    if (points.length < 2) return;

    final BitmapDescriptor arrowIcon = await _createArrowIcon();

    // Add arrow every N points to avoid clutter
    const int gap = 15;
    for (int i = 0; i < points.length - 1; i += gap) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final bearing = _calculateBearing(p1, p2);
      
      final pos = _historyData[i];
      final dateRaw = pos['deviceTime'] ?? pos['serverTime'];
      String dateStr = "";
      String timeStr = "";
      if (dateRaw != null) {
        final date = DateTime.parse(dateRaw).toLocal();
        dateStr = DateFormat("dd/MM/yyyy").format(date);
        timeStr = DateFormat("HH:mm:ss").format(date);
      }
      final double speedVal = (pos['speed'] as num? ?? 0.0).toDouble() * 1.852; // knots to km/h

      final marker = Marker(
        markerId: MarkerId("arrow_$i"),
        position: p1,
        icon: arrowIcon,
        rotation: bearing,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        infoWindow: InfoWindow(
          title: "Velocidad: ${speedVal.toStringAsFixed(1)} km/h",
          snippet: "Fecha: $dateStr  Hora: $timeStr",
        ),
      );
      _arrowMarkers.add(marker);
    }
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final double lat1 = start.latitude * (3.141592653589793 / 180.0);
    final double lon1 = start.longitude * (3.141592653589793 / 180.0);
    final double lat2 = end.latitude * (3.141592653589793 / 180.0);
    final double lon2 = end.longitude * (3.141592653589793 / 180.0);

    final double dLon = lon2 - lon1;
    final double y = math.sin(dLon) * math.cos(lat2);
    final double x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final double radians = math.atan2(y, x);
    return (radians * (180.0 / 3.141592653589793) + 360.0) % 360.0;
  }

  @override
  Set<Marker> get markers => {..._markers, ..._arrowMarkers};

  void stopReplay() {
    final int? formerId = _replayedDeviceId;
    _isReplaying = false;
    _isPlaying = false;
    _playbackTimer?.cancel();
    _historyData = [];
    _polylines.clear();
    _arrowMarkers.clear();
    _markers.removeWhere((m) => m.markerId.value == "replay_marker");
    _replayedDeviceId = null;
    
    // Center camera on the unit if it exists in our real-time list
    if (formerId != null && _mapController != null) {
      try {
        final route = _allRoutes.firstWhere((r) => r.id == formerId);
        _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(route.lat, route.lng)));
      } catch (_) {
        // Route not found in current list
      }
    }
    
    notifyListeners();
  }
}
