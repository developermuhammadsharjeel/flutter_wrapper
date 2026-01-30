import 'package:flutter/material.dart';

class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key, required this.onRetry, this.onViewCached});

  final VoidCallback onRetry;
  final VoidCallback? onViewCached;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'You are offline',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check your connection and try again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
                if (onViewCached != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: onViewCached,
                    child: const Text('View cached page'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
