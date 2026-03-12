import 'package:flutter/material.dart';
import 'package:geo_rastreo/models/camera_device_unit_model.dart';
import 'package:geo_rastreo/service/RequestServ.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class CameraUnit extends StatefulWidget {
  const CameraUnit({super.key, required this.nameUnit});
  final String nameUnit;

  @override
  State<CameraUnit> createState() => _CameraUnitState();
}

class _CameraUnitState extends State<CameraUnit> {
  List<String> _cameraUrls = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getCameraUnite();
  }

  Future<void> _getCameraUnite() async {
    String urlDevice = "https://apiscamarasbusmen.geovoy.com/api/dispotivosCam";
    try {
      CameraDeviceUnitModel? respCamera = await RequestServ.instance.handlingRequestParsed(
          urlParam: urlDevice,
          params: {"unidad": widget.nameUnit},
          method: "GET",
          asJson: false,
          fromJson: (json) => CameraDeviceUnitModel.fromJson(json));

      if (respCamera != null && respCamera.mensaje.isNotEmpty) {
        String deviceID = respCamera.mensaje.first.deviceID;
        if (mounted) {
          setState(() {
            _cameraUrls = List.generate(4, (i) => 
              "https://camarasbusmen.geovoy.com:22060/live.flv?devid=$deviceID&chl=${i + 1}&st=1&audio=1"
            );
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("[ Error ] _getCameraUnite => $e");
      if (mounted) setState(() => _isLoading = false);
    }
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
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _cameraUrls.length,
                        itemBuilder: (context, index) {
                          return _CameraPlayerItem(
                            url: _cameraUrls[index], 
                            title: "Cámara ${index + 1}",
                            key: ValueKey(_cameraUrls[index]),
                          );
                        },
                      ),
                ),
              ],
            ),
          );
        });
  }
}

class _CameraPlayerItem extends StatefulWidget {
  final String url;
  final String title;
  const _CameraPlayerItem({super.key, required this.url, required this.title});

  @override
  State<_CameraPlayerItem> createState() => _CameraPlayerItemState();
}

class _CameraPlayerItemState extends State<_CameraPlayerItem> {
  late final Player player = Player();
  late final VideoController controller = VideoController(player);

  @override
  void initState() {
    super.initState();
    player.open(Media(widget.url));
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            widget.title,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF14143A)),
          ),
        ),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Video(controller: controller),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
