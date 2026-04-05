import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class EditCourseScreen extends StatefulWidget {
  final String? docId;
  final String? initialName;
  final Map<String, dynamic>? initialCourses;
  final int? initialBestScore;
  final String? initialBestScorer;

  const EditCourseScreen({
    super.key,
    this.docId,
    this.initialName,
    this.initialCourses,
    this.initialBestScore,
    this.initialBestScorer,
  });

  @override
  State<EditCourseScreen> createState() => _EditCourseScreenState();
}

class _EditCourseScreenState extends State<EditCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _bestScoreCtrl;
  late TextEditingController _bestScorerCtrl;

  // 코스별 데이터: 코스이름 -> List<int> (9 holes par)
  List<MapEntry<TextEditingController, List<int>>> _courseSections = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
    _bestScoreCtrl = TextEditingController(text: widget.initialBestScore?.toString() ?? '');
    _bestScorerCtrl = TextEditingController(text: widget.initialBestScorer ?? '');

    if (widget.initialCourses != null && widget.initialCourses!.isNotEmpty) {
      widget.initialCourses!.forEach((courseName, parsDynamic) {
        List<int> pars = [];
        if (parsDynamic is List) {
          pars = parsDynamic.map((e) => e as int).toList();
        }
        if (pars.length < 9) {
          pars.addAll(List.filled(9 - pars.length, 4));
        } else if (pars.length > 9) {
          pars = pars.sublist(0, 9);
        }
        _courseSections.add(MapEntry(TextEditingController(text: courseName), pars));
      });
      // 코스명 기준으로 가나다순 정렬
      _courseSections.sort((a, b) => a.key.text.compareTo(b.key.text));
    } else {
      // 신규 생성 시 기본 2개 코스(전/후반) 추가
      _courseSections.add(MapEntry(TextEditingController(text: '전반'), List.generate(9, (index) => 4)));
      _courseSections.add(MapEntry(TextEditingController(text: '후반'), List.generate(9, (index) => 4)));
    }

    // 만약 수동 베스트가 비어있다면, 기존 라운드 기록에서 가장 낮은 타수를 찾아 자동으로 채워줌
    if (widget.initialBestScore == null && widget.initialName != null) {
      _autoUpdateBestScore();
    }
  }

  Future<void> _autoUpdateBestScore() async {
    try {
      final roundSnap = await FirebaseFirestore.instance
          .collection('rounds')
          .where('golfCourseName', isEqualTo: widget.initialName)
          .get();

      if (roundSnap.docs.isNotEmpty) {
        int? bestGross;
        String? bestScorer;

        for (var rDoc in roundSnap.docs) {
          final rData = rDoc.data();
          final holes = rData['holes'] as List?;
          if (holes != null) {
            int totalGross = 0;
            for (var h in holes) {
              final m = h as Map<String, dynamic>;
              totalGross += ((m['par'] as int?) ?? 4) + ((m['score'] as int?) ?? 0);
            }
            if (bestGross == null || totalGross < bestGross) {
              bestGross = totalGross;
              bestScorer = rData['userName'] ?? '이름 모름';
            }
          }
        }

        if (bestGross != null && mounted) {
          setState(() {
            _bestScoreCtrl.text = bestGross.toString();
            _bestScorerCtrl.text = bestScorer ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('자동 베스트 집계 실패: $e');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bestScoreCtrl.dispose();
    _bestScorerCtrl.dispose();
    for (var entry in _courseSections) {
      entry.key.dispose();
    }
    super.dispose();
  }

  void _addCourseSection() {
    setState(() {
      _courseSections.add(MapEntry(TextEditingController(), List.generate(9, (index) => 4)));
    });
  }

  void _removeCourseSection(int index) {
    setState(() {
      _courseSections[index].key.dispose();
      _courseSections.removeAt(index);
    });
  }

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final docId = widget.docId ?? name; // 없으면 이름 그대로 ID로 사용
      
      Map<String, dynamic> coursesMap = {};
      for (var entry in _courseSections) {
        final courseName = entry.key.text.trim();
        if (courseName.isNotEmpty) {
          coursesMap[courseName] = entry.value;
        }
      }

      int? bestScore;
      if (_bestScoreCtrl.text.isNotEmpty) {
        bestScore = int.tryParse(_bestScoreCtrl.text);
      }

      await FirebaseFirestore.instance.collection('courses').doc(docId).set({
        'name': name,
        'courses': coursesMap,
        if (bestScore != null) 'bestScore': bestScore,
        if (_bestScorerCtrl.text.trim().isNotEmpty) 'bestScorer': _bestScorerCtrl.text.trim(),
        'userId': AuthService().currentUser?.uid,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장되었습니다.')));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.docId == null ? '골프장 추가' : '골프장 수정'),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveCourse,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF27AE60),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('저장하기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 32),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '골프장명 (예: 안양CC)',
                border: OutlineInputBorder(),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? '골프장 이름을 입력하세요' : null,
            ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _bestScoreCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '베스트 스코어 (타수)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.emoji_events, color: Colors.orange),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _bestScorerCtrl,
                          decoration: const InputDecoration(
                            labelText: '달성자 (이름)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person, color: Colors.blue),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('세부 코스 설정', style: Theme.of(context).textTheme.titleLarge),
                      TextButton.icon(
                        onPressed: _addCourseSection,
                        icon: const Icon(Icons.add),
                        label: const Text('코스 추가'),
                      )
                    ],
                  ),
                  const Divider(),
                  ...List.generate(_courseSections.length, (index) {
                    final section = _courseSections[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: section.key,
                                    decoration: InputDecoration(
                                      labelText: '코스명 (예: Out, In)',
                                      isDense: true,
                                      border: const OutlineInputBorder(),
                                    ),
                                    validator: (val) => val == null || val.trim().isEmpty ? '코스명을 입력하세요' : null,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                                  onPressed: () => _removeCourseSection(index),
                                )
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text('홀별 Par 설정 (총 9홀)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List.generate(9, (hIdx) {
                                return SizedBox(
                                  width: 58,
                                  child: Column(
                                    children: [
                                      Text('${hIdx + 1}H', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      DropdownButton<int>(
                                        value: section.value[hIdx],
                                        isExpanded: true,
                                        items: [3, 4, 5].map((e) => DropdownMenuItem(value: e, child: Center(child: Text('$e')))).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() => section.value[hIdx] = val);
                                          }
                                        },
                                      )
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    );
                  })
                ],
              ),
            ),
    );
  }
}
