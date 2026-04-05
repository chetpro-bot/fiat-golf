import '../models/round_model.dart';

class BettingResult {
  final List<int> netGains; // 각 플레이어별 최종 손익 (0:유저, 1~3:동반자)
  final List<List<int>> transactions; // [from][to] 얼마를 주는지 매트릭스

  BettingResult({required this.netGains, required this.transactions});
}

class BettingService {
  static BettingResult calculateHole(HoleData hole, OjangConfig config, int playerCount) {
    List<int> scores = [hole.score, ...hole.companionScores.take(playerCount - 1)];
    List<int> netGains = List.filled(playerCount, 0);
    List<List<int>> transactions = List.generate(playerCount, (_) => List.filled(playerCount, 0));

    // 1. 배판 여부 확인
    bool isBaepan = false;
    if (config.enabled) {
      if (config.baepanThreeSame) {
        // 3명 이상이 같은 스코어인지 확인
        Map<int, int> scoreCounts = {};
        for (var s in scores) {
          if (s == -99) continue;
          scoreCounts[s] = (scoreCounts[s] ?? 0) + 1;
        }
        if (scoreCounts.values.any((count) => count >= 3)) isBaepan = true;
      }

      if (config.baepanBirdie && scores.any((s) => s != -99 && s <= -1)) {
        isBaepan = true;
      }

      if (hole.par == 3 && config.baepanDoubleP3 && scores.any((s) => s != -99 && s >= 2)) {
        isBaepan = true;
      }

      if (hole.par >= 4 && config.baepanTripleP45 && scores.any((s) => s != -99 && s >= 3)) {
        isBaepan = true;
      }
    }

    // 2. 모든 쌍(Pair)에 대해 정산
    for (int i = 0; i < playerCount; i++) {
      for (int j = i + 1; j < playerCount; j++) {
        int sI = scores[i];
        int sJ = scores[j];

        if (sI == -99 || sJ == -99) continue;

        // i가 j보다 잘했을 때 기준 (i가 돈을 받는 입장)
        int diff = sJ - sI;
        int bonus = 0;

        // 버디 보너스 (+1타)
        if (sI <= -1) bonus += 1;
        if (sJ <= -1) bonus -= 1;

        // 니어리스트 보너스
        if (config.nearestRule > 0) {
          // i가 니어 성공
          if (hole.nearestPlayerIndex == i && hole.nearestErasePlayerIndex == -1) {
            // 니어 성공 조건: 파/버디 (score <= 0)
            if (sI <= 0) bonus += 1;
            // 니어 실패 조건: 보기 이상 (score > 0)
            else if (config.nearestRule == 2) bonus -= 1;
          }
          // j가 니어 성공
          if (hole.nearestPlayerIndex == j && hole.nearestErasePlayerIndex == -1) {
            if (sJ <= 0) bonus -= 1;
            else if (config.nearestRule == 2) bonus += 1;
          }
        }

        int finalAmount = 0;
        if (isBaepan) {
          // 배판 공식: (타수차이 + 2 * 보너스) * 단가
          finalAmount = (diff + 2 * bonus) * config.unitPrice;
        } else {
          // 홑판 공식: (보너스) * 단가 (타수차이는 무시)
          finalAmount = bonus * config.unitPrice;
        }

        if (finalAmount > 0) {
          // j가 i에게 준다
          transactions[j][i] += finalAmount;
          netGains[i] += finalAmount;
          netGains[j] -= finalAmount;
        } else if (finalAmount < 0) {
          // i가 j에게 준다
          transactions[i][j] += finalAmount.abs();
          netGains[j] += finalAmount.abs();
          netGains[i] -= finalAmount.abs();
        }
      }
    }

    return BettingResult(netGains: netGains, transactions: transactions);
  }

  static List<int> calculateTotal(RoundData round) {
    int playerCount = 1 + round.companions.length;
    List<int> totals = List.filled(playerCount, 0);

    if (!round.ojangConfig.enabled) return totals;

    for (var hole in round.holes) {
      if (hole.score == -99) continue;
      var result = calculateHole(hole, round.ojangConfig, playerCount);
      for (int i = 0; i < playerCount; i++) {
        totals[i] += result.netGains[i];
      }
    }
    return totals;
  }
}
