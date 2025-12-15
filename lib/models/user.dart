/// User roles in the system
enum UserRole {
  manager,
  user,
}

/// User model representing a user account
class AppUser {
  final String id;
  final String name;
  final String password;
  final UserRole role;
  final String? tajUser;      // TAJ username
  final String? tajPass;      // TAJ password
  final String? accNumber;    // Account number
  final DateTime createdAt;
  final DateTime updatedAt;

  AppUser({
    required this.id,
    required this.name,
    required this.password,
    this.role = UserRole.user,
    this.tajUser,
    this.tajPass,
    this.accNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Check if user is manager
  bool get isManager => role == UserRole.manager;

  /// Create a copy with updated fields
  AppUser copyWith({
    String? id,
    String? name,
    String? password,
    UserRole? role,
    String? tajUser,
    String? tajPass,
    String? accNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      password: password ?? this.password,
      role: role ?? this.role,
      tajUser: tajUser ?? this.tajUser,
      tajPass: tajPass ?? this.tajPass,
      accNumber: accNumber ?? this.accNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Convert to JSON for storage/sync
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'password': password,
    'role': role.name,
    'tajUser': tajUser,
    'tajPass': tajPass,
    'accNumber': accNumber,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// Create from JSON
  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'],
    name: json['name'],
    password: json['password'],
    role: UserRole.values.firstWhere(
      (r) => r.name == json['role'],
      orElse: () => UserRole.user,
    ),
    tajUser: json['tajUser'],
    tajPass: json['tajPass'],
    accNumber: json['accNumber'],
    createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt']) 
        : null,
    updatedAt: json['updatedAt'] != null 
        ? DateTime.parse(json['updatedAt']) 
        : null,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Current session data
class UserSession {
  final AppUser user;
  final bool hasBranchToday;
  final DateTime loginTime;

  UserSession({
    required this.user,
    required this.hasBranchToday,
    DateTime? loginTime,
  }) : loginTime = loginTime ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'user': user.toJson(),
    'hasBranchToday': hasBranchToday,
    'loginTime': loginTime.toIso8601String(),
  };

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
    user: AppUser.fromJson(json['user']),
    hasBranchToday: json['hasBranchToday'] ?? false,
    loginTime: json['loginTime'] != null 
        ? DateTime.parse(json['loginTime']) 
        : null,
  );
}
