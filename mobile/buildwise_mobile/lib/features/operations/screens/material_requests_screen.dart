import 'package:flutter/material.dart';

import '../../../core/widgets/error_widget.dart' as buildwise;
import '../../../core/widgets/field_format.dart';
import '../../../core/widgets/field_messages.dart';
import '../../../core/widgets/widgets.dart' hide ErrorWidget;
import '../services/operations_service.dart';
import '../widgets/agent_analysis_panels.dart';

class MaterialRequestsScreen extends StatefulWidget {
  const MaterialRequestsScreen({super.key, this.service, this.readOnly = false});
  final OperationsService? service;
  final bool readOnly;

  @override
  State<MaterialRequestsScreen> createState() => _MaterialRequestsScreenState();
}

class _MaterialRequestsScreenState extends State<MaterialRequestsScreen> {
  final _service = OperationsService();
  List<Map<String, dynamic>> _requests = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final requests = widget.readOnly
          ? await (widget.service ?? _service).listRequests()
          : await (widget.service ?? _service).listMyRequests();
      if (mounted) setState(() => _requests = requests);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateRequestSheet(service: widget.service ?? _service),
    );
    if (created == true) _load();
  }

  /// Runs the RequestAnalysisAgent (:8002) over one material request to surface
  /// planning risks. Advisory only: it flags urgency, bulk and large-quantity
  /// risk but never approves, rejects or changes the request.
  Future<void> _analyzeRequest(Map<String, dynamic> request) async {
    final id = (request['id'] as num).toInt();
    await showAiAnalysisSheet(
      context,
      title: 'AI Request Analysis - MR-$id',
      run: () => (widget.service ?? _service).analyzeRequest(id),
      builder: buildRequestAnalysisPanel,
    );
  }

  /// Approve or reject a material request.
  ///
  /// This is the authoritative human decision on the request. The
  /// RequestAnalysisAgent flags risk but never decides, so the request only
  /// becomes Approved when an authorized manager records that decision here.
  Future<void> _decide(Map<String, dynamic> request, {required String decision}) async {
    final id = (request['id'] as num).toInt();
    final comments = await showDialog<String>(
      context: context,
      builder: (_) => _DecisionDialog(decision: decision),
    );
    if (comments == null || !mounted) return;
    try {
      await (widget.service ?? _service).decideMaterialRequest(
        id,
        decision: decision,
        comments: comments,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request #$id $decision.')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Material Requests'),
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
    ),
    floatingActionButton: widget.readOnly
        ? null
        : FloatingActionButton.extended(
          onPressed: _create,
          icon: const Icon(Icons.add),
          label: const Text('Create Request'),
        ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? buildwise.ErrorWidget(message: _error!, onRetry: _load)
            : _requests.isEmpty
                ? const EmptyStateWidget(
                    title: 'No material requests',
                    message: 'Create a request for an active project and material.',
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _requests.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final request = _requests[index];
                        return AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // The material is what the row is *about*, so it is
                              // the headline. The API returns the line-ordered
                              // `materialNames`; `itemCount` alone left the list
                              // reading as bare "Request #77 · 1 item(s)", which
                              // tells a site user nothing they can act on.
                              Text(
                                FieldFormat.materialRequestLabel(request),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                request['projectName']?.toString() ?? 'Project',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 6),
                              Text('Request #${request['id']}'),
                              const SizedBox(height: 6),
                              StatusChip(
                                label: request['status']?.toString() ?? 'Unknown',
                                tone: _statusTone(request['status']?.toString()),
                              ),
                              const SizedBox(height: 12),
                              AppButton(
                                label: 'Run AI Analysis',
                                expand: true,
                                variant: AppButtonVariant.secondary,
                                onPressed: () => _analyzeRequest(request),
                              ),
                              // Approve/Reject is offered only on a request that
                              // is actually awaiting a decision, so the control
                              // never appears on an already-decided request.
                              if (request['status']?.toString() == 'PendingApproval') ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: AppButton(
                                        label: 'Approve',
                                        expand: true,
                                        onPressed: () => _decide(request, decision: 'Approved'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: AppButton(
                                        label: 'Reject',
                                        expand: true,
                                        variant: AppButtonVariant.danger,
                                        onPressed: () => _decide(request, decision: 'Rejected'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
  );
}

/// Collects the reviewer's comments before recording an approval decision.
class _DecisionDialog extends StatefulWidget {
  const _DecisionDialog({required this.decision});

  final String decision;

  @override
  State<_DecisionDialog> createState() => _DecisionDialogState();
}

class _DecisionDialogState extends State<_DecisionDialog> {
  final _comments = TextEditingController();

  @override
  void dispose() {
    _comments.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${widget.decision} this request?'),
    content: AppTextField(
      label: 'Comments',
      hint: 'Recorded against the request for audit',
      controller: _comments,
      maxLines: 3,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      AppButton(
        label: widget.decision,
        variant: widget.decision == 'Rejected'
            ? AppButtonVariant.danger
            : AppButtonVariant.primary,
        onPressed: () => Navigator.of(context).pop(_comments.text.trim()),
      ),
    ],
  );
}

StatusTone _statusTone(String? value) => switch (value) {
      'Approved' => StatusTone.success,
      'Rejected' => StatusTone.danger,
      'PendingApproval' => StatusTone.warning,
      _ => StatusTone.neutral,
    };

class _CreateRequestSheet extends StatefulWidget {
  const _CreateRequestSheet({required this.service});
  final OperationsService service;

  @override
  State<_CreateRequestSheet> createState() => _CreateRequestSheetState();
}

class _CreateRequestSheetState extends State<_CreateRequestSheet> {
  final _quantity = TextEditingController();
  final _reason = TextEditingController();
  final _siteNotes = TextEditingController();

  /// Populated from `/projects` and `/materials`. This form previously submitted
  /// a hard-coded `projectId: 1, materialId: 1`, which silently filed every
  /// request against the first seeded row - wrong project, wrong material, and
  /// no way for the engineer to notice on the form.
  List<Map<String, dynamic>> _projects = const [];
  List<Map<String, dynamic>> _materials = const [];
  int? _projectId;
  int? _materialId;

  /// Unit comes from the chosen material's master record, so the engineer does
  /// not have to remember whether cement is counted in bags or tonnes.
  String _unit = '';

  DateTime _requiredDate = DateTime.now().add(const Duration(days: 5));
  String _priority = 'Normal';

  bool _loadingOptions = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final results = await Future.wait([
        widget.service.listProjects(),
        widget.service.listMaterials(),
      ]);
      if (!mounted) return;
      setState(() {
        _projects = results[0];
        _materials = results[1];
        // Preselect only when there is exactly one candidate; otherwise the
        // engineer must choose deliberately.
        _projectId = _projects.length == 1 ? _projects.first['id'] as int? : null;
        if (_materials.length == 1) _selectMaterial(_materials.first);
        _loadingOptions = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingOptions = false;
        _error = FieldMessages.friendly(error.toString());
      });
    }
  }

  void _selectMaterial(Map<String, dynamic> material) {
    setState(() {
      _materialId = material['id'] as int?;
      _unit = material['unit']?.toString() ?? '';
    });
  }

  @override
  void dispose() {
    _quantity.dispose();
    _reason.dispose();
    _siteNotes.dispose();
    super.dispose();
  }

  /// Client-side validation, for immediate feedback only.
  ///
  /// This is UX. The backend re-validates every field and stays authoritative -
  /// a bypassed check must still fail server-side.
  String? _validate() {
    if (_projectId == null) return 'Select a project.';
    if (_materialId == null) return 'Select a material.';

    final rawQuantity = _quantity.text.trim();
    if (rawQuantity.isEmpty) return 'Enter a quantity.';
    final quantity = double.tryParse(rawQuantity);
    if (quantity == null) return 'Quantity must be a number.';
    if (quantity <= 0) return 'Quantity must be greater than zero.';

    if (_requiredDate.isBefore(DateTime.now())) {
      return 'Required date cannot be in the past.';
    }
    if (_reason.text.trim().isEmpty) {
      return 'Enter a justification for this request.';
    }
    return null;
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final material = _materials.firstWhere((m) => m['id'] == _materialId);
      await widget.service.createRequest(
        projectId: _projectId!,
        requiredDate: _dateOnly(_requiredDate),
        materialId: _materialId!,
        quantity: double.parse(_quantity.text.trim()),
        reason: _reason.text.trim(),
        priority: _priority,
        siteNotes: _siteNotes.text.trim().isEmpty ? null : _siteNotes.text.trim(),
        description: material['name']?.toString(),
        unit: _unit.isEmpty ? null : _unit,
        itemRequiredDate: _dateOnly(_requiredDate),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = FieldMessages.friendly(error.toString()));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    // Tomorrow at the earliest: material cannot be required for today.
    final first = now.add(const Duration(days: 1));
    final initial = _requiredDate.isBefore(first) ? first : _requiredDate;
    final selected = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: initial,
    );
    if (selected != null) setState(() => _requiredDate = selected);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingOptions) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('Loading projects and materials...'),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create Material Request', style: Theme.of(context).textTheme.titleLarge),
            // The error sits directly under the title, not at the bottom of the
            // sheet: on a phone the button and the failure message are often in
            // different scroll positions, so an error the user must scroll to
            // find reads as "nothing happened".
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFB91C1C).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFB91C1C)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFB91C1C), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _projectId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Project *', border: OutlineInputBorder()),
              items: _projects
                  .map((p) => DropdownMenuItem<int>(
                        value: p['id'] as int?,
                        child: Text(p['name']?.toString() ?? 'Project', overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _projectId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _materialId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Material *', border: OutlineInputBorder()),
              items: _materials
                  .map((m) => DropdownMenuItem<int>(
                        value: m['id'] as int?,
                        child: Text(m['name']?.toString() ?? 'Material', overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (value) {
                final match = _materials.where((m) => m['id'] == value).firstOrNull;
                if (match != null) _selectMaterial(match);
              },
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Quantity *',
              controller: _quantity,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              hint: _unit.isEmpty ? 'e.g. 500' : 'e.g. 500 $_unit',
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Required Date *'),
              trailing: Text(FieldFormat.date(_requiredDate)),
              onTap: _pickDate,
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'Low', child: Text('Low')),
                DropdownMenuItem(value: 'Normal', child: Text('Normal')),
                DropdownMenuItem(value: 'High', child: Text('High')),
                DropdownMenuItem(value: 'Urgent', child: Text('Urgent')),
              ],
              onChanged: (value) => setState(() => _priority = value ?? 'Normal'),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Justification *',
              controller: _reason,
              maxLines: 2,
              hint: 'Why is this material needed?',
            ),
            const SizedBox(height: 12),
            AppTextField(label: 'Site Notes', controller: _siteNotes, maxLines: 2),
            const SizedBox(height: 18),
            AppButton(
              // Disabled while in flight so a double tap cannot create two
              // material requests.
              label: _submitting ? FieldMessages.submitting('request') : 'Submit Request',
              expand: true,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
