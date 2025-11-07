import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/lesson_service.dart';
import '../models/lesson.dart';
import '../widgets/app_navbar.dart';
import '../widgets/course_card.dart';
import 'lesson_detail_screen.dart';
import 'add_lesson_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Lesson>> _lessonsFuture;
  late Future<List<Lesson>> _recsFuture;
  late Future<List<Lesson>> _myCoursesFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    _lessonsFuture = LessonService.fetchLessons(context);
    _recsFuture = LessonService.fetchRecommendations(context);
    _myCoursesFuture = LessonService.fetchMyCourses(context);
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FA),
      appBar: const AppNavbar(title: 'Courses'),
      body: Column(
        children: [
          if (authService.userRole != 'ADMIN')
          FutureBuilder<List<Lesson>>(
            future: _recsFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
              }
              if (!snap.hasData || snap.data!.isEmpty) return const SizedBox.shrink();
              final recs = snap.data!;
              return Container(
                height: 240,
                margin: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: Text(
                        'Recommended for you',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C1D1F),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        scrollDirection: Axis.horizontal,
                        itemCount: recs.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (context, i) {
                          final l = recs[i];
                          return SizedBox(
                            width: 280,
                            child: CourseCard(
                              lesson: l,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => LessonDetailScreen(lesson: l)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          FutureBuilder<List<Lesson>>(
            future: _myCoursesFuture,
            builder: (context, snap) {
              if (snap.hasData && snap.data!.isNotEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'My Courses',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1C1D1F),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 240,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        scrollDirection: Axis.horizontal,
                        itemCount: snap.data!.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (context, i) {
                          final l = snap.data![i];
                          return SizedBox(
                            width: 280,
                            child: CourseCard(
                              lesson: l,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => LessonDetailScreen(lesson: l)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Row(
              children: [
                const Text(
                  'All Courses',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1D1F),
                  ),
                ),
              ],
            ),
          ),
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
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Tap + to add your first course',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ),
                      ],
                    ),
                  );
                }
                final lessons = snapshot.data!;
                final crossAxisCount = MediaQuery.of(context).size.width > 1200 ? 4 
                    : MediaQuery.of(context).size.width > 800 ? 3 
                    : MediaQuery.of(context).size.width > 600 ? 2 
                    : 1;
                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: lessons.length,
                  itemBuilder: (context, i) {
                    final lesson = lessons[i];
                    return CourseCard(
                      lesson: lesson,
                      showEnrollButton: authService.userRole != 'ADMIN',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LessonDetailScreen(lesson: lesson),
                        ),
                      ),
                      onEnroll: () async {
                        final success = await LessonService.enrollInLesson(lesson.id, context);
                        if (success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Enrolled successfully!')),
                          );
                          setState(() {
                            _refreshData();
                          });
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Enrollment failed or already enrolled')),
                          );
                        }
                      },
                    );
                  },
                );
              },
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
                  setState(() {
                    _refreshData();
                  });
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Course'),
              backgroundColor: const Color(0xFF0056D2),
            )
          : null,
    );
  }
}
