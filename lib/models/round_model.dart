import 'package:cloud_firestore/cloud_firestore.dart';

class OjangConfig {
  bool enabled;
  int unitPrice;
  bool baepanBirdie; // 버디 이상 배판
  bool baepanThreeSame; // 3명 동타 배판
  bool baepanTripleP45; // 파4,5 트리플 이상 배판
  bool baepanDoubleP3; // 파3 더블 이상 배판
  int nearestRule; // 0:안함, 1:기본, 2:지우기/실패포함

  OjangConfig({
    this.enabled = false,
    this.unitPrice = 5000,
    this.baepanBirdie = true,
    this.baepanThreeSame = true,
    this.baepanTripleP45 = true,
    this.baepanDoubleP3 = true,
    this.nearestRule = 2,
  });

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'unitPrice': unitPrice,
      'baepanBirdie': baepanBirdie,
      'baepanThreeSame': baepanThreeSame,
      'baepanTripleP45': baepanTripleP45,
      'baepanDoubleP3': baepanDoubleP3,
      'nearestRule': nearestRule,
    };
  }

  factory OjangConfig.fromMap(Map<String, dynamic> map) {
    return OjangConfig(
      enabled: map['enabled'] ?? false,
      unitPrice: map['unitPrice'] ?? 5000,
      baepanBirdie: map['baepanBirdie'] ?? true,
      baepanThreeSame: map['baepanThreeSame'] ?? true,
      baepanTripleP45: map['baepanTripleP45'] ?? true,
      baepanDoubleP3: map['baepanDoubleP3'] ?? true,
      nearestRule: map['nearestRule'] ?? 2,
    );
  }
}

class HoleData {
  final int holeNumber;
  int par;
  int score; // 유저 본인 오버/언더 (0=Par)
  int putt;
  int teeOb;
  int teeHazard;
  int secondOb;
  int secondHazard;
  
  // 오장마스터를 위한 동반자 점수 (유저가 0번 인덱스, 동반자 1~3은 여기에 저장)
  // companions 리스트 순서와 매칭: companions[0]의 score는 companionScores[0]
  List<int> companionScores;
  
  // 내기 이벤트
  int nearestPlayerIndex; // -1:없음, 0:유저, 1~3:동반자
  int nearestErasePlayerIndex; // 누가 지웠는지 (-1:없음)

  HoleData({
    required this.holeNumber,
    this.par = 4,
    this.score = -99, // -99: 미입력
    this.putt = -99,
    this.teeOb = 0,
    this.teeHazard = 0,
    this.secondOb = 0,
    this.secondHazard = 0,
    List<int>? companionScores,
    this.nearestPlayerIndex = -1,
    this.nearestErasePlayerIndex = -1,
  }) : companionScores = companionScores ?? List.filled(3, -99);

  Map<String, dynamic> toMap() {
    return {
      'holeNumber': holeNumber,
      'par': par,
      'score': score,
      'putt': putt,
      'teeOb': teeOb,
      'teeHazard': teeHazard,
      'secondOb': secondOb,
      'secondHazard': secondHazard,
      'companionScores': companionScores,
      'nearestPlayerIndex': nearestPlayerIndex,
      'nearestErasePlayerIndex': nearestErasePlayerIndex,
    };
  }

  factory HoleData.fromMap(Map<String, dynamic> map) {
    return HoleData(
      holeNumber: map['holeNumber'] ?? 1,
      par: map['par'] ?? 4,
      score: map['score'] ?? -99,
      putt: map['putt'] ?? -99,
      teeOb: map['teeOb'] ?? 0,
      teeHazard: map['teeHazard'] ?? 0,
      secondOb: map['secondOb'] ?? 0,
      secondHazard: map['secondHazard'] ?? 0,
      companionScores: List<int>.from(map['companionScores'] ?? List.filled(3, -99)),
      nearestPlayerIndex: map['nearestPlayerIndex'] ?? -1,
      nearestErasePlayerIndex: map['nearestErasePlayerIndex'] ?? -1,
    );
  }

  int get penaltyStrokes => (teeOb * 2) + (secondOb * 2) + teeHazard + secondHazard;
  int get qPoint => (6 - score - putt).clamp(0, 5);
}

class RoundData {
  String? id;
  DateTime date;
  String teeUpTime;
  String golfCourseName;
  String frontCourseName;
  String backCourseName;
  List<String> companions;
  String? userId;
  String? userName;
  int totalScore;
  List<HoleData> holes;
  DateTime createdAt;
  OjangConfig ojangConfig;

  RoundData({
    this.id,
    required this.date,
    required this.teeUpTime,
    required this.golfCourseName,
    required this.frontCourseName,
    required this.backCourseName,
    required this.companions,
    required this.totalScore,
    required this.holes,
    required this.createdAt,
    this.userId,
    this.userName,
    OjangConfig? ojangConfig,
  }) : ojangConfig = ojangConfig ?? OjangConfig();

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'teeUpTime': teeUpTime,
      'golfCourseName': golfCourseName,
      'frontCourseName': frontCourseName,
      'backCourseName': backCourseName,
      'companions': companions,
      'totalScore': totalScore,
      'holes': holes.map((e) => e.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
      'userName': userName,
      'ojangConfig': ojangConfig.toMap(),
    };
  }

  factory RoundData.fromMap(String id, Map<String, dynamic> map) {
    return RoundData(
      id: id,
      date: (map['date'] as Timestamp).toDate(),
      teeUpTime: map['teeUpTime'] ?? '',
      golfCourseName: map['golfCourseName'] ?? '',
      frontCourseName: map['frontCourseName'] ?? '',
      backCourseName: map['backCourseName'] ?? '',
      companions: List<String>.from(map['companions'] ?? []),
      totalScore: map['totalScore'] ?? 0,
      holes: (map['holes'] as List?)
              ?.map((e) => HoleData.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userId: map['userId'],
      userName: map['userName'],
      ojangConfig: map['ojangConfig'] != null 
          ? OjangConfig.fromMap(Map<String, dynamic>.from(map['ojangConfig']))
          : OjangConfig(),
    );
  }

  int get qPoint {
    int points = 0;
    
    // 보너스 점수 로직 추가
    int totalPar = holes.fold(0, (sum, h) => sum + h.par);
    int grossScore = totalPar + totalScore;
    if (grossScore <= 79) points += 2;

    int scramblingChances = 0;
    int scramblingSuccesses = 0;
    int totalPenalty = 0;
    bool hasThreePutt = false;
    bool isDigital = true;

    for (var hole in holes) {
      totalPenalty += hole.penaltyStrokes;
      if (hole.putt >= 3) hasThreePutt = true;
      if (hole.score > 1) isDigital = false;

      bool isGir = (hole.score - hole.putt) <= -2;
      if (!isGir) {
        scramblingChances++;
        if (hole.score <= 0) scramblingSuccesses++;
      }
    }

    if (scramblingChances > 0 && (scramblingSuccesses / scramblingChances) >= 0.5) points += 2;
    if (totalPenalty == 0) points += 2;
    if (isDigital) points += 2;
    if (!hasThreePutt) points += 2;

    for (var hole in holes) {
      // hole.score는 오버/언더파 값 (0=Par, 1=Bogey, -1=Birdie 등)
      // 새 공식: (6 - score - putt).clamp(0, 5) -> HoleData.qPoint
      points += hole.qPoint;
    }
    return points;
  }
}
