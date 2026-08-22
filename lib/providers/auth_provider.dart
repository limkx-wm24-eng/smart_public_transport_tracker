import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Wraps Supabase Auth (email/password) and the user's profile row.
///
/// Supabase Auth handles the account itself (email, password, session).
/// Extra fields like name/phone live in a separate `profiles` table,
/// linked by the same user id — see README for the SQL to create it.
class AuthProvider extends ChangeNotifier {
  SupabaseClient get _client => Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? get profile => _profile;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _loading = false;
  bool get loading => _loading;

  AuthProvider() {
    // Keep this provider in sync if Supabase's own auth state changes
    // (e.g. the session expires while the app is open).
    _client.auth.onAuthStateChange.listen((_) => notifyListeners());
  }

  Future<bool> signUp({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _client.auth.signUp(email: email, password: password);
      final user = res.user;
      if (user == null) {
        _errorMessage = 'Sign up failed — please try again.';
        return false;
      }

      // Store the extra profile fields Supabase Auth doesn't hold itself.
      await _client.from('profiles').upsert({
        'id': user.id,
        'name': name,
        'phone': phone,
        'email': email,
      });

      await loadProfile();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Something went wrong: $e';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      await loadProfile();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Something went wrong: $e';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _client.auth.resetPasswordForEmail(email);
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Something went wrong: $e';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    _profile = null;
    notifyListeners();
  }

  Future<void> loadProfile() async {
    final user = currentUser;
    if (user == null) return;
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      _profile = row;
    } catch (e) {
      debugPrint('Could not load profile: $e');
    }
    notifyListeners();
  }
}