import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const _apiUrl = 'http://localhost:8080/api/auth';

class AuthService with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  String? _jwt;
  String? _role;
  String? _email;
  String? _fullName;

  String? get jwt => _jwt;
  String? get userRole => _role;
  String? get email => _email;
  String? get fullName => _fullName;
  bool get isAuthenticated => _jwt != null;

  Future<String?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 10));
      
      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _jwt = data['jwtToken'];
        _role = data['userRole'];
        _email = data['email'];
        _fullName = data['fullName'];
        await _storage.write(key: 'jwt', value: _jwt);
        notifyListeners();
        return null;
      } else {
        final errorBody = response.body;
        print('Login failed with status ${response.statusCode}: $errorBody');
        return 'Login failed: ${errorBody.isNotEmpty ? errorBody : 'Unknown error'}';
      }
    } catch (e) {
      print('Login exception: $e');
      return 'Login failed: ${e.toString()}';
    }
  }

  Future<String?> signup(String fullName, String email, String password, String specialization) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password, 'fullName': fullName, 'specialization': specialization}),
      ).timeout(const Duration(seconds: 10));
      
      print('Signup response status: ${response.statusCode}');
      print('Signup response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _jwt = data['jwtToken'];
        _role = data['userRole'];
        _email = data['email'];
        _fullName = data['fullName'];
        await _storage.write(key: 'jwt', value: _jwt);
        notifyListeners();
        return null;
      } else {
        final errorBody = response.body;
        print('Signup failed with status ${response.statusCode}: $errorBody');
        return 'Signup failed: ${errorBody.isNotEmpty ? errorBody : 'Unknown error'}';
      }
    } catch (e) {
      print('Signup exception: $e');
      return 'Signup failed: ${e.toString()}';
    }
  }

  void logout() async {
    _jwt = null;
    _role = null;
    _email = null;
    _fullName = null;
    await _storage.delete(key: 'jwt');
    notifyListeners();
  }
}

