import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class AdminScreen extends StatefulWidget {
  final String name;
  const AdminScreen({super.key, this.name = 'Admin'});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<dynamic> _users = [];
  bool _loading = true;

  static const Map<String, Color> roleColors = {
    'admin': Color(0xFFef4444),
    'owner': Color(0xFF7c3aed),
    'manager': Color(0xFF3b82f6),
  };

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final data = await ApiService.get('/auth/admin/users');
      setState(() {
        _users = data;
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

  void _showCreateUserDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String role = 'owner';
    bool submitting = false;
    String error = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1b1e26),
              title: const Text('Create User', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Full Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Password'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: role,
                    dropdownColor: const Color(0xFF1b1e26),
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Role'),
                    items: const [
                      DropdownMenuItem(value: 'owner', child: Text('Owner')),
                      DropdownMenuItem(value: 'manager', child: Text('Manager')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                    onChanged: (v) => setDialogState(() => role = v!),
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
                                '/auth/admin/create-user?full_name=$name&email=$email&password=$password&role=$role');
                            if (context.mounted) Navigator.pop(context);
                            _loadUsers();
                          } catch (e) {
                            setDialogState(() {
                              submitting = false;
                              error = 'Failed to create user';
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

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1b1e26),
        title: const Text('Delete User', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete "${user['full_name']}" (${user['email']})? This cannot be undone.',
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
      await ApiService.delete('/auth/admin/users/${user['id']}');
      _loadUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete user')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFef4444).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('admin', style: TextStyle(fontSize: 12)),
              ),
            ),
          ),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF7c3aed),
        onPressed: _showCreateUserDialog,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Create User'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('No users found'))
              : RefreshIndicator(
                  onRefresh: _loadUsers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final role = (user['role'] ?? 'owner').toString();
                      final color = roleColors[role] ?? Colors.grey;
                      final name = (user['full_name'] ?? '?').toString();
                      final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                      return Card(
                        color: const Color(0xFF1b1e26),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: color,
                            child: Text(initial,
                                style: const TextStyle(color: Colors.white)),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              user['email'] ?? '',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  role,
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _deleteUser(user),
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red, size: 20),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}