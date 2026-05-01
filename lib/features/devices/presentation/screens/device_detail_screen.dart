import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/device_model.dart';
import '../providers/device_provider.dart';
import '../widgets/device_control_widget.dart';

/// Detailed view for a single IoT device.
class DeviceDetailScreen extends ConsumerWidget {
  const DeviceDetailScreen({super.key, required this.device});

  final DeviceModel device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceState = ref.watch(deviceStateProvider(device));
    final notifier = ref.read(deviceStateProvider(device).notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(deviceState.displayName),
        actions: [
          // Refresh status
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => notifier.refreshStatus(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status card
          _StatusCard(device: deviceState),
          const SizedBox(height: 16),

          // Control widget
          DeviceControlWidget(device: deviceState),
          const SizedBox(height: 16),

          // Device info card
          _InfoCard(device: deviceState),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.device});

  final DeviceModel device;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: device.isOnline
              ? Colors.green.withOpacity(0.15)
              : Colors.grey.withOpacity(0.15),
          child: Icon(
            device.isOnline ? Icons.wifi : Icons.wifi_off,
            color: device.isOnline ? Colors.green : Colors.grey,
          ),
        ),
        title: Text(
          device.isOnline ? 'Online' : 'Offline',
          style: TextStyle(
            color: device.isOnline ? Colors.green : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          device.isPoweredOn ? 'Powered On' : 'Powered Off',
          style: TextStyle(
            color: device.isPoweredOn
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
        trailing: Icon(
          device.isPoweredOn ? Icons.power : Icons.power_off,
          color: device.isPoweredOn
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withOpacity(0.4),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.device});

  final DeviceModel device;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Device Info',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            _InfoRow(label: 'Brand', value: device.brand.name.toUpperCase()),
            _InfoRow(label: 'Type', value: device.type.name),
            if (device.model != null) _InfoRow(label: 'Model', value: device.model!),
            if (device.ipAddress != null)
              _InfoRow(label: 'IP Address', value: device.ipAddress!),
            if (device.macAddress != null)
              _InfoRow(label: 'MAC Address', value: device.macAddress!),
            if (device.firmwareVersion != null)
              _InfoRow(label: 'Firmware', value: device.firmwareVersion!),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
