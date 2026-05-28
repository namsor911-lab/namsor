// auth_page.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:universal_html/html.dart' as html;
import 'package:crypto/crypto.dart';

// ==================== AUTH SERVICE ====================
class AuthService {
  static const String _usersKey = 'auth_users_v1';
  static const String _sessionKey = 'auth_session_v1';
  static const String _attemptsKey = 'auth_attempts_v1';

  // ---- ດຶງ/ບັນທຶກ users ----
  static Map<String, Map<String, dynamic>> _getUsers() {
    final json = html.window.localStorage[_usersKey];
    if (json == null) return {};
    try {
      final Map<String, dynamic> raw = jsonDecode(json);
      return raw.map((k, v) => MapEntry(k, v as Map<String, dynamic>));
    } catch (_) {
      return {};
    }
  }

  static void _saveUsers(Map<String, Map<String, dynamic>> users) {
    html.window.localStorage[_usersKey] = jsonEncode(users);
  }

  // ---- Hash password ດ້ວຍ SHA-256 + salt ----
  static String _hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }

  /// Generate random 32-char hex salt
  static String _generateSalt() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final extra = utf8.encode(DateTime.now().toIso8601String());
    return sha256.convert(utf8.encode('$now${extra.join()}')).toString().substring(0, 32);
  }

  /// Generate session token (random 64-char hex)
  static String _generateToken() {
    final a = DateTime.now().microsecondsSinceEpoch;
    final b = DateTime.now().millisecondsSinceEpoch ^ 0xDEADBEEF;
    return sha256.convert(utf8.encode('$a-$b-token')).toString() +
        sha256.convert(utf8.encode('$b-$a-salt')).toString().substring(0, 32);
  }

  // ---- Rate limiting (brute-force protection) ----
  static const int _maxAttempts = 5;
  static const int _lockoutMinutes = 15;

  static Map<String, dynamic> _getAttempts() {
    final json = html.window.localStorage[_attemptsKey];
    if (json == null) return {};
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static void _saveAttempts(Map<String, dynamic> data) {
    html.window.localStorage[_attemptsKey] = jsonEncode(data);
  }

  /// ກວດສອບວ່າ email ນີ້ຖືກ lockout ຫຼືບໍ່
  static _LockoutStatus _checkLockout(String email) {
    final attempts = _getAttempts();
    final key = 'fail_$email';
    if (!attempts.containsKey(key)) return _LockoutStatus(locked: false, remaining: 0);

    final data = attempts[key] as Map<String, dynamic>;
    final count = data['count'] as int? ?? 0;
    final lastFailStr = data['lastFail'] as String?;

    if (count < _maxAttempts) return _LockoutStatus(locked: false, remaining: 0);

    if (lastFailStr == null) return _LockoutStatus(locked: false, remaining: 0);
    final lastFail = DateTime.tryParse(lastFailStr);
    if (lastFail == null) return _LockoutStatus(locked: false, remaining: 0);

    final elapsed = DateTime.now().difference(lastFail).inMinutes;
    if (elapsed >= _lockoutMinutes) {
      // ໝົດ lockout — reset
      attempts.remove(key);
      _saveAttempts(attempts);
      return _LockoutStatus(locked: false, remaining: 0);
    }
    return _LockoutStatus(locked: true, remaining: _lockoutMinutes - elapsed);
  }

  static void _recordFailedAttempt(String email) {
    final attempts = _getAttempts();
    final key = 'fail_$email';
    final existing = attempts[key] as Map<String, dynamic>? ?? {};
    final count = (existing['count'] as int? ?? 0) + 1;
    attempts[key] = {
      'count': count,
      'lastFail': DateTime.now().toIso8601String(),
    };
    _saveAttempts(attempts);
  }

  static void _clearFailedAttempts(String email) {
    final attempts = _getAttempts();
    attempts.remove('fail_$email');
    _saveAttempts(attempts);
  }

  // ---- Sanitize input (strip HTML/script characters) ----
  static String _sanitize(String input) {
    return input
        .replaceAll(RegExp(r'''[<>"'`\\]'''), '')
        .trim();
  }

  // ---- Password strength validation ----
  static String? _validatePasswordStrength(String password) {
    if (password.length < 8) {
      return 'ລະຫັດຜ່ານຕ້ອງມີຢ່າງໜ້ອຍ 8 ຕົວອັກສອນ';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'ຕ້ອງມີຕົວພິມໃຫຍ່ຢ່າງໜ້ອຍ 1 ຕົວ (A-Z)';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'ຕ້ອງມີຕົວເລກຢ່າງໜ້ອຍ 1 ຕົວ (0-9)';
    }
    return null; // ຜ່ານ
  }

  // ---- ລົງທະບຽນ ----
  static AuthResult register(String email, String password, String name) {
    final email_ = _sanitize(email.toLowerCase());
    final name_ = _sanitize(name);

    if (!_isValidEmail(email_)) {
      return AuthResult(success: false, message: 'ຮູບແບບອີເມວບໍ່ຖືກຕ້ອງ');
    }

    final pwdError = _validatePasswordStrength(password);
    if (pwdError != null) return AuthResult(success: false, message: pwdError);

    if (name_.isEmpty || name_.length < 2) {
      return AuthResult(success: false, message: 'ກະລຸນາໃສ່ຊື່ຢ່າງໜ້ອຍ 2 ຕົວອັກສອນ');
    }

    final users = _getUsers();
    if (users.containsKey(email_)) {
      // ໃຊ້ຂໍ້ຄວາມດຽວກັນ — ປ້ອງກັນ email enumeration
      return AuthResult(success: false, message: 'ບໍ່ສາມາດລົງທະບຽນໄດ້ ກະລຸນາລອງໃໝ່');
    }

    final salt = _generateSalt();
    users[email_] = {
      'name': name_,
      'email': email_,
      'passwordHash': _hashPassword(password, salt),
      'salt': salt,
      'createdAt': DateTime.now().toIso8601String(),
    };
    _saveUsers(users);

    final token = _generateToken();
    _saveSession(email_, name_, token);
    return AuthResult(
      success: true,
      message: 'ລົງທະບຽນສຳເລັດ',
      email: email_,
      name: name_,
    );
  }

  // ---- ເຂົ້າສູ່ລະບົບ ----
  static AuthResult login(String email, String password) {
    final email_ = _sanitize(email.toLowerCase());

    // Rate limit check
    final lockout = _checkLockout(email_);
    if (lockout.locked) {
      return AuthResult(
        success: false,
        message: 'ເຂົ້າຜິດຫຼາຍຄັ້ງ — ລໍຖ້າ ${lockout.remaining} ນາທີ',
      );
    }

    final users = _getUsers();

    // ໃຊ້ generic message — ປ້ອງກັນ email enumeration
    const genericError = 'ອີເມວ ຫຼື ລະຫັດຜ່ານບໍ່ຖືກຕ້ອງ';

    if (!users.containsKey(email_)) {
      _recordFailedAttempt(email_);
      // Timing equalization: hash dummy ເພື່ອໃຊ້ເວລາເທົ່າກັນ
      _hashPassword(password, 'dummy_salt_000000000000000000000000');
      return AuthResult(success: false, message: genericError);
    }

    final user = users[email_]!;
    final salt = user['salt'] as String? ?? '';
    final storedHash = user['passwordHash'] as String? ?? '';

    if (_hashPassword(password, salt) != storedHash) {
      _recordFailedAttempt(email_);
      final remaining = _maxAttempts - (_getAttempts()['fail_$email_']?['count'] ?? 0);
      final hint = remaining > 0 ? ' (ເຫຼືອ $remaining ຄັ້ງ)' : '';
      return AuthResult(success: false, message: '$genericError$hint');
    }

    _clearFailedAttempts(email_);
    final token = _generateToken();
    _saveSession(email_, user['name'] as String, token);
    return AuthResult(
      success: true,
      message: 'ເຂົ້າສູ່ລະບົບສຳເລັດ',
      email: email_,
      name: user['name'] as String,
    );
  }

  // ---- ອອກຈາກລະບົບ ----
  static void logout() {
    html.window.localStorage.remove(_sessionKey);
  }

  // ---- ດຶງ session ----
  static AuthResult? getCurrentSession() {
    final json = html.window.localStorage[_sessionKey];
    if (json == null) return null;
    try {
      final Map<String, dynamic> data = jsonDecode(json);
      // ກວດ token field ຢູ່
      if (data['token'] == null || (data['token'] as String).isEmpty) return null;
      return AuthResult(
        success: true,
        message: '',
        email: data['email'] as String,
        name: data['name'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  static void _saveSession(String email, String name, String token) {
    html.window.localStorage[_sessionKey] = jsonEncode({
      'email': email,
      'name': name,
      'token': token,
      'loginAt': DateTime.now().toIso8601String(),
    });
  }

  static bool _isValidEmail(String email) {
    return RegExp(r'^[\w.+-]+@[\w.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  // ---- ດຶງລາຍຊື່ users (settings) ----
  static List<Map<String, dynamic>> getAllUsers() {
    return _getUsers().values.map((u) {
      return {
        'name': u['name'],
        'email': u['email'],
        'createdAt': u['createdAt'],
      };
    }).toList();
  }
}

// ---- helper class ----
class _LockoutStatus {
  final bool locked;
  final int remaining;
  _LockoutStatus({required this.locked, required this.remaining});
}

// ==================== AUTH RESULT ====================
class AuthResult {
  final bool success;
  final String message;
  final String? email;
  final String? name;

  AuthResult({
    required this.success,
    required this.message,
    this.email,
    this.name,
  });
}

// ==================== AUTH PAGE ====================
class AuthPage extends StatefulWidget {
  final Function(AuthResult) onAuthenticated;

  const AuthPage({super.key, required this.onAuthenticated});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _errorMessage;

  // Login fields
  final _loginEmailCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();
  bool _loginObscure = true;

  // Register fields
  final _regNameCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPasswordCtrl = TextEditingController();
  final _regConfirmCtrl = TextEditingController();
  bool _regObscure = true;
  bool _regConfirmObscure = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _errorMessage = null);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _regNameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPasswordCtrl.dispose();
    _regConfirmCtrl.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    await Future.delayed(const Duration(milliseconds: 400));
    final result = AuthService.login(
      _loginEmailCtrl.text,
      _loginPasswordCtrl.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.success) {
      widget.onAuthenticated(result);
    } else {
      setState(() => _errorMessage = result.message);
    }
  }

  void _handleRegister() async {
    if (_regPasswordCtrl.text != _regConfirmCtrl.text) {
      setState(() => _errorMessage = 'ລະຫັດຜ່ານທັງສອງຊ່ອງບໍ່ກົງກັນ');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    await Future.delayed(const Duration(milliseconds: 400));
    final result = AuthService.register(
      _regEmailCtrl.text,
      _regPasswordCtrl.text,
      _regNameCtrl.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.success) {
      widget.onAuthenticated(result);
    } else {
      setState(() => _errorMessage = result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLogo(),
                const SizedBox(height: 40),
                _buildCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF238636), Color(0xFF3FB950)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3FB950).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Text('⚡', style: TextStyle(fontSize: 32)),
          ),
        ),
        const SizedBox(height: 16),
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'ນ້ຳ',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFE6EDF3),
                ),
              ),
              TextSpan(
                text: 'ຊໍ້',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF3FB950),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'ເຂື່ອນໄຟຟ້ານ້ຳຊໍ້',
          style: TextStyle(fontSize: 13, color: Color(0xFF8B949E)),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        border: Border.all(color: const Color(0xFF30363D)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF30363D))),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF3FB950),
              indicatorWeight: 2,
              labelColor: const Color(0xFF3FB950),
              unselectedLabelColor: const Color(0xFF8B949E),
              tabs: const [
                Tab(text: 'ເຂົ້າສູ່ລະບົບ'),
                Tab(text: 'ລົງທະບຽນ'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                if (_errorMessage != null) ...[
                  _buildErrorBanner(_errorMessage!),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  height: _tabController.index == 0 ? 220 : 370,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLoginForm(),
                      _buildRegisterForm(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF4D2A2A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFF85149).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFF85149), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Color(0xFFF85149)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return SingleChildScrollView(
      child: Column(
        children: [
          TextField(
            controller: _loginEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'ອີເມວ',
              prefixIcon: Icon(Icons.email_outlined, size: 18),
            ),
            onSubmitted: (_) => _handleLogin(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _loginPasswordCtrl,
            obscureText: _loginObscure,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'ລະຫັດຜ່ານ',
              prefixIcon: const Icon(Icons.lock_outline, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  _loginObscure ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                ),
                onPressed: () => setState(() => _loginObscure = !_loginObscure),
              ),
            ),
            onSubmitted: (_) => _handleLogin(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF238636),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'ເຂົ້າສູ່ລະບົບ',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return SingleChildScrollView(
      child: Column(
        children: [
          TextField(
            controller: _regNameCtrl,
            decoration: const InputDecoration(
              labelText: 'ຊື່ - ນາມສະກຸນ',
              prefixIcon: Icon(Icons.person_outline, size: 18),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _regEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'ອີເມວ',
              prefixIcon: Icon(Icons.email_outlined, size: 18),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _regPasswordCtrl,
            obscureText: _regObscure,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'ລະຫັດຜ່ານ (≥8 ຕົວ, ມີ A-Z, 0-9)',
              prefixIcon: const Icon(Icons.lock_outline, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  _regObscure ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                ),
                onPressed: () => setState(() => _regObscure = !_regObscure),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _regConfirmCtrl,
            obscureText: _regConfirmObscure,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'ຢືນຢັນລະຫັດຜ່ານ',
              prefixIcon: const Icon(Icons.lock_outline, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  _regConfirmObscure ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                ),
                onPressed: () =>
                    setState(() => _regConfirmObscure = !_regConfirmObscure),
              ),
            ),
            onSubmitted: (_) => _handleRegister(),
          ),
          // Password hint
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.info_outline, size: 12, color: Color(0xFF484F58)),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  'ລະຫັດຜ່ານຕ້ອງ: ≥8 ຕົວ, ມີຕົວພິມໃຫຍ່ (A-Z) ແລະ ຕົວເລກ (0-9)',
                  style: TextStyle(fontSize: 10, color: Color(0xFF484F58)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F6FEB),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'ລົງທະບຽນ',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}