import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class MapsView extends StatefulWidget {
  const MapsView({super.key});

  @override
  State<MapsView> createState() => _MapsViewState();
}

class _MapsViewState extends State<MapsView> {
  final Color _colorAmarillo = const Color(0xFFF69D32);
  final Color _colorAzulFuerte = const Color(0xFF14143A);
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  GoogleMapController? _mapController;
  
  
  List<dynamic> _allRoutes = [];
  List<dynamic> _filteredRoutes = [];
  final List<dynamic> _selectedRoutes = [];
  bool _isLoadingRoutes = false;
  
  
  final String _cookie = "JSESSIONID=node07741a99m8jq11isjf5hdfnvoa22686.node0";

  
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(20.543508165491687, -103.47583907776028),
    zoom: 14,
  );

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  Future<void> _fetchRoutes() async {
    setState(() {
      _isLoadingRoutes = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://rastreobusmen.geovoy.com/api/devices'),
        headers: {'Cookie': _cookie},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _allRoutes = data;
          _filteredRoutes = data;
        });
      } else {
        // Manejar error
        debugPrint('Error fetching routes: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching routes: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRoutes = false;
        });
      }
    }
  }

  void _showUnitSelectionSheet() {
    
    if (_allRoutes.isEmpty) {
      _fetchRoutes();
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (_, controller) {
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
                      // Handle bar
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
                          color: _colorAzulFuerte,
                        ),
                      ),
                      const SizedBox(height: 15),
                      
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Buscar ruta...',
                            prefixIcon: Icon(Icons.search, color: _colorAzulFuerte),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          ),
                          onChanged: (value) {
                            setSheetState(() {
                              _filteredRoutes = _allRoutes
                                  .where((route) => route['name']
                                      .toString()
                                      .toLowerCase()
                                      .contains(value.toLowerCase()))
                                  .toList();
                            });
                          },
                        ),
                      ),
                      
                      const SizedBox(height: 10),
                      
                      
                      CheckboxListTile(
                        title: const Text(
                          'TODAS',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        value: _selectedRoutes.length == _allRoutes.length && _allRoutes.isNotEmpty,
                        activeColor: _colorAmarillo,
                        onChanged: (bool? value) {
                          setSheetState(() {
                            if (value == true) {
                              _selectedRoutes.clear();
                              _selectedRoutes.addAll(_allRoutes);
                            } else {
                              _selectedRoutes.clear();
                            }
                          });
                          setState(() {}); 
                        },
                      ),
                      
                      const Divider(),
                      
                      
                      Expanded(
                        child: _isLoadingRoutes
                            ? Center(child: CircularProgressIndicator(color: _colorAmarillo))
                            : ListView.builder(
                                controller: controller,
                                itemCount: _filteredRoutes.length,
                                itemBuilder: (context, index) {
                                  final route = _filteredRoutes[index];
                                  final isSelected = _selectedRoutes.contains(route);
                                  
                                  return CheckboxListTile(
                                    title: Text(
                                      route['name'] ?? 'Sin nombre',
                                      style: TextStyle(
                                        color: _colorAzulFuerte,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    value: isSelected,
                                    activeColor: _colorAmarillo,
                                    onChanged: (bool? value) {
                                      setSheetState(() {
                                        if (value == true) {
                                          _selectedRoutes.add(route);
                                        } else {
                                          _selectedRoutes.remove(route);
                                        }
                                      });
                                      setState(() {}); // Actualizar vista principal
                                    },
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: _colorAzulFuerte,
              ),
              accountName: const Text(
                'Usuario Demo',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              accountEmail: const Text(
                'usuario@demo.com',
                style: TextStyle(
                  color: Colors.white70,
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: _colorAmarillo,
                child: Text(
                  'U',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _colorAzulFuerte,
                  ),
                ),
              ),
            ),
            
            const Spacer(),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Cerrar Sesión',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pop(context);
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
            onMapCreated: _onMapCreated,
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
                icon: Icon(Icons.menu, color: _colorAzulFuerte),
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
                _selectedRoutes.isEmpty
                    ? '(Sin rutas seleccionadas)'
                    : _selectedRoutes.map((e) => e['name']).join(', '),
                style: TextStyle(
                  color: _colorAzulFuerte,
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
                  color: _colorAmarillo,
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
                      color: _colorAzulFuerte,
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
