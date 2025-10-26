/// Fuzzy subsequence matcher & scorer (inspired by fzy/fzf).
/// - Matches non-contiguously while preserving order
/// - Scores higher for contiguous runs, word boundaries, and early starts
/// - Ignores separators in gaps (no penalty)
/// - Treats "only separators between hits" as adjacency (gives adjacency bonus)
/// - Rewards consecutive boundary hits for abbreviations (acronym chain)
/// - Normalizes against a target-agnostic ideal (contiguous, separator-free prefix)
class FuzzyMatchResult {
  final bool matched;
  final double score;           // 0..1 (normalized)
  final List<int> positions;    // indices of matched chars in target
  final String target;

  FuzzyMatchResult({
    required this.matched,
    required this.score,
    required this.positions,
    required this.target,
  });

  String highlighted({String open = "[", String close = "]"}) {
    if (!matched || positions.isEmpty) return target;
    final set = positions.toSet();
    final b = StringBuffer();
    for (int i = 0; i < target.length; i++) {
      final ch = target[i];
      if (set.contains(i)) {
        b..write(open)..write(ch)..write(close);
      } else {
        b.write(ch);
      }
    }
    return b.toString();
  }
}

FuzzyMatchResult fuzzyScore(String query, String target) {
  if (query.isEmpty) {
    return FuzzyMatchResult(matched: true, score: 1.0, positions: [], target: target);
  }
  if (target.isEmpty || query.length > target.length) {
    return FuzzyMatchResult(matched: false, score: 0.0, positions: [], target: target);
  }

  // 1) Greedy subsequence match positions (case-insensitive)
  final q = query;
  final t = target;
  final qLower = q.toLowerCase();
  final tLower = t.toLowerCase();

  final pos = <int>[];
  int ti = 0;
  for (int qi = 0; qi < q.length; qi++) {
    final qc = qLower[qi];
    bool found = false;
    while (ti < t.length) {
      if (tLower[ti] == qc) {
        pos.add(ti);
        ti++;
        found = true;
        break;
      }
      ti++;
    }
    if (!found) {
      return FuzzyMatchResult(matched: false, score: 0.0, positions: [], target: target);
    }
  }

  // 2) Score the alignment
  const double basePerChar = 1.0;
  const double adjBonus = 0.8;           // consecutive (incl. soft adjacency across only separators)
  const double boundaryBonus = 0.7;      // word/camelCase/digit-letter boundary
  const double startBonus = 0.8;         // first match at index 0
  const double caseBonus = 0.05;         // exact-case match
  const double gapPenalty = 0.08;        // per skipped NON-separator char
  const double tailPenalty = 0.0;        // unused here
  const double acronymChainBonus = 0.4;  // boundary->boundary boosts abbreviations

  double scoreRaw = 0.0;

  bool isBoundary(int idx) {
    if (idx == 0) return true;
    final prev = t[idx - 1];
    final curr = t[idx];
    if (_isSep(prev)) return true;
    if (_isLower(prev) && _isUpper(curr)) return true; // camelCase
    if (_isAlpha(prev) != _isAlpha(curr)) return true; // digit/letter split
    return false;
  }

  for (int i = 0; i < pos.length; i++) {
    final p = pos[i];
    double s = basePerChar;

    if (t[p] == q[i]) s += caseBonus;
    if (isBoundary(p)) s += boundaryBonus;

    if (i > 0) {
      final prev = pos[i - 1];

      if (p == prev + 1 || _onlySepsBetween(t, prev, p)) {
        // contiguous OR separated only by separators: give adjacency
        s += adjBonus;
      } else {
        // penalize only non-separator chars skipped
        final effGap = _countNonSepBetween(t, prev, p);
        if (effGap > 0) s -= gapPenalty * effGap;
      }

      if (isBoundary(prev) && isBoundary(p)) {
        s += acronymChainBonus;
      }
    }

    scoreRaw += s;
  }

  if (pos.isNotEmpty && pos.first == 0) {
    scoreRaw += startBonus;
  }

  if (pos.isNotEmpty && tailPenalty > 0) {
    final tail = (t.length - 1) - pos.last;
    scoreRaw -= tailPenalty * tail.clamp(0, t.length);
  }

  // 3) Target-agnostic ideal: contiguous, separator-free prefix of length m
  double idealPrefixScore(int m) {
    if (m <= 0) return 0.0;
    final perChar = basePerChar + caseBonus; // assume best-case case match
    final contiguousAdj = (m - 1) * adjBonus;
    // first char: boundary+start bonuses apply in ideal
    return m * perChar + startBonus + boundaryBonus + contiguousAdj;
  }

  final idealScore = idealPrefixScore(q.length);
  final normalized = (idealScore > 0)
      ? (scoreRaw / idealScore).clamp(0.0, 1.0)
      : 0.0;

  return FuzzyMatchResult(
    matched: true,
    score: normalized,
    positions: pos,
    target: target,
  );
}

// =====================
// Helpers
// =====================

bool _isLower(String ch) => ch.toLowerCase() == ch && ch.toUpperCase() != ch;
bool _isUpper(String ch) => ch.toUpperCase() == ch && ch.toLowerCase() != ch;
bool _isAlpha(String ch) {
  final c = ch.codeUnitAt(0);
  return (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
}

bool _isSep(String ch) {
  const seps = {'/', '\\', '_', '-', ' ', '.', ':', '\t'};
  return seps.contains(ch);
}

int _countNonSepBetween(String t, int fromIndex, int toIndex) {
  int cnt = 0;
  for (int i = fromIndex + 1; i < toIndex; i++) {
    if (!_isSep(t[i])) cnt++;
  }
  return cnt;
}

bool _onlySepsBetween(String t, int fromIndex, int toIndex) {
  for (int i = fromIndex + 1; i < toIndex; i++) {
    if (!_isSep(t[i])) return false;
  }
  return true;
}
