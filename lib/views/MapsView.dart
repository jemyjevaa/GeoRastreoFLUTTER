import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../service/auth_service.dart';
import '../models/user_session.dart';
import '../viewmodel/map_viewmodel.dart';


class MapsView extends StatelessWidget {
  const MapsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MapViewModel(),
      child: const _MapsViewContent(),
    );
  }
}

class _MapsViewContent extends StatefulWidget {
  const _MapsViewContent();

  @override
  State<_MapsViewContent> createState() => _MapsViewContentState();
}

class _MapsViewContentState extends State<_MapsViewContent> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  final AuthService _authService = AuthService();
  UserSession? _userSession;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(20.543508165491687, -103.47583907776028),
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();
    _loadUserSession();

  }

  Future<void> _loadUserSession() async {
    final session = await _authService.getUserSession();
    
    if (mounted) {
      setState(() {
        _userSession = session;
      });
    }
  }


  void _showUnitSelectionSheet() async {
    final viewModel = Provider.of<MapViewModel>(context, listen: false);

    if (viewModel.isBottomSheetOpen) return;

    viewModel.toggleBottomSheet();
    viewModel.fetchRoutes();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return ChangeNotifierProvider.value(
          value: viewModel,
          child: Consumer<MapViewModel>(
            builder: (sheetContext, model, child) {
              return DraggableScrollableSheet(
                initialChildSize: 0.90,
                minChildSize: 0.4,
                maxChildSize: 0.9,
                builder: (_, scrollController) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Seleccionar Rutas',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: model.colorAzulFuerte,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // ---- STATUS FILTER BUTTONS ----
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              // EN LÍNEA
                              Expanded(
                                child: _StatusFilterButton(
                                  label: 'EN LÍNEA',
                                  count: model.onlineCount,
                                  icon: Icons.circle,
                                  activeColor: Colors.green,
                                  isActive: model.statusFilter == true && !model.statusFilterUnknown,
                                  onTap: () {
                                    if (model.statusFilter == true && !model.statusFilterUnknown) {
                                      model.clearStatusFilter();
                                    } else {
                                      model.filterByStatus(true);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              // FUERA DE LÍNEA
                              Expanded(
                                child: _StatusFilterButton(
                                  label: 'FUERA',
                                  count: model.offlineCount,
                                  icon: Icons.circle,
                                  activeColor: Colors.red,
                                  isActive: model.statusFilter == false && !model.statusFilterUnknown,
                                  onTap: () {
                                    if (model.statusFilter == false && !model.statusFilterUnknown) {
                                      model.clearStatusFilter();
                                    } else {
                                      model.filterByStatus(false);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              // DESCONOCIDO
                              Expanded(
                                child: _StatusFilterButton(
                                  label: 'DESC.',
                                  count: model.unknownCount,
                                  icon: Icons.help_outline,
                                  activeColor: Colors.grey,
                                  isActive: model.statusFilterUnknown,
                                  onTap: () {
                                    if (model.statusFilterUnknown) {
                                      model.clearStatusFilter();
                                    } else {
                                      model.filterByStatus(null, unknown: true);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: GestureDetector(
                            onTap: () => _showCompanySearchDialog(model),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.business_center, color: model.colorAzulFuerte, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      model.selectedGroupId == null 
                                          ? 'Todas las empresas' 
                                          : model.getGroupName(model.selectedGroupId!),
                                      style: TextStyle(color: model.colorAzulFuerte, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Icon(Icons.arrow_drop_down, color: model.colorAzulFuerte),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Buscar ruta...',
                              prefixIcon: Icon(Icons.search, color: model.colorAzulFuerte),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            ),
                            onChanged: model.searchRoutes,
                          ),
                        ),
                        const SizedBox(height: 10),
                        CheckboxListTile(
                          title: const Text(
                            'TODAS',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          value: model.selectedRoutesCount == model.totalRoutesCount && model.totalRoutesCount > 0,
                          activeColor: model.colorAmarillo,
                          onChanged: (bool? value) {
                            model.toggleSelectAll();
                          },
                        ),
                        const Divider(),
                        Expanded(
                          child: model.isLoadingRoutes
                              ? Center(child: CircularProgressIndicator(color: model.colorAmarillo))
                              : ListView.builder(
                                  controller: scrollController,
                                  itemCount: model.filteredRoutes.length,
                                  itemBuilder: (context, index) {
                                    final route = model.filteredRoutes[index];
                                    final isSelected = model.isRouteSelected(route);
                                    final isLoading = model.isRouteLoading(route);

                                    return ListTile(
                                      onTap: isLoading ? null : () => model.toggleRouteSelection(route),
                                      leading: Container(
                                        width: 10,
                                        height: 10,
                                        margin: const EdgeInsets.only(top: 4),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: route.status == null
                                              ? Colors.grey
                                              : route.status == true
                                                  ? Colors.green
                                                  : Colors.red,
                                        ),
                                      ),
                                      title: Text(
                                        route.name,
                                        style: TextStyle(
                                          color: model.colorAzulFuerte,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        model.getGroupName(route.groupId),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                      trailing: isLoading
                                          ? SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                color: model.colorAmarillo,
                                                strokeWidth: 2.5,
                                              ),
                                            )
                                          : Checkbox(
                                              value: isSelected,
                                              activeColor: model.colorAmarillo,
                                              onChanged: (bool? value) {
                                                model.toggleRouteSelection(route);
                                              },
                                            ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );

    viewModel.toggleBottomSheet();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<MapViewModel>(context);
    
    // Actualizamos el contexto de forma segura después de que el frame se dibuje
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) viewModel.updateContext(context);
    });

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: viewModel.colorAzulFuerte,
              ),
              accountName: Text(
                _userSession?.name ?? 'Usuario',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              accountEmail: Text(
                _userSession?.email ?? 'usuario@demo.com',
                style: const TextStyle(
                  color: Colors.white70,
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: viewModel.colorAmarillo,
                child: Text(
                  (_userSession?.name ?? 'U').substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: viewModel.colorAzulFuerte,
                  ),
                ),
              ),
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Cerrar Sesión',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                await _authService.logout();
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: viewModel.onMapCreated,
            markers: viewModel.markers,
            polylines: viewModel.polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(Icons.menu, color: viewModel.colorAzulFuerte),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
            ),
          ),
          Positioned(
            top: 110, 
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                viewModel.selectedRoutes.isEmpty
                    ? '(Sin rutas seleccionadas)'
                    : viewModel.selectedRoutes.map((e) => e.name).join(', '),
                style: TextStyle(
                  color: viewModel.colorAzulFuerte,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: GestureDetector(
              onTap: _showUnitSelectionSheet,
              child: Container(
                height: 45,
                decoration: BoxDecoration(
                  color: viewModel.colorAmarillo,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'SELECCIONAR UNIDAD',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: viewModel.colorAzulFuerte,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (viewModel.isReplaying)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: _ReplayConsole(viewModel: viewModel),
            ),
        ],
      ),
    );
  }

  void _showCompanySearchDialog(MapViewModel model) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Seleccionar Empresa'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (val) {
                        model.searchGroups(val);
                        setModalState(() {});
                      },
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: model.filteredGroups.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return ListTile(
                              title: const Text('Todas las empresas'),
                              onTap: () {
                                model.filterByGroup(null);
                                Navigator.pop(context);
                              },
                              selected: model.selectedGroupId == null,
                            );
                          }
                          final group = model.filteredGroups[index - 1];
                          return ListTile(
                            title: Text(group.name),
                            onTap: () {
                              model.filterByGroup(group.id);
                              Navigator.pop(context);
                            },
                            selected: model.selectedGroupId == group.id,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ReplayConsole extends StatelessWidget {
  final MapViewModel viewModel;

  const _ReplayConsole({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: viewModel.colorAzulFuerte,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(
                  viewModel.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: viewModel.colorAmarillo,
                  size: 40,
                ),
                onPressed: viewModel.togglePlayPause,
              ),
              Expanded(
                child: Column(
                  children: [
                    Slider(
                      value: viewModel.currentStepIndex.toDouble().clamp(0, (viewModel.totalSteps - 1).toDouble().clamp(0, double.infinity)),
                      min: 0,
                      max: (viewModel.totalSteps - 1).toDouble().clamp(0, double.infinity),
                      activeColor: viewModel.colorAmarillo,
                      inactiveColor: Colors.grey[700],
                      onChanged: viewModel.seekTo,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            viewModel.currentTimestamp,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    viewModel.isFollowActive ? Icons.location_searching : Icons.location_disabled,
                                    color: viewModel.isFollowActive ? viewModel.colorAmarillo : Colors.grey,
                                    size: 18,
                                  ),
                                  onPressed: viewModel.toggleFollow,
                                  tooltip: 'Seguir unidad',
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    "${viewModel.playbackSpeed.toStringAsFixed(1)}x",
                                    style: const TextStyle(color: Colors.white, fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 30),
                onPressed: viewModel.stopReplay,
                tooltip: 'Cerrar Replay',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [1.0, 2.0, 5.0, 10.0].map((speed) {
              final isSelected = viewModel.playbackSpeed == speed;
              return GestureDetector(
                onTap: () => viewModel.setPlaybackSpeed(speed),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? viewModel.colorAmarillo : Colors.transparent,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: viewModel.colorAmarillo),
                  ),
                  child: Text(
                    "${speed.toInt()}x",
                    style: TextStyle(
                      color: isSelected ? viewModel.colorAzulFuerte : viewModel.colorAmarillo,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Compact button for status filtering in the unit selection sheet
class _StatusFilterButton extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color activeColor;
  final bool isActive;
  final VoidCallback onTap;

  const _StatusFilterButton({
    required this.label,
    required this.count,
    required this.icon,
    required this.activeColor,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.12) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? activeColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: activeColor, //isActive ? activeColor : Colors.grey[400],
              size: 14,
            ),
            const SizedBox(height: 3),
            Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isActive ? activeColor : const Color(0xFF14143A),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isActive ? activeColor : Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
