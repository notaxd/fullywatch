import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'station_list_screen.dart';
import 'admin_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  String _role = '';
  String _name = '';
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await ApiService.getMe();
      setState(() {
        _name = user['full_name'] ?? '';
        _role = user['role'] ?? '';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error.isNotEmpty) {
      return Scaffold(
        body: Center(child: Text(_error)),
      );
    }

    // Route based on role
    if (_role == 'admin') {
      return const AdminScreen();
    } else {
      // owner and manager both see stations
      return StationListScreen(role: _role, name: _name);
    }
  }
}