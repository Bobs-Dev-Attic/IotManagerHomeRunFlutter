import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/device_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/device_provider.dart';
import '../widgets/device_card.dart';
import 'add_device_screen.dart';
import 'device_detail_screen.dart';

/// Main screen showing all registered IoT devices.
class DeviceListScreen extends ConsumerWidget {
  const DeviceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(devicesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('IoT Manager'),
        actions: [
          IconButton(
            tooltip: 'Developer Mode',
            icon: const Icon(Icons.developer_mode),
            onPressed: () =>
                Navigator.of(context).pushNamed('/developer-mode'),
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/', (_) => false);
              }
            },
          ),
        ],
      ),
      body: devicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text('Error: $e'),
            ],
          ),
        ),
        data: (devices) {
          if (devices.isEmpty) {
            return _EmptyState(
              onAddDevice: () => _navigateToAdd(context),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(devicesStreamProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return DeviceCard(
                  device: device,
                  onTap: () => _navigateToDetail(context, device),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAdd(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Device'),
      ),
    );
  }

  void _navigateToDetail(BuildContext context, DeviceModel device) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeviceDetailScreen(device: device),
      ),
    );
  }

  void _navigateToAdd(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddDeviceScreen()),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddDevice});

  final VoidCallback onAddDevice;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.device_hub_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          const Text(
            'No devices yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the button below to add your first device.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAddDevice,
            icon: const Icon(Icons.add),
            label: const Text('Add Device'),
          ),
        ],
      ),
    );
  }
}
