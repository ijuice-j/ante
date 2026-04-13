import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class PermissionDeniedView extends StatelessWidget {
  final VoidCallback onRequestPermission;
  final VoidCallback onOpenSettings;

  const PermissionDeniedView({
    super.key,
    required this.onRequestPermission,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with gradient background
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.accent.withValues(alpha: 0.2),
                    AppTheme.accent.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Icon(
                Icons.photo_library_outlined,
                size: 48,
                color: AppTheme.accent.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Access Your Gallery',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Grant photo access to browse and view all your memories in one place.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRequestPermission,
                child: const Text('Allow Access'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onOpenSettings,
              child: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
