class UserModel {
  final String id;       // Unique ID (same as Firebase Auth UID)
  final String name;     // Full name e.g. "Yassin"
  final String email;    // Email e.g. "yassin@gmail.com"
  final String password; // Password (only stored locally for offline login)

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
  });

  // Convert UserModel → Map (to save in database)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
    };
  }

  // Convert Map → UserModel (to read from database)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      password: map['password'],
    );
  }

  // Convert UserModel → Map for Firestore (no password stored online!)
  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      // ⚠️ We never save the password to Firestore for security
    };
  }
}