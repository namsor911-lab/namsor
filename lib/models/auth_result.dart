class AuthResult {
  final bool success;
  final String message;
  final String? uid;
  final String? email;
  final String? name;

  AuthResult({
    required this.success,
    required this.message,
    this.uid,
    this.email,
    this.name,
  });
}
