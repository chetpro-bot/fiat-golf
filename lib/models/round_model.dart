import 'package:cloud_firestore/cloud_firestore.dart';

class HoleData {
  final int holeNumber;
  int par;
  int score;
  int putt;
  int teeOb;
  int teeHazard;
  int secondOb;
  int secondHazard;

  HoleData({
    required this.holeNumber,
    this.par = 4,
    this.score = 4,
    this.putt = 2,
    this.teeOb = 0,
    this.teeHazard = 0,
    this.secondOb = 0,
    this.secondHazard = 0,
  });

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
    };
  }

  factory HoleData.fromMap(Map<String, dynamic> map) {
    return HoleData(
      holeNumber: map['holeNumber'] ?? 1,
      par: map['par'] ?? 4,
      score: map['score'] ?? 4,
      putt: map['putt'] ?? 2,
      teeOb: map['teeOb'] ?? 0,
      teeHazard: map['teeHazard'] ?? 0,
      secondOb: map['secondOb'] ?? 0,
      secondHazard: map['secondHazard'] ?? 0,
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
  });

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
