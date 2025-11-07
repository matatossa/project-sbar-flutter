import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/lesson.dart';
import 'auth_service.dart';

class LessonService {
  static Future<List<Lesson>> fetchLessons(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) return [];
    final response = await http.get(
      Uri.parse('http://localhost:8080/api/lessons'),
      headers: {'Authorization': 'Bearer ${authService.jwt}'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => Lesson.fromJson(item)).toList();
    }
    return [];
  }

  static Future<bool> markLessonWatched(int lessonId, BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) return false;
    final response = await http.post(
      Uri.parse('http://localhost:8080/api/lessons/$lessonId/watched'),
      headers: {'Authorization': 'Bearer ${authService.jwt}'},
    );
    return response.statusCode == 200;
  }

  static Future<bool> enrollInLesson(int lessonId, BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) return false;
    final response = await http.post(
      Uri.parse('http://localhost:8080/api/lessons/$lessonId/enroll'),
      headers: {'Authorization': 'Bearer ${authService.jwt}'},
    );
    return response.statusCode == 200;
  }

  static Future<bool> deleteLesson(int lessonId, BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) return false;
    final response = await http.delete(
      Uri.parse('http://localhost:8080/api/lessons/$lessonId'),
      headers: {'Authorization': 'Bearer ${authService.jwt}'},
    );
    return response.statusCode == 200;
  }

  static Future<List<Lesson>> fetchMyCourses(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) return [];
    final response = await http.get(
      Uri.parse('http://localhost:8080/api/lessons/my-courses'),
      headers: {'Authorization': 'Bearer ${authService.jwt}'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => Lesson.fromJson(item)).toList();
    }
    return [];
  }

  static Future<List<Lesson>> fetchRecommendations(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) return [];
    final response = await http.get(
      Uri.parse('http://localhost:8080/api/recommendations'),
      headers: {'Authorization': 'Bearer ${authService.jwt}'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => Lesson.fromJson(item)).toList();
    }
    return [];
  }

  static Future<Lesson?> fetchLessonById(int lessonId, BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) return null;
    final response = await http.get(
      Uri.parse('http://localhost:8080/api/lessons/$lessonId'),
      headers: {'Authorization': 'Bearer ${authService.jwt}'},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Lesson.fromJson(data);
    }
    return null;
  }

  static Future<bool> triggerTranscript(int lessonId, BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) return false;
    final response = await http.post(
      Uri.parse('http://localhost:8080/api/lessons/$lessonId/transcript'),
      headers: {'Authorization': 'Bearer ${authService.jwt}'},
    );
    return response.statusCode == 200;
  }

  static Future<bool> addLesson(BuildContext ctx, String title, String desc, String specialization, int duration, PlatformFile videoFile) async {
    final authService = Provider.of<AuthService>(ctx, listen: false);
    if (!authService.isAuthenticated) return false;
    // 1. Create lesson CRUD
    final createRes = await http.post(
      Uri.parse('http://localhost:8080/api/lessons'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${authService.jwt}'
      },
      body: jsonEncode({
        'title': title,
        'description': desc,
        'specialization': specialization,
        'videoUrl': null,
        'transcript': null,
        'durationSec': duration
      }),
    );
    if (createRes.statusCode != 200 && createRes.statusCode != 201) return false;
    final lessonId = jsonDecode(createRes.body)['id'];
    // 2. Upload video
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('http://localhost:8080/api/lessons/$lessonId/video'),
    );
    req.headers['Authorization'] = 'Bearer ${authService.jwt}';
    
    if (kIsWeb) {
      // Web: use bytes
      if (videoFile.bytes == null) return false;
      req.files.add(http.MultipartFile.fromBytes(
        'file',
        videoFile.bytes!,
        filename: videoFile.name,
      ));
    } else {
      // Mobile/Desktop: use path (only access path when not on web)
      final filePath = videoFile.path;
      if (filePath == null) return false;
      req.files.add(await http.MultipartFile.fromPath('file', filePath));
    }
    
    final videoRes = await req.send();
    return videoRes.statusCode == 200;
  }
}
