import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/models/device_model.dart';
import '../providers/device_provider.dart';

/// Screen for adding a new device to the registry.
class AddDeviceScreen extends ConsumerStatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  ConsumerState<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends ConsumerState<AddDeviceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ipController = TextEditingController();
  final _macController = TextEditingController();
  final _modelController = TextEditingController();

  DeviceBrand _selectedBrand = DeviceBrand.kasa;
  DeviceType _selectedType = DeviceType.smartPlug;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    _macController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      const uuid = Uuid();
      final device = DeviceModel(
        deviceId: uuid.v4(),
        userId: '', // filled in by the service
        displayName: _nameController.text.trim(),
        brand: _selectedBrand,
        type: _selectedType,
        ipAddress: _ipController.text.trim().isEmpty
            ? null
            : _ipController.text.trim(),
        macAddress: _macController.text.trim().isEmpty
            ? null
            : _macController.text.trim(),
        model: _modelController.text.trim().isEmpty
            ? null
            : _modelController.text.trim(),
        createdAt: DateTime.now(),
      );

      final service = ref.read(deviceRegistryServiceProvider);
      await service.addDevice(device);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device added successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Device')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Device name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Device Name *',
                hintText: 'e.g. Living Room Lamp',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.devices),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),

            // Brand picker
            DropdownButtonFormField<DeviceBrand>(
              value: _selectedBrand,
              decoration: const InputDecoration(
                labelText: 'Brand *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              items: DeviceBrand.values
                  .where((b) => b != DeviceBrand.unknown)
                  .map(
                    (b) => DropdownMenuItem(
                      value: b,
                      child: Text(_brandLabel(b)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedBrand = v!),
            ),
            const SizedBox(height: 16),

            // Type picker
            DropdownButtonFormField<DeviceType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Device Type *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: DeviceType.values
                  .where((t) => t != DeviceType.unknown)
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(_typeLabel(t)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedType = v!),
            ),
            const SizedBox(height: 16),

            // IP address (optional for cloud devices)
            TextFormField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'IP Address',
                hintText: '192.168.1.100',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.router),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),

            // MAC address
            TextFormField(
              controller: _macController,
              decoration: const InputDecoration(
                labelText: 'MAC Address',
                hintText: 'AA:BB:CC:DD:EE:FF',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.memory),
              ),
            ),
            const SizedBox(height: 16),

            // Model
            TextFormField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: 'Model',
                hintText: 'e.g. KP115',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.info_outline),
              ),
            ),
            const SizedBox(height: 32),

            // Save button
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save Device'),
            ),
          ],
        ),
      ),
    );
  }

  String _brandLabel(DeviceBrand brand) {
    switch (brand) {
      case DeviceBrand.kasa:
        return 'TP-Link Kasa';
      case DeviceBrand.cync:
        return 'GE Cync';
      case DeviceBrand.leviton:
        return 'Leviton';
      case DeviceBrand.matter:
        return 'Matter';
      case DeviceBrand.unknown:
        return 'Unknown';
    }
  }

  String _typeLabel(DeviceType type) {
    switch (type) {
      case DeviceType.smartPlug:
        return 'Smart Plug';
      case DeviceType.dimmerSwitch:
        return 'Dimmer Switch';
      case DeviceType.colorBulb:
        return 'Color Bulb';
      case DeviceType.sensor:
        return 'Sensor';
      case DeviceType.unknown:
        return 'Unknown';
    }
  }
}
