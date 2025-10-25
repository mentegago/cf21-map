/// Fuzzy subsequence matcher & scorer (inspired by fzy/fzf).
/// - Matches non-contiguously while preserving order
/// - Scores higher for contiguous runs, word boundaries, and early starts
/// - Penalizes big gaps
///
/// Usage:
/// final r = fuzzyScore("helwod", "helloworld");
/// if (r.matched) {
///   print(r.score);        // 0..1
///   print(r.positions);    // indices of matched chars in target
///   print(r.highlighted()); // e.g., he[l]lo[w]or[l] [o][d]
/// }
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

  /// Wrap matched characters with [open][close] (for debug/UX).
  String highlighted({String open = "[", String close = "]"}) {
    if (!matched || positions.isEmpty) return target;
    final set = positions.toSet();
    final b = StringBuffer();
    for (int i = 0; i < target.length; i++) {
      final ch = target[i];
      if (set.contains(i)) {
        b.write(open);
        b.write(ch);
        b.write(close);
      } else {
        b.write(ch);
      }
    }
    return b.toString();
  }
}

FuzzyMatchResult fuzzyScore(String query, String target) {
  // Fast paths
  if (query.isEmpty) {
    return FuzzyMatchResult(matched: true, score: 1.0, positions: [], target: target);
  }
  if (target.isEmpty || query.length > target.length) {
    return FuzzyMatchResult(matched: false, score: 0.0, positions: [], target: target);
  }

  // 1) Greedy subsequence match to get positions
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
  // Tunable constants (kept small so nothing dominates excessively).
  const double basePerChar = 1.0;
  const double adjBonus = 0.8;          // consecutive characters
  const double boundaryBonus = 0.7;     // start of word/camelCase/symbol boundary
  const double startBonus = 0.8;        // starts at index 0
  const double caseBonus = 0.05;        // exact case matched
  const double gapPenalty = 0.08;       // per skipped character
  const double tailPenalty = 0.0;       // optional: penalize distance of last match to end

  double scoreRaw = 0.0;

  bool isBoundary(int idx) {
    if (idx == 0) return true;
    final prev = t[idx - 1];
    final curr = t[idx];
    // Word separators / path separators
    const seps = {'/', '\\', '_', '-', ' ', '.', ':'};
    if (seps.contains(prev)) return true;
    // camelCase or digit-to-letter or letter-to-digit split
    final prevIsLower = _isLower(prev);
    final currIsUpper = _isUpper(curr);
    if (prevIsLower && currIsUpper) return true;
    // Digit/letter boundary
    if (_isAlpha(prev) != _isAlpha(curr)) return true;
    return false;
  }

  // Sum per-char contributions
  for (int i = 0; i < pos.length; i++) {
    final p = pos[i];
    double s = basePerChar;

    // Case exactness
    if (t[p] == q[i]) s += caseBonus;

    // Boundary bonus
    if (isBoundary(p)) s += boundaryBonus;

    // Adjacency bonus and gap penalty
    if (i > 0) {
      final prev = pos[i - 1];
      final gap = p - prev - 1;
      if (p == prev + 1) {
        s += adjBonus; // contiguous
      } else if (gap > 0) {
        s -= gapPenalty * gap;
      }
    }

    scoreRaw += s;
  }

  // Start-of-string bonus
  if (pos.isNotEmpty && pos.first == 0) {
    scoreRaw += startBonus;
  }

  // Optional: penalize if last match is far from end
  if (pos.isNotEmpty && tailPenalty > 0) {
    final tail = (t.length - 1) - pos.last;
    scoreRaw -= tailPenalty * tail.clamp(0, t.length);
  }

  // 3) Normalize against an ideal alignment: perfect prefix match at target[0..m-1]
  final idealPos = List<int>.generate(q.length, (i) => i);
  final idealScore = _scoreGivenPositions(
    q: q,
    t: t,
    positions: idealPos,
    basePerChar: basePerChar,
    adjBonus: adjBonus,
    boundaryBonus: boundaryBonus,
    startBonus: startBonus,
    caseBonus: caseBonus,
    gapPenalty: gapPenalty,
    tailPenalty: tailPenalty,
  );

  // Guard against division by zero (shouldn’t happen unless constants go weird)
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

double _scoreGivenPositions({
  required String q,
  required String t,
  required List<int> positions,
  required double basePerChar,
  required double adjBonus,
  required double boundaryBonus,
  required double startBonus,
  required double caseBonus,
  required double gapPenalty,
  required double tailPenalty,
}) {
  double scoreRaw = 0.0;

  bool isBoundary(int idx) {
    if (idx == 0) return true;
    final prev = t[idx - 1];
    final curr = t[idx];
    const seps = {'/', '\\', '_', '-', ' ', '.', ':'};
    if (seps.contains(prev)) return true;
    final prevIsLower = _isLower(prev);
    final currIsUpper = _isUpper(curr);
    if (prevIsLower && currIsUpper) return true;
    if (_isAlpha(prev) != _isAlpha(curr)) return true;
    return false;
  }

  for (int i = 0; i < positions.length; i++) {
    final p = positions[i];
    double s = basePerChar;

    if (t[p] == q[i]) s += caseBonus;
    if (isBoundary(p)) s += boundaryBonus;

    if (i > 0) {
      final prev = positions[i - 1];
      final gap = p - prev - 1;
      if (p == prev + 1) {
        s += adjBonus;
      } else if (gap > 0) {
        s -= gapPenalty * gap;
      }
    }
    scoreRaw += s;
  }

  if (positions.isNotEmpty && positions.first == 0) {
    scoreRaw += startBonus;
  }
  if (positions.isNotEmpty && tailPenalty > 0) {
    final tail = (t.length - 1) - positions.last;
    scoreRaw -= tailPenalty * tail.clamp(0, t.length);
  }
  return scoreRaw;
}

bool _isLower(String ch) => ch.toLowerCase() == ch && ch.toUpperCase() != ch;
bool _isUpper(String ch) => ch.toUpperCase() == ch && ch.toLowerCase() != ch;
bool _isAlpha(String ch) {
  final c = ch.codeUnitAt(0);
  return (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
}
