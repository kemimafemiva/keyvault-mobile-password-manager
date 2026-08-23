class Credential {
  final String id;
  final String serviceName;
  final String username;
  final String password;
  final String? website;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Credential({
    required this.id,
    required this.serviceName,
    required this.username,
    required this.password,
    this.website,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'serviceName': serviceName,
      'username': username,
      'password': password,
      'website': website,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Credential.fromJson(Map<String, dynamic> json) {
    return Credential(
      id: json['id'] as String,
      serviceName: json['serviceName'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      website: json['website'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Credential copyWith({
    String? serviceName,
    String? username,
    String? password,
    String? website,
    DateTime? updatedAt,
  }) {
    return Credential(
      id: id,
      serviceName: serviceName ?? this.serviceName,
      username: username ?? this.username,
      password: password ?? this.password,
      website: website ?? this.website,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
