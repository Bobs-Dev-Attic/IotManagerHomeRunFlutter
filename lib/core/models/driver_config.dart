/// Describes the data type expected for a single configuration field.
enum DriverConfigFieldType {
  text,
  password,
  integer,
  decimal,
  boolean,
  ipAddress,
  select,
}

/// Describes one input field in the JSON-based configuration UI rendered in
/// Developer Mode.
class DriverConfigField {
  const DriverConfigField({
    required this.key,
    required this.label,
    required this.type,
    this.hint,
    this.defaultValue,
    this.required = true,
    this.options,
    this.validator,
  });

  /// The key used in [DeviceModel.extraConfig] and the driver's config map.
  final String key;

  /// Label shown next to the text field.
  final String label;

  final DriverConfigFieldType type;

  /// Short hint / placeholder text.
  final String? hint;

  /// Pre-filled default value (as a string; parsed by type).
  final String? defaultValue;

  final bool required;

  /// Valid only when [type] == [DriverConfigFieldType.select].
  final List<String>? options;

  /// Optional custom validation logic.  Returns an error string or `null`.
  final String? Function(String? value)? validator;

  // -----------------------------------------------------------------------
  // Serialisation (for persisting schema to Firestore in Developer Mode)
  // -----------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'type': type.name,
        if (hint != null) 'hint': hint,
        if (defaultValue != null) 'defaultValue': defaultValue,
        'required': required,
        if (options != null) 'options': options,
      };

  factory DriverConfigField.fromJson(Map<String, dynamic> json) {
    return DriverConfigField(
      key: json['key'] as String,
      label: json['label'] as String,
      type: DriverConfigFieldType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => DriverConfigFieldType.text,
      ),
      hint: json['hint'] as String?,
      defaultValue: json['defaultValue'] as String?,
      required: json['required'] as bool? ?? true,
      options: (json['options'] as List<dynamic>?)?.cast<String>(),
    );
  }
}

/// Holds the runtime configuration values for a driver instance.
///
/// Values are loaded from [DeviceModel.extraConfig] and validated against the
/// driver's [configSchema].
class DriverConfig {
  const DriverConfig({required this.values});

  final Map<String, dynamic> values;

  T? get<T>(String key) => values[key] as T?;

  T getRequired<T>(String key) {
    final value = values[key];
    if (value == null) {
      throw StateError('Required driver config key "$key" is missing.');
    }
    return value as T;
  }

  DriverConfig copyWith(Map<String, dynamic> overrides) {
    return DriverConfig(values: {...values, ...overrides});
  }
}
