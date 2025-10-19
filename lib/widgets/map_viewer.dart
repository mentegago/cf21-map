import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../models/map_cell.dart';
import '../models/creator.dart';
import '../services/creator_data_service.dart';

class MapViewer extends StatefulWidget {
  final List<MergedCell> mergedCells;
  final int rows;
  final int cols;
  final Function(String?)? onBoothTap;

  const MapViewer({
    super.key,
    required this.mergedCells,
    required this.rows,
    required this.cols,
    this.onBoothTap,
  });

  @override
  State<MapViewer> createState() => _MapViewerState();
}

class _MapViewerState extends State<MapViewer> with SingleTickerProviderStateMixin {
  final TransformationController _transformationController = TransformationController();
  final double _cellSize = 40.0;
  String? _hoveredBooth;
  late List<List<String?>> _boothLookupGrid; // O(1) spatial lookup
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  @override
  void initState() {
    super.initState();
    _buildBoothLookupGrid();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    // Add listener to provider for selection changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<CreatorDataProvider>();
      provider.addListener(_onProviderChanged);
    });
    
    // Set initial zoom and position after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      // Get viewport size
      final viewportWidth = MediaQuery.of(context).size.width;
      final viewportHeight = MediaQuery.of(context).size.height;
      
      // Calculate map size
      final mapWidth = widget.cols * _cellSize;
      final mapHeight = widget.rows * _cellSize;
      
      // Set initial scale (e.g., 0.5 to zoom out, 1.0 for default, 2.0 to zoom in)
      const initialScale = 0.5;
      
      // Center the map with the initial scale
      final translationX = (viewportWidth - mapWidth * initialScale) / 1.3;
      final translationY = (viewportHeight - mapHeight * initialScale) / 1.3;
      
      // Create initial transformation
      _transformationController.value = Matrix4.identity()
        ..translate(translationX, translationY)
        ..scale(initialScale);
    });
  }

  @override
  void dispose() {
    // Remove provider listener
    try {
      final provider = context.read<CreatorDataProvider>();
      provider.removeListener(_onProviderChanged);
    } catch (e) {
      // Provider might be disposed already
    }
    _animationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MapViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Rebuild lookup grid if cells changed
    if (oldWidget.mergedCells != widget.mergedCells) {
      _buildBoothLookupGrid();
    }
  }

  // Handle provider changes for selection animations
  void _onProviderChanged() {
    if (!mounted) return;
    
    final provider = context.read<CreatorDataProvider>();
    final currentSelectedCreator = provider.selectedCreator;
    
    if (currentSelectedCreator != null && currentSelectedCreator.booths.isNotEmpty) {
      _centerOnBooths(currentSelectedCreator.booths);
    }
  }

  // Precompute a 2D grid for O(1) booth lookups
  void _buildBoothLookupGrid() {
    // Initialize grid with nulls
    _boothLookupGrid = List.generate(
      widget.rows,
      (_) => List.filled(widget.cols, null),
    );
    
    // Fill grid with booth IDs
    for (final cell in widget.mergedCells) {
      if (cell.isBooth) {
        // Fill all grid positions covered by this booth
        for (int row = cell.startRow; row < cell.startRow + cell.rowSpan; row++) {
          for (int col = cell.startCol; col < cell.startCol + cell.colSpan; col++) {
            if (row < widget.rows && col < widget.cols) {
              _boothLookupGrid[row][col] = cell.content;
            }
          }
        }
      }
    }
  }

  void _centerOnBooths(List<String> boothIds) {
    // Find all booth cells
    final boothCells = widget.mergedCells.where(
      (cell) => boothIds.contains(cell.content),
    ).toList();

    if (boothCells.isEmpty) return;

    // Calculate the average center position of all booths
    double totalX = 0;
    double totalY = 0;
    
    for (final cell in boothCells) {
      totalX += (cell.startCol + cell.colSpan / 2) * _cellSize;
      totalY += (cell.startRow + cell.rowSpan / 2) * _cellSize;
    }

    final avgX = totalX / boothCells.length;
    final avgY = totalY / boothCells.length;

    // Get the viewport size
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // On desktop, account for sidebar width (400px)
    final isDesktop = screenWidth > 768;
    final viewportWidth = isDesktop ? screenWidth - 400 : screenWidth;
    final viewportHeight = screenHeight;

    // Get the current transformation
    final currentTransform = _transformationController.value;
    
    // Determine target zoom based on booth area
    // Multi-letter areas (AA-AF) need more zoom out to see context
    bool isMultiLetterArea = false;
    if (boothCells.isNotEmpty) {
      final firstBoothId = boothCells.first.content;
      final hyphenIndex = firstBoothId.indexOf('-');
      if (hyphenIndex > 0) {
        final area = firstBoothId.substring(0, hyphenIndex);
        isMultiLetterArea = area.length > 1;
      }
    }
    final targetScale = isMultiLetterArea ? 0.6 : 0.8;

    // Calculate the translation to center the booths with target zoom
    final translationX = viewportWidth / 2 - avgX * targetScale;
    final translationY = viewportHeight / (isDesktop ? 2 : 3) - avgY * targetScale;

    // Create target transformation
    final targetTransform = Matrix4.identity()
      ..translate(translationX, translationY)
      ..scale(targetScale);

    // Animate from current to target transformation
    _animation = Matrix4Tween(
      begin: currentTransform,
      end: targetTransform,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    ));

    // Delay animation to let search panel finish closing
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _animationController.reset();
      _animationController.forward();

      _animation!.addListener(() {
        _transformationController.value = _animation!.value;
      });
    });
  }

  // O(1) booth lookup using precomputed grid
  String? _findBoothAt(double x, double y) {
    final col = (x / _cellSize).floor();
    final row = (y / _cellSize).floor();
    
    // Bounds check
    if (row < 0 || row >= widget.rows || col < 0 || col >= widget.cols) {
      return null;
    }
    
    return _boothLookupGrid[row][col];
  }

  void _handleTap(TapUpDetails details) {
    if (widget.onBoothTap == null) return;
    
    // Clear hover state on tap (for touch devices)
    if (_hoveredBooth != null) {
      setState(() {
        _hoveredBooth = null;
      });
    }
    
    // The tap position is already in the child coordinate system (map space)
    // because GestureDetector is a child of InteractiveViewer
    final tapX = details.localPosition.dx;
    final tapY = details.localPosition.dy;
    
    final boothId = _findBoothAt(tapX, tapY);
    widget.onBoothTap!(boothId);
  }

  void _handleHover(PointerEvent event) {
    // Ignore hover events from touch devices
    if (event.kind == PointerDeviceKind.touch) {
      return;
    }
    
    final hoverX = event.localPosition.dx;
    final hoverY = event.localPosition.dy;
    
    final boothId = _findBoothAt(hoverX, hoverY);
    
    if (boothId != _hoveredBooth) {
      setState(() {
        _hoveredBooth = boothId;
      });
    }
  }

  void _handleExit(PointerEvent event) {
    if (_hoveredBooth != null) {
      setState(() {
        _hoveredBooth = null;
      });
    }
  }

  MergedCell? _getHoveredCell() {
    if (_hoveredBooth == null) return null;
    return widget.mergedCells.firstWhere(
      (cell) => cell.content == _hoveredBooth,
      orElse: () => widget.mergedCells.first, // dummy, won't be used
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBackgroundColor = Theme.of(context).scaffoldBackgroundColor;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Get selected creator from provider
    final selectedCreator = context.watch<CreatorDataProvider>().selectedCreator;
    final selectedBooths = selectedCreator?.booths;
    
    // Find selected cells
    final selectedCells = selectedBooths != null
        ? widget.mergedCells.where((cell) => selectedBooths.contains(cell.content)).toList()
        : <MergedCell>[];
    
    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 0.1,
      maxScale: 1.5,
      boundaryMargin: EdgeInsets.symmetric(horizontal: screenWidth * 0.8, vertical: screenHeight * 0.8),
      constrained: false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: _handleTap,
        child: MouseRegion(
          cursor: _hoveredBooth != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onHover: _handleHover,
          onExit: _handleExit,
          child: Stack(
            children: [
              // Main map (doesn't repaint on hover or selection)
              RepaintBoundary(
                child: CustomPaint(
                  size: Size(
                    widget.cols * _cellSize,
                    widget.rows * _cellSize,
                  ),
                  painter: MapPainter(
                    mergedCells: widget.mergedCells,
                    cellSize: _cellSize,
                    isDark: isDark,
                    scaffoldBackgroundColor: scaffoldBackgroundColor,
                  ),
                ),
              ),
              // Hover overlay (only repaints hover effect)
              if (_hoveredBooth != null)
                RepaintBoundary(
                  child: CustomPaint(
                    size: Size(
                      widget.cols * _cellSize,
                      widget.rows * _cellSize,
                    ),
                    painter: HoverOverlayPainter(
                      hoveredCell: _getHoveredCell(),
                      cellSize: _cellSize,
                      isDark: isDark,
                    ),
                  ),
                ),
              // Selection overlay (only repaints selection effect)
              if (selectedCells.isNotEmpty)
                RepaintBoundary(
                  child: CustomPaint(
                    size: Size(
                      widget.cols * _cellSize,
                      widget.rows * _cellSize,
                    ),
                    painter: SelectionOverlayPainter(
                      selectedCells: selectedCells,
                      cellSize: _cellSize,
                      isDark: isDark,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

}

class MapPainter extends CustomPainter {
  final List<MergedCell> mergedCells;
  final double cellSize;
  final bool isDark;
  final Color scaffoldBackgroundColor;

  MapPainter({
    required this.mergedCells,
    required this.cellSize,
    required this.isDark,
    required this.scaffoldBackgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = scaffoldBackgroundColor,
    );

    final hall7Rect = Rect.fromLTWH(
      0.5,
      3 / 103 * size.height,
      size.width * 44 / 146 - 1,
      size.height * 99 / 103,
    );
    canvas.drawRect(
      hall7Rect,
      Paint()..color = _getHallColor("HALL 7").withValues(alpha: isDark ? 0.15 : 0.5),
    );
    canvas.drawRect(
      hall7Rect,
      Paint()
        ..color = _getHallBorderColor("HALL 7")
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    final hall8Rect = Rect.fromLTWH(
      size.width * 44 / 146 + 0.5,
      3 / 103 * size.height,
      size.width * 50 / 146 - 1,
      size.height * 99 / 103,
    );
    canvas.drawRect(
      hall8Rect,
      Paint()..color = _getHallColor("HALL 8").withValues(alpha: isDark ? 0.15 : 0.5),
    );
    canvas.drawRect(
      hall8Rect,
      Paint()
        ..color = _getHallBorderColor("HALL 8")
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    final hall9Rect = Rect.fromLTWH(
      size.width * 94 / 146 + 0.5,
      3 / 103 * size.height,
      size.width * 52 / 146 - 1,
      size.height * 99 / 103,
    );
    canvas.drawRect(
      hall9Rect,
      Paint()..color = _getHallColor("HALL 9").withValues(alpha: isDark ? 0.15 : 0.5),
    );
    canvas.drawRect(
      hall9Rect,
      Paint()
        ..color = _getHallBorderColor("HALL 9")
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Only draw text if zoomed in enough
    final shouldDrawText = cellSize >= 30;
    final useRoundedCorners = cellSize >= 20;
    final cornerRadius = cellSize >= 60
        ? const Radius.circular(6)
        : (cellSize >= 40 ? const Radius.circular(4) : const Radius.circular(2));
    
    // Pre-create paints to avoid creating them in the loop
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    // Single pass through cells
    for (final cell in mergedCells) {
      if (cell.isEmpty) continue;

      final left = cell.startCol * cellSize;
      final top = cell.startRow * cellSize;
      final width = cell.colSpan * cellSize;
      final height = cell.rowSpan * cellSize;

      final rect = Rect.fromLTWH(left + 0.5, top + 0.5, width - 1, height - 1);

      // Draw base fill using a more refined palette
      Color fillColor = _getCellColor(cell);
      fillPaint.color = fillColor;
      if (useRoundedCorners && !cell.isHall) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, cornerRadius),
          fillPaint,
        );
      } else {
        canvas.drawRect(rect, fillPaint);
      }
      
      // Draw border with dynamic thickness
      Color borderColor = _getBorderColor(cell);
      // Scale stroke subtly with zoom for visual consistency
      final zoomScale = (cellSize / 40.0).clamp(0.8, 2.0);
      double strokeWidth = (cell.isBooth ? 1.4 : 0.9) * zoomScale;
      borderPaint.color = borderColor;
      borderPaint.strokeWidth = strokeWidth;
      if (useRoundedCorners && !cell.isHall) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, cornerRadius),
          borderPaint,
        );
      } else {
        canvas.drawRect(rect, borderPaint);
      }
      
      // Draw text if zoomed in and cell is large enough
      if (shouldDrawText && cell.content.isNotEmpty && width > 20 && height > 15) {
        _drawText(canvas, cell, rect);
      }
    }
  }

  String _getDisplayText(MergedCell cell) {
    if (cell.isBooth) {
      // Extract just the number from booth IDs (e.g., "O-33a" -> "33")
      final match = RegExp(r'\d+').firstMatch(cell.content);
      if (match != null) {
        return match.group(0)!;
      }
    }
    return cell.content;
  }

  void _drawText(Canvas canvas, MergedCell cell, Rect rect) {
    final textStyle = _getTextStyle(cell);
    final displayText = _getDisplayText(cell);
    final textSpan = TextSpan(
      text: displayText,
      style: textStyle,
    );

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: cell.rowSpan,
      ellipsis: '...',
    );

    textPainter.layout(maxWidth: rect.width - 4);

    // Center the text in the rect
    final xCenter = rect.left + (rect.width - textPainter.width) / 2;
    final yCenter = rect.top + (rect.height - textPainter.height) / 2;

    // Remove background pill entirely for a cleaner look
    // No background pill behind labels for a cleaner look

    textPainter.paint(canvas, Offset(xCenter, yCenter));
  }

  Color _getCellColor(MergedCell cell) {
    if (cell.isEmpty) {
      return Colors.transparent;
    } else if (cell.isWall) {
      return isDark ? const Color(0xFF1A1A1A) : const Color(0xFF424242);
    } else if (cell.isHall) {
      return _getHallColor(cell.content);
    } else if (cell.isBooth) {
      final section = _getBoothSection(cell.content);
      return _boothFillColor(section);
    } else if (cell.isLocationMarker) {
      if (cell.content == 'a' || cell.content == 'b') {
        return isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE);
      }
      return isDark ? const Color(0xFF4A2C00) : const Color(0xFFFFE0B2);
    }
    return isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0);
  }

  Color _getBorderColor(MergedCell cell) {
    if (cell.isEmpty) {
      return Colors.transparent;
    } else if (cell.isWall) {
      return isDark ? const Color(0xFF2A2A2A) : const Color(0xFF616161);
    } else if (cell.isHall) {
      return _getHallBorderColor(cell.content);
    } else if (cell.isBooth) {
      final section = _getBoothSection(cell.content);
      return _boothBorderColor(section);
    } else if (cell.isLocationMarker) {
      if (cell.content == 'a' || cell.content == 'b') {
        return isDark ? const Color(0xFF4A4A4A) : const Color(0xFFBDBDBD);
      }
      return isDark ? const Color(0xFFFF8A50) : const Color(0xFFE64A19);
    }
    return isDark ? const Color(0xFF4A4A4A) : const Color(0xFF9E9E9E);
  }

  TextStyle _getTextStyle(MergedCell cell) {
    if (cell.isWall) {
      return const TextStyle(
        fontSize: 0,
        color: Colors.transparent,
        fontFamily: 'Roboto',
      );
    } else if (cell.isBooth) {
      Color textColor = isDark ? Colors.white : const Color(0xFF0D47A1);
      return TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: textColor,
        fontFamily: 'Roboto',
      );
    } else if (cell.isLocationMarker && cell.content != 'a' && cell.content != 'b') {
      return TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100),
        fontFamily: 'Roboto',
      );
    } else if (cell.isHall) {
      return TextStyle(
        fontSize: 24,
        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        fontFamily: 'Roboto',
      );
    }
    return TextStyle(
      fontSize: 14,
      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
      fontFamily: 'Roboto',
    );
  }

  // --- Palette helpers for booth sections ---
  String _getBoothSection(String content) {
    final hyphen = content.indexOf('-');
    if (hyphen > 0) {
      return content.substring(0, hyphen).toUpperCase();
    }
    // Fallback to first letter group
    return content.isNotEmpty ? content.substring(0, 1).toUpperCase() : 'X';
  }

  // Soft, readable fills per section group (adapts to theme)
  Color _boothFillColor(String section) {
    List<Color> lightPalette = const [
      Color(0xFFE3F2FD), // blue 50
      Color(0xFFE8F5E9), // green 50
      Color(0xFFFFF3E0), // orange 50
      Color(0xFFF3E5F5), // purple 50
      Color(0xFFFFEBEE), // red 50
      Color(0xFFE0F7FA), // cyan 50
      Color(0xFFF1F8E9), // light green 50
      Color(0xFFFFF8E1), // amber 50
    ];
    List<Color> darkPalette = const [
      Color(0xFF1A237E), // blue 900
      Color(0xFF1B5E20), // green 900
      Color(0xFFE65100), // orange 900
      Color(0xFF4A148C), // purple 900
      Color(0xFFB71C1C), // red 900
      Color(0xFF006064), // cyan 900
      Color(0xFF33691E), // light green 900
      Color(0xFFFF6F00), // amber 900
    ];
    final palette = isDark ? darkPalette : lightPalette;

    // Special-case readability in dark mode:
    // Sections 'O' and 'G' previously mapped to amber/orange which had poor contrast.
    if (isDark) {
      if (section == 'O') {
        return const Color(0xFF5E35B1); // deepPurple 600
      }
      if (section == 'G') {
        return const Color(0xFF00897B); // teal 600
      }
    }

    final idx = section.codeUnitAt(0) % palette.length;
    return palette[idx];
  }

  Color _boothBorderColor(String section) {
    // Adjust borders for special dark-mode overrides to keep harmony
    if (isDark) {
      if (section == 'O') return const Color(0xFF7E57C2); // deepPurple 400
      if (section == 'G') return const Color(0xFF26A69A); // teal 400
    }

    List<Color> palette = const [
      Color(0xFF1976D2), // blue 700
      Color(0xFF388E3C), // green 600
      Color(0xFFEF6C00), // orange 800
      Color(0xFF7B1FA2), // purple 700
      Color(0xFFD32F2F), // red 700
      Color(0xFF00838F), // cyan 800
      Color(0xFF558B2F), // light green 700
      Color(0xFFFF8F00), // amber 800
    ];
    final idx = section.codeUnitAt(0) % palette.length;
    return palette[idx];
  }

  // Hall-specific background colors
  Color _getHallColor(String content) {
    // Extract hall number from content (e.g., "HALL 7" -> "7")
    final match = RegExp(r'HALL\s+(\d+)', caseSensitive: false).firstMatch(content);
    if (match == null) {
      // Fallback color if parsing fails
      return isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0);
    }
    
    final hallNumber = match.group(1)!;
    
    // Define distinct color palettes for each hall
    switch (hallNumber) {
      case '7':
        return isDark 
            ? const Color(0xFF1A237E) // Deep blue for dark mode
            : const Color(0xFFE3F2FD); // Light blue for light mode
      case '8':
        return isDark 
            ? const Color(0xFF1B5E20) // Deep green for dark mode
            : const Color(0xFFE8F5E9); // Light green for light mode
      case '9':
        return isDark 
            ? const Color(0xFF4A148C) // Deep purple for dark mode
            : const Color(0xFFF3E5F5); // Light purple for light mode
      default:
        // Fallback for any other hall numbers
        return isDark 
            ? const Color(0xFF424242) // Dark grey for dark mode
            : const Color(0xFFF5F5F5); // Light grey for light mode
    }
  }

  // Hall-specific border colors
  Color _getHallBorderColor(String content) {
    // Extract hall number from content (e.g., "HALL 7" -> "7")
    final match = RegExp(r'HALL\s+(\d+)', caseSensitive: false).firstMatch(content);
    if (match == null) {
      // Fallback color if parsing fails
      return isDark ? const Color(0xFF4A4A4A) : const Color(0xFF9E9E9E);
    }
    
    final hallNumber = match.group(1)!;
    
    // Define distinct border colors for each hall (darker than fill for contrast)
    switch (hallNumber) {
      case '7':
        return isDark 
            ? const Color(0xFF283593) // Darker blue for dark mode
            : const Color(0xFF1976D2); // Blue for light mode
      case '8':
        return isDark 
            ? const Color(0xFF2E7D32) // Darker green for dark mode
            : const Color(0xFF388E3C); // Green for light mode
      case '9':
        return isDark 
            ? const Color(0xFF6A1B9A) // Darker purple for dark mode
            : const Color(0xFF7B1FA2); // Purple for light mode
      default:
        // Fallback for any other hall numbers
        return isDark 
            ? const Color(0xFF616161) // Dark grey for dark mode
            : const Color(0xFF9E9E9E); // Light grey for light mode
    }
  }

  @override
  bool shouldRepaint(MapPainter oldDelegate) {
    // Only repaint if cellSize, data, or theme changed
    final shouldRepaint = oldDelegate.cellSize != cellSize ||
        oldDelegate.mergedCells != mergedCells ||
        oldDelegate.isDark != isDark;
    return shouldRepaint;
  }
}

// Separate painter for hover overlay - only repaints this layer
class HoverOverlayPainter extends CustomPainter {
  final MergedCell? hoveredCell;
  final double cellSize;
  final bool isDark;

  HoverOverlayPainter({
    required this.hoveredCell,
    required this.cellSize,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (hoveredCell == null) return;

    final cell = hoveredCell!;
    final left = cell.startCol * cellSize;
    final top = cell.startRow * cellSize;
    final width = cell.colSpan * cellSize;
    final height = cell.rowSpan * cellSize;

    final rect = Rect.fromLTWH(left + 0.5, top + 0.5, width - 1, height - 1);
    
    // Draw hover fill
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = isDark 
          ? const Color(0x40BBDEFB) // Semi-transparent light blue for dark mode
          : const Color(0x80E3F2FD); // Semi-transparent light blue for light mode
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      fillPaint,
    );
    
    // Draw hover border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = isDark 
          ? const Color(0xFF64B5F6) // Lighter blue for dark mode
          : const Color(0xFF2196F3)
      ..strokeWidth = 2.0;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(HoverOverlayPainter oldDelegate) {
    return oldDelegate.hoveredCell != hoveredCell || oldDelegate.isDark != isDark;
  }
}

// Separate painter for selection overlay - only repaints this layer
class SelectionOverlayPainter extends CustomPainter {
  final List<MergedCell> selectedCells;
  final double cellSize;
  final bool isDark;

  SelectionOverlayPainter({
    required this.selectedCells,
    required this.cellSize,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (selectedCells.isEmpty) return;

    final useRoundedCorners = cellSize >= 20;
    final cornerRadius = cellSize >= 60
        ? const Radius.circular(6)
        : (cellSize >= 40 ? const Radius.circular(4) : const Radius.circular(2));
    
    // Scale stroke subtly with zoom for visual consistency
    final zoomScale = (cellSize / 40.0).clamp(0.8, 2.0);
    
    // Only draw text if zoomed in enough
    final shouldDrawText = cellSize >= 30;
    
    for (final cell in selectedCells) {
      final left = cell.startCol * cellSize;
      final top = cell.startRow * cellSize;
      final width = cell.colSpan * cellSize;
      final height = cell.rowSpan * cellSize;

      final rect = Rect.fromLTWH(left + 0.5, top + 0.5, width - 1, height - 1);
      
      // Draw selection fill overlay
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        // White-ish overlay in dark mode, dark blue in light mode
        ..color = isDark 
            ? const Color.fromARGB(255, 255, 250, 180) // Semi-transparent white
            : const Color.fromARGB(255, 255, 128, 9); // Semi-transparent deep blue
      
      if (useRoundedCorners && !cell.isHall) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, cornerRadius),
          fillPaint,
        );
      } else {
        canvas.drawRect(rect, fillPaint);
      }
      
      // Draw selection border
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        // Bright yellow in dark mode, deep blue in light mode
        ..color = isDark ? const Color.fromARGB(255, 253, 173, 53) : const Color.fromARGB(255, 206, 102, 41)
        ..strokeWidth = 3.0 * zoomScale;
      
      if (useRoundedCorners && !cell.isHall) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, cornerRadius),
          borderPaint,
        );
      } else {
        canvas.drawRect(rect, borderPaint);
      }
      
      // Draw text if zoomed in and cell is large enough
      if (shouldDrawText && cell.content.isNotEmpty && width > 20 && height > 15) {
        _drawText(canvas, cell, rect);
      }
    }
  }

  String _getDisplayText(MergedCell cell) {
    if (cell.isBooth) {
      // Extract just the number from booth IDs (e.g., "O-33a" -> "33")
      final match = RegExp(r'\d+').firstMatch(cell.content);
      if (match != null) {
        return match.group(0)!;
      }
    }
    return cell.content;
  }

  void _drawText(Canvas canvas, MergedCell cell, Rect rect) {
    final textStyle = _getTextStyle(cell);
    final displayText = _getDisplayText(cell);
    final textSpan = TextSpan(
      text: displayText,
      style: textStyle,
    );

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: cell.rowSpan,
      ellipsis: '...',
    );

    textPainter.layout(maxWidth: rect.width - 4);

    // Center the text in the rect
    final xCenter = rect.left + (rect.width - textPainter.width) / 2;
    final yCenter = rect.top + (rect.height - textPainter.height) / 2;

    textPainter.paint(canvas, Offset(xCenter, yCenter));
  }

  TextStyle _getTextStyle(MergedCell cell) {
    if (cell.isBooth) {
      // When highlighted: dark text on bright/white overlay (dark mode), white text on dark blue (light mode)
      Color textColor;
      if (isDark) {
        textColor = Colors.black; // Dark text on bright overlay
      } else {
        textColor = Colors.white; // White text on dark overlay
      }
      return TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: textColor,
        fontFamily: 'Roboto',
      );
    }
    return TextStyle(
      fontSize: 14,
      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
      fontFamily: 'Roboto',
    );
  }

  @override
  bool shouldRepaint(SelectionOverlayPainter oldDelegate) {
    return oldDelegate.selectedCells != selectedCells || oldDelegate.isDark != isDark;
  }
}


