import 'package:flutter/material.dart';

import '../../../../core/models/device_model.dart';

/// A card widget representing a single IoT device in the list view.
class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.device,
    required this.onTap,
  });

  final DeviceModel device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Brand icon
              CircleAvatar(
                radius: 26,
                backgroundColor:
                    theme.colorScheme.primaryContainer,
                child: Icon(
                  _iconForBrand(device.brand),
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),

              // Name + status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _brandLabel(device.brand),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _StatusDot(isOnline: device.isOnline),
                        const SizedBox(width: 4),
                        Text(
                          device.isOnline ? 'Online' : 'Offline',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                device.isOnline ? Colors.green : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          device.isPoweredOn
                              ? Icons.lightbulb
                              : Icons.lightbulb_outline,
                          size: 14,
                          color: device.isPoweredOn
                              ? theme.colorScheme.primary
                              : Colors.grey,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          device.isPoweredOn ? 'On' : 'Off',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: device.isPoweredOn
                                ? theme.colorScheme.primary
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Chevron
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForBrand(DeviceBrand brand) {
    switch (brand) {
      case DeviceBrand.kasa:
        return Icons.electrical_services;
      case DeviceBrand.cync:
        return Icons.lightbulb;
      case DeviceBrand.leviton:
        return Icons.toggle_on;
      case DeviceBrand.matter:
        return Icons.hub;
      case DeviceBrand.unknown:
        return Icons.device_unknown;
    }
  }

  String _brandLabel(DeviceBrand brand) {
    switch (brand) {
      case DeviceBrand.kasa:
        return 'TP-Link Kasa';
      case DeviceBrand.cync:
        return 'GE Cync';
      case DeviceBrand.leviton:
        return 'Leviton Decora Smart';
      case DeviceBrand.matter:
        return 'Matter';
      case DeviceBrand.unknown:
        return 'Unknown';
    }
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline ? Colors.green : Colors.grey,
      ),
    );
  }
}
