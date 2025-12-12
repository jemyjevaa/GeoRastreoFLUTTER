
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/route_model.dart';
import '../service/RequestServ.dart';
import '../service/SocketServ.dart';
import 'package:fluttertoast/fluttertoast.dart';


class MapViewModel extends ChangeNotifier {

  // Estado
  final Color colorAmarillo = const Color(0xFFF69D32);
  final Color colorAzulFuerte = const Color(0xFF14143A);
  final String _cookie = "JSESSIONID=node07741a99m8jq11isjf5hdfnvoa22686.node0";

  List<RouteModel> _allRoutes = [];
  List<RouteModel> _filteredRoutes = [];
  final List<RouteModel> _selectedRoutes = [];
  final List<int> _loadingRoutes = [];

  GoogleMapController? _mapController;
  bool _isLoadingRoutes = false;
  String _searchQuery = '';
  bool _isBottomSheetOpen = false;

  bool get isLoadingRoutes => _isLoadingRoutes;
  bool get isBottomSheetOpen => _isBottomSheetOpen;

  List<RouteModel> get selectedRoutes => _selectedRoutes;
  List<RouteModel> get filteredRoutes => _filteredRoutes;
  int get totalRoutesCount => _allRoutes.length;
  int get selectedRoutesCount => _selectedRoutes.length;


  GoogleMapController? get mapController => _mapController;

  final Set<Marker> _markers = {};
  Set<Marker> get markers => _markers;

  final Map<int, Timer> _animationTimers = {};


  void toggleBottomSheet() {
    _isBottomSheetOpen = !_isBottomSheetOpen;
    if (!_isBottomSheetOpen) {
      _searchQuery = '';
    }else{
      _filteredRoutes = _allRoutes
          .toList();
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
    _filteredRoutes = _allRoutes
        .where((route) =>
            route.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
    notifyListeners();
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
    notifyListeners();
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
      final response = await http.get(
        Uri.parse('https://rastreobusmen.geovoy.com/api/devices'),
        headers: {'Cookie': _cookie},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _allRoutes = data.map((json) => RouteModel.fromJson(json)).toList();
        _filteredRoutes = List.from(_allRoutes);
        initSocket();
      } else {
        debugPrint('Error fetching routes: ${response.statusCode}');
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
      _updateCameraBounds();

      Fluttertoast.showToast(
        msg: "Unidad removida del mapa",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );

      notifyListeners();
    } else {
      _loadingRoutes.add(route.id);
      notifyListeners();

      try {
        Map<String, dynamic>? things = await RequestServ.instance.fetchByUnit(cookie: _cookie, deviceId: route.id);
        var result = await RequestServ.instance.fetchStatusDevice(cookie: _cookie, deviceId: route.id);
        route.lat = things!["latitude"];
        route.lng = things["longitude"];
        route.status = result["status"].toString().toUpperCase() == "ONLINE";
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

        notifyListeners();
      }
    }

  }

  void _updateMarker(RouteModel unit, BitmapDescriptor icon, {LatLng? position}) {
    final marker = Marker(
      markerId: MarkerId(unit.id.toString()),
      position: position ?? LatLng(unit.lat, unit.lng),
      infoWindow: InfoWindow(title: unit.name),
      icon: icon,
      anchor: const Offset(0.5, 1.0),
    );
    _markers.removeWhere((m) => m.markerId.value == unit.id.toString());
    _markers.add(marker);
  }

  Future<void> _addOrUpdateMarker(RouteModel unit, {LatLng? position}) async {
    final BitmapDescriptor icon = await _createCustomMarker(unit.name, unit.status);
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
      final newLatLng = LatLng(pos['latitude'] as double, pos['longitude'] as double);

      unit.status = pos["attributes"]['ignition'].toString().toUpperCase() == "TRUE" &&
          pos["attributes"]['motion'].toString().toUpperCase() == "TRUE";

      if (_animationTimers.containsKey(deviceId)) {
        _animationTimers[deviceId]!.cancel();
      }

      final BitmapDescriptor icon = await _createCustomMarker(unit.name, unit.status);

      const animationDuration = Duration(seconds: 2);
      const framesPerSecond = 30;
      final totalFrames = animationDuration.inSeconds * framesPerSecond;
      var currentFrame = 0;

      final latTween = Tween(begin: oldLatLng.latitude, end: newLatLng.latitude);
      final lngTween = Tween(begin: oldLatLng.longitude, end: newLatLng.longitude);

      _animationTimers[deviceId] = Timer.periodic(Duration(milliseconds: 1000 ~/ framesPerSecond), (timer) {
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
    final double iconWidth = Platform.isAndroid ? 115.0 : 180.0;
    const double padding = 1.0;

    final TextPainter textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    textPainter.text = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: Platform.isAndroid ? 30 : 50,
        color: Colors.black,
      ),
    );

    textPainter.layout(maxWidth: iconWidth * 1.5);

    String text_icon = text.toUpperCase();
    final String imagePath = switch (text_icon) {
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
    final Uint8List pngBytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(pngBytes);
  }
}
