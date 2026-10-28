import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_course_screen.dart';
import '../services/course_service.dart';

class CourseListScreen extends StatelessWidget {
  const CourseListScreen({super.key});

  void _openEditScreen(
    BuildContext context, {
    String? docId,
    String? name,
    Map<String, dynamic>? coursesMap,
    int? bestScore,
    String? bestScorer,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditCourseScreen(
          docId: docId,
          initialName: name,
          initialCourses: coursesMap,
          initialBestScore: bestScore,
          initialBestScorer: bestScorer,
        ),
      ),
    );
  }

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
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? doc.id;
              final coursesMap = data['courses'] as Map<String, dynamic>? ?? {};

              final sortedKeys = coursesMap.keys.toList()..sort();
              final courseNames = sortedKeys.join(', ');

              final bestScoreData = data['bestScore'];
              final int? bestScore = bestScoreData != null ? int.tryParse(bestScoreData.toString()) : null;
              final bestScorer = data['bestScorer'] as String?;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _openEditScreen(
                    context,
                    docId: doc.id,
                    name: name,
                    coursesMap: coursesMap,
                    bestScore: bestScore,
                    bestScorer: bestScorer,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 22, color: Colors.grey),
                              tooltip: '메뉴',
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  _openEditScreen(
                                    context,
                                    docId: doc.id,
                                    name: name,
                                    coursesMap: coursesMap,
                                    bestScore: bestScore,
                                    bestScorer: bestScorer,
                                  );
                                } else if (value == 'delete') {
                                  await CourseService().confirmAndDeleteCourse(
                                    context,
                                    docId: doc.id,
                                    courseName: name,
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text('수정'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('삭제', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          courseNames.isNotEmpty ? '등록된 코스: $courseNames' : '등록된 세부 코스 없음',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        ),
                        if (bestScore != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('🏆 ', style: TextStyle(fontSize: 14)),
                              Text(
                                '베스트: $bestScore타 (${bestScorer ?? '미입력'})',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
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
