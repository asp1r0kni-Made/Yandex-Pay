import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Сервис для общения с backend «Сплит Банк».
/// Замените [baseUrl] на адрес вашего развёрнутого backend (app.py).
class ApiService {
  ApiService._internal();
  static final ApiService instance = ApiService._internal();

  // TODO: замените на адрес вашего сервера перед сборкой релиза.
  static const String baseUrl = "http://10.0.2.2:8000";

  final _storage = const FlutterSecureStorage();
  static const _tokenKey = "splitbank_token";

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  Future<String?> getToken() => _storage.read(key: _tokenKey);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  Future<Map<String, dynamic>> register(String phone, {String? fullName}) async {
    final res = await http.post(
      Uri.parse("$baseUrl/auth/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"phone": phone, "full_name": fullName}),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> requestCode(String phone) async {
    final res = await http.post(
      Uri.parse("$baseUrl/auth/request-code"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"phone": phone}),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> verifyCode(String phone, String code) async {
    final res = await http.post(
      Uri.parse("$baseUrl/auth/verify"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"phone": phone, "code": code}),
    );
    final data = _decode(res);
    if (data["token"] != null) {
      await saveToken(data["token"]);
    }
    return data;
  }

  Future<List<dynamic>> listCards() async {
    final res = await http.get(
      Uri.parse("$baseUrl/cards"),
      headers: await _authHeaders(),
    );
    return _decode(res) as List<dynamic>;
  }

  Future<Map<String, dynamic>> issueCard({String label = "Цифровая карта"}) async {
    final res = await http.post(
      Uri.parse("$baseUrl/cards/issue"),
      headers: await _authHeaders(),
      body: jsonEncode({"label": label}),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> toggleFreeze(int cardId) async {
    final res = await http.post(
      Uri.parse("$baseUrl/cards/$cardId/freeze"),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    final body = res.body.isEmpty ? "{}" : res.body;
    final data = jsonDecode(body);
    if (res.statusCode >= 400) {
      final detail = (data is Map && data["detail"] != null) ? data["detail"] : "Ошибка сервера";
      throw ApiException(detail.toString(), res.statusCode);
    }
    return data;
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override
  String toString() => message;
}
