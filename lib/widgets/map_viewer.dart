import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/map_cell.dart';

class MapViewer extends StatefulWidget {
  final List<MergedCell> mergedCells;
  final int rows;
  final int cols;
  final List<String>? highlightedBooths;
  final Function(String?)? onBoothTap;
  final bool shouldCenterOnHighlight;

  const MapViewer({
    super.key,
    required this.mergedCells,
    required this.rows,
    required this.cols,
    this.highlightedBooths,
    this.onBoothTap,
    this.shouldCenterOnHighlight = true,
  });

  @override
  State<MapViewer> createState() => _MapViewerState();
}

class _MapViewerState extends State<MapViewer> {
  final TransformationController _transformationController = TransformationController();
  double _cellSize = 40.0;
  String? _hoveredBooth;
  late List<List<String?>> _boothLookupGrid; // O(1) spatial lookup

  @override
  void initState() {
    super.initState();
    _buildBoothLookupGrid();
  }

  @override
  void dispose() {
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
    
    if (widget.shouldCenterOnHighlight &&
        widget.highlightedBooths != oldWidget.highlightedBooths && 
        widget.highlightedBooths != null && widget.highlightedBooths!.isNotEmpty) {
      _centerOnBooths(widget.highlightedBooths!);
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
    final viewportWidth = MediaQuery.of(context).size.width;
    final viewportHeight = MediaQuery.of(context).size.height;

    // Get the current scale from the transformation
    final currentTransform = _transformationController.value;
    final currentScale = currentTransform.getMaxScaleOnAxis();

    // Calculate the translation to center the booths (keeping current zoom)
    final translationX = viewportWidth / 2 - avgX * currentScale;
    final translationY = viewportHeight / 2 - avgY * currentScale;

    // Animate to the booths with current zoom level
    final newTransform = Matrix4.identity()
      ..translate(translationX, translationY)
      ..scale(currentScale);

    setState(() {
      _transformationController.value = newTransform;
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
    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 0.1,
      maxScale: 10.0,
      boundaryMargin: const EdgeInsets.all(double.infinity),
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
              // Main map (doesn't repaint on hover)
              RepaintBoundary(
                child: CustomPaint(
                  size: Size(
                    widget.cols * _cellSize,
                    widget.rows * _cellSize,
                  ),
                  painter: MapPainter(
                    mergedCells: widget.mergedCells,
                    cellSize: _cellSize,
                    highlightedBooths: widget.highlightedBooths,
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
  final List<String>? highlightedBooths;

  MapPainter({
    required this.mergedCells,
    required this.cellSize,
    this.highlightedBooths,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFF5F5F5),
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
      final isHighlighted = highlightedBooths != null && highlightedBooths!.contains(cell.content);

      // Draw base fill using a more refined palette
      Color fillColor = _getCellColor(cell);
      fillPaint.color = fillColor;
      if (useRoundedCorners) {
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
      if (isHighlighted) {
        // Strong indigo border to stand out from orange sections
        borderColor = const Color(0xFF1565C0);
        strokeWidth = 3.0 * zoomScale;
      }
      borderPaint.color = borderColor;
      borderPaint.strokeWidth = strokeWidth;
      if (useRoundedCorners) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, cornerRadius),
          borderPaint,
        );
      } else {
        canvas.drawRect(rect, borderPaint);
      }

      // Subtle highlight overlay for selections (keeps original color visible)
      if (isHighlighted) {
        final overlay = Paint()
          ..style = PaintingStyle.fill
          // Subtle indigo overlay for clearer contrast on orange fills
          ..color = const Color(0x403D5AFE);
        if (useRoundedCorners) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, cornerRadius),
            overlay,
          );
        } else {
          canvas.drawRect(rect, overlay);
        }
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
    } else if (cell.isBooth) {
      // Light fill color per booth section
      final section = _getBoothSection(cell.content);
      return _boothFillColor(section);
    } else if (cell.isLocationMarker) {
      if (cell.content == 'a' || cell.content == 'b') {
        return const Color(0xFFEEEEEE); // Colors.grey.shade200
      }
      return const Color(0xFFFFE0B2); // Colors.orange.shade100
    }
    return const Color(0xFFE0E0E0); // Colors.grey.shade300
  }

  Color _getBorderColor(MergedCell cell) {
    if (cell.isEmpty) {
      return Colors.transparent;
    } else if (cell.isBooth) {
      final section = _getBoothSection(cell.content);
      return _boothBorderColor(section);
    } else if (cell.isLocationMarker) {
      if (cell.content == 'a' || cell.content == 'b') {
        return const Color(0xFFBDBDBD); // Colors.grey.shade400
      }
      return const Color(0xFFE64A19); // Colors.orange.shade700
    }
    return const Color(0xFF9E9E9E); // Colors.grey.shade500
  }

  TextStyle _getTextStyle(MergedCell cell) {
    if (cell.isBooth) {
      return const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF0D47A1), // Colors.blue.shade900
      );
    } else if (cell.isLocationMarker && cell.content != 'a' && cell.content != 'b') {
      return const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Color(0xFFE65100), // Colors.orange.shade900
      );
    }
    return const TextStyle(
      fontSize: 14,
      color: Colors.grey,
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

  // Soft, readable pastel fills per section group
  Color _boothFillColor(String section) {
    List<Color> palette = const [
      Color(0xFFE3F2FD), // blue 50
      Color(0xFFE8F5E9), // green 50
      Color(0xFFFFF3E0), // orange 50
      Color(0xFFF3E5F5), // purple 50
      Color(0xFFFFEBEE), // red 50
      Color(0xFFE0F7FA), // cyan 50
      Color(0xFFF1F8E9), // light green 50
      Color(0xFFFFF8E1), // amber 50
    ];
    final idx = section.codeUnitAt(0) % palette.length;
    return palette[idx];
  }

  Color _boothBorderColor(String section) {
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

  @override
  bool shouldRepaint(MapPainter oldDelegate) {
    // Only repaint if cellSize, data, or highlighted booths changed
    final shouldRepaint = oldDelegate.cellSize != cellSize ||
        oldDelegate.mergedCells != mergedCells ||
        oldDelegate.highlightedBooths != highlightedBooths;
    return shouldRepaint;
  }
}

// Separate painter for hover overlay - only repaints this layer
class HoverOverlayPainter extends CustomPainter {
  final MergedCell? hoveredCell;
  final double cellSize;

  HoverOverlayPainter({
    required this.hoveredCell,
    required this.cellSize,
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
      ..color = const Color(0x80E3F2FD); // Semi-transparent light blue
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      fillPaint,
    );
    
    // Draw hover border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF2196F3)
      ..strokeWidth = 2.0;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(HoverOverlayPainter oldDelegate) {
    return oldDelegate.hoveredCell != hoveredCell;
  }
}


