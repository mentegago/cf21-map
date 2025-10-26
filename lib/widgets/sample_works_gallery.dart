import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

/// Shows a responsive gallery dialog for sample works images
Future<void> showSampleWorksGallery({
  required BuildContext context,
  required List<String> imageUrls,
  int initialIndex = 0,
}) {
  return showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive sizing: full screen on mobile, constrained on desktop
          final isWideScreen = constraints.maxWidth > 600;
          final dialogWidth = isWideScreen 
              ? constraints.maxWidth * 0.9 
              : constraints.maxWidth;
          final dialogHeight = isWideScreen 
              ? constraints.maxHeight * 0.9 
              : constraints.maxHeight;

          return Center(
            child: Container(
              width: dialogWidth,
              height: dialogHeight,
              constraints: BoxConstraints(
                maxWidth: isWideScreen ? 1200 : double.infinity,
                maxHeight: isWideScreen ? 900 : double.infinity,
              ),
              child: SampleWorksGallery(
                imageUrls: imageUrls,
                initialIndex: initialIndex,
              ),
            ),
          );
        },
      ),
    ),
  );
}

class SampleWorksGallery extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const SampleWorksGallery({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<SampleWorksGallery> createState() => _SampleWorksGalleryState();
}

class _SampleWorksGalleryState extends State<SampleWorksGallery> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, PhotoViewController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    // Initialize controllers for all pages
    for (int i = 0; i < widget.imageUrls.length; i++) {
      _controllers[i] = PhotoViewController();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadImages();
    });
  }

  void _preloadImages() async {
    for (var imageUrl in widget.imageUrls) {
      try {
        if (!context.mounted) break;
        await precacheImage(CachedNetworkImageProvider(imageUrl), context);
      } catch (e) { continue; }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    
    // Reset zoom and pan by recreating the controller
    final controller = _controllers[index];
    if (controller != null) {
      controller.dispose();
      _controllers[index] = PhotoViewController();
    }
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNext() {
    if (_currentIndex < widget.imageUrls.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Photo Gallery
        Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              final controller = _controllers[_currentIndex];
              if (controller != null && controller.scale != null) {
                final currentScale = controller.scale!;
                // Scroll down (dy > 0) = zoom out, scroll up (dy < 0) = zoom in
                final double scaleChange = event.scrollDelta.dy > 0 ? -0.1 : 0.1;
                final double newScale = (currentScale + scaleChange).clamp(0.3, 4.0);
                
                // Preserve the current pan position by adjusting it proportionally
                final currentPosition = controller.position;
                // Adjust position to keep the same visible area centered
                final scaleRatio = newScale / currentScale;
                final newPosition = Offset(
                  currentPosition.dx * scaleRatio,
                  currentPosition.dy * scaleRatio,
                );
                controller.position = newPosition;
                              
                controller.scale = newScale;
              }
            }
          },
          child: PhotoViewGallery.builder(
            scrollPhysics: const BouncingScrollPhysics(),
            builder: (BuildContext context, int index) {
              final controller = _controllers[index] ?? PhotoViewController();
              return PhotoViewGalleryPageOptions(
                imageProvider: CachedNetworkImageProvider(widget.imageUrls[index]),
                controller: controller,
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3,
                heroAttributes: PhotoViewHeroAttributes(
                  tag: 'sample_work_$index',
                ),
              );
            },
            itemCount: widget.imageUrls.length,
            loadingBuilder: (context, event) => Center(
              child: SizedBox(
                width: 40.0,
                height: 40.0,
                child: CircularProgressIndicator(
                  value: event == null
                      ? 0
                      : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
                  color: Colors.white,
                ),
              ),
            ),
            backgroundDecoration: const BoxDecoration(
              color: Colors.black,
            ),
            pageController: _pageController,
            onPageChanged: _onPageChanged,
          ),
        ),

        // Close button (top-right)
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              iconSize: 28,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),

        // Page indicator (top-center)
        if (widget.imageUrls.length > 1)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${widget.imageUrls.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

        // Navigation arrows (only show on desktop/wide screens with multiple images)
        if (widget.imageUrls.length > 1)
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // Previous button (left)
                  if (_currentIndex > 0)
                    Positioned(
                      left: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.chevron_left, color: Colors.white),
                            iconSize: 32,
                            tooltip: 'Previous',
                            onPressed: _goToPrevious,
                          ),
                        ),
                      ),
                    ),

                  // Next button (right)
                  if (_currentIndex < widget.imageUrls.length - 1)
                    Positioned(
                      right: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.chevron_right, color: Colors.white),
                            iconSize: 32,
                            tooltip: 'Next',
                            onPressed: _goToNext,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}
