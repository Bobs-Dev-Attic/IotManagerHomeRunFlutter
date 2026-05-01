import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/driver_config.dart';
import '../../../devices/presentation/providers/device_provider.dart';
import 'driver_config_screen.dart';

/// Developer Mode screen — lists all registered drivers and allows the user
/// to configure and test each one via the JSON config UI.
class DeveloperModeScreen extends ConsumerWidget {
  const DeveloperModeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.read(driverManagerProvider);
    final drivers = manager.registeredDrivers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Mode'),
        actions: [
          IconButton(
            tooltip: 'About',
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAboutDialog(context),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Developer mode warning banner
          Container(
            width: double.infinity,
            color: Colors.orange.withOpacity(0.12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Developer Mode is active. All registered drivers are '
                    'listed below. Drop a new driver class into lib/drivers/ '
                    'to make it appear here.',
                    style: TextStyle(color: Colors.orange[800], fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Driver list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: drivers.length,
              itemBuilder: (context, index) {
                final driver = drivers[index];
                return _DriverListTile(
                  driverId: driver.driverId,
                  displayName: driver.displayName,
                  configSchema: driver.configSchema,
                  onConfigure: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DriverConfigScreen(
                          driverId: driver.driverId,
                          displayName: driver.displayName,
                          configSchema: driver.configSchema,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'IoT Manager',
      applicationVersion: '1.0.0',
      children: const [
        Text(
          'Developer Mode allows you to inspect and configure registered '
          'device drivers.\n\n'
          'To add a new driver, create a class extending BaseDeviceDriver '
          'in lib/drivers/ and register it in the driverManagerProvider.',
        ),
      ],
    );
  }
}

class _DriverListTile extends StatelessWidget {
  const _DriverListTile({
    required this.driverId,
    required this.displayName,
    required this.configSchema,
    required this.onConfigure,
  });

  final String driverId;
  final String displayName;
  final List<DriverConfigField> configSchema;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          child: Icon(
            Icons.extension,
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Driver ID: $driverId  ·  ${configSchema.length} config field(s)',
        ),
        trailing: FilledButton.tonal(
          onPressed: onConfigure,
          child: const Text('Configure'),
        ),
      ),
    );
  }
}
