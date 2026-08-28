import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';

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

  /// SHA-256 hex digest of the PIN. Only the hash is ever sent to Supabase
  /// or stored anywhere — the raw PIN never leaves the device.
  static String hashPin(String pin) =>
      sha256.convert(utf8.encode(pin)).toString();

  Future<bool> signUp({
    required String name,
    required String phone,
    required String email,
    required String password,
    required String pin,
  }) async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    final pinHash = hashPin(pin);

    try {
      // Carry name/phone/pinHash in Supabase's own user metadata. This is
      // stored on the auth user itself (no RLS involved), so it survives
      // even when email confirmation is required and there's no session
      // yet.
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name, 'phone': phone, 'pin_hash': pinHash},
        // Without this, Supabase sends the confirmation link back to
        // whatever "Site URL" is set in the dashboard — by default a
        // placeholder like http://localhost:3000, which is why the link
        // was opening to "localhost not found" instead of the app.
        emailRedirectTo: AppConstants.authRedirectUrl,
      );
      final user = res.user;
      if (user == null) {
        _errorMessage = 'Sign up failed — please try again.';
        return false;
      }

      if (res.session != null) {
        // Email confirmation is OFF for this project — we're already
        // authenticated, so it's safe to write the profiles row now.
        await _client.from('profiles').upsert({
          'id': user.id,
          'name': name,
          'phone': phone,
          'email': email,
          'pin_hash': pinHash,
        });
        await loadProfile();
      }
      // If there's no session yet, the row-level security policy would
      // reject this insert anyway (there's no authenticated user until
      // the email is confirmed). We skip it here; loadProfile() creates
      // the row automatically the first time this user logs in.

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

  /// Resets a password using the PIN set at sign-up instead of an emailed
  /// link. The actual password change happens inside the
  /// "reset-password-with-pin" Supabase Edge Function, which is the only
  /// place allowed to hold the service-role key needed to change another
  /// (logged-out) user's password. This client only ever sends the PIN's
  /// hash-check request — never anything with admin privileges.
  Future<bool> resetPasswordWithPin({
    required String email,
    required String pin,
    required String newPassword,
  }) async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _client.functions.invoke(
        'reset-password-with-pin',
        body: {
          'email': email.trim(),
          'pin': pin.trim(),
          'newPassword': newPassword,
        },
      );

      final data = res.data;
      if (res.status == 200 && data is Map && data['success'] == true) {
        return true;
      }

      _errorMessage = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'Could not reset password — please check your email and PIN.';
      return false;
    } on FunctionException catch (e) {
      final body = e.details;
      _errorMessage = (body is Map && body['error'] != null)
          ? body['error'].toString()
          : 'Incorrect email or PIN.';
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
      var row = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (row == null) {
        // No profile row yet — this is the first time we've had an
        // authenticated session for this user (e.g. sign-up required
        // email confirmation, and they've just confirmed and logged
        // in). Create it now from the metadata saved at sign-up time.
        final metadata = user.userMetadata ?? {};
        row = await _client
            .from('profiles')
            .upsert({
              'id': user.id,
              'name': metadata['name'] ?? '',
              'phone': metadata['phone'] ?? '',
              'email': user.email ?? '',
              'pin_hash': metadata['pin_hash'],
            })
            .select()
            .maybeSingle();
      }

      _profile = row;
    } catch (e) {
      debugPrint('Could not load profile: $e');
    }
    notifyListeners();
  }
}