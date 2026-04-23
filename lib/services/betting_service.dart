import '../models/round_model.dart';

class BettingResult {
  final List<int> netGains; // 각 플레이어별 최종 손익 (0:유저, 1~3:동반자)
  final List<List<int>> transactions; // [from][to] 얼마를 주는지 매트릭스

  BettingResult({required this.netGains, required this.transactions});
}

class BettingService {
  static BettingResult calculateHole(HoleData hole, OjangConfig config, int playerCount, List<String> playerNames) {
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

    int multiplier = isBaepan ? 2 : 1;

    // 2. 모든 쌍(Pair)에 대해 정산
    for (int i = 0; i < playerCount; i++) {
      for (int j = i + 1; j < playerCount; j++) {
        int sI = scores[i];
        int sJ = scores[j];

        if (sI == -99 || sJ == -99) continue;

        int finalAmount = 0;

        if (config.ruleType == 1) {
          // --- 오목회 룰 ---
          // i가 j보다 잘했을 때 기준 (i가 돈을 받는 입장)
          int diff = sJ - sI;
          int bonus = 0;
          if (sI == -1) bonus += 1;
          if (sJ == -1) bonus -= 1;

          int strokeDiff = diff + bonus;
          finalAmount = strokeDiff * multiplier * config.unitPrice;

          // 니어리스트 (파3 전용)
          if (hole.par == 3 && hole.nearestPlayerIndex != -1) {
            if (hole.nearestPlayerIndex == i) {
              if (sI <= 0) finalAmount += 1 * multiplier * config.unitPrice;
              else finalAmount -= 1 * multiplier * config.unitPrice;
            } else if (hole.nearestPlayerIndex == j) {
              if (sJ <= 0) finalAmount -= 1 * multiplier * config.unitPrice;
              else finalAmount += 1 * multiplier * config.unitPrice;
            }
          }
        } else {
          // --- 오장 후핸디 룰 (기존) ---
          int bonus = 0;
          if (sI <= -1) bonus += 1;
          if (sJ <= -1) bonus -= 1;

          if (hole.par == 3 && hole.nearestPlayerIndex != -1) {
            if (hole.nearestPlayerIndex == i) {
              if (sI <= 0) bonus += 1;
              else bonus -= 1;
            }
            if (hole.nearestPlayerIndex == j) {
              if (sJ <= 0) bonus -= 1;
              else bonus += 1;
            }
          }

          if (isBaepan) {
            int diff = sJ - sI;
            finalAmount = (diff + 2 * bonus) * config.unitPrice;
          } else {
            finalAmount = bonus * config.unitPrice;
          }
        }

        // 고수 패널티 적용 (오목회 룰일 때 패배한 사람이 고수면 2배)
        if (finalAmount > 0) {
          // i가 이김, j가 돈을 줌 (j 패배)
          // j가 고수(0: 본인)이거나 지정된 고수일 경우 2배
          if (config.ruleType == 1 && (j == 0 || config.expertPlayers.contains(playerNames[j]))) {
            finalAmount *= 2;
          }
          transactions[j][i] += finalAmount;
          netGains[i] += finalAmount;
          netGains[j] -= finalAmount;
        } else if (finalAmount < 0) {
          // j가 이김, i가 돈을 줌 (i 패배)
          int absAmount = finalAmount.abs();
          // i가 고수(0: 본인)이거나 지정된 고수일 경우 2배
          if (config.ruleType == 1 && (i == 0 || config.expertPlayers.contains(playerNames[i]))) {
            absAmount *= 2;
          }
          transactions[i][j] += absAmount;
          netGains[j] += absAmount;
          netGains[i] -= absAmount;
        }
      }
    }

    return BettingResult(netGains: netGains, transactions: transactions);
  }

  static List<int> calculateTotal(RoundData round) {
    int playerCount = 1 + round.companions.length;
    List<String> playerNames = [round.userName ?? '나', ...round.companions];
    List<int> totals = List.filled(playerCount, 0);

    if (!round.ojangConfig.enabled) return totals;

    for (var hole in round.holes) {
      if (hole.score == -99) continue;
      var result = calculateHole(hole, round.ojangConfig, playerCount, playerNames);
      for (int i = 0; i < playerCount; i++) {
        totals[i] += result.netGains[i];
      }
    }
    return totals;
  }
}
