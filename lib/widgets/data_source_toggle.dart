import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/creator.dart';
import '../services/data_source_manager.dart';

class DataSourceToggle extends StatelessWidget {
  const DataSourceToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DataSourceManager>(
      builder: (context, dataSourceManager, child) {
        final currentSource = dataSourceManager.preferredDataSource;
        final isLoading = dataSourceManager.isLoading;

        return FloatingActionButton.extended(
          onPressed: isLoading
              ? null
              : () => _showDataSourceDialog(context, dataSourceManager),
          backgroundColor: currentSource == DataSource.catalog
              ? Colors.blue
              : Colors.orange,
          foregroundColor: Colors.white,
          icon: Icon(
            currentSource == DataSource.catalog
                ? Icons.cloud
                : Icons.storage,
          ),
          label: Text(
            isLoading
                ? 'Loading...'
                : currentSource.shortName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  void _showDataSourceDialog(BuildContext context, DataSourceManager dataSourceManager) {
    final stats = dataSourceManager.getStatistics();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Data Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose which data source to use for booth information:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Statistics
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Data Statistics:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('📊 Local Data: ${stats['totalLocal']} creators'),
                  Text('☁️ Catalog Data: ${stats['totalCatalog']} creators'),
                  Text('🔄 Combined: ${stats['totalCombined']} creators'),
                  Text('❓ Missing in Catalog: ${stats['missingInCatalog']} creators'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Data source options
            _buildDataSourceOption(
              context: context,
              source: DataSource.catalog,
              title: 'Online Catalog (Recommended)',
              description: 'Rich data from live catalog API with images, social media, and detailed info.',
              icon: Icons.cloud,
              color: Colors.blue,
              dataSourceManager: dataSourceManager,
            ),
            const SizedBox(height: 8),
            _buildDataSourceOption(
              context: context,
              source: DataSource.local,
              title: 'Local Data Only',
              description: 'Basic booth information from local files. More complete but less detailed.',
              icon: Icons.storage,
              color: Colors.orange,
              dataSourceManager: dataSourceManager,
            ),

            const SizedBox(height: 16),
            const Text(
              '💡 Tip: Online Catalog shows richer information, but Local Data may have more booths.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSourceOption({
    required BuildContext context,
    required DataSource source,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required DataSourceManager dataSourceManager,
  }) {
    final isSelected = dataSourceManager.preferredDataSource == source;

    return InkWell(
      onTap: () {
        dataSourceManager.setPreferredDataSource(source);
        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? color.withOpacity(0.1) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
