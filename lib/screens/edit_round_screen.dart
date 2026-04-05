import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/round_model.dart';
import '../services/auth_service.dart';

class EditRoundScreen extends StatefulWidget {
  final RoundData? round; // null이면 신규 생성, 값이 있으면 수정 모드

  const EditRoundScreen({super.key, this.round});

  @override
  State<EditRoundScreen> createState() => _EditRoundScreenState();
}

class _EditRoundScreenState extends State<EditRoundScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  
  final TextEditingController _golfCourseCtrl = TextEditingController();
  final TextEditingController _frontCourseCtrl = TextEditingController();
  final TextEditingController _backCourseCtrl = TextEditingController();
  final TextEditingController _companionsCtrl = TextEditingController(); // 쉼표로 구분입력

  late List<HoleData> _holes;
  int _currentHoleIndex = 0;
  bool _isSaving = false;
  
  // Autocomplete 내부 컨트롤러에 접근하기 위한 참조 변수
  TextEditingController? _internalGolfCourseCtrl;
  TextEditingController? _internalFrontCourseCtrl;
  TextEditingController? _internalBackCourseCtrl;
  
  Map<String, Map<String, List<int>>> _courseDatabase = {};

  @override
  void initState() {
    super.initState();
    _loadCourseDatabase();
    // 데이터 초기화 세팅
    if (widget.round != null) {
      _selectedDate = widget.round!.date;
      final timeParts = widget.round!.teeUpTime.split(':');
      _selectedTime = timeParts.length == 2 
          ? TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]))
          : TimeOfDay.now();
      _golfCourseCtrl.text = widget.round!.golfCourseName;
      _frontCourseCtrl.text = widget.round!.frontCourseName;
      _backCourseCtrl.text = widget.round!.backCourseName;
      _companionsCtrl.text = widget.round!.companions.join(', ');
      
      // 깊은 복사하여 수정 시 원본 객체 오염 방지
      _holes = widget.round!.holes.map((h) => 
        HoleData(
          holeNumber: h.holeNumber, 
          par: h.par, 
          score: h.score, 
          putt: h.putt,
          teeOb: h.teeOb,
          teeHazard: h.teeHazard,
          secondOb: h.secondOb,
          secondHazard: h.secondHazard,
        )
      ).toList();
    } else {
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
      _holes = List.generate(
        18,
        (index) => HoleData(holeNumber: index + 1, par: 4, score: -99, putt: -99), 
      );
      _loadLatestRoundAndFill();
    }
  }

  Future<void> _loadLatestRoundAndFill() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('rounds')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        if (mounted) {
          setState(() {
            _golfCourseCtrl.text = data['golfCourseName'] ?? '';
            _frontCourseCtrl.text = data['frontCourseName'] ?? '';
            _backCourseCtrl.text = data['backCourseName'] ?? '';
            // 최신 골프장의 파(Par) 데이터를 _courseDatabase에서 불러와서 현재 UI에 맞게 다시 세팅할 수 있도록 딜레이 적용
            Future.delayed(const Duration(milliseconds: 300), () {
              if (!mounted) return;
              if (_frontCourseCtrl.text.isNotEmpty) _applyCoursePars(_frontCourseCtrl.text, 0, showSnackbar: false);
              if (_backCourseCtrl.text.isNotEmpty) _applyCoursePars(_backCourseCtrl.text, 9, showSnackbar: false);
            });
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading latest round: $e');
    }
  }

  @override
  void dispose() {
    _golfCourseCtrl.dispose();
    _frontCourseCtrl.dispose();
    _backCourseCtrl.dispose();
    _companionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _loadCourseDatabase() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('courses').get();
      final db = <String, Map<String, List<int>>>{};
      for (var doc in snap.docs) {
        final data = doc.data();
        if (data['courses'] != null) {
          final coursesMap = data['courses'] as Map<String, dynamic>;
          final parsedMap = <String, List<int>>{};
          coursesMap.forEach((k, v) {
            if (v is List) {
              parsedMap[k] = v.map((e) => e as int).toList();
            }
          });
          db[doc.id] = parsedMap;
        }
      }
      if (mounted) {
        setState(() {
          _courseDatabase = db;
        });
      }
    } catch (e) {
      debugPrint('Error loading courses: $e');
    }
  }

  void _applyCoursePars(String courseName, int startIndex, {bool showSnackbar = true}) {
    final golfCourse = _golfCourseCtrl.text.trim();
    final pars = _courseDatabase[golfCourse]?[courseName];
    if (pars != null && pars.length == 9) {
      setState(() {
        for (int i = 0; i < 9; i++) {
          _holes[startIndex + i].par = pars[i];
        }
      });
      if (showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("'$courseName' 코스의 Par 정보가 로드되었습니다.")),
        );
      }
    }
  }

  int get _overUnder => _holes.fold(0, (sum, hole) => sum + (hole.score == -99 ? 0 : hole.score)); // 미입력은 Par(0) 취급
  int get _totalPar => _holes.fold(0, (sum, hole) => sum + hole.par);
  int get _totalGross => _totalPar + _overUnder; 
  int get _totalPutt => _holes.fold(0, (sum, hole) => sum + (hole.putt == -99 ? 2 : hole.putt)); // 미입력은 2퍼트 취급

  String get _overUnderStr {
    final ou = _overUnder;
    return ou > 0 ? '+$ou' : (ou < 0 ? '$ou' : 'E');
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;
    
    // UI Rebuild(setState)가 일어나기 전에 화면의 텍스트 값을 안전하게 미리 캡처합니다.
    final capturedGolfCourse = _internalGolfCourseCtrl?.text.trim() ?? _golfCourseCtrl.text.trim();
    final capturedFrontCourse = (_internalFrontCourseCtrl?.text.trim() ?? _frontCourseCtrl.text.trim()).isNotEmpty 
        ? (_internalFrontCourseCtrl?.text.trim() ?? _frontCourseCtrl.text.trim()) : '전반';
    final capturedBackCourse = (_internalBackCourseCtrl?.text.trim() ?? _backCourseCtrl.text.trim()).isNotEmpty 
        ? (_internalBackCourseCtrl?.text.trim() ?? _backCourseCtrl.text.trim()) : '후반';

    setState(() => _isSaving = true);
    
    try {
      final String teeUpTimeStr = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
      final List<String> companionsList = _companionsCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      String? docId = widget.round?.id;
      if (docId == null) {
        docId = FirebaseFirestore.instance.collection('rounds').doc().id;
      }

      // 저장 전, 미입력(-99) 구역을 기본값(0, 2)으로 보정
      final List<HoleData> savingHoles = _holes.map((h) => HoleData(
        holeNumber: h.holeNumber,
        par: h.par,
        score: h.score == -99 ? 0 : h.score,
        putt: h.putt == -99 ? 2 : h.putt,
        teeOb: h.teeOb,
        teeHazard: h.teeHazard,
        secondOb: h.secondOb,
        secondHazard: h.secondHazard,
      )).toList();

      final roundData = RoundData(
        id: docId,
        date: _selectedDate,
        teeUpTime: teeUpTimeStr,
        golfCourseName: capturedGolfCourse,
        frontCourseName: capturedFrontCourse == '전반' && _internalFrontCourseCtrl?.text.trim().isEmpty == true ? '' : capturedFrontCourse,
        backCourseName: capturedBackCourse == '후반' && _internalBackCourseCtrl?.text.trim().isEmpty == true ? '' : capturedBackCourse,
        companions: companionsList,
        totalScore: savingHoles.fold(0, (sum, h) => sum + h.score), // 누적 오버/언더파 값 저장
        holes: savingHoles,
        createdAt: widget.round?.createdAt ?? DateTime.now(),
        userId: AuthService().currentUser?.uid,
        userName: AuthService().currentUser?.displayName,
      );

      await FirebaseFirestore.instance.collection('rounds').doc(docId).set(
        roundData.toMap(),
        SetOptions(merge: true),
      ).timeout(const Duration(seconds: 10), onTimeout: () => throw Exception('라운드 저장 시간 초과 (10초)'));

      final golfCourse = capturedGolfCourse;
      final frontCourse = capturedFrontCourse;
      final backCourse = capturedBackCourse;
      
      print('=== DEBUG SAVE COURSE ===');
      print('golfCourse: $golfCourse');
      print('frontCourse: $frontCourse');
      print('backCourse: $backCourse');
      
      if (golfCourse.isNotEmpty) {
        final frontPars = _holes.sublist(0, 9).map((h) => h.par).toList();
        final backPars = _holes.sublist(9, 18).map((h) => h.par).toList();
        
        final Map<String, dynamic> courseUpdates = {};
        courseUpdates[frontCourse] = frontPars;
        courseUpdates[backCourse] = backPars;
        
        print('courseUpdates: $courseUpdates');
        
        if (courseUpdates.isNotEmpty) {
          final courseDoc = FirebaseFirestore.instance.collection('courses').doc(golfCourse);
          final snap = await courseDoc.get().timeout(const Duration(seconds: 10), onTimeout: () => throw Exception('코스 조회 시간 초과 (10초)'));
          
          if (snap.exists) {
            // 안전하게 Map 캐스팅 (만약 DB에 이상한 타입으로 들어있으면 빈 Map으로 초기화)
            Map<String, dynamic> mergedCourses = {};
            try {
              if (snap.data()?['courses'] is Map) {
                mergedCourses = Map<String, dynamic>.from(snap.data()?['courses'] as Map);
              }
            } catch (_) {}
            
            mergedCourses[frontCourse] = frontPars;
            mergedCourses[backCourse] = backPars;
            await courseDoc.update({'courses': mergedCourses}).timeout(const Duration(seconds: 10), onTimeout: () => throw Exception('코스 업데이트 시간 초과 (10초)'));
          } else {
            // 없는 골프장이라면 새로 생성
            await courseDoc.set({
              'name': golfCourse,
              'courses': courseUpdates,
            }).timeout(const Duration(seconds: 10), onTimeout: () => throw Exception('코스 생성 시간 초과 (10초)'));
          }
        }
      }

      if (mounted) Navigator.pop(context); // 저장 완료 후 화면 닫기
      
    } catch (e, stack) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('저장 오류 분석기'),
            content: SingleChildScrollView(child: Text('에러원인:\n$e\n\n$stack')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인'))
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기록 삭제'),
        content: const Text('정말로 이 라운드 기록을 삭제하시겠습니까?\n삭제된 데이터는 복구할 수 없으며, 통계에서도 지워집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _isSaving = true);
      try {
        await FirebaseFirestore.instance.collection('rounds').doc(widget.round!.id).delete();
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.round != null ? '기록 수정' : '기록 추가'),
        actions: widget.round != null ? [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            tooltip: '라운드 삭제',
            onPressed: () => _confirmDelete(),
          )
        ] : null,
      ),
      body: Form(
        key: _formKey,
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              Expanded(
                child: NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverToBoxAdapter(
                        child: ExpansionTile(
                          initiallyExpanded: widget.round == null,
                          title: Text('기본 정보', style: Theme.of(context).textTheme.titleLarge),
                          subtitle: const Text('터치하여 기본 정보를 접거나 펼칠 수 있습니다.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _selectDate,
                                    icon: const Icon(Icons.calendar_today),
                                    label: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _selectTime,
                                    icon: const Icon(Icons.access_time),
                                    label: Text(_selectedTime.format(context)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Autocomplete<String>(
                              initialValue: TextEditingValue(text: _golfCourseCtrl.text),
                              optionsBuilder: (TextEditingValue text) {
                                if (text.text.isEmpty) return _courseDatabase.keys;
                                return _courseDatabase.keys.where((String option) => option.contains(text.text));
                              },
                              onSelected: (String selection) {
                                _golfCourseCtrl.text = selection;
                                setState(() {}); // 선택 시 하위 코스 업데이트
                              },
                              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                _internalGolfCourseCtrl = controller;
                                final currentText = controller.text.trim();
                                final bool isNew = currentText.isNotEmpty && !_courseDatabase.keys.contains(currentText);
                                return TextFormField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  onChanged: (val) {
                                    if (_golfCourseCtrl.text != val) {
                                      _golfCourseCtrl.text = val;
                                      setState(() {}); 
                                    }
                                  },
                                  decoration: InputDecoration(
                                    labelText: '골프장명 (검색 또는 직접 입력)', 
                                    border: const OutlineInputBorder(),
                                    helperText: isNew ? '✨ 입력하신 이름으로 코스가 신규 등록됩니다.' : null,
                                    helperStyle: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                                  ),
                                  validator: (v) => v!.isEmpty ? '골프장명을 입력하세요' : null,
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Autocomplete<String>(
                                    initialValue: TextEditingValue(text: _frontCourseCtrl.text),
                                    optionsBuilder: (TextEditingValue text) {
                                      final golfCourse = _golfCourseCtrl.text.trim();
                                      final available = _courseDatabase[golfCourse]?.keys ?? [];
                                      if (text.text.isEmpty) return available;
                                      return available.where((o) => o.contains(text.text));
                                    },
                                    onSelected: (String selection) {
                                      _frontCourseCtrl.text = selection;
                                      _applyCoursePars(selection, 0);
                                    },
                                    fieldViewBuilder: (context, controller, focus, onSub) {
                                      _internalFrontCourseCtrl = controller;
                                      final golfCourse = _internalGolfCourseCtrl?.text.trim() ?? _golfCourseCtrl.text.trim();
                                      final available = _courseDatabase[golfCourse]?.keys ?? [];
                                      final currentText = controller.text.trim();
                                      final bool isNew = currentText.isNotEmpty && !available.contains(currentText);
                                      return TextFormField(
                                        controller: controller,
                                        focusNode: focus,
                                        onChanged: (val) {
                                          if (_frontCourseCtrl.text != val) {
                                            _frontCourseCtrl.text = val;
                                            setState(() {});
                                          }
                                        },
                                        decoration: InputDecoration(
                                          labelText: '전반 코스', 
                                          border: const OutlineInputBorder(),
                                          helperText: isNew ? '✨ 신규 등록' : null,
                                          helperStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Autocomplete<String>(
                                    initialValue: TextEditingValue(text: _backCourseCtrl.text),
                                    optionsBuilder: (TextEditingValue text) {
                                      final golfCourse = _golfCourseCtrl.text.trim();
                                      final available = _courseDatabase[golfCourse]?.keys ?? [];
                                      if (text.text.isEmpty) return available;
                                      return available.where((o) => o.contains(text.text));
                                    },
                                    onSelected: (String selection) {
                                      _backCourseCtrl.text = selection;
                                      _applyCoursePars(selection, 9);
                                    },
                                    fieldViewBuilder: (context, controller, focus, onSub) {
                                      _internalBackCourseCtrl = controller;
                                      final golfCourse = _internalGolfCourseCtrl?.text.trim() ?? _golfCourseCtrl.text.trim();
                                      final available = _courseDatabase[golfCourse]?.keys ?? [];
                                      final currentText = controller.text.trim();
                                      final bool isNew = currentText.isNotEmpty && !available.contains(currentText);
                                      return TextFormField(
                                        controller: controller,
                                        focusNode: focus,
                                        onChanged: (val) {
                                          if (_backCourseCtrl.text != val) {
                                            _backCourseCtrl.text = val;
                                            setState(() {});
                                          }
                                        },
                                        decoration: InputDecoration(
                                          labelText: '후반 코스', 
                                          border: const OutlineInputBorder(),
                                          helperText: isNew ? '✨ 신규 등록' : null,
                                          helperStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _companionsCtrl,
                              decoration: const InputDecoration(
                                labelText: '동반자 (쉼표로 구분)', 
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('홀별 스코어', style: Theme.of(context).textTheme.titleLarge),
                              Text(
                                '$_totalGross($_overUnderStr), $_totalPutt putt', 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigo),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverAppBar(
                        pinned: true,
                        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                        elevation: 0,
                        toolbarHeight: 0,
                        bottom: TabBar(
                          labelColor: Colors.indigo,
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: Colors.indigo,
                          tabs: [
                            Tab(
                              child: ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _frontCourseCtrl,
                                builder: (context, value, _) {
                                  final text = value.text.trim();
                                  return Text(text.isNotEmpty ? text : '전반 (Front)');
                                },
                              ),
                            ),
                            Tab(
                              child: ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _backCourseCtrl,
                                builder: (context, value, _) {
                                  final text = value.text.trim();
                                  return Text(text.isNotEmpty ? text : '후반 (Back)');
                                },
                              ),
                            ),
                            const Tab(text: '스코어카드'),
                          ],
                        ),
                      ),
                    ];
                  },
                  body: TabBarView(
                    children: [
                      _buildHoleList(0, 9),
                      _buildHoleList(9, 18),
                      _buildScorecardTab(),
                    ],
                  ),
                ),
              ),
              // 하단: 저장 버튼 
              Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                color: Colors.white,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isSaving ? null : _saveRecord,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(widget.round != null ? '수정하기' : '저장하기', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHoleList(int start, int end) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: end - start,
      itemBuilder: (context, index) {
        final hole = _holes[start + index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  // 홀 번호 표시
                  SizedBox(
                    width: 65,
                    child: Text('${hole.holeNumber} Hole', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  // Par 선택 영역
                  const Text('Par', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: hole.par,
                    underline: Container(
                      height: 1,
                      color: Colors.grey.shade400,
                    ),
                    items: [3, 4, 5].map((e) => DropdownMenuItem(value: e, child: Text('$e', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))).toList(),
                    onChanged: (val) {
                      if(val != null) setState(() => hole.par = val);
                    },
                  ),
                  const SizedBox(width: 16),
                  // Score 컨트롤
                  _buildCounter('Score', hole.score, (val) {
                    setState(() => hole.score = val);
                  }, isOverUnder: true),
                  const SizedBox(width: 16),
                  // Putt 컨트롤
                  _buildCounter('Putt', hole.putt, (val) {
                    setState(() => hole.putt = val);
                  }),
                  const SizedBox(width: 16),
                  // 페널티 다이얼로그 버튼
                  GestureDetector(
                    onTap: () => _showPenaltyDialog(context, hole),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: hole.penaltyStrokes > 0 
                            ? Colors.red.shade50 
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: hole.penaltyStrokes > 0 
                              ? Colors.red.shade300 
                              : Colors.grey.shade300
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded, 
                            size: 20, 
                            color: hole.penaltyStrokes > 0 ? Colors.red.shade700 : Colors.grey
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hole.penaltyStrokes > 0 
                                ? '${hole.penaltyStrokes} 벌타' 
                                : '벌타',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: hole.penaltyStrokes > 0 ? Colors.red.shade700 : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 보다 슬림해진 +/- 구조 UI 컨트롤러 위젯 
  Widget _buildCounter(String label, int value, ValueChanged<int> onChanged, {bool isOverUnder = false}) {
    // -99는 미입력 상태를 의미하므로 빈칸 처리
    String displayValue = (value == -99) ? '' : ((isOverUnder && value > 0) ? '+$value' : '$value');
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () {
                if (value == -99) {
                  // 미입력 상태에서 클릭 시: 스코어는 0, 퍼트는 2부터 시작
                  onChanged(isOverUnder ? 0 : 2);
                } else {
                  onChanged(isOverUnder ? value - 1 : (value > 0 ? value - 1 : 0));
                }
              },
              child: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 28),
            ),
            SizedBox(
              width: 34,
              child: Text(displayValue, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            InkWell(
              onTap: () {
                if (value == -99) {
                  // 미입력 상태에서 클릭 시: 스코어는 0, 퍼트는 2부터 시작
                  onChanged(isOverUnder ? 0 : 2);
                } else {
                  onChanged(value + 1);
                }
              },
              child: const Icon(Icons.add_circle, color: Colors.blueAccent, size: 28),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPenaltyCounter(String label, int value, ValueChanged<int> onChanged) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => onChanged(value > 0 ? value - 1 : 0),
              child: const Icon(Icons.remove_circle, color: Colors.grey, size: 36),
            ),
            SizedBox(
              width: 36,
              child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            InkWell(
              onTap: () => onChanged(value + 1),
              child: const Icon(Icons.add_circle, color: Colors.orange, size: 36),
            ),
          ],
        ),
      ],
    );
  }

  void _showPenaltyDialog(BuildContext context, HoleData hole) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 32, 
                top: 24, left: 16, right: 16
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${hole.holeNumber} Hole 벌타 입력', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPenaltyCounter('티샷 OB', hole.teeOb, (v) {
                        setState(() => hole.teeOb = v);
                        setModalState(() {});
                      }),
                      _buildPenaltyCounter('티샷 해저드', hole.teeHazard, (v) {
                        setState(() => hole.teeHazard = v);
                        setModalState(() {});
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPenaltyCounter('세컨샷 OB', hole.secondOb, (v) {
                        setState(() => hole.secondOb = v);
                        setModalState(() {});
                      }),
                      _buildPenaltyCounter('세컨샷 해저드', hole.secondHazard, (v) {
                        setState(() => hole.secondHazard = v);
                        setModalState(() {});
                      }),
                    ],
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('확인', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildScorecardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _frontCourseCtrl,
            builder: (context, value, child) {
              final text = value.text.trim();
              return Padding(
                padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                child: Text(text.isNotEmpty ? '$text 코스' : '전반 코스', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              );
            },
          ),
          _buildScorecardGrid(_holes, 0),
          const SizedBox(height: 24),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _backCourseCtrl,
            builder: (context, value, child) {
              final text = value.text.trim();
              return Padding(
                padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                child: Text(text.isNotEmpty ? '$text 코스' : '후반 코스', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              );
            },
          ),
          _buildScorecardGrid(_holes, 9),
          _buildRoundStatistics(_holes),
          const SizedBox(height: 80), // 여백 확보
        ],
      ),
    );
  }

  Widget _buildRoundStatistics(List<HoleData> holes) {
    if (holes.isEmpty) return const SizedBox();
    
    int girHits = 0;
    int scramblingChances = 0;
    int scramblingSuccesses = 0;
    int totalPutts = 0;
    int totalPenaltyStrokes = 0;
    
    int girPutts = 0;
    int nonGirPutts = 0;
    int onePuttCount = 0;
    int twoPuttCount = 0;
    int threePlusPuttCount = 0;

    int teeObCount = 0;
    int secondObCount = 0;
    int teeHazardCount = 0;
    int secondHazardCount = 0;

    for (var hole in holes) {
      totalPutts += hole.putt;
      totalPenaltyStrokes += hole.penaltyStrokes;
      
      teeObCount += hole.teeOb;
      secondObCount += hole.secondOb;
      teeHazardCount += hole.teeHazard;
      secondHazardCount += hole.secondHazard;
      
      if (hole.putt == 1) onePuttCount++;
      else if (hole.putt == 2) twoPuttCount++;
      else if (hole.putt >= 3) threePlusPuttCount++;

      bool isGir = (hole.score - hole.putt) <= -2;
      if (isGir) {
        girHits++;
        girPutts += hole.putt;
      } else {
        scramblingChances++;
        nonGirPutts += hole.putt;
        if (hole.score <= 0) scramblingSuccesses++;
      }
    }

    double girPct = (girHits / 18) * 100;
    double scramblingPct = scramblingChances > 0 ? (scramblingSuccesses / scramblingChances) * 100 : 0;
    double avgGirPutts = girHits > 0 ? girPutts / girHits : 0.0;
    double avgNonGirPutts = scramblingChances > 0 ? nonGirPutts / scramblingChances : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⛳ 라운드 통계', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const Divider(height: 24),
            Table(
              border: TableBorder.all(color: Colors.grey.shade300),
              defaultVerticalAlignment: TableCellVerticalAlignment.top,
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade50),
                  children: [
                    _buildStatCell('그린 적중률', '${girPct.toStringAsFixed(1)}% ($girHits/18)', valueColor: Colors.black87),
                    _buildStatCell('스크램블링', '${scramblingPct.toStringAsFixed(1)}% ($scramblingSuccesses/$scramblingChances)', valueColor: Colors.black87),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('퍼트 통계', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 8),
            Table(
              border: TableBorder.all(color: Colors.grey.shade300),
              defaultVerticalAlignment: TableCellVerticalAlignment.top,
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade50),
                  children: [
                    _buildStatCell('총 퍼트 (평균)', '$totalPutts (${(totalPutts/18).toStringAsFixed(1)})', valueColor: Colors.black87),
                    _buildStatCell('파온 성공시', avgGirPutts > 0 ? avgGirPutts.toStringAsFixed(1) : "0", valueColor: Colors.black87),
                    _buildStatCell('파온 실패시', avgNonGirPutts > 0 ? avgNonGirPutts.toStringAsFixed(1) : "0", valueColor: Colors.black87),
                  ],
                ),
                TableRow(
                  decoration: BoxDecoration(color: Colors.white),
                  children: [
                    _buildStatCell('1퍼트', '$onePuttCount', valueColor: Colors.black87),
                    _buildStatCell('2퍼트', '$twoPuttCount', valueColor: Colors.black87),
                    _buildStatCell('3퍼트 이상', '$threePlusPuttCount', valueColor: Colors.black87),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('패널티 통계', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 8),
            Table(
              border: TableBorder.all(color: Colors.grey.shade300),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade50),
                  children: [
                    _buildStatCell('합계 (벌타)', '$totalPenaltyStrokes'),
                    _buildStatCell('티샷 벌타', _buildPenaltyValue(teeObCount, teeHazardCount)),
                    _buildStatCell('세컨샷 벌타', _buildPenaltyValue(secondObCount, secondHazardCount)),
                  ],
                ),
              ],
            ),
            // 모든 홀(18홀)이 입력되었을 때만 보너스 점수판 노출 ("짠~")
            if (holes.every((h) => h.score != -99 && h.putt != -99)) ...[
              const Divider(height: 32),
              const Text('✨ Q-Point Bonus Status', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.indigo)),
              const SizedBox(height: 12),
              _buildBonusRowStatic('Sub-80 Round (+2)', (_totalPar + (_totalGross - _totalPar)) <= 79),
              _buildBonusRowStatic('Scrambling 50%+ (+2)', scramblingChances > 0 && (scramblingSuccesses / scramblingChances) >= 0.5),
              _buildBonusRowStatic('One Ball Play (+2)', totalPenaltyStrokes == 0),
              _buildBonusRowStatic('Digital Round (+2)', holes.every((h) => h.score <= 1)),
              _buildBonusRowStatic('No Three Putt (+2)', holes.every((h) => h.putt < 3)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBonusRowStatic(String title, bool achieved) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          Text(
            achieved ? 'SUCCESS' : 'FAIL', 
            style: TextStyle(
              color: achieved ? Colors.blue : Colors.red, 
              fontWeight: FontWeight.bold,
              fontSize: 14
            )
          ),
        ],
      ),
    );
  }

  Widget _buildStatCell(String title, dynamic value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          if (value is Widget)
            value
          else
            Text(value.toString(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor ?? Colors.black87), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildPenaltyValue(int ob, int hazard) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            children: [
              const TextSpan(text: 'O.B ', style: TextStyle(color: Colors.red)),
              TextSpan(text: '$ob', style: const TextStyle(color: Colors.black87)),
            ],
          ),
        ),
        const SizedBox(height: 2),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            children: [
              const TextSpan(text: 'Hazard ', style: TextStyle(color: Colors.red)),
              TextSpan(text: '$hazard', style: const TextStyle(color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScorecardGrid(List<HoleData> holes, int startIndex) {
    if (holes.length < startIndex + 9) return const SizedBox(); 

    final subHoles = holes.sublist(startIndex, startIndex + 9);
    final totalPar = subHoles.fold(0, (sum, h) => sum + h.par);
    final totalScore = subHoles.fold(0, (sum, h) => sum + h.score);
    final totalPutt = subHoles.fold(0, (sum, h) => sum + h.putt);

    return Table(
      border: TableBorder.all(color: Colors.grey.shade300, width: 1),
      columnWidths: const {
        0: FlexColumnWidth(1.6),
        10: FlexColumnWidth(1.6),
      },
      defaultColumnWidth: const FlexColumnWidth(1.0),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: [
            _buildGridCell('HOLE', isHeader: true),
            for (int i = 1; i <= 9; i++) _buildGridCell('${startIndex + i}', isHeader: true),
            _buildGridCell('TOTAL', isHeader: true),
          ],
        ),
        TableRow(
          children: [
            _buildGridCell('PAR', isHeader: true),
            for (var h in subHoles) _buildGridCell('${h.par}'),
            _buildGridCell('$totalPar', isBold: true),
          ],
        ),
        TableRow(
          children: [
            _buildGridCell('SCORE', isHeader: true),
            for (var h in subHoles) _buildGridScoreCell(h.score),
            _buildGridScoreCell(totalScore, isBold: true, isTotal: true),
          ],
        ),
        TableRow(
          children: [
            _buildGridCell('PUTT', isHeader: true),
            for (var h in subHoles) _buildGridCell('${h.putt}'),
            _buildGridCell('$totalPutt', isBold: true),
          ],
        ),
      ],
    );
  }

  Widget _buildGridCell(String text, {bool isHeader = false, bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: (isHeader || isBold) ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? Colors.grey.shade600 : Colors.black87,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildGridScoreCell(int score, {bool isBold = false, bool isTotal = false}) {
    Color bgColor = Colors.transparent;
    String text = score == 0 ? '0' : (score > 0 ? '+$score' : '$score');
    
    if (isTotal) {
      bgColor = Colors.transparent; // TOTAL 칼럼은 배경색 없음
    } else {
      if (score < 0) {
        bgColor = Colors.red.shade200;
      } else if (score > 0) {
        bgColor = Colors.cyan.shade200;
      } else {
        bgColor = Colors.grey.shade100;
      }
    }

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.bold,
          fontSize: 12,
          color: Colors.black87,
        ),
      ),
    );
  }
}
