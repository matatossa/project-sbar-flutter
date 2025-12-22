import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/lesson.dart';
import '../models/video.dart';
import '../models/document.dart';
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

  static Future<bool> addLesson(BuildContext ctx, String title, String desc, String specialization, int duration, List<PlatformFile> videoFiles) async {
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
    
    // 2. Upload all videos
    for (var videoFile in videoFiles) {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost:8080/api/videos/lesson/$lessonId'),
      );
      req.headers['Authorization'] = 'Bearer ${authService.jwt}';
      
      if (kIsWeb) {
        // Web: use bytes
        if (videoFile.bytes == null) continue;
        req.files.add(http.MultipartFile.fromBytes(
          'file',
          videoFile.bytes!,
          filename: videoFile.name,
        ));
      } else {
        // Mobile/Desktop: use path (only access path when not on web)
        final filePath = videoFile.path;
        if (filePath == null) continue;
        req.files.add(await http.MultipartFile.fromPath('file', filePath));
      }
      
      final videoRes = await req.send();
      if (videoRes.statusCode != 200 && videoRes.statusCode != 201) {
        return false;
      }
    }
    
    return true;
  }

  static Future<List<Video>> fetchVideosByLesson(int lessonId, BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) return [];
    final response = await http.get(
      Uri.parse('http://localhost:8080/api/videos/lesson/$lessonId'),
      headers: {'Authorization': 'Bearer ${authService.jwt}'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => Video.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  static Future<bool> deleteVideo(int videoId, BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) return false;
    final response = await http.delete(
      Uri.parse('http://localhost:8080/api/videos/$videoId'),
      headers: {'Authorization': 'Bearer ${authService.jwt}'},
    );
    return response.statusCode == 200;
  }

  static Future<bool> uploadVideoToLesson(int lessonId, PlatformFile videoFile, BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) return false;
    
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('http://localhost:8080/api/videos/lesson/$lessonId'),
    );
    req.headers['Authorization'] = 'Bearer ${authService.jwt}';
    
    if (kIsWeb) {
      if (videoFile.bytes == null) return false;
      req.files.add(http.MultipartFile.fromBytes(
        'file',
        videoFile.bytes!,
        filename: videoFile.name,
      ));
    } else {
      final filePath = videoFile.path;
      if (filePath == null) return false;
      req.files.add(await http.MultipartFile.fromPath('file', filePath));
    }
    
    final videoRes = await req.send();
    return videoRes.statusCode == 200 || videoRes.statusCode == 201;
  }

  static Future<List<Document>> fetchDocumentsByLesson(int lessonId, BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) return [];
    final response = await http.get(
      Uri.parse('http://localhost:8080/api/documents/lesson/$lessonId'),
      headers: {'Authorization': 'Bearer ${authService.jwt}'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => Document.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  static Future<bool> deleteDocument(int documentId, BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) return false;
    final response = await http.delete(
      Uri.parse('http://localhost:8080/api/documents/$documentId'),
      headers: {'Authorization': 'Bearer ${authService.jwt}'},
    );
    return response.statusCode == 200;
  }

  static Future<bool> uploadDocumentToLesson(int lessonId, PlatformFile documentFile, String? description, BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) return false;
    
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('http://localhost:8080/api/documents/lesson/$lessonId'),
    );
    req.headers['Authorization'] = 'Bearer ${authService.jwt}';
    
    if (description != null && description.isNotEmpty) {
      req.fields['description'] = description;
    }
    
    if (kIsWeb) {
      if (documentFile.bytes == null) return false;
      req.files.add(http.MultipartFile.fromBytes(
        'file',
        documentFile.bytes!,
        filename: documentFile.name,
        contentType: MediaType('application', 'pdf'),
      ));
    } else {
      final filePath = documentFile.path;
      if (filePath == null) return false;
      req.files.add(await http.MultipartFile.fromPath(
        'file',
        filePath,
        contentType: MediaType('application', 'pdf'),
      ));
    }
    
    final docRes = await req.send();
    return docRes.statusCode == 200 || docRes.statusCode == 201;
  }
}
