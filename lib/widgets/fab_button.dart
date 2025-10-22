import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/creator_data_service.dart';

class FABButton extends StatelessWidget {
  const FABButton({super.key, required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final githubIcon = isDark ? 'assets/github-mark-white.svg' : 'assets/github-mark.svg';
    
    return Positioned(
      bottom: 16,
      left: isDesktop ? 16 : null,
      right: isDesktop ? null : 16,
      child: Row(
        children: [
          _randomButton(context),
          const SizedBox(width: 8),
          _githubButton(context, githubIcon),
        ],
      ),
    );
  }

  Container _randomButton(BuildContext context) {
    return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.read<CreatorDataProvider>().selectRandomCreator(),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                spacing: 8,
                children: [
                  Icon(Icons.auto_awesome, size: 24),
                  Text("Surprise me!"),
                ],
              ),
            ),
          ),
        );
  }

  Container _githubButton(BuildContext context, String githubIcon) {
    return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _launchGitHubUrl(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: SvgPicture.asset(
                githubIcon,
                width: 24,
                height: 24,
              ),
            ),
          ),
        );
  }

  Future<void> _launchGitHubUrl() async {
    final url = Uri.parse('https://github.com/mentegago/cf21-map');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
