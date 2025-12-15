import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

/// Service for managing user accounts and authentication
class UserService extends ChangeNotifier {
  static const String _usersKey = 'app_users';
  static const String _sessionKey = 'current_session';
  static const String _defaultManagerPin = '1234';
  
  List<AppUser> _users = [];
  UserSession? _currentSession;
  SharedPreferences? _prefs;

  List<AppUser> get users => List.unmodifiable(_users);
  UserSession? get currentSession => _currentSession;
  AppUser? get currentUser => _currentSession?.user;
  bool get isLoggedIn => _currentSession != null;
  bool get isManager => _currentSession?.user.isManager ?? false;
  bool get hasBranchToday => _currentSession?.hasBranchToday ?? false;

  /// Initialize the service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadUsers();
    await _loadSession();
    
    // Create default manager if no users exist
    if (_users.isEmpty) {
      await _createDefaultManager();
    }
  }

  /// Load users from storage
  Future<void> _loadUsers() async {
    final data = _prefs?.getString(_usersKey);
    if (data != null) {
      final List<dynamic> jsonList = jsonDecode(data);
      _users = jsonList.map((j) => AppUser.fromJson(j)).toList();
    }
  }

  /// Save users to storage
  Future<void> _saveUsers() async {
    final data = jsonEncode(_users.map((u) => u.toJson()).toList());
    await _prefs?.setString(_usersKey, data);
    notifyListeners();
  }

  /// Load current session
  Future<void> _loadSession() async {
    final data = _prefs?.getString(_sessionKey);
    if (data != null) {
      try {
        _currentSession = UserSession.fromJson(jsonDecode(data));
        // Verify user still exists
        if (!_users.any((u) => u.id == _currentSession?.user.id)) {
          _currentSession = null;
          await _prefs?.remove(_sessionKey);
        }
      } catch (e) {
        _currentSession = null;
      }
    }
  }

  /// Create default manager account
  Future<void> _createDefaultManager() async {
    final manager = AppUser(
      id: 'manager_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Manager',
      password: _defaultManagerPin,
      role: UserRole.manager,
    );
    _users.add(manager);
    await _saveUsers();
  }

  /// Login with username and password
  Future<LoginResult> login(String name, String password, bool hasBranchToday) async {
    final user = _users.firstWhere(
      (u) => u.name.toLowerCase() == name.toLowerCase(),
      orElse: () => AppUser(id: '', name: '', password: ''),
    );

    if (user.id.isEmpty) {
      return LoginResult.userNotFound;
    }

    if (user.password != password) {
      return LoginResult.wrongPassword;
    }

    _currentSession = UserSession(
      user: user,
      hasBranchToday: hasBranchToday,
    );

    await _prefs?.setString(_sessionKey, jsonEncode(_currentSession!.toJson()));
    notifyListeners();
    return LoginResult.success;
  }

  /// Logout current user
  Future<void> logout() async {
    _currentSession = null;
    await _prefs?.remove(_sessionKey);
    notifyListeners();
  }

  /// Add a new user (manager only)
  Future<UserOperationResult> addUser(AppUser user) async {
    if (!isManager) {
      return UserOperationResult.unauthorized;
    }

    // Check if name already exists
    if (_users.any((u) => u.name.toLowerCase() == user.name.toLowerCase())) {
      return UserOperationResult.nameExists;
    }

    _users.add(user);
    await _saveUsers();
    return UserOperationResult.success;
  }

  /// Update an existing user
  Future<UserOperationResult> updateUser(AppUser updatedUser) async {
    // Users can update their own profile, managers can update anyone
    if (!isManager && currentUser?.id != updatedUser.id) {
      return UserOperationResult.unauthorized;
    }

    // Check if name already exists (exclude current user)
    if (_users.any((u) => 
        u.name.toLowerCase() == updatedUser.name.toLowerCase() && 
        u.id != updatedUser.id)) {
      return UserOperationResult.nameExists;
    }

    final index = _users.indexWhere((u) => u.id == updatedUser.id);
    if (index == -1) {
      return UserOperationResult.userNotFound;
    }

    // Non-managers cannot change their role
    if (!isManager && updatedUser.role != _users[index].role) {
      return UserOperationResult.unauthorized;
    }

    _users[index] = updatedUser;
    await _saveUsers();

    // Update session if current user was updated
    if (_currentSession?.user.id == updatedUser.id) {
      _currentSession = UserSession(
        user: updatedUser,
        hasBranchToday: _currentSession!.hasBranchToday,
        loginTime: _currentSession!.loginTime,
      );
      await _prefs?.setString(_sessionKey, jsonEncode(_currentSession!.toJson()));
    }

    return UserOperationResult.success;
  }

  /// Delete a user (manager only)
  Future<UserOperationResult> deleteUser(String userId) async {
    if (!isManager) {
      return UserOperationResult.unauthorized;
    }

    // Cannot delete yourself
    if (currentUser?.id == userId) {
      return UserOperationResult.cannotDeleteSelf;
    }

    // Must have at least one manager
    final userToDelete = _users.firstWhere(
      (u) => u.id == userId,
      orElse: () => AppUser(id: '', name: '', password: ''),
    );

    if (userToDelete.id.isEmpty) {
      return UserOperationResult.userNotFound;
    }

    if (userToDelete.isManager) {
      final managerCount = _users.where((u) => u.isManager).length;
      if (managerCount <= 1) {
        return UserOperationResult.lastManager;
      }
    }

    _users.removeWhere((u) => u.id == userId);
    await _saveUsers();
    return UserOperationResult.success;
  }

  /// Get user by ID
  AppUser? getUserById(String id) {
    try {
      return _users.firstWhere((u) => u.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get all users (for sync)
  List<Map<String, dynamic>> exportUsers() {
    return _users.map((u) => u.toJson()).toList();
  }

  /// Import users from sync
  Future<void> importUsers(List<Map<String, dynamic>> usersData) async {
    final importedUsers = usersData.map((j) => AppUser.fromJson(j)).toList();
    
    // Merge users - newer updatedAt wins
    for (final imported in importedUsers) {
      final existingIndex = _users.indexWhere((u) => u.id == imported.id);
      if (existingIndex == -1) {
        _users.add(imported);
      } else if (imported.updatedAt.isAfter(_users[existingIndex].updatedAt)) {
        _users[existingIndex] = imported;
      }
    }
    
    await _saveUsers();
  }

  /// Change password
  Future<UserOperationResult> changePassword(
    String userId, 
    String oldPassword, 
    String newPassword,
  ) async {
    final user = getUserById(userId);
    if (user == null) {
      return UserOperationResult.userNotFound;
    }

    // Verify old password (managers can skip this for other users)
    if (!isManager || currentUser?.id == userId) {
      if (user.password != oldPassword) {
        return UserOperationResult.wrongPassword;
      }
    }

    final updated = user.copyWith(password: newPassword);
    return updateUser(updated);
  }

  /// Update "has branch today" status
  Future<void> setHasBranchToday(bool value) async {
    if (_currentSession != null) {
      _currentSession = UserSession(
        user: _currentSession!.user,
        hasBranchToday: value,
        loginTime: _currentSession!.loginTime,
      );
      await _prefs?.setString(_sessionKey, jsonEncode(_currentSession!.toJson()));
      notifyListeners();
    }
  }
}

/// Login result enum
enum LoginResult {
  success,
  userNotFound,
  wrongPassword,
}

/// User operation result enum
enum UserOperationResult {
  success,
  unauthorized,
  userNotFound,
  nameExists,
  wrongPassword,
  cannotDeleteSelf,
  lastManager,
}
