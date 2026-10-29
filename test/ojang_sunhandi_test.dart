import 'package:flutter_test/flutter_test.dart';
import 'package:golf_score/models/round_model.dart';
import 'package:golf_score/services/betting_service.dart';

void main() {
  group('선핸디 홀별 계산 검증 (calculateHole with ruleType: 1)', () {
    final config = OjangConfig(
      enabled: true,
      unitPrice: 1000,
      ruleType: 1, // 선핸디
      baepanTiming: 0, // 당배판
      baepanBirdie: false,
      baepanThreeSame: false,
      baepanTripleP45: false,
      baepanDoubleP3: false,
    );

    test('선핸디 평판: 타수차이 * 타당 단가 정산', () {
      // 나(0, Par), 동반자1(1, Bogey), 동반자2(2, Double)
      // 나 vs 동반자1: 1타 차이 -> 나: +1,000, 동반자1: -1,000
      // 나 vs 동반자2: 2타 차이 -> 나: +2,000, 동반자2: -2,000
      // 동반자1 vs 동반자2: 1타 차이 -> 동반자1: +1,000, 동반자2: -1,000
      // 최종 손익: 나: +3,000, 동반자1: 0, 동반자2: -3,000
      final hole = HoleData(
        holeNumber: 1,
        par: 4,
        score: 0,
        putt: 2,
        companionScores: [1, 2],
        companionPutts: [2, 2],
      );

      final result = BettingService.calculateHole(
        hole,
        config,
        3,
        ['나', '동반자1', '동반자2'],
      );

      expect(result.isBaepan, false);
      expect(result.netGains[0], 3000);
      expect(result.netGains[1], 0);
      expect(result.netGains[2], -3000);
    });

    test('선핸디 배판: 타수차이 * 타당 단가 * 2 정산', () {
      final baepanConfig = OjangConfig(
        enabled: true,
        unitPrice: 1000,
        ruleType: 1, // 선핸디
        baepanTiming: 0,
        baepanThreeSame: true, // 3명 동타 배판 활성화
      );

      // 나(1, Bogey), 동반자1(0, Par), 동반자2(0, Par), 동반자3(0, Par)
      // 3명 동타로 배판 조건 만족!
      // 나 vs 동반자1: -1타 차이 * 2배 -> 나: -2,000, 동반자1: +2,000
      // 나 vs 동반자2: -1타 차이 * 2배 -> 나: -2,000, 동반자2: +2,000
      // 나 vs 동반자3: -1타 차이 * 2배 -> 나: -2,000, 동반자3: +2,000
      // 나의 손익: -6,000원
      final hole = HoleData(
        holeNumber: 2,
        par: 4,
        score: 1,
        putt: 2,
        companionScores: [0, 0, 0],
        companionPutts: [2, 2, 2],
      );

      final result = BettingService.calculateHole(
        hole,
        baepanConfig,
        4,
        ['나', '동반자1', '동반자2', '동반자3'],
      );

      expect(result.isBaepan, true);
      expect(result.netGains[0], -6000);
      expect(result.netGains[1], 2000);
      expect(result.netGains[2], 2000);
      expect(result.netGains[3], 2000);
    });

    test('선핸디 평판에서 버디(보너스 1타) 발생 시: (타수차이 + 보너스타수) * 단가', () {
      final noBaepanConfig = OjangConfig(
        enabled: true,
        unitPrice: 1000,
        ruleType: 1, // 선핸디
        baepanBirdie: false,
        baepanThreeSame: false,
      );

      // 나(-1, Birdie), 동반자1(0, Par)
      // 타수차이 1타 + 버디보너스 1타 = 2타 * 1,000 = 2,000원
      final hole = HoleData(
        holeNumber: 1,
        par: 4,
        score: -1,
        putt: 1,
        companionScores: [0],
        companionPutts: [2],
      );

      final result = BettingService.calculateHole(
        hole,
        noBaepanConfig,
        2,
        ['나', '동반자1'],
      );

      expect(result.isBaepan, false);
      expect(result.netGains[0], 2000);
      expect(result.netGains[1], -2000);
    });
  });

  group('후핸디 홀별 계산 유지 검증 (calculateHole with ruleType: 0)', () {
    test('후핸디 평판: 타수차이는 무시하고 보너스만 정산', () {
      final config = OjangConfig(
        enabled: true,
        unitPrice: 1000,
        ruleType: 0, // 후핸디
        baepanThreeSame: false,
      );

      // 나(0, Par), 동반자1(1, Bogey) -> 보너스 없음
      // 후핸디 평판에서는 타수차이 무시 -> 손익 0원
      final hole = HoleData(
        holeNumber: 1,
        par: 4,
        score: 0,
        putt: 2,
        companionScores: [1],
        companionPutts: [2],
      );

      final result = BettingService.calculateHole(
        hole,
        config,
        2,
        ['나', '동반자1'],
      );

      expect(result.isBaepan, false);
      expect(result.netGains[0], 0);
      expect(result.netGains[1], 0);
    });

    test('후핸디 배판: 타수차이 + 2 * 보너스 정산', () {
      final config = OjangConfig(
        enabled: true,
        unitPrice: 1000,
        ruleType: 0, // 후핸디
        baepanThreeSame: true,
      );

      // 나(1, Bogey), 동반자1(0, Par), 동반자2(0, Par), 동반자3(0, Par)
      // 3명 동타 배판!
      // 후핸디 배판에서는 diff(1) * 1,000원 = 각 동반자에게 1,000원 지급 (총 -3,000원)
      final hole = HoleData(
        holeNumber: 2,
        par: 4,
        score: 1,
        putt: 2,
        companionScores: [0, 0, 0],
        companionPutts: [2, 2, 2],
      );

      final result = BettingService.calculateHole(
        hole,
        config,
        4,
        ['나', '동반자1', '동반자2', '동반자3'],
      );

      expect(result.isBaepan, true);
      expect(result.netGains[0], -3000);
      expect(result.netGains[1], 1000);
      expect(result.netGains[2], 1000);
      expect(result.netGains[3], 1000);
    });
  });

  group('선핸디 전체 라운드 정산 (calculateTotal) 검증', () {
    test('초기 핸디캡 정산금 + 홀별 정산금의 합계가 최종 총액에 반영됨', () {
      // 나(핸디 10), 동반자1(핸디 15) -> 나: -5,000원, 동반자1: +5,000원
      // 1번 홀 (평판): 나(Par, 0), 동반자1(Bogey, 1) -> 나: +1,000원, 동반자1: -1,000원
      // 총액: 나: -4,000원, 동반자1: +4,000원
      final round = RoundData(
        date: DateTime.now(),
        teeUpTime: '08:00',
        golfCourseName: 'CC',
        frontCourseName: 'In',
        backCourseName: 'Out',
        companions: ['동반자1'],
        totalScore: 73,
        createdAt: DateTime.now(),
        ojangConfig: OjangConfig(
          enabled: true,
          unitPrice: 1000,
          ruleType: 1, // 선핸디
          playerHandicaps: [10, 15],
          baepanBirdie: false,
          baepanThreeSame: false,
          baepanTripleP45: false,
          baepanDoubleP3: false,
        ),
        holes: [
          HoleData(
            holeNumber: 1,
            par: 4,
            score: 0,
            putt: 2,
            companionScores: [1],
            companionPutts: [2],
          ),
        ],
      );

      final totals = BettingService.calculateTotal(round);
      expect(totals[0], -4000);
      expect(totals[1], 4000);
    });
  });

  group('상계 정산 송금 요약 (simplifiedTransfers) 검증', () {
    test('사용자 요청 예시: A(파), B(보기), C(보기), D(더블보기) -> D가 A에게 4,000원 송금', () {
      final config = OjangConfig(
        enabled: true,
        unitPrice: 1000,
        ruleType: 1, // 선핸디
        baepanTiming: 0,
        baepanBirdie: false,
        baepanThreeSame: false,
        baepanTripleP45: false,
        baepanDoubleP3: false,
      );

      // A(Par, 0), B(Bogey, 1), C(Bogey, 1), D(Double, 2)
      final hole = HoleData(
        holeNumber: 1,
        par: 4,
        score: 0,
        putt: 2,
        companionScores: [1, 1, 2],
        companionPutts: [2, 2, 2],
      );

      final result = BettingService.calculateHole(
        hole,
        config,
        4,
        ['A', 'B', 'C', 'D'],
      );

      // 홀별 손익 확인
      expect(result.netGains[0], 4000); // A: +4,000
      expect(result.netGains[1], 0);    // B: 0
      expect(result.netGains[2], 0);    // C: 0
      expect(result.netGains[3], -4000); // D: -4,000

      // 송금 요약: D -> A 4,000원 (단 1회)
      expect(result.simplifiedTransfers.length, 1);
      final t = result.simplifiedTransfers.first;
      expect(t.fromName, 'D');
      expect(t.toName, 'A');
      expect(t.amount, 4000);
    });

    test('2명 승리, 2명 패배 시 최소 횟수 상계 송금', () {
      final transfers = BettingService.simplifyTransfers(
        [2000, 2000, -2000, -2000],
        ['A', 'B', 'C', 'D'],
      );

      expect(transfers.length, 2);
      expect(transfers.map((t) => t.amount).reduce((a, b) => a + b), 4000);
      for (var t in transfers) {
        expect(['C', 'D'].contains(t.fromName), true);
        expect(['A', 'B'].contains(t.toName), true);
      }
    });

    test('동타로 전원 0원일 때 송금 목록은 빈 리스트', () {
      final transfers = BettingService.simplifyTransfers(
        [0, 0, 0, 0],
        ['A', 'B', 'C', 'D'],
      );

      expect(transfers.isEmpty, true);
    });
  });
}
