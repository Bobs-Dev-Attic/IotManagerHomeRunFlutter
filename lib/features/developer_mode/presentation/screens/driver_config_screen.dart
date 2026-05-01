import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/models/driver_config.dart';

/// Screen that renders a dynamic JSON-based configuration form for a driver.
///
/// Each [DriverConfigField] in [configSchema] generates one form field.
/// On submission, the values are collected into a Map and shown as JSON —
/// in a real implementation they would be passed to [DriverManager.bindDevice].
class DriverConfigScreen extends StatefulWidget {
  const DriverConfigScreen({
    super.key,
    required this.driverId,
    required this.displayName,
    required this.configSchema,
    this.initialValues = const {},
  });

  final String driverId;
  final String displayName;
  final List<DriverConfigField> configSchema;
  final Map<String, dynamic> initialValues;

  @override
  State<DriverConfigScreen> createState() => _DriverConfigScreenState();
}

class _DriverConfigScreenState extends State<DriverConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, bool> _boolValues;
  late final Map<String, String?> _selectValues;

  @override
  void initState() {
    super.initState();
    _controllers = {};
    _boolValues = {};
    _selectValues = {};

    for (final field in widget.configSchema) {
      final initial = widget.initialValues[field.key];
      switch (field.type) {
        case DriverConfigFieldType.boolean:
          _boolValues[field.key] =
              (initial as bool?) ?? (field.defaultValue == 'true');
          break;
        case DriverConfigFieldType.select:
          _selectValues[field.key] =
              (initial as String?) ?? field.defaultValue ?? field.options?.first;
          break;
        default:
          _controllers[field.key] = TextEditingController(
            text: (initial as String?) ?? field.defaultValue ?? '',
          );
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _collectValues() {
    final values = <String, dynamic>{};
    for (final field in widget.configSchema) {
      switch (field.type) {
        case DriverConfigFieldType.boolean:
          values[field.key] = _boolValues[field.key] ?? false;
          break;
        case DriverConfigFieldType.select:
          values[field.key] = _selectValues[field.key];
          break;
        case DriverConfigFieldType.integer:
          values[field.key] =
              int.tryParse(_controllers[field.key]!.text) ?? 0;
          break;
        case DriverConfigFieldType.decimal:
          values[field.key] =
              double.tryParse(_controllers[field.key]!.text) ?? 0.0;
          break;
        default:
          values[field.key] = _controllers[field.key]!.text;
      }
    }
    return values;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final values = _collectValues();
    final json = const JsonEncoder.withIndent('  ').convert(values);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Config for ${widget.displayName}'),
        content: SingleChildScrollView(
          child: SelectableText(
            json,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(values);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configure: ${widget.displayName}'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Schema header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.schema_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Driver ID: ${widget.driverId}',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Dynamic fields
            ...widget.configSchema.map((field) => _buildField(field)),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check),
              label: const Text('Preview & Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(DriverConfigField field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: switch (field.type) {
        DriverConfigFieldType.boolean => SwitchListTile(
            title: Text(field.label),
            subtitle: field.hint != null ? Text(field.hint!) : null,
            value: _boolValues[field.key] ?? false,
            onChanged: (v) => setState(() => _boolValues[field.key] = v),
          ),
        DriverConfigFieldType.select => DropdownButtonFormField<String>(
            value: _selectValues[field.key],
            decoration: InputDecoration(
              labelText: field.label,
              hintText: field.hint,
              border: const OutlineInputBorder(),
            ),
            items: (field.options ?? [])
                .map(
                  (o) => DropdownMenuItem(value: o, child: Text(o)),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectValues[field.key] = v),
            validator: field.required
                ? (v) => v == null ? '${field.label} is required' : null
                : null,
          ),
        _ => TextFormField(
            controller: _controllers[field.key],
            obscureText: field.type == DriverConfigFieldType.password,
            keyboardType: switch (field.type) {
              DriverConfigFieldType.integer => TextInputType.number,
              DriverConfigFieldType.decimal => const TextInputType.numberWithOptions(decimal: true),
              DriverConfigFieldType.ipAddress => TextInputType.phone,
              _ => TextInputType.text,
            },
            decoration: InputDecoration(
              labelText: field.label +
                  (field.required ? ' *' : ' (optional)'),
              hintText: field.hint,
              border: const OutlineInputBorder(),
            ),
            validator: (v) {
              if (field.required && (v == null || v.trim().isEmpty)) {
                return '${field.label} is required';
              }
              if (field.validator != null) return field.validator!(v);
              return null;
            },
          ),
      },
    );
  }
}
