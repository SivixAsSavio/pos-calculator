import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user.dart';
import '../services/user_service.dart';

class UserManagementScreen extends StatefulWidget {
  final UserService userService;

  const UserManagementScreen({
    super.key,
    required this.userService,
  });

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final users = widget.userService.users;
    final currentUser = widget.userService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: const Color(0xFF16213e),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add User',
            onPressed: () => _showUserDialog(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade900.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.people, color: Colors.blue.shade300, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Team Members',
                          style: TextStyle(
                            color: Colors.blue.shade100,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${users.length} user${users.length != 1 ? 's' : ''} registered',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add User'),
                    onPressed: () => _showUserDialog(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Users list
            Expanded(
              child: users.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline, 
                              size: 64, color: Colors.grey.shade600),
                          const SizedBox(height: 16),
                          Text(
                            'No users yet',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final isCurrentUser = user.id == currentUser?.id;
                        
                        return Card(
                          color: const Color(0xFF16213e),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: user.isManager 
                                  ? Colors.amber.shade700 
                                  : Colors.blue.shade700,
                              child: Text(
                                user.name.isNotEmpty 
                                    ? user.name[0].toUpperCase() 
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  user.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (isCurrentUser) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade700,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'You',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: user.isManager 
                                            ? Colors.amber.shade900 
                                            : Colors.blue.shade900,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        user.isManager ? 'Manager' : 'User',
                                        style: TextStyle(
                                          color: user.isManager 
                                              ? Colors.amber.shade100 
                                              : Colors.blue.shade100,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    if (user.accNumber != null && 
                                        user.accNumber!.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        'Acc: ${user.accNumber}',
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (user.tajUser != null && 
                                    user.tajUser!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'TAJ: ${user.tajUser}',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  tooltip: 'Edit User',
                                  onPressed: () => _showUserDialog(user: user),
                                ),
                                if (!isCurrentUser)
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    tooltip: 'Delete User',
                                    onPressed: () => _confirmDelete(user),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showUserDialog({AppUser? user}) async {
    final isEdit = user != null;
    final nameController = TextEditingController(text: user?.name ?? '');
    final passwordController = TextEditingController(text: user?.password ?? '');
    final tajUserController = TextEditingController(text: user?.tajUser ?? '');
    final tajPassController = TextEditingController(text: user?.tajPass ?? '');
    final accNumberController = TextEditingController(text: user?.accNumber ?? '');
    var role = user?.role ?? UserRole.user;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF16213e),
          title: Text(
            isEdit ? 'Edit User' : 'Add New User',
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Name *',
                      labelStyle: TextStyle(color: Colors.grey.shade400),
                      prefixIcon: const Icon(Icons.person, color: Colors.blue),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade700),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.blue),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextField(
                    controller: passwordController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Password *',
                      labelStyle: TextStyle(color: Colors.grey.shade400),
                      prefixIcon: const Icon(Icons.lock, color: Colors.blue),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade700),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.blue),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Role dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade700),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<UserRole>(
                        value: role,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF16213e),
                        style: const TextStyle(color: Colors.white),
                        items: UserRole.values.map((r) => DropdownMenuItem(
                          value: r,
                          child: Row(
                            children: [
                              Icon(
                                r == UserRole.manager 
                                    ? Icons.admin_panel_settings 
                                    : Icons.person,
                                color: r == UserRole.manager 
                                    ? Colors.amber 
                                    : Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              Text(r == UserRole.manager ? 'Manager' : 'User'),
                            ],
                          ),
                        )).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => role = value);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // TAJ Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade700),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TAJ Information (Optional)',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: tajUserController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'TAJ Username',
                            labelStyle: TextStyle(color: Colors.grey.shade500),
                            isDense: true,
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey.shade700),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.blue),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: tajPassController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'TAJ Password',
                            labelStyle: TextStyle(color: Colors.grey.shade500),
                            isDense: true,
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey.shade700),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.blue),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Account Number
                  TextField(
                    controller: accNumberController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Account Number (Optional)',
                      labelStyle: TextStyle(color: Colors.grey.shade400),
                      prefixIcon: const Icon(Icons.numbers, color: Colors.blue),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade700),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.blue),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade400)),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name is required')),
                  );
                  return;
                }
                if (passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password is required')),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text(isEdit ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final newUser = AppUser(
        id: user?.id ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
        name: nameController.text.trim(),
        password: passwordController.text,
        role: role,
        tajUser: tajUserController.text.trim().isEmpty 
            ? null : tajUserController.text.trim(),
        tajPass: tajPassController.text.isEmpty 
            ? null : tajPassController.text,
        accNumber: accNumberController.text.trim().isEmpty 
            ? null : accNumberController.text.trim(),
        createdAt: user?.createdAt,
      );

      UserOperationResult opResult;
      if (isEdit) {
        opResult = await widget.userService.updateUser(newUser);
      } else {
        opResult = await widget.userService.addUser(newUser);
      }

      if (mounted) {
        switch (opResult) {
          case UserOperationResult.success:
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isEdit ? 'User updated' : 'User added'),
                backgroundColor: Colors.green,
              ),
            );
            break;
          case UserOperationResult.nameExists:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('A user with this name already exists'),
                backgroundColor: Colors.red,
              ),
            );
            break;
          case UserOperationResult.unauthorized:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You don\'t have permission to do this'),
                backgroundColor: Colors.red,
              ),
            );
            break;
          default:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Operation failed'),
                backgroundColor: Colors.red,
              ),
            );
        }
      }
    }

    nameController.dispose();
    passwordController.dispose();
    tajUserController.dispose();
    tajPassController.dispose();
    accNumberController.dispose();
  }

  Future<void> _confirmDelete(AppUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213e),
        title: const Text('Delete User', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${user.name}"?\n\nThis action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade400)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await widget.userService.deleteUser(user.id);
      
      if (mounted) {
        switch (result) {
          case UserOperationResult.success:
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User deleted'),
                backgroundColor: Colors.green,
              ),
            );
            break;
          case UserOperationResult.lastManager:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cannot delete the last manager'),
                backgroundColor: Colors.red,
              ),
            );
            break;
          case UserOperationResult.cannotDeleteSelf:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cannot delete yourself'),
                backgroundColor: Colors.red,
              ),
            );
            break;
          default:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to delete user'),
                backgroundColor: Colors.red,
              ),
            );
        }
      }
    }
  }
}
