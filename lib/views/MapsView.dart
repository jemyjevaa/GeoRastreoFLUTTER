import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/auth_service.dart';
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
                initialChildSize: 0.6,
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
                        const SizedBox(height: 15),
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
                                      title: Text(
                                        route.name,
                                        style: TextStyle(
                                          color: model.colorAzulFuerte,
                                          fontWeight: FontWeight.w500,
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
        ],
      ),
    );
  }
}
