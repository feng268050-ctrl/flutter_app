/// Semver-ish dotted numeric compare: negative if [a] < [b], zero if equal, positive if [a] > [b].
int compareVersion(String a, String b) {
  final partsA = _parseVersionParts(a);
  final partsB = _parseVersionParts(b);
  final maxLen = partsA.length > partsB.length ? partsA.length : partsB.length;

  for (var i = 0; i < maxLen; i++) {
    final va = i < partsA.length ? partsA[i] : _VersionPart.zero;
    final vb = i < partsB.length ? partsB[i] : _VersionPart.zero;
    final cmp = va.compareTo(vb);
    if (cmp != 0) {
      return cmp;
    }
  }
  return 0;
}

/// True when [remote] is strictly newer than [local].
bool isNewer(String remote, String local) => compareVersion(remote, local) > 0;

List<_VersionPart> _parseVersionParts(String raw) {
  var value = raw.trim();
  if (value.startsWith('v') || value.startsWith('V')) {
    value = value.substring(1);
  }
  final mainAndPre = _splitMainAndPreRelease(value);
  final main = mainAndPre.$1;
  final preRelease = mainAndPre.$2;

  final numericParts = main.split('.').map((segment) {
    final match = RegExp(r'^(\d+)').firstMatch(segment.trim());
    if (match != null) {
      return _VersionPart.number(int.parse(match.group(1)!));
    }
    return _VersionPart.text(segment.trim());
  }).toList();

  if (preRelease != null && preRelease.isNotEmpty) {
    numericParts.add(_VersionPart.text(preRelease));
  }
  return numericParts;
}

final class _VersionPart implements Comparable<_VersionPart> {
  const _VersionPart.number(this.number)
      : kind = _Kind.number,
        text = '';

  const _VersionPart.text(this.text)
      : kind = _Kind.text,
        number = 0;

  static const zero = _VersionPart.number(0);

  final _Kind kind;
  final int number;
  final String text;

  @override
  int compareTo(_VersionPart other) {
    if (kind == _Kind.number && other.kind == _Kind.number) {
      return number.compareTo(other.number);
    }
    if (kind == _Kind.number && other.kind == _Kind.text) {
      // Numeric release beats pre-release suffix at same position.
      return 1;
    }
    if (kind == _Kind.text && other.kind == _Kind.number) {
      return -1;
    }
    return text.compareTo(other.text);
  }
}

enum _Kind { number, text }

(String, String?) _splitMainAndPreRelease(String value) {
  final dashIndex = value.indexOf('-');
  if (dashIndex < 0) {
    return (value, null);
  }
  return (
    value.substring(0, dashIndex),
    value.substring(dashIndex + 1),
  );
}
