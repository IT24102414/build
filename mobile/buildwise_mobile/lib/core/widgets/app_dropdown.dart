import 'package:flutter/material.dart';

class AppDropdown extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.label,
    required this.items,
    this.value,
    this.onChanged,
    this.itemLabels,
  });
  final String label;
  final List<String> items;
  final String? value;
  final ValueChanged<String?>? onChanged;

  /// Optional display text per item, index-aligned with [items].
  ///
  /// A list keyed by opaque id (`"7"`) is useless to read, so this renders the
  /// human name while [items] stays the value. Falls back to the raw item.
  final List<String>? itemLabels;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: [
      for (var i = 0; i < items.length; i++)
        DropdownMenuItem(
          value: items[i],
          child: Text(
            (itemLabels != null && i < itemLabels!.length)
                ? itemLabels![i]
                : items[i],
          ),
        ),
    ],
    onChanged: onChanged,
  );
}
