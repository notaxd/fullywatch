import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';

class StationDetailScreen extends StatefulWidget {
  final int stationId;
  final String stationName;
  final String role;
  const StationDetailScreen({
    super.key,
    required this.stationId,
    required this.stationName,
    this.role = 'owner',
  });

  @override
  State<StationDetailScreen> createState() => _StationDetailScreenState();
}

class _StationDetailScreenState extends State<StationDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  WebSocketChannel? _channel;
  bool _wsConnected = false;
  int? _pulsingDispenserId;
  List<dynamic> _managers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadManagers();
    _connectWebSocket();
  }

  Future<void> _loadManagers() async {
    try {
      final data = await ApiService.get('/stations/${widget.stationId}/managers');
      setState(() => _managers = data);
    } catch (e) {
      // managers list is optional
    }
  }

  void _showInviteManagerDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool submitting = false;
    String error = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1b1e26),
              title: const Text('Invite Manager', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dialogInput('Full Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dialogInput('Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dialogInput('Password'),
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
                            final email = Uri.encodeComponent(emailController.text.trim());
                            final password = Uri.encodeComponent(passwordController.text.trim());
                            await ApiService.post(
                                '/auth/invite-manager?full_name=$name&email=$email&password=$password&station_id=${widget.stationId}');
                            if (context.mounted) Navigator.pop(context);
                            _loadManagers();
                          } catch (e) {
                            setDialogState(() {
                              submitting = false;
                              error = 'Failed to invite manager';
                            });
                          }
                        },
                  child: Text(submitting ? 'Inviting...' : 'Invite'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _loadData() async {
    try {
      final data = await ApiService.get('/stations/${widget.stationId}/live');
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(AppConfig.wsUrl));
      setState(() => _wsConnected = true);

      _channel!.stream.listen(
  (message) {
    final decoded = jsonDecode(message);
    if (decoded['type'] == 'new_transaction') {
      _loadData();
      final dispId = decoded['data']['dispenser_id'];
      setState(() => _pulsingDispenserId = dispId);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _pulsingDispenserId = null);
      });
    } else if (decoded['type'] == 'data_changed') {
      _loadData();
    }
  },
        onDone: () {
          if (mounted) setState(() => _wsConnected = false);
        },
        onError: (e) {
          if (mounted) setState(() => _wsConnected = false);
        },
      );
    } catch (e) {
      setState(() => _wsConnected = false);
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  InputDecoration _dialogInput(String label) {
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

  void _showAddDispenserDialog() {
    final nameController = TextEditingController();
    bool submitting = false;
    String error = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1b1e26),
              title: const Text('Add Dispenser', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dialogInput('Dispenser Name (e.g. Pump 1)'),
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
                            await ApiService.post(
                                '/dispensers/?name=$name&station_id=${widget.stationId}');
                            if (context.mounted) Navigator.pop(context);
                            _loadData();
                          } catch (e) {
                            setDialogState(() {
                              submitting = false;
                              error = 'Failed to add dispenser';
                            });
                          }
                        },
                  child: Text(submitting ? 'Adding...' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void showAddNozzleDialog(int dispenserId) {
    final numberController = TextEditingController();
    String fuelType = 'petrol';
    bool submitting = false;
    String error = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1b1e26),
              title: const Text('Add Nozzle', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: numberController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dialogInput('Nozzle Number'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: fuelType,
                    dropdownColor: const Color(0xFF1b1e26),
                    style: const TextStyle(color: Colors.white),
                    decoration: _dialogInput('Fuel Type'),
                    items: const [
                      DropdownMenuItem(value: 'petrol', child: Text('Petrol')),
                      DropdownMenuItem(value: 'diesel', child: Text('Diesel')),
                      DropdownMenuItem(value: 'high-octane', child: Text('High-Octane')),
                    ],
                    onChanged: (v) => setDialogState(() => fuelType = v!),
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
                            final number = numberController.text.trim();
                            await ApiService.post(
                                '/nozzles/?dispenser_id=$dispenserId&nozzle_number=$number&fuel_type=$fuelType');
                            if (context.mounted) Navigator.pop(context);
                            _loadData();
                          } catch (e) {
                            setDialogState(() {
                              submitting = false;
                              error = 'Failed to add nozzle';
                            });
                          }
                        },
                  child: Text(submitting ? 'Adding...' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openDispenserSheet(Map<String, dynamic> dispenser) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1b1e26),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _DispenserSheet(
          dispenser: dispenser,
          onChanged: () {
            _loadData();
          },
          onAddNozzle: () => showAddNozzleDialog(dispenser['id']),
        );
      },
    );
  }

  Widget _buildManagersBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1b1e26),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Station Managers (${_managers.length})',
              style: const TextStyle(
                  color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _managers.map((m) {
              final name = (m['full_name'] ?? 'M').toString();
              final initial = name.isNotEmpty ? name[0].toUpperCase() : 'M';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: const Color(0xFF7c3aed),
                      child: Text(initial,
                          style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                    const SizedBox(width: 6),
                    Text(name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(m['email'] ?? '',
                        style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dispensers = _data?['dispensers'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stationName),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _wsConnected ? Colors.green : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _wsConnected ? 'Live' : 'Offline',
                    style: TextStyle(
                      fontSize: 13,
                      color: _wsConnected ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.role == 'owner' || widget.role == 'admin')
            IconButton(
              tooltip: 'Invite Manager',
              onPressed: _showInviteManagerDialog,
              icon: const Icon(Icons.person_add_alt_1),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF7c3aed),
        onPressed: _showAddDispenserDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Dispenser'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : dispensers.isEmpty
              ? const Center(child: Text('No dispensers at this station'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_managers.isNotEmpty) _buildManagersBanner(),
                      ...List.generate(dispensers.length, (index) {
                        return _DispenserCard(
                          dispenser: dispensers[index],
                          isPulsing: _pulsingDispenserId == dispensers[index]['id'],
                          onAddNozzle: () => showAddNozzleDialog(dispensers[index]['id']),
                          onTap: () => _openDispenserSheet(dispensers[index]),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}

class _DispenserSheet extends StatefulWidget {
  final Map<String, dynamic> dispenser;
  final VoidCallback onChanged;
  final VoidCallback onAddNozzle;
  const _DispenserSheet({
    required this.dispenser,
    required this.onChanged,
    required this.onAddNozzle,
  });

  @override
  State<_DispenserSheet> createState() => _DispenserSheetState();
}

class _DispenserSheetState extends State<_DispenserSheet> {
  late String _dispStatus;
  bool _updating = false;
  int _selectedNozzleIndex = 0;
  List<dynamic> _history = [];
  bool _loadingHistory = false;
  int? _historyNozzleId;

  static const Map<String, Color> statusColors = {
    'active': Colors.green,
    'offline': Colors.grey,
    'error': Colors.red,
  };

  @override
  void initState() {
    super.initState();
    _dispStatus = widget.dispenser['status'] ?? 'active';
    final nozzles = widget.dispenser['nozzles'] as List<dynamic>? ?? [];
    if (nozzles.isNotEmpty) {
      _fetchHistory(nozzles[0]['id']);
    }
  }

  Future<void> _fetchHistory(int nozzleId) async {
    setState(() {
      _loadingHistory = true;
      _historyNozzleId = nozzleId;
    });
    try {
      final data = await ApiService.get('/nozzles/$nozzleId/transactions');
      if (_historyNozzleId == nozzleId) {
        setState(() {
          _history = data;
          _loadingHistory = false;
        });
      }
    } catch (e) {
      setState(() {
        _history = [];
        _loadingHistory = false;
      });
    }
  }

  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      final m = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month - 1]} ${dt.day}, $h:$m $ampm';
    } catch (e) {
      return timestamp;
    }
  }

  Future<void> _changeDispenserStatus(String status) async {
    setState(() => _updating = true);
    try {
      await ApiService.patch('/dispensers/${widget.dispenser['id']}/status?status=$status');
      setState(() => _dispStatus = status);
      widget.onChanged();
    } catch (e) {
      _toast('Failed to update dispenser status');
    } finally {
      setState(() => _updating = false);
    }
  }

  Future<void> _changeNozzleStatus(int nozzleId, String status) async {
    setState(() => _updating = true);
    try {
      await ApiService.patch('/nozzles/$nozzleId/status?status=$status');
      widget.onChanged();
      final nozzles = widget.dispenser['nozzles'] as List<dynamic>;
      for (var n in nozzles) {
        if (n['id'] == nozzleId) n['status'] = status;
      }
      setState(() {});
    } catch (e) {
      _toast('Failed to update nozzle status');
    } finally {
      setState(() => _updating = false);
    }
  }

  Future<void> _renameDispenser() async {
    final controller = TextEditingController(text: widget.dispenser['name']);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1b1e26),
        title: const Text('Rename Dispenser', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Dispenser Name',
            labelStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7c3aed)),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;
    setState(() => _updating = true);
    try {
      final encoded = Uri.encodeComponent(newName);
      await ApiService.put('/dispensers/${widget.dispenser['id']}?name=$encoded');
      widget.dispenser['name'] = newName;
      widget.onChanged();
      setState(() {});
    } catch (e) {
      _toast('Failed to rename dispenser');
    } finally {
      setState(() => _updating = false);
    }
  }

  Future<void> _deleteDispenser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1b1e26),
        title: const Text('Delete Dispenser', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete "${widget.dispenser['name']}"? This also removes its nozzles and their transactions. This cannot be undone.',
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
      await ApiService.delete('/dispensers/${widget.dispenser['id']}');
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _toast('Failed to delete dispenser');
    }
  }

  void _toast(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Widget _statusButtons(String current, void Function(String) onSelect) {
    return Row(
      children: ['active', 'offline', 'error'].map((s) {
        final selected = current == s;
        final color = statusColors[s]!;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: OutlinedButton(
              onPressed: _updating ? null : () => onSelect(s),
              style: OutlinedButton.styleFrom(
                backgroundColor: selected ? color : Colors.transparent,
                side: BorderSide(color: color),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Text(
                s,
                style: TextStyle(
                  color: selected ? Colors.white : color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nozzles = widget.dispenser['nozzles'] as List<dynamic>? ?? [];
    if (_selectedNozzleIndex >= nozzles.length && nozzles.isNotEmpty) {
      _selectedNozzleIndex = 0;
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.dispenser['name'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _updating ? null : _renameDispenser,
                  icon: const Icon(Icons.edit, color: Color(0xFFa855f7), size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Dispenser Status',
                style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _statusButtons(_dispStatus, _changeDispenserStatus),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _updating ? null : _deleteDispenser,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('Delete Dispenser', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (nozzles.isEmpty)
              Column(
                children: [
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No nozzles yet', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onAddNozzle();
                      },
                      icon: const Icon(Icons.add, color: Color(0xFFa855f7)),
                      label: const Text('Add Nozzle', style: TextStyle(color: Color(0xFFa855f7))),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFa855f7)),
                      ),
                    ),
                  ),
                ],
              )
            else ...[
              const Text('Nozzles',
                  style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(nozzles.length, (i) {
                  final selected = i == _selectedNozzleIndex;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedNozzleIndex = i);
                      _fetchHistory(nozzles[i]['id']);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFF7c3aed) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? const Color(0xFF7c3aed) : Colors.grey.shade700,
                        ),
                      ),
                      child: Text(
                        nozzles[i]['fuel_type'],
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              _nozzleDetail(nozzles[_selectedNozzleIndex]),
              const SizedBox(height: 20),
              _buildHistory(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Transaction History',
            style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (_loadingHistory)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: SizedBox(
              width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2),
            )),
          )
        else if (_history.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('No transactions yet',
                style: TextStyle(color: Colors.grey))),
          )
        else
          ..._history.map((txn) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${txn['volume_dispensed']} L',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(_formatTime(txn['timestamp'].toString()),
                          style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Rs ${txn['total_amount']}',
                          style: const TextStyle(
                              color: Color(0xFFa855f7), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('Rs ${txn['price_per_liter']}/L',
                          style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _nozzleDetail(Map<String, dynamic> nozzle) {
    final nozzleStatus = nozzle['status'] ?? 'active';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow('Nozzle Number', '${nozzle['nozzle_number']}'),
          _infoRow('Fuel Type', '${nozzle['fuel_type']}'),
          _infoRow('Total Meter', '${nozzle['total_meter']}'),
          const SizedBox(height: 12),
          const Text('Nozzle Status',
              style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _statusButtons(nozzleStatus, (s) => _changeNozzleStatus(nozzle['id'], s)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _DispenserCard extends StatefulWidget {
  final Map<String, dynamic> dispenser;
  final bool isPulsing;
  final VoidCallback onAddNozzle;
  final VoidCallback onTap;
  const _DispenserCard({
    required this.dispenser,
    required this.isPulsing,
    required this.onAddNozzle,
    required this.onTap,
  });

  @override
  State<_DispenserCard> createState() => _DispenserCardState();
}

class _DispenserCardState extends State<_DispenserCard> {
  int _selectedNozzleIndex = 0;

  @override
  Widget build(BuildContext context) {
    final nozzles = widget.dispenser['nozzles'] as List<dynamic>? ?? [];
    final status = widget.dispenser['status'] ?? 'active';

    if (_selectedNozzleIndex >= nozzles.length && nozzles.isNotEmpty) {
      _selectedNozzleIndex = 0;
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1b1e26),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isPulsing ? const Color(0xFFa855f7) : Colors.transparent,
            width: 2,
          ),
          boxShadow: widget.isPulsing
              ? [
                  BoxShadow(
                    color: const Color(0xFFa855f7).withOpacity(0.5),
                    blurRadius: 16,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      widget.dispenser['name'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: status == 'active'
                            ? Colors.green
                            : status == 'error'
                                ? Colors.red
                                : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(status, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (nozzles.isEmpty)
              Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text('No Nozzles Available', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onAddNozzle,
                    icon: const Icon(Icons.add, color: Color(0xFFa855f7)),
                    label: const Text('Add Nozzle', style: TextStyle(color: Color(0xFFa855f7))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFa855f7)),
                    ),
                  ),
                ],
              )
            else ...[
              Wrap(
                spacing: 8,
                children: [
                  ...List.generate(nozzles.length, (i) {
                    final selected = i == _selectedNozzleIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedNozzleIndex = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFF7c3aed) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? const Color(0xFF7c3aed) : Colors.grey.shade700,
                          ),
                        ),
                        child: Text(
                          nozzles[i]['fuel_type'],
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }),
                  GestureDetector(
                    onTap: widget.onAddNozzle,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFa855f7)),
                      ),
                      child: const Text('+', style: TextStyle(color: Color(0xFFa855f7))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTransaction(nozzles[_selectedNozzleIndex]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransaction(Map<String, dynamic> nozzle) {
    final txn = nozzle['latest_transaction'];
    if (txn == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text('No transactions yet', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${txn['volume_dispensed']} L',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Rs ${txn['total_amount']}',
              style: const TextStyle(
                color: Color(0xFFa855f7),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const Divider(color: Colors.white10, height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Meter: ${txn['meter_reading']}',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            Text('Rs ${txn['price_per_liter']}/L',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}