import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/round_model.dart';
import '../services/auth_service.dart';
import '../services/betting_service.dart';
import '../services/download_service.dart';
import '../widgets/q_point_breakdown_dialog.dart';

class EditRoundScreen extends StatefulWidget {
  final RoundData? round; // null이면 신규 생성, 값이 있으면 수정 모드

  const EditRoundScreen({super.key, this.round});

  @override
  State<EditRoundScreen> createState() => _EditRoundScreenState();
}

class _EditRoundScreenState extends State<EditRoundScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  
  String? _currentDocId;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  
  final TextEditingController _golfCourseCtrl = TextEditingController();
  final TextEditingController _frontCourseCtrl = TextEditingController();
  final TextEditingController _backCourseCtrl = TextEditingController();
  final TextEditingController _companionsCtrl = TextEditingController(); // 쉼표로 구분입력
  final TextEditingController _unitPriceCtrl = TextEditingController();

  late List<HoleData> _holes;
  int _currentHoleIndex = 0;
  bool _isSaving = false;
  late OjangConfig _ojangConfig;
  int _selectedScorecardPlayerIndex = 0;
  final GlobalKey _scorecardRepaintKey = GlobalKey();
  bool _isDownloadingScorecard = false;
  
  // Autocomplete 내부 컨트롤러에 접근하기 위한 참조 변수
  TextEditingController? _internalGolfCourseCtrl;
  TextEditingController? _internalFrontCourseCtrl;
  TextEditingController? _internalBackCourseCtrl;
  
  Map<String, Map<String, List<int>>> _courseDatabase = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentDocId = widget.round?.id;
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
          companionScores: List<int>.from(h.companionScores),
          companionPutts: List<int>.from(h.companionPutts),
          companionPenalties: List<int>.from(h.companionPenalties),
          companionTeeOb: List<int>.from(h.companionTeeOb),
          companionTeeHazard: List<int>.from(h.companionTeeHazard),
          companionSecondOb: List<int>.from(h.companionSecondOb),
          companionSecondHazard: List<int>.from(h.companionSecondHazard),
          nearestPlayerIndex: h.nearestPlayerIndex,
          nearestErasePlayerIndex: h.nearestErasePlayerIndex,
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
    _ojangConfig = widget.round != null 
        ? OjangConfig.fromMap(widget.round!.ojangConfig.toMap())
        : OjangConfig();
    
    // 타당 단가 초기값 세팅 (천단위 콤마 적용)
    _unitPriceCtrl.text = NumberFormat('#,###').format(_ojangConfig.unitPrice);
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
    WidgetsBinding.instance.removeObserver(this);
    _golfCourseCtrl.dispose();
    _frontCourseCtrl.dispose();
    _backCourseCtrl.dispose();
    _companionsCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 백그라운드로 가거나 비활성화될 때 자동 저장
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _saveRecord(isAutosave: true);
    }
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
  int get _totalPutt => _holes.fold(0, (sum, hole) => sum + (hole.putt == -99 ? 0 : hole.putt)); // 미입력은 0퍼트 취급 (반영 기준 일치)
  int get _qPoint {
    return RoundData(
      date: _selectedDate,
      teeUpTime: '',
      golfCourseName: '',
      frontCourseName: '',
      backCourseName: '',
      companions: [],
      totalScore: _overUnder,
      holes: _holes,
      createdAt: DateTime.now(),
    ).qPoint;
  }

  String get _overUnderStr {
    final ou = _overUnder;
    return ou > 0 ? '+$ou' : (ou < 0 ? '$ou' : 'E');
  }

  Future<void> _saveRecord({bool isAutosave = false}) async {
    // 자동 저장인 경우 밸리데이션 생략 (데이터 유실 방지가 우선)
    if (!isAutosave && !_formKey.currentState!.validate()) return;
    
    // 이미 저장 중이면 중복 실행 방지
    if (_isSaving && !isAutosave) return;
    
    // UI Rebuild(setState)가 일어나기 전에 화면의 텍스트 값을 안전하게 미리 캡처합니다.
    final capturedGolfCourse = _internalGolfCourseCtrl?.text.trim() ?? _golfCourseCtrl.text.trim();
    final capturedFrontCourse = (_internalFrontCourseCtrl?.text.trim() ?? _frontCourseCtrl.text.trim()).isNotEmpty 
        ? (_internalFrontCourseCtrl?.text.trim() ?? _frontCourseCtrl.text.trim()) : '전반';
    final capturedBackCourse = (_internalBackCourseCtrl?.text.trim() ?? _backCourseCtrl.text.trim()).isNotEmpty 
        ? (_internalBackCourseCtrl?.text.trim() ?? _backCourseCtrl.text.trim()) : '후반';

    if (!isAutosave) setState(() => _isSaving = true);
    
    try {
      final String teeUpTimeStr = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
      final List<String> companionsList = _companionsCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      String? docId = _currentDocId;
      if (docId == null) {
        docId = FirebaseFirestore.instance.collection('rounds').doc().id;
        _currentDocId = docId;
      }

      // 저장 전, 미입력(-99) 구역을 그대로 유지
      final List<HoleData> savingHoles = _holes.map((h) => HoleData(
        holeNumber: h.holeNumber,
        par: h.par,
        score: h.score,
        putt: h.putt,
        teeOb: h.teeOb,
        teeHazard: h.teeHazard,
        secondOb: h.secondOb,
        secondHazard: h.secondHazard,
        companionScores: List<int>.from(h.companionScores),
        companionPutts: List<int>.from(h.companionPutts),
        companionPenalties: List.from(h.companionPenalties),
        companionTeeOb: List<int>.from(h.companionTeeOb),
        companionTeeHazard: List<int>.from(h.companionTeeHazard),
        companionSecondOb: List<int>.from(h.companionSecondOb),
        companionSecondHazard: List<int>.from(h.companionSecondHazard),
        nearestPlayerIndex: h.nearestPlayerIndex,
        nearestErasePlayerIndex: h.nearestErasePlayerIndex,
      )).toList();

      // 입력된 홀 수 확인
      int enteredHolesCount = _holes.where((h) => h.score != -99).length;

      final roundData = RoundData(
        id: docId,
        date: _selectedDate,
        teeUpTime: teeUpTimeStr,
        golfCourseName: capturedGolfCourse,
        frontCourseName: capturedFrontCourse == '전반' && _internalFrontCourseCtrl?.text.trim().isEmpty == true ? '' : capturedFrontCourse,
        backCourseName: capturedBackCourse == '후반' && _internalBackCourseCtrl?.text.trim().isEmpty == true ? '' : capturedBackCourse,
        companions: companionsList,
        totalScore: savingHoles.where((h) => h.score != -99).fold(0, (sum, h) => sum + h.score), // 입력된 홀만 합산
        holes: savingHoles,
        createdAt: widget.round?.createdAt ?? DateTime.now(),
        userId: AuthService().currentUser?.uid,
        userName: AuthService().currentUser?.displayName,
        ojangConfig: _ojangConfig,
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
          // 이름으로 기존 골프장 문서 찾기 (ID가 이름과 다를 수 있음)
          final courseSnap = await FirebaseFirestore.instance
              .collection('courses')
              .where('name', isEqualTo: golfCourse)
              .limit(1)
              .get();

          DocumentReference courseDoc;
          DocumentSnapshot? existingDoc;

          if (courseSnap.docs.isNotEmpty) {
            courseDoc = courseSnap.docs.first.reference;
            existingDoc = courseSnap.docs.first;
          } else {
            // 없으면 이름 그대로 ID로 사용
            courseDoc = FirebaseFirestore.instance.collection('courses').doc(golfCourse);
          }
          
          final snap = existingDoc ?? await courseDoc.get().timeout(const Duration(seconds: 10), onTimeout: () => throw Exception('코스 조회 시간 초과 (10초)'));
          
          // 베스트 스코어 계산 및 업데이트 (18홀 모두 입력된 경우에만 수행)
          bool isCompleteRound = enteredHolesCount == 18;
          int? currentRoundBestGross;
          String? currentRoundBestScorer;

          if (isCompleteRound) {
            // 나의 스코어
            int myGross = _holes.fold(0, (sum, h) => sum + h.par) + savingHoles.fold(0, (sum, h) => sum + h.score);
            currentRoundBestGross = myGross;
            currentRoundBestScorer = roundData.userName ?? '나';

            // 동반자들 스코어
            for (int i = 0; i < companionsList.length; i++) {
              // 해당 동반자의 18홀 점수가 모두 입력되었는지 확인 (-99 제외)
              bool compComplete = savingHoles.every((h) => h.companionScores.length > i && h.companionScores[i] != -99);
              if (!compComplete) continue;

              int compScore = savingHoles.fold(0, (sum, h) => sum + (h.companionScores.length > i ? h.companionScores[i] : 0));
              int compGross = _holes.fold(0, (sum, h) => sum + h.par) + compScore;
              if (compGross < currentRoundBestGross!) {
                currentRoundBestGross = compGross;
                currentRoundBestScorer = companionsList[i];
              }
            }
          }

          if (snap.exists) {
            final data = snap.data() as Map<String, dynamic>?;
            // 타입 안정성을 위해 int.tryParse 사용
            int? existingBest = data?['bestScore'] != null ? int.tryParse(data!['bestScore'].toString()) : null;
            
            // 18홀이 다 입력되었고, 기존 베스트보다 낮거나(더 잘침), 기존 베스트가 없거나 비정상적이면 업데이트
            bool shouldUpdateBest = isCompleteRound && (existingBest == null || existingBest < 40 || currentRoundBestGross! <= existingBest);

            Map<String, dynamic> mergedCourses = {};
            try {
              if (data?['courses'] is Map) {
                mergedCourses = Map<String, dynamic>.from(data?['courses'] as Map);
              }
            } catch (_) {}
            
            mergedCourses[frontCourse] = frontPars;
            mergedCourses[backCourse] = backPars;
            
            final Map<String, dynamic> finalUpdates = {
              'courses': mergedCourses,
              'name': golfCourse, // 이름 필드도 확실히 유지
            };
            
            if (shouldUpdateBest) {
              finalUpdates['bestScore'] = currentRoundBestGross;
              finalUpdates['bestScorer'] = currentRoundBestScorer;
            }

            await courseDoc.update(finalUpdates).timeout(const Duration(seconds: 10), onTimeout: () => throw Exception('코스 업데이트 시간 초과 (10초)'));
          } else {
            // 없는 골프장이라면 새로 생성
            final Map<String, dynamic> newCourseData = {
              'name': golfCourse,
              'courses': courseUpdates,
              'userId': AuthService().currentUser?.uid,
            };
            
            if (isCompleteRound) {
              newCourseData['bestScore'] = currentRoundBestGross;
              newCourseData['bestScorer'] = currentRoundBestScorer;
            }
            
            await courseDoc.set(newCourseData).timeout(const Duration(seconds: 10), onTimeout: () => throw Exception('코스 생성 시간 초과 (10초)'));
          }
        }
      }

      if (mounted && !isAutosave) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(enteredHolesCount < 18 
              ? '$enteredHolesCount홀의 기록이 중간 저장되었습니다. (작업 계속 가능)' 
              : '18홀 기록이 모두 저장되었습니다.'),
            backgroundColor: enteredHolesCount < 18 ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        // Navigator.pop(context); // 더 이상 저장 후 자동으로 나가지 않음
      }
      
    } catch (e, stack) {
      if (mounted && !isAutosave) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('저장 오류'),
            content: SingleChildScrollView(child: Text('상태를 저장하던 중 오류가 발생했습니다: $e')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인'))
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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
    final List<String> compNames = _companionsCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.round != null ? '기록 수정 (v1.5.8)' : '기록 추가 (v1.5.8)'),
        actions: [
          if (widget.round != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.black26),
              tooltip: '라운드 삭제',
              onPressed: () => _confirmDelete(),
            ),
          TextButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('입력 종료'),
                  content: const Text('입력 중인 화면을 나갈까요?\n저장하지 않은 데이터가 있다면 중간 저장을 눌러주세요.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('계속 입력')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      child: const Text('나가기'),
                    )
                  ],
                ),
              );
            },
            child: const Text('나가기', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
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
                              onChanged: (v) => setState(() {}), // 이름 변경 시 홀별 UI 갱신을 위함
                              decoration: const InputDecoration(
                                labelText: '동반자 (쉼표로 구분)', 
                                border: OutlineInputBorder(),
                                hintText: '예: 김철수, 이영희, 박지민 (최대 3명)',
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF27AE60).withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF27AE60).withOpacity(0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('오장마스터 활성화', style: TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: const Text('타당 정산 및 실시간 핸디 반영'),
                                    value: _ojangConfig.enabled,
                                    onChanged: (v) => setState(() => _ojangConfig.enabled = v),
                                    activeColor: const Color(0xFFD4AF37),
                                  ),
                                  if (_ojangConfig.enabled) ...[
                                    const Divider(),
                                    const Text('내기 룰 선택', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    const SizedBox(height: 8),
                                    SegmentedButton<int>(
                                      segments: const [
                                        ButtonSegment(value: 0, label: Text('오장(후핸디)', style: TextStyle(fontSize: 12))),
                                        ButtonSegment(value: 1, label: Text('오목회(고수2배)', style: TextStyle(fontSize: 12))),
                                      ],
                                      selected: {_ojangConfig.ruleType},
                                      onSelectionChanged: (Set<int> newSelection) {
                                        setState(() => _ojangConfig.ruleType = newSelection.first);
                                      },
                                      style: SegmentedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        selectedBackgroundColor: const Color(0xFFD4AF37).withOpacity(0.2),
                                        selectedForegroundColor: const Color(0xFFB8860B),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        const Text('타당 단가:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: 100, // 최대 10,000원에 맞게 너비 제한
                                          child: TextFormField(
                                            controller: _unitPriceCtrl,
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF27AE60)),
                                            decoration: const InputDecoration(
                                              suffixText: '원',
                                              isDense: true,
                                              contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                              border: UnderlineInputBorder(),
                                            ),
                                            onChanged: (v) {
                                              // 천단위 콤마 처리
                                              String raw = v.replaceAll(',', '');
                                              if (raw.isEmpty) raw = '0';
                                              int? val = int.tryParse(raw);
                                              if (val != null) {
                                                _ojangConfig.unitPrice = val;
                                                String formatted = NumberFormat('#,###').format(val);
                                                if (formatted != v) {
                                                  _unitPriceCtrl.value = TextEditingValue(
                                                    text: formatted,
                                                    selection: TextSelection.collapsed(offset: formatted.length),
                                                  );
                                                }
                                              }
                                              setState(() {}); // 정산 요약 갱신을 위해 호출
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
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
                              GestureDetector(
                                onTap: () {
                                  final tempRound = RoundData(
                                    date: _selectedDate,
                                    teeUpTime: '',
                                    golfCourseName: _golfCourseCtrl.text,
                                    frontCourseName: _frontCourseCtrl.text,
                                    backCourseName: _backCourseCtrl.text,
                                    companions: [],
                                    totalScore: _overUnder,
                                    holes: _holes,
                                    createdAt: DateTime.now(),
                                  );
                                  final List<String> compNames = _companionsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                                  final allNames = [AuthService().currentUser?.displayName ?? '나', ...compNames];
                                  final breakdown = tempRound.getQPointBreakdown(0);
                                  _showQPointBreakdown(context, allNames[0], breakdown);
                                },
                                child: Text(
                                  '$_totalGross($_overUnderStr), $_totalPutt putt, Q ${_qPoint}pt', 
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 18, 
                                    color: _overUnder < 0 ? Colors.red : (_overUnder == 0 ? Colors.black87 : Colors.blue)
                                  ),
                                ),
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
                          labelColor: const Color(0xFF27AE60),
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: const Color(0xFF27AE60),
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
              // 오장마스터 총 정산 요약
              if (_ojangConfig.enabled)
                _buildTotalSettlementSummary(compNames),
              // 하단: 저장 버튼 
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                width: double.infinity,
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isSaving ? null : _saveRecord,
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(widget.round != null ? '기록 수정' : '기록 저장', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHoleList(int start, int end) {
    // 동반자 이름 리스트 파싱
    final List<String> compNames = _companionsCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: end - start,
      itemBuilder: (context, index) {
        final hole = _holes[start + index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: hole.score != -99 ? BorderSide(color: const Color(0xFF27AE60).withOpacity(0.3), width: 1) : BorderSide.none,
          ),
          child: ExpansionTile(
            title: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text('${hole.holeNumber}', 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF27AE60))),
                ),
                Expanded(
                  child: Text(
                    _getScoreLabel(hole.score, hole.par),
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      color: _getScoreColor(hole.score)
                    ),
                  ),
                ),
                if (_ojangConfig.enabled && hole.score != -99)
                  _buildHoleSettlementChip(hole, compNames),
              ],
            ),
            childrenPadding: const EdgeInsets.all(12),
            initiallyExpanded: false, // 필요시 true로 변경 가능
            children: [
              // 1. 기본 홀 설정 (Par)
              Row(
                children: [
                   const Text('Hole Par', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                   const SizedBox(width: 12),
                   DropdownButton<int>(
                    value: hole.par,
                    items: [3, 4, 5].map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
                    onChanged: (val) {
                      if(val != null) setState(() => hole.par = val);
                    },
                   ),
                ],
              ),
              const Divider(),
              // 2. 플레이어별 점수 입력 헤더
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    Expanded(flex: 12, child: Text('플레이어', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold))),
                    Expanded(flex: 23, child: Center(child: Text('스코어', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)))),
                    Expanded(flex: 23, child: Center(child: Text('퍼트', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)))),
                    Expanded(flex: 23, child: Center(child: Text('벌타', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)))),
                  ],
                ),
              ),
              const Divider(height: 8),
              // 사용자 본인
              _buildPlayerScoreRow(
                name: AuthService().currentUser?.displayName ?? '나', 
                score: hole.score, 
                putt: hole.putt, 
                penalty: hole.getPlayerPenaltyStrokes(0),
                onScoreChanged: (v) => setState(() => hole.score = v),
                onPuttChanged: (v) => setState(() => hole.putt = v),
                onPenaltyChanged: (v) {}, // Detailed dialog handles this
                onPenaltyTap: () => _showPenaltyDialog(context, hole, playerIndex: 0),
                isUser: true
              ),
              // 동반자들
              if (_ojangConfig.enabled) ...[
                for (int i = 0; i < compNames.length; i++)
                  _buildPlayerScoreRow(
                    name: compNames[i], 
                    score: hole.companionScores[i],
                    putt: hole.companionPutts[i],
                    penalty: hole.getPlayerPenaltyStrokes(i + 1),
                    onScoreChanged: (v) => setState(() => hole.companionScores[i] = v),
                    onPuttChanged: (v) => setState(() => hole.companionPutts[i] = v),
                    onPenaltyChanged: (v) {}, // Detailed dialog handles this
                    onPenaltyTap: () => _showPenaltyDialog(context, hole, playerIndex: i + 1),
                  ),
                
                const Divider(),
                // 3. 내기 이벤트 (니어리스트 - 파3 전용)
                if (hole.par == 3) _buildBettingEvents(hole, compNames),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayerScoreRow({
    required String name,
    required int score,
    required int putt,
    required int penalty,
    required ValueChanged<int> onScoreChanged,
    required ValueChanged<int> onPuttChanged,
    required ValueChanged<int> onPenaltyChanged,
    required VoidCallback onPenaltyTap,
    bool isUser = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12), // 상하폭 추가 확대
      child: Row(
        children: [
          Expanded(
            flex: 12, // 이름 영역 최소화
            child: Text(
              name, 
              style: TextStyle(
                fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
                overflow: TextOverflow.ellipsis
              )
            )
          ),
          // 스코어
          Expanded(flex: 23, child: _buildMiniCounter(score, onScoreChanged, isScore: true)),
          // 퍼트
          Expanded(flex: 23, child: _buildMiniCounter(putt, onPuttChanged, isPutt: true, defaultValue: 2)),
          // 벌타
          Expanded(
            flex: 23, 
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: onPenaltyTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        penalty == 0 ? '-' : '$penalty',
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 16, 
                          color: penalty > 0 ? Colors.redAccent : Colors.black87
                        ),
                      ),
                      if (penalty > 0)
                        Text(
                          '상세',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCounter(int value, ValueChanged<int> onChanged, {bool isScore = false, bool isPenalty = false, bool isPutt = false, int defaultValue = 0}) {
    String display = (value == -99) ? '-' : (isScore && value > 0 ? '+$value' : '$value');
    Color textColor = Colors.black87;
    if (isScore && value != -99) {
      if (value < 0) textColor = const Color(0xFF27AE60);
      else if (value > 0) textColor = Colors.redAccent;
    }
    if (isPenalty && value > 0) textColor = Colors.redAccent;

    Color btnColor = Colors.grey.shade100;
    if (isScore) btnColor = Colors.green.shade100;
    else if (isPutt) btnColor = Colors.blue.shade100;
    else if (isPenalty) btnColor = Colors.orange.shade100;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            if (value == -99) onChanged(defaultValue);
            else if (isPenalty) { if (value > 0) onChanged(value - 1); }
            else onChanged(value - 1);
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(shape: BoxShape.circle, color: btnColor),
            child: const Icon(Icons.remove, size: 20, color: Colors.black54),
          ),
        ),
        SizedBox(
          width: 30,
          child: Text(
            display, 
            textAlign: TextAlign.center, 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)
          )
        ),
        GestureDetector(
          onTap: () {
            if (value == -99) onChanged(defaultValue);
            else onChanged(value + 1);
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(shape: BoxShape.circle, color: btnColor),
            child: const Icon(Icons.add, size: 20, color: Colors.black54),
          ),
        ),
      ],
    );
  }

  Widget _buildCounterSmall(int value, ValueChanged<int> onChanged, {bool isOverUnder = false}) {
    String display = (value == -99) ? '-' : (isOverUnder && value > 0 ? '+$value' : '$value');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(icon: const Icon(Icons.remove_circle_outline, size: 24, color: Colors.redAccent), onPressed: () {
          if (value == -99) onChanged(0);
          else onChanged(value - 1);
        }),
        SizedBox(width: 30, child: Text(display, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
        IconButton(icon: const Icon(Icons.add_circle_outline, size: 24, color: Color(0xFFD4AF37)), onPressed: () {
          if (value == -99) onChanged(0);
          else onChanged(value + 1);
        }),
      ],
    );
  }

  Widget _buildBettingEvents(HoleData hole, List<String> compNames) {
    List<String> allPlayers = [AuthService().currentUser?.displayName ?? '나', ...compNames];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('🎯 니어리스트', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF667C7A))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: List.generate(allPlayers.length, (i) {
            bool isSelected = hole.nearestPlayerIndex == i;
            return ChoiceChip(
              label: Text(allPlayers[i]),
              selected: isSelected,
              onSelected: (v) => setState(() => hole.nearestPlayerIndex = v ? i : -1),
              selectedColor: const Color(0xFFD4AF37).withOpacity(0.3),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildHoleSettlementChip(HoleData hole, List<String> compNames) {
    if (hole.companionScores.any((s) => s == -99)) return const SizedBox.shrink();
    
    final playerNames = [AuthService().currentUser?.displayName ?? '나', ...compNames];
    final result = BettingService.calculateHole(hole, _ojangConfig, 1 + compNames.length, playerNames);
    final myGain = result.netGains[0];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: myGain >= 0 ? const Color(0xFF27AE60).withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        myGain >= 0 ? '+${NumberFormat('#,###').format(myGain)}' : NumberFormat('#,###').format(myGain),
        style: TextStyle(
          fontSize: 12, 
          fontWeight: FontWeight.bold, 
          color: myGain >= 0 ? const Color(0xFF27AE60) : Colors.redAccent
        ),
      ),
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
              child: const Icon(Icons.add_circle, color: Color(0xFFD4AF37), size: 28),
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
              child: const Icon(Icons.add_circle, color: Color(0xFFD4AF37), size: 36),
            ),
          ],
        ),
      ],
    );
  }

  void _showPenaltyDialog(BuildContext context, HoleData hole, {int playerIndex = 0}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final int teeOb = playerIndex == 0 ? hole.teeOb : hole.companionTeeOb[playerIndex - 1];
            final int teeHazard = playerIndex == 0 ? hole.teeHazard : hole.companionTeeHazard[playerIndex - 1];
            final int secondOb = playerIndex == 0 ? hole.secondOb : hole.companionSecondOb[playerIndex - 1];
            final int secondHazard = playerIndex == 0 ? hole.secondHazard : hole.companionSecondHazard[playerIndex - 1];

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 32, 
                top: 24, left: 24, right: 24
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40, height: 4, 
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 20),
                  Text('${hole.holeNumber}번 홀 패널티', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 32),
                  _buildDetailedPenaltyRow('티샷', [
                    _buildPenaltyItem('O.B', teeOb, (v) {
                      setState(() {
                        if (playerIndex == 0) hole.teeOb = v;
                        else hole.companionTeeOb[playerIndex - 1] = v;
                      });
                      setModalState(() {});
                    }),
                    _buildPenaltyItem('해저드', teeHazard, (v) {
                      setState(() {
                        if (playerIndex == 0) hole.teeHazard = v;
                        else hole.companionTeeHazard[playerIndex - 1] = v;
                      });
                      setModalState(() {});
                    }),
                  ]),
                  const Divider(height: 48),
                  _buildDetailedPenaltyRow('세컨샷', [
                    _buildPenaltyItem('O.B', secondOb, (v) {
                      setState(() {
                        if (playerIndex == 0) hole.secondOb = v;
                        else hole.companionSecondOb[playerIndex - 1] = v;
                      });
                      setModalState(() {});
                    }),
                    _buildPenaltyItem('해저드', secondHazard, (v) {
                      setState(() {
                        if (playerIndex == 0) hole.secondHazard = v;
                        else hole.companionSecondHazard[playerIndex - 1] = v;
                      });
                      setModalState(() {});
                    }),
                  ]),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: const Color(0xFF27AE60),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('입력 완료', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildDetailedPenaltyRow(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: items,
        ),
      ],
    );
  }

  Widget _buildPenaltyItem(String label, int value, ValueChanged<int> onChanged) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRoundIconBtn(Icons.remove, () => onChanged(value > 0 ? value - 1 : 0)),
            SizedBox(
              width: 36,
              child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            _buildRoundIconBtn(Icons.add, () => onChanged(value + 1)),
          ],
        ),
      ],
    );
  }

  Widget _buildRoundIconBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(icon, size: 18, color: Colors.black87),
      ),
    );
  }

  Widget _buildScorecardTab() {
    final compNames = _companionsCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    List<String> players = ['전체', AuthService().currentUser?.displayName ?? '나'];
    if (_ojangConfig.enabled) players.addAll(compNames);
    
    // Ensure index is within bounds
    if (_selectedScorecardPlayerIndex >= players.length) {
      _selectedScorecardPlayerIndex = players.length - 1;
    }
    
    // 동반자가 없으면 '전체' 탭을 스킵하고 무조건 '나'를 보여주도록 강제
    if (compNames.isEmpty && _selectedScorecardPlayerIndex == 0) {
      _selectedScorecardPlayerIndex = 1;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 다운로드 버튼 영역
          Builder(
                builder: (context) {
                  // 18홀 모두 입력되었는지 확인 (score가 -99가 아닌지)
                  final bool isAllHolesEntered = _holes.every((h) => h.score != -99);
                  
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isAllHolesEntered && _selectedScorecardPlayerIndex == 0) ...[
                          // 전체 탭 & 18홀 완료 시 -> 일괄 다운로드 버튼
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF27AE60),
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: _isDownloadingScorecard ? null : () async {
                              setState(() => _isDownloadingScorecard = true);
                              
                              try {
                                // 전체 탭부터 개인 탭까지 순차적으로 렌더링 후 다운로드
                                for (int i = 0; i < players.length; i++) {
                                  setState(() {
                                    _selectedScorecardPlayerIndex = i;
                                  });
                                  // 화면 렌더링 대기
                                  await Future.delayed(const Duration(milliseconds: 400));
                                  
                                  final playerName = players[i];
                                  final dateStr = DateFormat('yyyyMMdd').format(_selectedDate);
                                  final filename = '스코어카드_${_golfCourseCtrl.text.trim()}_${playerName}_$dateStr.png';
                                  
                                  await DownloadService.captureAndDownload(
                                    repaintKey: _scorecardRepaintKey,
                                    filename: filename,
                                    pixelRatio: 2.5,
                                    context: context,
                                  );
                                  
                                  // 브라우저 다중 다운로드 차단 방지를 위한 약간의 대기 시간
                                  await Future.delayed(const Duration(milliseconds: 400));
                                }
                                
                                // 다시 전체 탭으로 복귀
                                if (mounted) {
                                  setState(() {
                                    _selectedScorecardPlayerIndex = 0;
                                  });
                                }
                                
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('모든 스코어카드 다운로드가 시작되었습니다.\n(브라우저의 다중 다운로드 허용이 필요할 수 있습니다)')),
                                );
                              } finally {
                                if (mounted) setState(() => _isDownloadingScorecard = false);
                              }
                            },
                            icon: _isDownloadingScorecard 
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.download_for_offline, size: 18),
                            label: Text('전체 일괄 저장 (${players.length}장)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ] else if (_selectedScorecardPlayerIndex > 0) ...[
                          // 개인 탭 선택 시 -> 단일 다운로드 버튼
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF27AE60),
                              elevation: 1,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: const BorderSide(color: Color(0xFF27AE60), width: 1),
                              ),
                            ),
                            onPressed: _isDownloadingScorecard ? null : () async {
                              setState(() => _isDownloadingScorecard = true);
                              final playerName = players[_selectedScorecardPlayerIndex];
                              final dateStr = DateFormat('yyyyMMdd').format(_selectedDate);
                              final filename = '스코어카드_${_golfCourseCtrl.text.trim()}_${playerName}_$dateStr.png';
                              
                              await DownloadService.captureAndDownload(
                                repaintKey: _scorecardRepaintKey,
                                filename: filename,
                                pixelRatio: 2.5,
                                context: context,
                              );
                              if (mounted) setState(() => _isDownloadingScorecard = false);
                            },
                            icon: _isDownloadingScorecard 
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.download, size: 18),
                            label: const Text('현재 화면 저장', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ],
                      ],
                    ),
                  );
                }
              ),
              // 여기서부터 캡처
              RepaintBoundary(
                key: _scorecardRepaintKey,
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 선수 선택 칩
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                    child: Row(
                      children: players.asMap().entries.where((e) {
                // 동반자가 없으면 '전체' 탭 숨김
                if (compNames.isEmpty && e.key == 0) return false;
                return true;
              }).map((e) {
                final idx = e.key;
                final name = e.value;
                final isSelected = _selectedScorecardPlayerIndex == idx;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: e.key == players.length - 1 ? 0 : 4.0),
                    child: ChoiceChip(
                      label: Center(child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                      selected: isSelected,
                      showCheckmark: false,
                      onSelected: (bool selected) {
                        if (selected) {
                          setState(() {
                            _selectedScorecardPlayerIndex = idx;
                          });
                        }
                      },
                      selectedColor: const Color(0xFF27AE60).withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: isSelected ? const Color(0xFF27AE60) : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                      ),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _frontCourseCtrl,
            builder: (context, value, child) {
              final text = value.text.trim();
              return Padding(
                padding: const EdgeInsets.only(left: 8.0, bottom: 8.0, right: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(text.isNotEmpty ? '$text 코스' : '전반 코스', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (_selectedScorecardPlayerIndex > 0)
                      _buildPlayerTotalScoreSummary(_selectedScorecardPlayerIndex),
                  ],
                ),
              );
            },
          ),
          _buildPersonalScorecardGrid(_holes, 0, _selectedScorecardPlayerIndex),
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
          _buildPersonalScorecardGrid(_holes, 9, _selectedScorecardPlayerIndex),
          _buildScoreLegend(),
          _buildPersonalRoundStatistics(_holes, _selectedScorecardPlayerIndex),
          const SizedBox(height: 80), // 여백 확보
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildPersonalRoundStatistics(List<HoleData> holes, int playerIndex) {
    if (holes.isEmpty || playerIndex == 0) return const SizedBox();
    
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
      int score = 0;
      int putt = 0;
      int penalty = 0;
      
      if (playerIndex == 1) {
        score = hole.score == -99 ? 0 : hole.score;
        putt = hole.putt == -99 ? 0 : hole.putt;
        penalty = hole.penaltyStrokes;
        teeObCount += hole.teeOb;
        secondObCount += hole.secondOb;
        teeHazardCount += hole.teeHazard;
        secondHazardCount += hole.secondHazard;
      } else {
        int compIdx = playerIndex - 2;
        score = (hole.companionScores.length > compIdx && hole.companionScores[compIdx] != -99) ? hole.companionScores[compIdx] : 0;
        putt = (hole.companionPutts.length > compIdx && hole.companionPutts[compIdx] != -99) ? hole.companionPutts[compIdx] : 0;
        penalty = hole.getPlayerPenaltyStrokes(compIdx + 1);
        teeObCount += hole.companionTeeOb[compIdx];
        secondObCount += hole.companionSecondOb[compIdx];
        teeHazardCount += hole.companionTeeHazard[compIdx];
        secondHazardCount += hole.companionSecondHazard[compIdx];
      }
      
      totalPutts += putt;
      totalPenaltyStrokes += penalty;
      
      if (putt == 1) onePuttCount++;
      else if (putt == 2) twoPuttCount++;
      else if (putt >= 3) threePlusPuttCount++;

      bool isGir = (score - putt) <= -2;
      if (isGir) {
        girHits++;
        girPutts += putt;
      } else {
        scramblingChances++;
        nonGirPutts += putt;
        if (score <= 0) scramblingSuccesses++;
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
            const Text('⛳ 개인 라운드 통계', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
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
          ],
        ),
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

  Widget _buildPersonalScorecardGrid(List<HoleData> holes, int startIndex, int playerIndex) {
    if (holes.length < startIndex + 9) return const SizedBox(); 

    final subHoles = holes.sublist(startIndex, startIndex + 9);
    final totalPar = subHoles.fold(0, (total, h) => total + h.par);
    
    if (playerIndex == 0) {
      final compNames = _companionsCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final allNames = [AuthService().currentUser?.displayName ?? '나'];
      if (_ojangConfig.enabled) allNames.addAll(compNames);
      
      final rows = <TableRow>[];
      rows.add(
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: [
            _buildGridCell('HOLE', isHeader: true),
            for (int i = 1; i <= 9; i++) _buildGridCell('${startIndex + i}', isHeader: true),
            _buildGridCell('TOTAL', isHeader: true),
          ],
        ),
      );
      rows.add(
        TableRow(
          children: [
            _buildGridCell('PAR', isHeader: true),
            for (var h in subHoles) _buildGridCell('${h.par}'),
            _buildGridCell('$totalPar', isBold: true),
          ],
        ),
      );
      
      for (int i = 0; i < allNames.length; i++) {
        int tempTotal = 0;
        for (var h in subHoles) tempTotal += _getPlayerScore(h, i + 1);
        
        rows.add(
          TableRow(
            children: [
              _buildGridCell(allNames[i], isHeader: true),
              for (var h in subHoles) _buildGridScoreCell(h, i + 1),
              _buildGridScoreCell(null, i + 1, customScore: tempTotal, isBold: true, isTotal: true, totalPar: totalPar),
            ],
          )
        );
      }
      
      return Table(
        border: TableBorder.all(color: Colors.grey.shade300, width: 1),
        columnWidths: const {
          0: FlexColumnWidth(1.8),
          10: FlexColumnWidth(1.6),
        },
        defaultColumnWidth: const FlexColumnWidth(1.0),
        children: rows,
      );
    }
    
    int totalScore = 0;
    int totalPutt = 0;
    
    for (var h in subHoles) {
      if (playerIndex == 1) {
        totalScore += (h.score == -99 ? 0 : h.score);
        totalPutt += (h.putt == -99 ? 0 : h.putt);
      } else {
        int compIdx = playerIndex - 2;
        totalScore += (h.companionScores.length > compIdx && h.companionScores[compIdx] != -99 ? h.companionScores[compIdx] : 0);
        totalPutt += (h.companionPutts.length > compIdx && h.companionPutts[compIdx] != -99 ? h.companionPutts[compIdx] : 0);
      }
    }

    return Table(
      border: TableBorder.all(color: Colors.grey.shade300, width: 1),
      columnWidths: const {
        0: FlexColumnWidth(1.8),
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
            for (var h in subHoles) _buildGridScoreCell(h, playerIndex),
            _buildGridScoreCell(null, playerIndex, customScore: totalScore, isBold: true, isTotal: true, totalPar: totalPar),
          ],
        ),
        TableRow(
          children: [
            _buildGridCell('PUTT', isHeader: true),
            for (var h in subHoles) _buildGridCell('${_getPlayerPutt(h, playerIndex)}'),
            _buildGridCell('$totalPutt', isBold: true),
          ],
        ),
      ],
    );
  }

  Widget _buildPlayerTotalScoreSummary(int playerIndex) {
    if (playerIndex == 0) return const SizedBox();
    
    int tScore = 0;
    int tPutt = 0;
    
    for (var h in _holes) {
      if (playerIndex == 1) {
        tScore += (h.score == -99 ? 0 : h.score);
        tPutt += (h.putt == -99 ? 0 : h.putt);
      } else {
        int compIdx = playerIndex - 2;
        tScore += (h.companionScores.length > compIdx && h.companionScores[compIdx] != -99 ? h.companionScores[compIdx] : 0);
        tPutt += (h.companionPutts.length > compIdx && h.companionPutts[compIdx] != -99 ? h.companionPutts[compIdx] : 0);
      }
    }
    
    int gross = _totalPar + tScore;
    String overUnderStr = tScore == 0 ? 'E' : (tScore > 0 ? '+$tScore' : '$tScore');
    Color tColor = tScore < 0 ? Colors.red : (tScore == 0 ? Colors.black87 : Colors.blue);
    
    // Q-point 계산
    final List<String> compNames = _companionsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final tempRound = RoundData(
      date: _selectedDate,
      teeUpTime: '',
      golfCourseName: _golfCourseCtrl.text,
      frontCourseName: _frontCourseCtrl.text,
      backCourseName: _backCourseCtrl.text,
      companions: compNames,
      totalScore: 0,
      holes: _holes,
      createdAt: DateTime.now(),
    );
    int qp = tempRound.getQPointBreakdown(playerIndex - 1).total;

    return InkWell(
      onTap: () {
        final List<String> compNames = _companionsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        final List<String> localAllNames = [AuthService().currentUser?.displayName ?? '나', ...compNames];
        _showQPointBreakdown(context, localAllNames[playerIndex - 1], tempRound.getQPointBreakdown(playerIndex - 1));
      },
      child: Text(
        '$gross($overUnderStr), $tPutt putt, Q ${qp}pt', 
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: tColor),
      ),
    );
  }
  
  int _getPlayerScore(HoleData h, int playerIndex) {
    if (playerIndex == 1) return h.score == -99 ? 0 : h.score;
    int cIdx = playerIndex - 2;
    return (h.companionScores.length > cIdx && h.companionScores[cIdx] != -99) ? h.companionScores[cIdx] : 0;
  }

  int _getPlayerPutt(HoleData h, int playerIndex) {
    if (playerIndex == 1) return h.putt == -99 ? 0 : h.putt;
    int cIdx = playerIndex - 2;
    return (h.companionPutts.length > cIdx && h.companionPutts[cIdx] != -99) ? h.companionPutts[cIdx] : 0;
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

  Widget _buildGridScoreCell(HoleData? h, int playerIndex, {int? customScore, bool isBold = false, bool isTotal = false, int? totalPar}) {
    int score = customScore ?? (h != null ? _getPlayerScore(h, playerIndex) : 0);
    String text = score == 0 ? '0' : (score > 0 ? '+$score' : '$score');
    
    if (isTotal && totalPar != null) {
      text = '${totalPar + score}';
    }

    Color textColor = Colors.black87;
    Color bgColor = Colors.transparent;
    
    if (isTotal) {
      bgColor = Colors.transparent;
    } else {
      if (score <= -2) {
        bgColor = Colors.red;
        textColor = Colors.white;
      } else if (score == -1) {
        bgColor = Colors.red.shade200;
        textColor = Colors.black87;
      } else if (score == 1) {
        bgColor = Colors.cyan.shade200;
        textColor = Colors.black87;
      } else if (score >= 2) {
        bgColor = Colors.blue;
        textColor = Colors.white;
      }
    }

    // 니어리스트 표시 (파3에서만)
    Widget? nearestMarker;
    if (h != null && h.par == 3 && h.nearestPlayerIndex == (playerIndex - 1)) {
      if (score <= 0) {
        nearestMarker = const Positioned(
          top: 0,
          right: 2,
          child: Text('★', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
        );
      } else {
        nearestMarker = const Positioned(
          top: 0,
          right: 2,
          child: Text('X', style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold)),
        );
      }
    }

    return Container(
      color: bgColor,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            child: Text(
              text,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.bold,
                fontSize: 12,
                color: textColor,
              ),
            ),
          ),
          if (nearestMarker != null) nearestMarker,
        ],
      ),
    );
  }

  Widget _buildScoreLegend() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem('이글', Colors.red),
          _buildLegendItem('버디', Colors.red.shade200),
          _buildLegendItem('파', Colors.transparent, hasBorder: true),
          _buildLegendItem('보기', Colors.cyan.shade200),
          _buildLegendItem('더블보기 이상', Colors.blue),
          const SizedBox(width: 8),
          const Text('★', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
          const Text(' 니어 성공', style: TextStyle(fontSize: 11, color: Colors.black87)),
          const SizedBox(width: 8),
          const Text('X', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
          const Text(' 니어 실패', style: TextStyle(fontSize: 11, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, {bool hasBorder = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color, 
              shape: BoxShape.circle,
              border: hasBorder ? Border.all(color: Colors.grey.shade400) : null,
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildTotalSettlementSummary(List<String> compNames) {
    if (widget.round == null && _holes.every((h) => h.score == -99)) return const SizedBox.shrink();
    
    // 임시 RoundData 생성하여 총액 계산
    final tempRound = RoundData(
      date: _selectedDate,
      teeUpTime: '',
      golfCourseName: '',
      frontCourseName: '',
      backCourseName: '',
      companions: compNames,
      totalScore: 0,
      holes: _holes,
      createdAt: DateTime.now(),
      ojangConfig: _ojangConfig,
    );
    
    final totals = BettingService.calculateTotal(tempRound);
    final List<String> allNames = [AuthService().currentUser?.displayName ?? '나', ...compNames];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8), // 부드러운 블루 그레이 바탕
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08), 
            blurRadius: 10, 
            offset: const Offset(0, -4)
          )
        ],
        border: const Border(top: BorderSide(color: Color(0xFFD1D9E6), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calculate, color: Color(0xFF2C3E50), size: 18),
              const SizedBox(width: 8),
              const Text(
                '오장마스터 정산 현황', 
                style: TextStyle(
                  color: Color(0xFF2C3E50), 
                  fontWeight: FontWeight.bold, 
                  fontSize: 15,
                  letterSpacing: -0.5
                )
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF3498DB),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(totals.length, (i) {
              final isPositive = totals[i] >= 0;
              final amountColor = isPositive ? const Color(0xFF27AE60) : const Color(0xFFE74C3C);
              final formattedAmount = NumberFormat('#,###').format(totals[i].abs());
              
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i == totals.length - 1 ? 0 : 8),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                    border: Border.all(
                      color: isPositive ? const Color(0xFF27AE60).withOpacity(0.3) : const Color(0xFFE74C3C).withOpacity(0.3),
                      width: 1.5
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        allNames[i], 
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF5D6D7E), fontSize: 11, fontWeight: FontWeight.w600)
                      ),
                      const SizedBox(height: 4),
                      Text(
                        totals[i] == 0 ? '0' : (isPositive ? '+$formattedAmount' : '-$formattedAmount'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: amountColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
  String _getScoreLabel(int score, int par) {
    if (score == -99) return '미입력';
    if (score <= -3) return 'Albatross';
    if (score == -2) return 'Eagle';
    if (score == -1) return 'Birdie';
    if (score == 0) return 'Par';
    if (score >= par) return 'Double Par';
    if (score == 1) return 'Bogey';
    if (score == 2) return 'Double Bogey';
    if (score == 3) return 'Triple Bogey';
    if (score == 4) return 'Quadruple Bogey';
    return (score > 0) ? '+$score' : '$score';
  }

  Color _getScoreColor(int score) {
    if (score == -99) return Colors.grey;
    if (score < 0) return Colors.red;
    return Colors.black87;
  }


  void _showQPointBreakdown(BuildContext context, String playerName, QPointBreakdown breakdown) {
    showQPointBreakdownDialog(
      context,
      courseName: _golfCourseCtrl.text.isEmpty ? '신규코스' : _golfCourseCtrl.text,
      playerName: playerName,
      breakdown: breakdown,
    );
  }

  Widget _buildConfigCheck(String label, bool value, ValueChanged<bool?> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          onChanged: (v) => setState(() => onChanged(v)),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 8),
      ],
    );
  }
}
