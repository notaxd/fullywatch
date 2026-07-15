import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';
import 'login_screen.dart';
import 'station_detail_screen.dart';
import 'reports_screen.dart';

class StationListScreen extends StatefulWidget {
  final String role;
  final String name;
  const StationListScreen({super.key, required this.role, required this.name});

  @override
  State<StationListScreen> createState() => _StationListScreenState();
}

class _StationListScreenState extends State<StationListScreen> {
  List<dynamic> _stations = [];
  bool _loading = true;
  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadStations();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(AppConfig.wsUrl));
      _channel!.stream.listen(
        (message) {
          final decoded = jsonDecode(message);
          if (decoded['type'] == 'data_changed') {
            _loadStations();
          }
        },
        onError: (e) {},
        onDone: () {},
      );
    } catch (e) {
      // websocket optional; list still works via manual refresh
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  Future<void> _loadStations() async {
    try {
      final data = await ApiService.get('/stations/');
      setState(() {
        _stations = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await ApiService.clearToken();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }

  void _showAddStationDialog() {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    bool submitting = false;
    String error = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1b1e26),
              title: const Text('Add New Station', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Station Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Location'),
                  ),
                  if (error.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(error, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7c3aed)),
                  onPressed: submitting
                      ? null
                      : () async {
                          setDialogState(() {
                            submitting = true;
                            error = '';
                          });
                          try {
                            final name = Uri.encodeComponent(nameController.text.trim());
                            final location = Uri.encodeComponent(locationController.text.trim());
                            await ApiService.post('/stations/?name=$name&location=$location');
                            if (context.mounted) Navigator.pop(context);
                            _loadStations();
                          } catch (e) {
                            setDialogState(() {
                              submitting = false;
                              error = 'Failed to create station';
                            });
                          }
                        },
                  child: Text(submitting ? 'Creating...' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditStationDialog(Map<String, dynamic> station) {
    final nameController = TextEditingController(text: station['name']);
    final locationController = TextEditingController(text: station['location']);
    bool submitting = false;
    String error = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1b1e26),
              title: const Text('Edit Station', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Station Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Location'),
                  ),
                  if (error.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(error, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7c3aed)),
                  onPressed: submitting
                      ? null
                      : () async {
                          setDialogState(() {
                            submitting = true;
                            error = '';
                          });
                          try {
                            final name = Uri.encodeComponent(nameController.text.trim());
                            final location = Uri.encodeComponent(locationController.text.trim());
                            await ApiService.put(
                                '/stations/${station['id']}?name=$name&location=$location');
                            if (context.mounted) Navigator.pop(context);
                            _loadStations();
                          } catch (e) {
                            setDialogState(() {
                              submitting = false;
                              error = 'Failed to update station';
                            });
                          }
                        },
                  child: Text(submitting ? 'Saving...' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteStation(Map<String, dynamic> station) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1b1e26),
        title: const Text('Delete Station', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete "${station['name']}"? This also removes its dispensers, nozzles, and transactions. This cannot be undone.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await ApiService.delete('/stations/${station['id']}');
      _loadStations();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete station')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = widget.role == 'owner' || widget.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Stations'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF7c3aed).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(widget.role, style: const TextStyle(fontSize: 12)),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Reports',
            onPressed: _stations.isEmpty
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportsScreen(stations: _stations),
                      ),
                    );
                  },
            icon: const Icon(Icons.bar_chart),
          ),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      floatingActionButton: widget.role == 'owner'
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF7c3aed),
              onPressed: _showAddStationDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Station'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stations.isEmpty
              ? const Center(child: Text('No stations found'))
              : RefreshIndicator(
                  onRefresh: _loadStations,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _stations.length,
                    itemBuilder: (context, index) {
                      final station = _stations[index];
                      return Card(
                        color: const Color(0xFF1b1e26),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            station['name'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '📍 ${station['location']}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                          trailing: isOwner
                              ? PopupMenuButton<String>(
                                  color: const Color(0xFF1b1e26),
                                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _showEditStationDialog(station);
                                    } else if (value == 'delete') {
                                      _deleteStation(station);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit',
                                          style: TextStyle(color: Colors.white)),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete',
                                          style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                )
                              : const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StationDetailScreen(
                                  stationId: station['id'],
                                  stationName: station['name'],
                                  role: widget.role,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}