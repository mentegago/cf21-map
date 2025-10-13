import 'package:flutter/material.dart';
import 'dart:html' as html;
import '../services/version_service.dart';

class VersionNotification extends StatefulWidget {
  const VersionNotification({super.key, required this.isDesktop});

  final bool isDesktop;

  @override
  State<VersionNotification> createState() => _VersionNotificationState();
}

class _VersionNotificationState extends State<VersionNotification>
    with SingleTickerProviderStateMixin {
  bool _isVisible = false;
  bool _isDismissed = false;
  VersionInfo? _versionInfo;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _checkForUpdates();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkForUpdates() async {
    try {
      final versionInfo = await VersionService.fetchVersionInfo();
      if (mounted && VersionService.isUpdateAvailable(versionInfo)) {
        setState(() {
          _versionInfo = versionInfo;
          _isVisible = true;
        });
        _animationController.forward();
      }
    } catch (e) {
      print('Error checking for updates: $e');
    }
  }

  void _dismiss() {
    setState(() {
      _isDismissed = true;
    });
    _animationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isVisible = false;
        });
      }
    });
  }

  void _refreshPage() {
    html.window.location.reload();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible || _isDismissed) {
      return const SizedBox.shrink();
    }

    return Positioned(
      width: widget.isDesktop ? 500 : null,
      bottom: widget.isDesktop ? 16 : 0,
      right: widget.isDesktop ? 16 : 0,
      left: widget.isDesktop ? null : 0,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            margin: widget.isDesktop 
                ? const EdgeInsets.all(0)
                : const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (_versionInfo?.releaseNotes.isNotEmpty ?? false)
                        ? _versionInfo!.releaseNotes
                        : "Please refresh the page to get the latest booth data.",
                      style: Theme.of(context).textTheme.bodyMedium,
                      softWrap: true,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        "Pastikan Anda berada di area yang sinyalnya baik sebelum menekan tombol refresh!",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withAlpha(200),
                            ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Spacer(),
                        MaterialButton(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          onPressed: _dismiss, 
                          child: Text(
                            'Nanti dulu', 
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        MaterialButton(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          color: Theme.of(context).colorScheme.primary,
                          onPressed: _refreshPage, 
                          child: Text('Refresh', style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.w500,
                          ),)
                          )
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
