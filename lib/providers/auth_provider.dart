import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';






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


    _client.auth.onAuthStateChange.listen((_) => notifyListeners());
  }



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




      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name, 'phone': phone, 'pin_hash': pinHash},




        emailRedirectTo: AppConstants.authRedirectUrl,
      );
      final user = res.user;
      if (user == null) {
        _errorMessage = 'Sign up failed — please try again.';
        return false;
      }

      if (res.session != null) {


        await _client.from('profiles').upsert({
          'id': user.id,
          'name': name,
          'phone': phone,
          'email': email,
          'pin_hash': pinHash,
        });
        await loadProfile();
      }





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
