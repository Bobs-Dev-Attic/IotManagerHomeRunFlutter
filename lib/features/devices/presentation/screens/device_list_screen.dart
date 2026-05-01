import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/device_model.dart';
import '../../../../core/utils/user_facing_error.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/device_provider.dart';
import '../widgets/device_card.dart';
import 'add_device_screen.dart';
import 'device_detail_screen.dart';

final onboardingSeenProvider = StateProvider<bool>((_) => false);

class DeviceListScreen extends ConsumerWidget {
  const DeviceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(devicesStreamProvider);
    final showOnboarding = !ref.watch(onboardingSeenProvider);

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
              await ref.read(driverManagerProvider).disposeAll();
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
        error: (e, _) => Center(child: Text(remediationMessageForError(e))),
        data: (devices) {
          if (devices.isEmpty) {
            return _EmptyState(
              onAddDevice: () => _navigateToAdd(context),
              showOnboarding: showOnboarding,
              onDismissOnboarding: () =>
                  ref.read(onboardingSeenProvider.notifier).state = true,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(devicesStreamProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: devices.length + (showOnboarding ? 1 : 0),
              itemBuilder: (context, index) {
                if (showOnboarding && index == 0) {
                  return _OnboardingCard(
                    onDismiss: () =>
                        ref.read(onboardingSeenProvider.notifier).state = true,
                  );
                }
                final adjusted = showOnboarding ? index - 1 : index;
                final device = devices[adjusted];
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

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({required this.onDismiss});
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: const Text('Before you start'),
        subtitle: const Text('Grant local network permission for local drivers, link cloud accounts only when needed, and review privacy settings in README.'),
        trailing: TextButton(onPressed: onDismiss, child: const Text('Got it')),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddDevice, required this.showOnboarding, required this.onDismissOnboarding});

  final VoidCallback onAddDevice;
  final bool showOnboarding;
  final VoidCallback onDismissOnboarding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showOnboarding) _OnboardingCard(onDismiss: onDismissOnboarding),
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
