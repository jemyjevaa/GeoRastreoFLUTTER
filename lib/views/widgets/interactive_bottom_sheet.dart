import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/interactive_bottom_sheet_provider.dart';
import '../../models/interactive_route_model.dart';
import '../../models/operator_model.dart';

class InteractiveBottomSheet extends StatefulWidget {
  final Function(InteractiveRouteModel, List<OperatorModel>) onConfirm;

  const InteractiveBottomSheet({super.key, required this.onConfirm});

  @override
  State<InteractiveBottomSheet> createState() => _InteractiveBottomSheetState();
}

class _InteractiveBottomSheetState extends State<InteractiveBottomSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InteractiveBottomSheetProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InteractiveBottomSheetProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 50,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 25),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF14143A).withOpacity(0.05),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.route_outlined, color: Color(0xFF14143A), size: 28),
                          ),
                          const SizedBox(width: 15),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selección de Ruta',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF14143A),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Encuentra tu ruta y operadores clave',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      
                      // Filter by Company
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade100),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF14143A),
                                    borderRadius: BorderRadius.all(Radius.circular(8)),
                                  ),
                                  child: Text('1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                                SizedBox(width: 10),
                                Text('Empresa', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF14143A))),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              decoration: InputDecoration(
                                hintText: 'Buscar Empresa...',
                                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                                prefixIcon: Icon(Icons.search, size: 22, color: Colors.grey.shade400),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade100)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFFF69D32))),
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onChanged: (value) => provider.setCompanySearch(value),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                              decoration: InputDecoration(
                                labelText: 'Seleccionar Empresa',
                                labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade100)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFFF69D32))),
                                prefixIcon: const Icon(Icons.business, color: Color(0xFFF69D32), size: 22),
                              ),
                              value: provider.selectedCompany,
                              items: provider.companies.map((company) {
                                return DropdownMenuItem(
                                  value: company,
                                  child: Text(company, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF14143A)), overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) provider.selectCompany(value);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      // Filter by Route
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade100),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF14143A),
                                    borderRadius: BorderRadius.all(Radius.circular(8)),
                                  ),
                                  child: Text('2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                                SizedBox(width: 10),
                                Text('Ruta', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF14143A))),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (provider.selectedCompany != null) ...[
                              TextField(
                                decoration: InputDecoration(
                                  hintText: 'Buscar Ruta...',
                                  hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                                  prefixIcon: Icon(Icons.search, size: 22, color: Colors.grey.shade400),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade100)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFFF69D32))),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onChanged: (value) => provider.setRouteSearch(value),
                              ),
                              const SizedBox(height: 16),
                            ],
                            DropdownButtonFormField<InteractiveRouteModel>(
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                              decoration: InputDecoration(
                                labelText: 'Seleccionar Nombre de Ruta',
                                labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade100)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFFF69D32))),
                                prefixIcon: const Icon(Icons.route, color: Color(0xFFF69D32), size: 22),
                              ),
                              value: provider.selectedRoute,
                              disabledHint: const Text('Primero selecciona una empresa', style: TextStyle(color: Colors.grey)),
                              items: provider.selectedCompany == null
                                  ? null
                                  : provider.filteredRoutes.map((route) {
                                      return DropdownMenuItem(
                                        value: route,
                                        child: Text(route.nombreRuta, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF14143A)), overflow: TextOverflow.ellipsis),
                                      );
                                    }).toList(),
                              onChanged: (value) {
                                if (value != null) provider.selectRoute(value);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // If a route is selected, show details
                      if (provider.selectedRoute != null) ...[
                        
                        // Stop Information Card
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF14143A),
                                    borderRadius: BorderRadius.all(Radius.circular(8)),
                                  ),
                                  child: Text('3', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                                SizedBox(width: 10),
                                Text('Detalle de la Parada', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF14143A))),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.white,
                                border: Border.all(color: Colors.grey.shade100),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8)),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.blueAccent.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: const Icon(Icons.location_on_rounded, color: Colors.blueAccent, size: 28),
                                        ),
                                        const SizedBox(width: 15),
                                        Expanded(
                                          child: Text(
                                            provider.selectedRoute!.nombreParada,
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF14143A),
                                                letterSpacing: -0.3),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 20),
                                      child: Divider(height: 1),
                                    ),
                                    _buildInfoRow(Icons.map_outlined, 'Latitud', provider.selectedRoute!.latitud.toString()),
                                    const SizedBox(height: 12),
                                    _buildInfoRow(Icons.explore_outlined, 'Longitud', provider.selectedRoute!.longitud.toString()),
                                    const SizedBox(height: 30),
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFF69D32).withOpacity(0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFF69D32), Color(0xFFE88A1A)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: ElevatedButton(
                                        onPressed: () {
                                          widget.onConfirm(provider.selectedRoute!, provider.nearestOperators);
                                          Navigator.pop(context);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          minimumSize: const Size(double.infinity, 55),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text('Confirmar Selección', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.2)),
                                            SizedBox(width: 10),
                                            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
      ],
    );
  }

  Widget _buildStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(value.toString(),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}
