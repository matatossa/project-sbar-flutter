import 'dart:convert';
import 'package:http/http.dart' as http;

class SpecializationService {
  // Returns a list of specialization names derived from lessons
  static Future<List<String>> fetchSpecializations() async {
    final response = await http.get(Uri.parse('http://localhost:8080/api/specializations'));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.cast<String>();
    }
    return [];
  }
}

