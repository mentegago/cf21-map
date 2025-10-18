import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/map_cell.dart';
import '../models/creator.dart';
import 'creator_data_service.dart';

class MapParser {
  static Future<List<List<String>>> loadMapData() async {
    final jsonString = await rootBundle.loadString('data/map.json');
    final List<dynamic> jsonData = json.decode(jsonString);
    
    // Convert to String list
    return jsonData.map<List<String>>((row) => 
      (row as List<dynamic>).map<String>((cell) => cell?.toString() ?? '').toList()
    ).toList();
  }
  
  static List<MergedCell> mergeCells(List<List<String>> grid) {
    final int rows = grid.length;
    final int cols = grid.isEmpty ? 0 : grid[0].length;
    
    // Track which cells have been merged
    final processed = List.generate(rows, (_) => List.generate(cols, (_) => false));
    final List<MergedCell> mergedCells = [];
    
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (processed[r][c]) continue;
        
        final content = grid[r][c].trim();
        
        // Find the extent of this merged cell
        int rowSpan = 1;
        int colSpan = 1;
        
        // Check how far right we can extend
        while (c + colSpan < cols && 
               !processed[r][c + colSpan] &&
               grid[r][c + colSpan].trim() == content) {
          colSpan++;
        }
        
        // Check how far down we can extend (for each column in the span)
        bool canExtendDown = true;
        while (canExtendDown && r + rowSpan < rows) {
          for (int dc = 0; dc < colSpan; dc++) {
            if (processed[r + rowSpan][c + dc] ||
                grid[r + rowSpan][c + dc].trim() != content) {
              canExtendDown = false;
              break;
            }
          }
          if (canExtendDown) rowSpan++;
        }
        
        // Mark all cells in this merged area as processed
        for (int dr = 0; dr < rowSpan; dr++) {
          for (int dc = 0; dc < colSpan; dc++) {
            processed[r + dr][c + dc] = true;
          }
        }
        
        // Create merged cell
        mergedCells.add(MergedCell(
          content: content,
          startRow: r,
          startCol: c,
          rowSpan: rowSpan,
          colSpan: colSpan,
        ));
      }
    }
    
    return mergedCells;
  }
  
  static Future<List<Creator>> loadCreatorData() async {
    // Try loading from cache first
    final cachedCreators = await CreatorDataService.getCachedCreatorData();
    if (cachedCreators != null && cachedCreators.isNotEmpty) {
      // Sort cached creators by name
      final sortedCreators = List<Creator>.from(cachedCreators);
      sortedCreators.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return sortedCreators;
    }

    // Fallback to bundled data
    final jsonString = await rootBundle.loadString('data/creator-data-initial.json');
    final dynamic jsonData = json.decode(jsonString);
    
    // Only handle new JSON structure with version and creators array, and sort by name
    final List<dynamic> creatorsJson = jsonData['creators'] as List<dynamic>;
    final creators = creatorsJson.map((json) => Creator.fromJson(json)).toList();
    creators.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return creators;
  }
}

