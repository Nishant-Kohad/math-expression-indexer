import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class PdfApiService {
  /// Base URL auto-switches between web (localhost) and Android emulator.
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:8080';
    return 'http://10.0.2.2:8080'; // Android emulator → host machine
  }

  /// Upload a PDF by bytes (works on web and native).
  static Future<Map<String, dynamic>> uploadPdf({
    required String fileName,
    required List<int> bytes,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/pdf/upload'),
    );
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
        'Upload failed (${response.statusCode}): ${response.body}');
  }

  /// Fetch all previously indexed PDFs, grouped by filename.
  static Future<List<dynamic>> getHistory() async {
    final response =
        await http.get(Uri.parse('$baseUrl/api/pdf/history'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception(
        'History failed (${response.statusCode}): ${response.body}');
  }

  /// URL for the CSV export download (open directly in browser).
  static String get exportCsvUrl => '$baseUrl/api/pdf/export/csv';
}
