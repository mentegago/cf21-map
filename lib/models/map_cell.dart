class MapCell {
  final String content;
  final int row;
  final int col;
  final bool isEmpty;
  final bool isBooth;
  final bool isLocationMarker;
  final bool isWall;
  final bool isHall;
  
  MapCell({
    required this.content,
    required this.row,
    required this.col,
  }) : isEmpty = content.trim().isEmpty,
       isBooth = _isBooth(content),
       isLocationMarker = _isLocationMarker(content),
       isWall = _isWall(content),
       isHall = _isHall(content);
  
  static bool _isBooth(String content) {
    if (content.trim().isEmpty) return false;
    // Booth format: X-x (e.g., R-12b, AB-28, Z-01a)
    return RegExp(r'^[A-Z]+-\d+[ab]?$', caseSensitive: true).hasMatch(content);
  }
  
  static bool _isLocationMarker(String content) {
    if (content.trim().isEmpty) return false;
    // Location markers are single/double letters or just "a" or "b"
    return !_isBooth(content) && !_isWall(content) && !_isHall(content) && content.trim().isNotEmpty;
  }
  
  static bool _isWall(String content) {
    if (content.trim().isEmpty) return false;
    // Wall cells are marked with "X"
    return content.trim() == 'X';
  }
  
  static bool _isHall(String content) {
    if (content.trim().isEmpty) return false;
    // Hall cells are marked with "HALL X" where X is a number
    return RegExp(r'^HALL\s+\d+$', caseSensitive: false).hasMatch(content.trim());
  }
  
  @override
  String toString() => 'MapCell($content at [$row,$col])';
}

class MergedCell {
  final String content;
  final int startRow;
  final int startCol;
  final int rowSpan;
  final int colSpan;
  final bool isEmpty;
  final bool isBooth;
  final bool isLocationMarker;
  final bool isWall;
  final bool isHall;
  
  MergedCell({
    required this.content,
    required this.startRow,
    required this.startCol,
    required this.rowSpan,
    required this.colSpan,
  }) : isEmpty = content.trim().isEmpty,
       isBooth = MapCell._isBooth(content),
       isLocationMarker = MapCell._isLocationMarker(content),
       isWall = MapCell._isWall(content),
       isHall = MapCell._isHall(content);
  
  bool containsPosition(int row, int col) {
    return row >= startRow && 
           row < startRow + rowSpan &&
           col >= startCol && 
           col < startCol + colSpan;
  }
  
  @override
  String toString() => 'MergedCell($content at [$startRow,$startCol] size ${rowSpan}x$colSpan)';
}

