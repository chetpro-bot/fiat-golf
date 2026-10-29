import '../models/round_model.dart';

class TransferItem {
  final int fromIndex;
  final int toIndex;
  final String fromName;
  final String toName;
  final int amount;

  TransferItem({
    required this.fromIndex,
    required this.toIndex,
    required this.fromName,
    required this.toName,
    required this.amount,
  });

  @override
  String toString() => '$fromName → $toName: $amount원';
}

class BettingResult {
  final List<int> netGains; // 각 플레이어별 최종 손익 (0:유저, 1~3:동반자)
  final List<List<int>> transactions; // [from][to] 얼마를 주는지 매트릭스
  final bool isBaepan; // 해당 홀의 배판 적용 여부
  final List<TransferItem> simplifiedTransfers; // 상계 정산 후 최종 송금 목록

  BettingResult({
    required this.netGains,
    required this.transactions,
    this.isBaepan = false,
    this.simplifiedTransfers = const [],
  });
}

class BettingService {
  /// 해당 플레이어의 언더파 보너스 타수 계산
  /// - 홀인원: 10타 (총 타수가 1타인 경우, par + score == 1)
  /// - 알바트로스: 10타 (score <= -3, 홀인원이 아닌 경우)
  /// - 샷이글: 5타 (score == -2 && putt == 0)
  /// - 퍼팅이글: 3타 (score == -2 && putt != 0)
  /// - 버디: 1타 (score == -1)
  static int getBonusStrokes({
    required int score,
    required int putt,
    required int par,
  }) {
    if (score >= 0 || score == -99) return 0;

    int gross = par + score;

    // 1. 홀인원: 총 타수가 1타인 경우 (10타 보너스)
    if (gross == 1) {
      return 10;
    }

    // 2. 알바트로스: 기준 타수 대비 -3타 이하 (10타 보너스)
    if (score <= -3) {
      return 10;
    }

    // 3. 이글: 기준 타수 대비 -2타
    if (score == -2) {
      // 샷이글 (퍼팅수 0): 5타 보너스
      // 퍼팅이글 (퍼팅수 0이 아님): 3타 보너스
      return (putt == 0) ? 5 : 3;
    }

    // 4. 버디: 기준 타수 대비 -1타 (1타 보너스)
    if (score == -1) {
      return 1;
    }

    return 0;
  }

  /// 특정 홀의 결과가 배판 조건을 만족하는지 판별
  static bool checkBaepanCondition(HoleData hole, OjangConfig config, int playerCount) {
    if (!config.enabled) return false;

    List<int> scores = [hole.score, ...hole.companionScores.take(playerCount - 1)];

    // 1. 3명 이상 동타
    if (config.baepanThreeSame) {
      Map<int, int> scoreCounts = {};
      for (var s in scores) {
        if (s == -99) continue;
        scoreCounts[s] = (scoreCounts[s] ?? 0) + 1;
      }
      if (scoreCounts.values.any((count) => count >= 3)) {
        return true;
      }
    }

    // 2. 버디 이상
    if (config.baepanBirdie && scores.any((s) => s != -99 && s <= -1)) {
      return true;
    }

    // 3. 파3 더블 이상
    if (hole.par == 3 && config.baepanDoubleP3 && scores.any((s) => s != -99 && s >= 2)) {
      return true;
    }

    // 4. 파4/5 트리플 이상
    if (hole.par >= 4 && config.baepanTripleP45 && scores.any((s) => s != -99 && s >= 3)) {
      return true;
    }

    return false;
  }

  /// 선핸디 룰일 때 라운드 시작 전 주고받는 핸디캡 정산금 계산
  /// handicaps: [나의 핸디, 동반자1 핸디, 동반자2 핸디, ...]
  /// 핸디캡이 낮은 사람(고수)이 높은 사람(하수)에게 차이 * unitPrice를 지급
  static List<int> calculateInitialHandicapGains({
    required List<int> handicaps,
    required int unitPrice,
    required int playerCount,
  }) {
    List<int> initialGains = List.filled(playerCount, 0);

    for (int i = 0; i < playerCount; i++) {
      for (int j = i + 1; j < playerCount; j++) {
        int hI = i < handicaps.length ? handicaps[i] : 0;
        int hJ = j < handicaps.length ? handicaps[j] : 0;

        // hJ - hI: 핸디캡 차이
        // hJ > hI: j가 하수, i가 고수 -> i가 j에게 (hJ - hI) * unitPrice 지급 (i -, j +)
        int diff = hJ - hI;
        int amount = diff * unitPrice;

        initialGains[i] -= amount;
        initialGains[j] += amount;
      }
    }

    return initialGains;
  }

  /// 후핸디 룰일 때 최종 타수(오버/언더파 합계) 차이에 따른 정산금 계산
  /// 타수가 적은 사람(잘 친 사람)이 타수가 많은 사람(못 친 사람)에게서 차이 * unitPrice를 받음
  static List<int> calculatePostHandicapGains({
    required List<HoleData> holes,
    required int unitPrice,
    required int playerCount,
  }) {
    List<int> postGains = List.filled(playerCount, 0);
    List<int> totalOverUnder = List.filled(playerCount, 0);
    int enteredHolesCount = 0;

    for (var hole in holes) {
      if (hole.score == -99) continue;
      bool allEntered = true;
      for (int i = 0; i < playerCount - 1; i++) {
        if (hole.companionScores.length <= i || hole.companionScores[i] == -99) {
          allEntered = false;
          break;
        }
      }
      if (!allEntered) continue;

      enteredHolesCount++;
      totalOverUnder[0] += hole.score;
      for (int i = 1; i < playerCount; i++) {
        totalOverUnder[i] += hole.companionScores[i - 1];
      }
    }

    if (enteredHolesCount == 0) return postGains;

    for (int i = 0; i < playerCount; i++) {
      for (int j = i + 1; j < playerCount; j++) {
        int scoreI = totalOverUnder[i];
        int scoreJ = totalOverUnder[j];

        // scoreJ - scoreI: i 기준 타수 우위 (j가 더 많이 쳐서 스코어가 높음)
        // i가 덜 쳤으면 j가 i에게 차이 * unitPrice 지급 (i +, j -)
        int diff = scoreJ - scoreI;
        int amount = diff * unitPrice;

        postGains[i] += amount;
        postGains[j] -= amount;
      }
    }

    return postGains;
  }

  /// 홀별 정산 계산
  /// - prevHole: 선핸디 후배판일 때 이전 홀의 결과를 참조하여 배판 여부 결정
  static BettingResult calculateHole(
    HoleData hole,
    OjangConfig config,
    int playerCount,
    List<String> playerNames, {
    HoleData? prevHole,
  }) {
    List<int> scores = [hole.score, ...hole.companionScores.take(playerCount - 1)];
    List<int> putts = [hole.putt, ...hole.companionPutts.take(playerCount - 1)];
    List<int> netGains = List.filled(playerCount, 0);
    List<List<int>> transactions = List.generate(playerCount, (_) => List.filled(playerCount, 0));

    // 1. 배판 여부 확인
    bool isBaepan = false;
    if (config.enabled) {
      if (config.ruleType == 1 && config.baepanTiming == 1) {
        // [선핸디 - 후배판]: 이전 홀의 기록으로 배판 여부 결정
        if (prevHole != null && prevHole.score != -99) {
          isBaepan = checkBaepanCondition(prevHole, config, playerCount);
        }
      } else {
        // [당배판 또는 후핸디]: 현재 홀의 기록으로 배판 여부 결정
        isBaepan = checkBaepanCondition(hole, config, playerCount);
      }
    }

    // 2. 모든 쌍(Pair)에 대해 정산
    for (int i = 0; i < playerCount; i++) {
      for (int j = i + 1; j < playerCount; j++) {
        int sI = scores[i];
        int sJ = scores[j];

        if (sI == -99 || sJ == -99) continue;

        int bonusI = getBonusStrokes(score: sI, putt: putts[i], par: hole.par);
        int bonusJ = getBonusStrokes(score: sJ, putt: putts[j], par: hole.par);
        int bonus = bonusI - bonusJ;

        // 니어리스트 (파3 전용)
        if (hole.par == 3 && hole.nearestPlayerIndex != -1) {
          if (hole.nearestPlayerIndex == i) {
            if (sI <= 0) {
              bonus += 1;
            } else {
              bonus -= 1;
            }
          }
          if (hole.nearestPlayerIndex == j) {
            if (sJ <= 0) {
              bonus -= 1;
            } else {
              bonus += 1;
            }
          }
        }

        int diff = sJ - sI;
        int finalAmount = 0;

        if (config.ruleType == 1) {
          // [오장 선핸디]
          // 선핸디 게임은 이미 시작하기 전에 핸디를 주고 받았으므로:
          // 평판이면 (타수차이 + 보너스타수) * 단가
          // 배판이면 (타수차이 + 보너스타수) * 단가 * 2
          if (isBaepan) {
            finalAmount = (diff + bonus) * config.unitPrice * 2;
          } else {
            finalAmount = (diff + bonus) * config.unitPrice;
          }
        } else {
          // [오장 후핸디]
          // 후핸디는 18홀 종료 후 최종 타수차이를 정산하므로,
          // 홀별 정산에서는 평판 시 보너스만, 배판 시 추가 1배 타수차이 + 2배 보너스를 정산함
          if (isBaepan) {
            // 배판: 타수 차이 + 2 * 보너스 타수
            finalAmount = (diff + 2 * bonus) * config.unitPrice;
          } else {
            // 평판: 보너스 타수만 정산
            finalAmount = bonus * config.unitPrice;
          }
        }

        if (finalAmount > 0) {
          // i가 이김, j가 돈을 줌
          transactions[j][i] += finalAmount;
          netGains[i] += finalAmount;
          netGains[j] -= finalAmount;
        } else if (finalAmount < 0) {
          // j가 이김, i가 돈을 줌
          int absAmount = finalAmount.abs();
          transactions[i][j] += absAmount;
          netGains[j] += absAmount;
          netGains[i] -= absAmount;
        }
      }
    }

    final simplifiedTransfers = simplifyTransfers(netGains, playerNames);

    return BettingResult(
      netGains: netGains,
      transactions: transactions,
      isBaepan: isBaepan,
      simplifiedTransfers: simplifiedTransfers,
    );
  }

  /// 최종 손익(netGains)을 바탕으로 최소 횟수의 송금 내역으로 상계 정산
  static List<TransferItem> simplifyTransfers(
    List<int> netGains,
    List<String> playerNames,
  ) {
    List<TransferItem> transfers = [];
    List<int> balances = List.from(netGains);

    while (true) {
      int debtorIdx = -1;
      int creditorIdx = -1;
      int minBal = 0;
      int maxBal = 0;

      for (int i = 0; i < balances.length; i++) {
        if (balances[i] < minBal) {
          minBal = balances[i];
          debtorIdx = i;
        }
        if (balances[i] > maxBal) {
          maxBal = balances[i];
          creditorIdx = i;
        }
      }

      if (debtorIdx == -1 || creditorIdx == -1 || minBal == 0 || maxBal == 0) {
        break;
      }

      int amount = (-minBal < maxBal) ? -minBal : maxBal;
      if (amount <= 0) break;

      transfers.add(TransferItem(
        fromIndex: debtorIdx,
        toIndex: creditorIdx,
        fromName: debtorIdx < playerNames.length ? playerNames[debtorIdx] : '플레이어${debtorIdx + 1}',
        toName: creditorIdx < playerNames.length ? playerNames[creditorIdx] : '플레이어${creditorIdx + 1}',
        amount: amount,
      ));

      balances[debtorIdx] += amount;
      balances[creditorIdx] -= amount;
    }

    return transfers;
  }

  /// 라운드 전체 누적 정산 계산
  static List<int> calculateTotal(RoundData round) {
    int playerCount = 1 + round.companions.length;
    List<String> playerNames = [round.userName ?? '나', ...round.companions];
    List<int> totals = List.filled(playerCount, 0);

    if (!round.ojangConfig.enabled) return totals;

    // 1. 선핸디 룰: 라운드 시작 전 주고받은 핸디 정산금 반영
    if (round.ojangConfig.ruleType == 1) {
      final initialGains = calculateInitialHandicapGains(
        handicaps: round.ojangConfig.playerHandicaps,
        unitPrice: round.ojangConfig.unitPrice,
        playerCount: playerCount,
      );
      for (int i = 0; i < playerCount; i++) {
        totals[i] += initialGains[i];
      }
    }

    // 2. 홀별 정산금 누적
    HoleData? prevHole;
    for (int hIdx = 0; hIdx < round.holes.length; hIdx++) {
      final hole = round.holes[hIdx];
      if (hole.score == -99) {
        prevHole = hole;
        continue;
      }
      var result = calculateHole(
        hole,
        round.ojangConfig,
        playerCount,
        playerNames,
        prevHole: prevHole,
      );
      for (int i = 0; i < playerCount; i++) {
        totals[i] += result.netGains[i];
      }
      prevHole = hole;
    }

    // 3. 후핸디 룰: 라운드 종료 후 최종 타수 차이에 따른 후핸디 정산금 반영
    if (round.ojangConfig.ruleType == 0) {
      final postGains = calculatePostHandicapGains(
        holes: round.holes,
        unitPrice: round.ojangConfig.unitPrice,
        playerCount: playerCount,
      );
      for (int i = 0; i < playerCount; i++) {
        totals[i] += postGains[i];
      }
    }

    return totals;
  }
}
