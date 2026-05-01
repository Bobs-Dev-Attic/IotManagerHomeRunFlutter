import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/device_model.dart';
import '../providers/device_provider.dart';

/// A reusable widget that renders the appropriate controls (toggle switch,
/// brightness slider) based on the device's type and capabilities.
class DeviceControlWidget extends ConsumerWidget {
  const DeviceControlWidget({super.key, required this.device});

  final DeviceModel device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(deviceStateProvider(device).notifier);
    final deviceState = ref.watch(deviceStateProvider(device));
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Controls',
              style: theme.textTheme.titleMedium,
            ),
            const Divider(),

            // Power toggle
            SwitchListTile(
              value: deviceState.isPoweredOn,
              onChanged: deviceState.isOnline
                  ? (v) => notifier.toggle()
                  : null,
              title: const Text('Power'),
              subtitle: Text(deviceState.isPoweredOn ? 'On' : 'Off'),
              secondary: Icon(
                deviceState.isPoweredOn
                    ? Icons.lightbulb
                    : Icons.lightbulb_outline,
                color: deviceState.isPoweredOn
                    ? theme.colorScheme.primary
                    : Colors.grey,
              ),
            ),

            // Brightness slider (only for dimmers and colour bulbs)
            if (deviceState.type == DeviceType.dimmerSwitch ||
                deviceState.type == DeviceType.colorBulb) ...[
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.brightness_6),
                title: const Text('Brightness'),
                subtitle: Slider(
                  value: deviceState.brightness ?? 1.0,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  label:
                      '${((deviceState.brightness ?? 1.0) * 100).round()}%',
                  onChanged: deviceState.isOnline && deviceState.isPoweredOn
                      ? (v) => notifier.setBrightness(v)
                      : null,
                ),
                trailing: Text(
                  '${((deviceState.brightness ?? 1.0) * 100).round()}%',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],

            if (!deviceState.isOnline)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Device is offline — controls disabled',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
