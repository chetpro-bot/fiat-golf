import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_course_screen.dart';

class CourseListScreen extends StatelessWidget {
  const CourseListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('골프장 관리'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('courses')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                '등록된 골프장이 없습니다.\n새로운 골프장을 추가해보세요.',
                textAlign: TextAlign.center,
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? doc.id;
              final coursesMap = data['courses'] as Map<String, dynamic>? ?? {};
              
              final sortedKeys = coursesMap.keys.toList()..sort();
              final courseNames = sortedKeys.join(', ');

              String bestScoreDisplay = '';
              if (data['bestScore'] != null) {
                bestScoreDisplay = '\n🏆 베스트: ${data['bestScore']}타 (${data['bestScorer'] ?? '미입력'})';
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    courseNames.isNotEmpty
                        ? '등록된 코스: $courseNames$bestScoreDisplay'
                        : '등록된 세부 코스 없음$bestScoreDisplay',
                  ),
                  trailing: const Icon(Icons.edit, size: 20, color: Colors.blue),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditCourseScreen(
                          docId: doc.id,
                          initialName: name,
                          initialCourses: coursesMap,
                          initialBestScore: data['bestScore'] as int?,
                          initialBestScorer: data['bestScorer'] as String?,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EditCourseScreen(),
            ),
          );
        },
        tooltip: '새 골프장 추가',
        child: const Icon(Icons.add),
      ),
    );
  }
}
