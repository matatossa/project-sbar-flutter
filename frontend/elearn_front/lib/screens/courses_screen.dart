import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/lesson_service.dart';
import '../models/lesson.dart';
import '../widgets/course_card.dart';
import '../widgets/sidebar_nav.dart';
import 'lesson_detail_screen.dart';
import 'add_lesson_screen.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({Key? key}) : super(key: key);

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  late Future<List<Lesson>> _lessonsFuture;
  String _selectedFilter = 'All';
  String? _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _lessonsFuture = LessonService.fetchLessons(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return Scaffold(
      body: Row(
        children: [
          SidebarNav(
            selectedIndex: 1,
            onItemSelected: (index) {
              if (index == 0) {
                Navigator.pushReplacementNamed(context, '/home');
              }
            },
          ),
          Expanded(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Courses',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C1D1F),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () {
                          // TODO: Implement search
                        },
                      ),
                    ],
                  ),
                ),
                // Filters
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  color: Colors.white,
                  child: Column(
                    children: [
                      // Status Tabs
                      Row(
                        children: ['All', 'Active', 'Completed'].map((filter) {
                          final isSelected = _selectedFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedFilter = filter),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFFF6B35) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  filter,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.grey[700],
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      // Language Filters
                      Row(
                        children: [
                          _LanguageFilter(
                            flag: '🇬🇧',
                            label: 'English',
                            isSelected: _selectedLanguage == 'English',
                            onTap: () => setState(() => _selectedLanguage = 'English'),
                          ),
                          const SizedBox(width: 8),
                          _LanguageFilter(
                            flag: '🇪🇸',
                            label: 'Spanish',
                            isSelected: _selectedLanguage == 'Spanish',
                            onTap: () => setState(() => _selectedLanguage = 'Spanish'),
                          ),
                          const SizedBox(width: 8),
                          _LanguageFilter(
                            flag: '🇫🇷',
                            label: 'French',
                            isSelected: _selectedLanguage == 'French',
                            onTap: () => setState(() => _selectedLanguage = 'French'),
                          ),
                          const SizedBox(width: 8),
                          _LanguageFilter(
                            flag: '🇨🇳',
                            label: 'Chinese',
                            isSelected: _selectedLanguage == 'Chinese',
                            onTap: () => setState(() => _selectedLanguage = 'Chinese'),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.tune),
                            onPressed: () {
                              // TODO: Show more filters
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Course List
                Expanded(
                  child: FutureBuilder<List<Lesson>>(
                    future: _lessonsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        );
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.school_outlined, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text(
                                'No courses available yet',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                              if (authService.userRole == 'ADMIN')
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final added = await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const AddLessonScreen()),
                                      );
                                      if (added == true) {
                                        _refreshData();
                                      }
                                    },
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Course'),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }
                      final lessons = snapshot.data!;
                      return ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: lessons.length,
                        itemBuilder: (context, index) {
                          final lesson = lessons[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _ModernCourseCard(
                              lesson: lesson,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LessonDetailScreen(lesson: lesson),
                                ),
                              ),
                              showEnrollButton: authService.userRole != 'ADMIN',
                              onEnroll: () async {
                                final success = await LessonService.enrollInLesson(lesson.id, context);
                                if (success && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Enrolled successfully!')),
                                  );
                                  _refreshData();
                                }
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: authService.userRole == 'ADMIN'
          ? FloatingActionButton.extended(
              onPressed: () async {
                final added = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddLessonScreen()),
                );
                if (added == true) {
                  _refreshData();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Course'),
              backgroundColor: const Color(0xFFFF6B35),
            )
          : null,
    );
  }
}

class _LanguageFilter extends StatelessWidget {
  final String flag;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageFilter({
    required this.flag,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6B35).withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF6B35) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFFFF6B35) : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernCourseCard extends StatelessWidget {
  final Lesson lesson;
  final VoidCallback? onTap;
  final bool showEnrollButton;
  final VoidCallback? onEnroll;

  const _ModernCourseCard({
    required this.lesson,
    this.onTap,
    this.showEnrollButton = false,
    this.onEnroll,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Course Illustration
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF6B35).withOpacity(0.8),
                      const Color(0xFFFF8C42).withOpacity(0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school, color: Colors.white, size: 60),
              ),
              const SizedBox(width: 20),
              // Course Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1D1F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lesson.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6A6F73),
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFFFF6B35), size: 18),
                        const SizedBox(width: 4),
                        const Text(
                          '4.5',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(1.2K)',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'All levels',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (showEnrollButton && onEnroll != null)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: ElevatedButton(
                    onPressed: onEnroll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Enroll'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}



