import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:chattify/services/local_store.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class ApiConfig {
  // For Android emulator use: http://10.0.2.2:8000
  // For a real phone use your PC LAN IP, example: http://192.168.1.5:8000
  static const String baseUrl = 'https://privatechat-i5aj.onrender.com/';
}

class ApiClient {
  ApiClient._();

  static Uri _uri(String path, [Map<String, String>? query]) {
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  static Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final token = await LocalStore.getString('token');
      if (token == null || token.isEmpty) throw ApiException('Please login again');
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static dynamic _decode(http.Response response) {
    dynamic body;
    try {
      body = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    } catch (_) {
      throw ApiException('Invalid server response');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Server error ${response.statusCode}');
    }

    if (body is Map && body['error'] != null) {
      throw ApiException(body['error'].toString());
    }

    return body;
  }

  static Future<Map<String, dynamic>> get(String path, {Map<String, String>? query, bool auth = true}) async {
    final response = await http.get(_uri(path, query), headers: await _headers(auth: auth));
    final body = _decode(response);
    if (body is Map<String, dynamic>) return body;
    throw ApiException('Unexpected server response');
  }

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> data, {bool auth = true}) async {
    final response = await http.post(_uri(path), headers: await _headers(auth: auth), body: jsonEncode(data));
    final body = _decode(response);
    if (body is Map<String, dynamic>) return body;
    throw ApiException('Unexpected server response');
  }

  static Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> data, {bool auth = true}) async {
    final response = await http.patch(_uri(path), headers: await _headers(auth: auth), body: jsonEncode(data));
    final body = _decode(response);
    if (body is Map<String, dynamic>) return body;
    throw ApiException('Unexpected server response');
  }

  static Future<Map<String, dynamic>> delete(String path, {bool auth = true}) async {
    final response = await http.delete(_uri(path), headers: await _headers(auth: auth));
    final body = _decode(response);
    if (body is Map<String, dynamic>) return body;
    throw ApiException('Unexpected server response');
  }
}
