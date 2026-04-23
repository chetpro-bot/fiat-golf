import 'package:cloud_firestore/cloud_firestore.dart';

class OjangConfig {
  bool enabled;
  int unitPrice;
  bool baepanBirdie; // 버디 이상 배판
  bool baepanThreeSame; // 3명 동타 배판
  bool baepanTripleP45; // 파4,5 트리플 이상 배판
  bool baepanDoubleP3; // 파3 더블 이상 배판
  int nearestRule; // 0:안함, 1:기본, 2:지우기/실패포함
  int ruleType; // 0: 오장 후핸디, 1: 오목회
  List<String> expertPlayers; // 고수 패널티 대상자 목록

  OjangConfig({
    this.enabled = false,
    this.unitPrice = 5000,
    this.baepanBirdie = true,
    this.baepanThreeSame = true,
    this.baepanTripleP45 = true,
    this.baepanDoubleP3 = true,
    this.nearestRule = 2,
    this.ruleType = 0,
    this.expertPlayers = const [],
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
      'ruleType': ruleType,
      'expertPlayers': expertPlayers,
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
      ruleType: map['ruleType'] ?? 0,
      expertPlayers: List<String>.from(map['expertPlayers'] ?? []),
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
  
  // 오장마스터를 위한 동반자 상세 데이터 (유저가 0번 인덱스, 동반자 1~3은 여기에 저장)
  // companions 리스트 순서와 매칭: companions[0]의 데이터는 인덱스 0에 저장
  List<int> companionScores;
  List<int> companionPutts;
  List<int> companionPenalties; // 총 벌타 (기존 호환성 유지용 또는 합계용)
  
  // 동반자 벌타 상세
  List<int> companionTeeOb;
  List<int> companionTeeHazard;
  List<int> companionSecondOb;
  List<int> companionSecondHazard;
  
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
    List<int>? companionPutts,
    List<int>? companionPenalties,
    List<int>? companionTeeOb,
    List<int>? companionTeeHazard,
    List<int>? companionSecondOb,
    List<int>? companionSecondHazard,
    this.nearestPlayerIndex = -1,
    this.nearestErasePlayerIndex = -1,
  }) : companionScores = companionScores ?? List.filled(3, -99),
       companionPutts = companionPutts ?? List.filled(3, -99),
       companionPenalties = companionPenalties ?? List.filled(3, 0),
       companionTeeOb = companionTeeOb ?? List.filled(3, 0),
       companionTeeHazard = companionTeeHazard ?? List.filled(3, 0),
       companionSecondOb = companionSecondOb ?? List.filled(3, 0),
       companionSecondHazard = companionSecondHazard ?? List.filled(3, 0);

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
      'companionPutts': companionPutts,
      'companionPenalties': companionPenalties,
      'companionTeeOb': companionTeeOb,
      'companionTeeHazard': companionTeeHazard,
      'companionSecondOb': companionSecondOb,
      'companionSecondHazard': companionSecondHazard,
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
      companionPutts: List<int>.from(map['companionPutts'] ?? List.filled(3, -99)),
      companionPenalties: List<int>.from(map['companionPenalties'] ?? List.filled(3, 0)),
      companionTeeOb: List<int>.from(map['companionTeeOb'] ?? List.filled(3, 0)),
      companionTeeHazard: List<int>.from(map['companionTeeHazard'] ?? List.filled(3, 0)),
      companionSecondOb: List<int>.from(map['companionSecondOb'] ?? List.filled(3, 0)),
      companionSecondHazard: List<int>.from(map['companionSecondHazard'] ?? List.filled(3, 0)),
      nearestPlayerIndex: map['nearestPlayerIndex'] ?? -1,
      nearestErasePlayerIndex: map['nearestErasePlayerIndex'] ?? -1,
    );
  }

  int get penaltyStrokes => (teeOb * 2) + (secondOb * 2) + teeHazard + secondHazard;

  int getPlayerPenaltyStrokes(int playerIndex) {
    if (playerIndex == 0) return penaltyStrokes;
    int cIdx = playerIndex - 1;
    if (cIdx < 0 || cIdx >= 3) return 0;
    
    return (companionTeeOb[cIdx] * 2) + (companionSecondOb[cIdx] * 2) + 
           companionTeeHazard[cIdx] + companionSecondHazard[cIdx];
  }

  int get qPoint => getPlayerQPoint(0);


  int getPlayerQPoint(int playerIndex) {
    int s, p;
    if (playerIndex == 0) {
      s = score;
      p = putt;
    } else {
      int cIdx = playerIndex - 1;
      s = (companionScores.length > cIdx) ? companionScores[cIdx] : -99;
      p = (companionPutts.length > cIdx) ? companionPutts[cIdx] : -99;
    }
    
    if (s == -99 || p == -99) return 0;

    // 1. 버디 이상은 무조건 4점
    if (s < 0) return 4;

    // 2. 파
    if (s == 0) {
      if (p <= 1) return 4;
      if (p == 2) return 3;
      if (p >= 3) return 2;
    }

    // 3. 보기
    if (s == 1) {
      if (p <= 1) return 3;
      if (p == 2) return 2;
      if (p >= 3) return 1;
    }

    // 4. 더블
    if (s == 2) {
      if (p <= 1) return 2;
      if (p >= 2) return 1;
    }

    // 5. 트리플 이상 0점
    return 0;
  }
}

class HoleQPointInfo {
  final int holeNumber;
  final int par;
  final int on;
  final int putt;
  final String scoreLabel;
  final int points;

  HoleQPointInfo({
    required this.holeNumber,
    required this.par,
    required this.on,
    required this.putt,
    required this.scoreLabel,
    required this.points,
  });
}

class QPointBreakdown {
  final int holePoints;
  final bool under80;
  final bool scrambling;
  final bool noPenalty;
  final bool digital;
  final bool noThreePutt;
  final bool gir50;
  final bool puttsUnder30;
  final int bounceBackCount;
  final List<HoleQPointInfo> holeDetails;

  QPointBreakdown({
    required this.holePoints,
    required this.under80,
    required this.scrambling,
    required this.noPenalty,
    required this.digital,
    required this.noThreePutt,
    required this.gir50,
    required this.puttsUnder30,
    required this.bounceBackCount,
    required this.holeDetails,
  });

  int get bonusPoints => (under80 ? 4 : 0) + 
                        (scrambling ? 4 : 0) + 
                        (noPenalty ? 4 : 0) + 
                        (digital ? 4 : 0) + 
                        (noThreePutt ? 4 : 0) +
                        (gir50 ? 4 : 0) +
                        (puttsUnder30 ? 4 : 0) +
                        (bounceBackCount * 2);

  int get total => holePoints + bonusPoints;
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

  int get qPoint => getPlayerQPoint(0);

  int getPlayerQPoint(int playerIndex) {
    return getQPointBreakdown(playerIndex).total;
  }

  QPointBreakdown getQPointBreakdown(int playerIndex) {
    int holePoints = 0;
    List<HoleQPointInfo> holeDetails = [];
    
    int totalPar = holes.fold(0, (total, h) => total + h.par);
    int playerOverUnder = 0;
    int totalPenalty = 0;
    bool hasThreePutt = false;
    bool isDigital = true;
    int scramblingChances = 0;
    int scramblingSuccesses = 0;
    int girCount = 0;
    int totalPutts = 0;
    int bounceBacks = 0;
    bool hadBadScoreLastHole = false;
    bool allHolesEntered = true;

    for (var hole in holes) {
      int s, p, pen;
      if (playerIndex == 0) {
        s = hole.score;
        p = hole.putt;
      } else {
        int cIdx = playerIndex - 1;
        s = (hole.companionScores.length > cIdx) ? hole.companionScores[cIdx] : -99;
        p = (hole.companionPutts.length > cIdx) ? hole.companionPutts[cIdx] : -99;
      }
      pen = hole.getPlayerPenaltyStrokes(playerIndex);

      if (s == -99 || p == -99) {
        allHolesEntered = false;
        hadBadScoreLastHole = false;
        holeDetails.add(HoleQPointInfo(
          holeNumber: hole.holeNumber,
          par: hole.par,
          on: 0,
          putt: 0,
          scoreLabel: '미입력',
          points: 0,
        ));
        continue;
      }

      playerOverUnder += s;
      totalPutts += p;
      if (p >= 3) hasThreePutt = true;
      totalPenalty += pen;
      if (s > 1) isDigital = false;

      // Bounce Back logic: Bad score (Double+) -> Good score (Par-)
      if (hadBadScoreLastHole && s <= 0) {
        bounceBacks++;
      }
      hadBadScoreLastHole = (s >= 2);

      // On = Hole Par + Score - Putts
      int on = hole.par + s - p;

      bool isGir = (s - p) <= -2;
      if (isGir) {
        girCount++;
      } else {
        scramblingChances++;
        if (s <= 0) scramblingSuccesses++;
      }
      
      int hp = hole.getPlayerQPoint(playerIndex);
      holePoints += hp;
      
      holeDetails.add(HoleQPointInfo(
        holeNumber: hole.holeNumber,
        par: hole.par,
        on: on,
        putt: p,
        scoreLabel: _getScoreLabel(s, hole.par),
        points: hp,
      ));
    }

    bool complete = holes.length == 18 && allHolesEntered;
    
    return QPointBreakdown(
      holePoints: holePoints,
      under80: complete && (totalPar + playerOverUnder) <= 79,
      scrambling: complete && scramblingChances > 0 && (scramblingSuccesses / scramblingChances) >= 0.5,
      noPenalty: complete && totalPenalty == 0,
      digital: complete && isDigital,
      noThreePutt: complete && !hasThreePutt,
      gir50: complete && (girCount / 18) >= 0.5,
      puttsUnder30: complete && totalPutts <= 29,
      bounceBackCount: bounceBacks,
      holeDetails: holeDetails,
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
}
