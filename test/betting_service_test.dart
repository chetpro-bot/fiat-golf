import 'package:flutter_test/flutter_test.dart';
import 'package:golf_score/models/round_model.dart';
import 'package:golf_score/services/betting_service.dart';

void main() {
  group('BettingService.getBonusStrokes', () {
    test('홀인원 (파3에서 1타, score: -2) -> 10타 보너스', () {
      final bonus = BettingService.getBonusStrokes(
        score: -2,
        putt: 0,
        par: 3,
      );
      expect(bonus, 10);
    });

    test('알바트로스 (파5에서 2타, score: -3) -> 10타 보너스', () {
      final bonus = BettingService.getBonusStrokes(
        score: -3,
        putt: 1,
        par: 5,
      );
      expect(bonus, 10);
    });

    test('샷이글 (파4에서 2타, putt: 0, score: -2) -> 5타 보너스', () {
      final bonus = BettingService.getBonusStrokes(
        score: -2,
        putt: 0,
        par: 4,
      );
      expect(bonus, 5);
    });

    test('퍼팅이글 (파5에서 3타, putt: 1, score: -2) -> 3타 보너스', () {
      final bonus = BettingService.getBonusStrokes(
        score: -2,
        putt: 1,
        par: 5,
      );
      expect(bonus, 3);
    });

    test('버디 (파4에서 3타, score: -1) -> 1타 보너스', () {
      final bonus = BettingService.getBonusStrokes(
        score: -1,
        putt: 1,
        par: 4,
      );
      expect(bonus, 1);
    });
  });

  group('선핸디 정산 검증 (calculateInitialHandicapGains)', () {
    test('A(핸디 10), B(핸디 15) -> A가 B에게 5장(25,000원) 선지급', () {
      final gains = BettingService.calculateInitialHandicapGains(
        handicaps: [10, 15],
        unitPrice: 5000,
        playerCount: 2,
      );
      // 고수 A: -25,000원, 하수 B: +25,000원
      expect(gains[0], -25000);
      expect(gains[1], 25000);
    });

    test('4인 선핸디: 나(10), 동반자1(12), 동반자2(15), 동반자3(8)', () {
      // 나(10) vs 동반자1(12): 차이 2타 -> 나: -10,000, 동반자1: +10,000
      // 나(10) vs 동반자2(15): 차이 5타 -> 나: -25,000, 동반자2: +25,000
      // 나(10) vs 동반자3(8):  차이 -2타 -> 동반자3이 나에게 2타 줌 -> 나: +10,000, 동반자3: -10,000
      // 나의 총 선핸디 손익: -10,000 - 25,000 + 10,000 = -25,000원
      final gains = BettingService.calculateInitialHandicapGains(
        handicaps: [10, 12, 15, 8],
        unitPrice: 5000,
        playerCount: 4,
      );
      expect(gains[0], -25000);
      // 합계는 항상 0 (제로섬)
      expect(gains.reduce((a, b) => a + b), 0);
    });
  });

  group('선핸디 당배판 vs 후배판 검증', () {
    test('당배판 (baepanTiming: 0)은 현재 홀의 결과로 배판 판정', () {
      final hole1 = HoleData(
        holeNumber: 1,
        par: 4,
        score: -1, // 버디!
        putt: 1,
        companionScores: [0, 0],
        companionPutts: [2, 2],
      );

      final config = OjangConfig(
        enabled: true,
        unitPrice: 5000,
        ruleType: 1, // 선핸디
        baepanTiming: 0, // 당배판
      );

      final result = BettingService.calculateHole(
        hole1,
        config,
        3,
        ['나', '동반자A', '동반자B'],
      );

      expect(result.isBaepan, true);
    });

    test('후배판 (baepanTiming: 1)은 1번 홀은 무조건 평판, 2번 홀은 1번 홀 결과로 배판 판정', () {
      final hole1 = HoleData(
        holeNumber: 1,
        par: 4,
        score: -1, // 1번 홀 버디
        putt: 1,
        companionScores: [0, 0],
        companionPutts: [2, 2],
      );

      final config = OjangConfig(
        enabled: true,
        unitPrice: 5000,
        ruleType: 1, // 선핸디
        baepanTiming: 1, // 후배판
      );

      // 1번 홀 (prevHole: null) -> 평판
      final result1 = BettingService.calculateHole(
        hole1,
        config,
        3,
        ['나', '동반자A', '동반자B'],
        prevHole: null,
      );
      expect(result1.isBaepan, false);

      // 2번 홀: 전원 파
      final hole2 = HoleData(
        holeNumber: 2,
        par: 4,
        score: 0,
        putt: 2,
        companionScores: [0, 1],
        companionPutts: [2, 2],
      );

      // 2번 홀 (prevHole: hole1 -> 1번 홀이 버디였으므로 배판!)
      final result2 = BettingService.calculateHole(
        hole2,
        config,
        3,
        ['나', '동반자A', '동반자B'],
        prevHole: hole1,
      );
      expect(result2.isBaepan, true);
    });
  });

  group('후핸디 최종 타수 차이 정산 검증 (calculatePostHandicapGains)', () {
    test('A(+10), B(+15) -> A가 5타 덜 쳤으므로 B가 A에게 25,000원 지급', () {
      final hole = HoleData(
        holeNumber: 1,
        par: 4,
        score: 10,
        companionScores: [15],
      );

      final postGains = BettingService.calculatePostHandicapGains(
        holes: [hole],
        unitPrice: 5000,
        playerCount: 2,
      );

      expect(postGains[0], 25000); // A: +25,000
      expect(postGains[1], -25000); // B: -25,000
    });
  });
}
