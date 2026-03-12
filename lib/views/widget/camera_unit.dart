import 'package:flutter/material.dart';
import 'package:geo_rastreo/models/camera_device_unit_model.dart';
import 'package:geo_rastreo/service/RequestServ.dart';
import 'package:video_player/video_player.dart';

class CameraUnit extends StatefulWidget {
  const CameraUnit({super.key, required this.nameUnit});

  final String nameUnit;

  @override
  State<CameraUnit> createState() => _CameraUnitState();
}

class _CameraUnitState extends State<CameraUnit> {
  // Usamos controladores opcionales para evitar errores de 'late' si la API tarda
  VideoPlayerController? _controller1;
  VideoPlayerController? _controller2;
  VideoPlayerController? _controller3;
  VideoPlayerController? _controller4;

  @override
  void initState() {
    super.initState();
    _getCameraUnite();
  }

  @override
  void dispose() {
    // Es muy importante liberar los controladores al cerrar el widget
    _controller1?.dispose();
    _controller2?.dispose();
    _controller3?.dispose();
    _controller4?.dispose();
    super.dispose();
  }

  Future<void> _getCameraUnite() async {
    String urlDevice = "https://apiscamarasbusmen.geovoy.com/api/dispotivosCam";
    RequestServ requestServ = RequestServ.instance;

    try {
      CameraDeviceUnitModel? respCamera = await requestServ.handlingRequestParsed(
          urlParam: urlDevice,
          params: {"unidad": widget.nameUnit},
          method: "GET",
          asJson: false,
          fromJson: (json) => CameraDeviceUnitModel.fromJson(json));

      if (respCamera == null || respCamera.mensaje.isEmpty) {
        return;
      }

      String deviceID = respCamera.mensaje.first.deviceID;

      // Inicializamos cada cámara. Usamos networkUrl porque es una URL de internet, no un archivo local.
      _controller1 = VideoPlayerController.networkUrl(
        Uri.parse("https://camarasbusmen.geovoy.com:22060/live.flv?devid=$deviceID&chl=1&st=1&audio=1"),
      )..initialize().then((_) {
          if (mounted) setState(() {});
          _controller1?.play(); // Opcional: auto-reproducir
        });

      _controller2 = VideoPlayerController.networkUrl(
        Uri.parse("https://camarasbusmen.geovoy.com:22060/live.flv?devid=$deviceID&chl=2&st=1&audio=1"),
      )..initialize().then((_) {
          if (mounted) setState(() {});
          _controller2?.play();
        });

      _controller3 = VideoPlayerController.networkUrl(
        Uri.parse("https://camarasbusmen.geovoy.com:22060/live.flv?devid=$deviceID&chl=3&st=1&audio=1"),
      )..initialize().then((_) {
          if (mounted) setState(() {});
          _controller3?.play();
        });

      _controller4 = VideoPlayerController.networkUrl(
        Uri.parse("https://camarasbusmen.geovoy.com:22060/live.flv?devid=$deviceID&chl=4&st=1&audio=1"),
      )..initialize().then((_) {
          if (mounted) setState(() {});
          _controller4?.play();
        });
    } catch (e) {
      debugPrint("[ Error ] _getCameraUnite => $e");
    }
  }

  // Widget reutilizable para cada cuadro de video
  Widget _buildVideoBox(VideoPlayerController? controller, String title) {
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF14143A))),
          ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: controller != null && controller.value.isInitialized
                  ? VideoPlayer(controller)
                  : const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Cámaras - ${widget.nameUnit}",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _buildVideoBox(_controller1, "Cámara"),
                      const SizedBox(width: 12),
                      _buildVideoBox(_controller2, "Cámara"),
                      const SizedBox(height: 12),
                      _buildVideoBox(_controller3, "Cámara"),
                      const SizedBox(width: 12),
                      _buildVideoBox(_controller4, "Cámara"),
                      // Row(
                      //   children: [
                      //     _buildVideoBox(_controller1, "Cámara 1"),
                      //     const SizedBox(width: 12),
                      //     _buildVideoBox(_controller2, "Cámara 2"),
                      //   ],
                      // ),
                      // const SizedBox(height: 16),
                      // Row(
                      //   children: [
                      //     _buildVideoBox(_controller3, "Cámara 3"),
                      //     const SizedBox(width: 12),
                      //     _buildVideoBox(_controller4, "Cámara 4"),
                      //   ],
                      // ),
                      // const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          );
        });
  }
}
