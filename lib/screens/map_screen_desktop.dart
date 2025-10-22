import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/creator.dart';
import '../models/map_cell.dart';
import '../services/creator_data_service.dart';
import '../widgets/desktop/desktop_sidebar.dart';
import '../widgets/fab_button.dart';
import '../widgets/map_viewer.dart';
import '../widgets/version_notification.dart';

class MapScreenDesktopView extends StatelessWidget {
  final List<MergedCell> mergedCells;
  final int rows;
  final int cols;
  final ValueChanged<Creator> onCreatorSelected;
  final Future<void> Function()? onClearSelection;
  final void Function(String?) onBoothTap;

  const MapScreenDesktopView({
    super.key,
    required this.mergedCells,
    required this.rows,
    required this.cols,
    required this.onCreatorSelected,
    required this.onClearSelection,
    required this.onBoothTap,
  });

  @override
  Widget build(BuildContext context) {
    final creators = context.select((CreatorDataProvider p) => p.creators);
    final selectedCreator = context.select((CreatorDataProvider p) => p.selectedCreator);

    return Row(
      children: [
        if (creators != null)
          DesktopSidebar(
            creators: creators,
            selectedCreator: selectedCreator,
            onCreatorSelected: onCreatorSelected,
            onClear: selectedCreator != null && onClearSelection != null
                ? () {
                    final clear = onClearSelection;
                    if (clear != null) {
                      clear();
                    }
                  }
                : null,
          ),
        Expanded(
          child: Stack(
            children: [
              MapViewer(
                mergedCells: mergedCells,
                rows: rows,
                cols: cols,
                onBoothTap: onBoothTap,
              ),
              const FABButton(isDesktop: true),
              const VersionNotification(isDesktop: true),
            ],
          ),
        ),
      ],
    );
  }
}
