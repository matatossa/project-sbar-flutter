import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/app_navbar.dart';
import '../services/auth_service.dart';
import '../services/lesson_service.dart';
import '../services/specialization_service.dart';

class AddLessonScreen extends StatefulWidget {
  const AddLessonScreen({Key? key}) : super(key: key);

  @override
  State<AddLessonScreen> createState() => _AddLessonScreenState();
}

class _AddLessonScreenState extends State<AddLessonScreen> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String _desc = '';
  String _specialization = '';
  int _duration = 1;
  List<PlatformFile> _selectedFiles = [];
  bool _uploading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FA),
      appBar: const AppNavbar(title: 'Add New Course', showBackButton: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (val) => val != null && val.isNotEmpty ? null : 'Required',
                onSaved: (val) => _title = val ?? '',
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (val) => val != null && val.isNotEmpty ? null : 'Required',
                onSaved: (val) => _desc = val ?? '',
              ),
              FutureBuilder<List<String>>(
                future: SpecializationService.fetchSpecializations(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    final specializations = snapshot.data!;
                    // Remove duplicates and ensure value exists in items
                    final uniqueSpecializations = specializations.toSet().toList();
                    final currentValue = _specialization.isNotEmpty && uniqueSpecializations.contains(_specialization) 
                        ? _specialization 
                        : null;
                    return DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Specialization (or type new)'),
                      items: uniqueSpecializations.map((s) => DropdownMenuItem<String>(
                        value: s,
                        child: Text(s),
                      )).toList(),
                      onChanged: (val) => setState(() { _specialization = val ?? ''; }),
                      value: currentValue,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Specialization (free text)'),
                onSaved: (val) => _specialization = (val?.isNotEmpty ?? false) ? val! : _specialization,
                validator: (val) => (_specialization.isNotEmpty || (val != null && val.isNotEmpty)) ? null : 'Required',
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload),
                label: Text(_selectedFiles.isEmpty ? 'Pick Videos' : 'Add More Videos'),
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.video,
                    allowMultiple: true,
                    withData: kIsWeb, // Read bytes on web
                  );
                  if (result != null && result.files.isNotEmpty) {
                    setState(() {
                      _selectedFiles.addAll(result.files.where((f) => f.size > 0));
                      // Auto-calculate duration estimate (approximate: 1-2 min videos = 60-120 seconds per video)
                      _duration = _selectedFiles.length * 90; // Default to 90 seconds per video
                    });
                  }
                },
              ),
              if (_selectedFiles.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${_selectedFiles.length} video(s) selected:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ..._selectedFiles.asMap().entries.map((entry) {
                  final index = entry.key;
                  final file = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${index + 1}. ${file.name}',
                            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () {
                            setState(() {
                              _selectedFiles.removeAt(index);
                              _duration = _selectedFiles.length * 90;
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14.0),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 24),
              _uploading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () async {
                        if (!_formKey.currentState!.validate() || _selectedFiles.isEmpty) {
                          setState(() { _error = 'Fill all fields and pick at least one video.'; });
                          return;
                        }
                        _formKey.currentState!.save();
                        setState(() { _uploading = true; _error = null; });
                        final ok = await LessonService.addLesson(
                          context, _title, _desc, _specialization, _duration, _selectedFiles);
                        setState(() { _uploading = false; });
                        if (ok) {
                          if (context.mounted) Navigator.pop(context, true);
                        } else {
                          setState(() { _error = 'Upload failed.'; });
                        }
                      },
                      child: const Text('Create Lesson'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

