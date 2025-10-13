import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

class GitHubButton extends StatelessWidget {
  const GitHubButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final githubIcon = isDark ? 'assets/github-mark-white.svg' : 'assets/github-mark.svg';
    
    return Positioned(
      bottom: 16,
      right: 16,
      child: Container(
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              spacing: 8,
              children: [
                SvgPicture.asset(
                  githubIcon,
                  width: 24,
                  height: 24,
                ),
                const Text("Source Code"),
              ],
            ),
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
