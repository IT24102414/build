import 'status_chip.dart';

/// Small display helpers shared by the field workspaces.
///
/// Kept together so a date or status reads identically on every field screen
/// instead of each screen re-deriving its own formatting.
class FieldFormat {
  const FieldFormat._();

  /// `2026-10-08` -> `08/10/2026`. Unparseable input is returned untouched
  /// rather than rendered as "Invalid Date", so a value is never hidden.
  static String date(Object? value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return '—';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  /// `PendingApproval` -> `Pending Approval`.
  static String humanize(String? value) {
    if (value == null || value.isEmpty) return 'Unknown';
    final spaced = value.replaceAllMapped(
      RegExp('([a-z0-9])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }

  /// Status colour for a material request or delivery.
  static StatusTone statusTone(String? status) => switch (status) {
        'Approved' => StatusTone.success,
        'Rejected' => StatusTone.danger,
        'PendingApproval' ||
        'RfqInProgress' ||
        'AwaitingProcurementApproval' =>
          StatusTone.warning,
        'RevisionRequested' => StatusTone.danger,
        'DiscrepancyReported' => StatusTone.danger,
        'Received' => StatusTone.success,
        _ => StatusTone.neutral,
      };
}