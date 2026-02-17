import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reader_event_model.dart';
import '../service/RequestServ.dart';

class ReaderEventsBottomSheet extends StatefulWidget {
  final int deviceId;
  final String unitName;
  final String fechaInicio;
  final String fechaFin;

  const ReaderEventsBottomSheet({
    super.key,
    required this.deviceId,
    required this.unitName,
    required this.fechaInicio,
    required this.fechaFin,
  });

  @override
  State<ReaderEventsBottomSheet> createState() => _ReaderEventsBottomSheetState();
}

class _ReaderEventsBottomSheetState extends State<ReaderEventsBottomSheet> {
  bool _isLoading = true;
  List<ReaderEvent> _events = [];
  String? _error;
  
  late DateTime _dtInicio;
  late DateTime _dtFin;
  final _formatter = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    try {
      _dtInicio = _formatter.parse(widget.fechaInicio);
      _dtFin = _formatter.parse(widget.fechaFin);
    } catch (e) {
      _dtInicio = DateTime.now().subtract(const Duration(hours: 24));
      _dtFin = DateTime.now();
    }
    _fetchData();
  }

  Future<void> _fetchData() async {
    final diff = _dtFin.difference(_dtInicio);
    if (diff.inDays >= 2) {
      bool? proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Advertencia'),
          content: const Text('La consulta que intenta hacer es grande y tardara en visualizarse o puede no responder ¿Desea continuar?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continuar')),
          ],
        ),
      );
      if (proceed != true) return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Petición del rango seleccionado
      final responseRange = await RequestServ.instance.fetchReaderEvents(
        deviceIds: [widget.deviceId],
        fechaInicio: _formatter.format(_dtInicio),
        fechaFin: _formatter.format(_dtFin),
      ).timeout(const Duration(seconds: 60));

      // 2. Petición de "Hoy" (independiente del rango seleccionado)
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day, 0, 0);
      final responseToday = await RequestServ.instance.fetchReaderEvents(
        deviceIds: [widget.deviceId],
        fechaInicio: _formatter.format(todayStart),
        fechaFin: _formatter.format(now),
      ).timeout(const Duration(seconds: 60));

      List<ReaderEvent> allEvents = [];

      if (responseRange != null && responseRange['respuesta'] == 'correcto') {
        allEvents.addAll(ReaderEventsResponse.fromJson(responseRange).datos);
      }
      
      if (responseToday != null && responseToday['respuesta'] == 'correcto') {
        allEvents.addAll(ReaderEventsResponse.fromJson(responseToday).datos);
      }

      if (!mounted) return;

      if (allEvents.isNotEmpty) {
        final seen = <String>{};
        final uniqueEvents = <ReaderEvent>[];
        
        for (var e in allEvents) {
          final key = "${e.unidad.trim()}|${e.noEmpleado.trim()}|${e.type.trim()}|${e.fecha.trim()}";
          if (seen.add(key)) {
            if (e.noEmpleado.isNotEmpty || e.type.isNotEmpty) {
              uniqueEvents.add(e);
            }
          }
        }

        uniqueEvents.sort((a, b) => b.fecha.compareTo(a.fecha));

        setState(() {
          _events = uniqueEvents;
          _isLoading = false;
        });
      } else if (responseRange == null && responseToday == null) {
        setState(() {
          _error = 'No se pudieron cargar los datos (Verifique su conexión)';
          _isLoading = false;
        });
      } else {
        setState(() {
          _events = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error in _fetchData: $e");
      if (!mounted) return;
      setState(() {
        if (e.toString().contains('timeout')) {
          _error = 'Tiempo de espera agotado al consultar registros';
        } else {
          _error = 'Error inesperado al cargar datos';
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateTime(bool isInicio) async {
    DateTime current = isInicio ? _dtInicio : _dtFin;
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current),
      );

      if (pickedTime != null) {
        setState(() {
          final newDt = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          if (isInicio) {
            _dtInicio = newDt;
          } else {
            _dtFin = newDt;
          }
        });
        _fetchData();
      }
    }
  }

  int get _totalEmployees {
    return _events
        .where((e) => e.noEmpleado.trim().isNotEmpty)
        .map((e) => e.noEmpleado.trim())
        .toSet()
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
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
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 48), 
                    Expanded(
                      child: Text(
                        'Eventos: ${widget.unitName}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF14143A),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _fetchData,
                      icon: const Icon(Icons.refresh, color: Color(0xFF14143A)),
                      tooltip: 'Actualizar',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              _buildDateFilters(),
              const Divider(),
              if (!_isLoading && _error == null) _buildSummary(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                          ))
                        : _events.isEmpty
                            ? const Center(child: Text('No hay eventos registrados'))
                            : RefreshIndicator(
                                onRefresh: _fetchData,
                                child: ListView.separated(
                                  controller: scrollController,
                                  itemCount: _events.length,
                                  separatorBuilder: (context, index) => const Divider(),
                                  itemBuilder: (context, index) {
                                    final event = _events[index];
                                    final bool hasEmployee = event.noEmpleado.isNotEmpty;
                                    
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: hasEmployee ? Colors.orange : _getTypeColor(event.type),
                                        child: Icon(
                                          hasEmployee ? Icons.person : _getTypeIcon(event.type),
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(
                                        hasEmployee && event.type.isEmpty 
                                            ? 'Registro de Empleado' 
                                            : (event.type.isNotEmpty ? event.type : 'Evento Desconocido'),
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Empleado: ${event.noEmpleado}'),
                                          Text('Fecha: ${event.fecha}'),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _selectDateTime(true),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Inicio', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(_formatter.format(_dtInicio), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const Icon(Icons.arrow_forward, color: Colors.grey, size: 16),
          Expanded(
            child: InkWell(
              onTap: () => _selectDateTime(false),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Fin', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(_formatter.format(_dtFin), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF69D32).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Total Empleados Registrados:',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF14143A)),
          ),
          Text(
            '$_totalEmployees',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF14143A)),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    if (type.toLowerCase().contains('encendido')) return Colors.green;
    if (type.toLowerCase().contains('apagado')) return Colors.red;
    return Colors.blue;
  }

  IconData _getTypeIcon(String type) {
    if (type.toLowerCase().contains('encendido')) return Icons.power_settings_new;
    if (type.toLowerCase().contains('apagado')) return Icons.power_off;
    return Icons.event;
  }
}
