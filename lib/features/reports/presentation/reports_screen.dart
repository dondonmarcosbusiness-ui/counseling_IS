import 'dart:async';
import 'dart:io' show File;

import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/core/time/display_format.dart';
import 'package:counseling_is/core/widgets/app_data_table.dart';
import 'package:counseling_is/core/widgets/app_dropdown.dart';
import 'package:counseling_is/core/widgets/error_banner.dart';
import 'package:counseling_is/core/widgets/picker_field.dart';
import 'package:counseling_is/features/reports/data/report_exporter.dart';
import 'package:counseling_is/features/reports/data/report_repository.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

/// Report builder: pick a report type, optional date range and status
/// filter, then render the result — with CSV/PDF export and printing.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _exporter = ReportExporter();
  ReportType _type = ReportType.clients;
  DateTime? _from;
  DateTime? _to;
  String? _status;
  bool _loading = true;
  ReportTable? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh(initial: true);
  }

  List<(String, String)> get _statusOptions => switch (_type) {
    ReportType.clients => const [
      ('active', 'Active'),
      ('archived', 'Archived'),
    ],
    ReportType.appointments => const [
      ('scheduled', 'Scheduled'),
      ('completed', 'Completed'),
      ('missed', 'Missed'),
      ('cancelled', 'Cancelled'),
    ],
    ReportType.sessions => const [],
    ReportType.depedDraft => const [],
  };

  ReportRequest _request() =>
      ReportRequest(type: _type, from: _from, to: _to, status: _status);

  Future<void> _refresh({bool initial = false}) async {
    if (!initial) {
      setState(() {
        _loading = true;
        _error = null;
        _result = null;
      });
    }
    final repo = context.read<ReportRepository>();
    try {
      final table = await repo.run(_request());
      if (!mounted) return;
      setState(() {
        _result = table;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is AppException
            ? error.message
            : 'The report could not be generated.';
        _loading = false;
      });
    }
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _from = picked;
    });
    await _refresh();
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to ?? _from ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _to = picked;
    });
    await _refresh();
  }

  Future<void> _clearDates() async {
    setState(() {
      _from = null;
      _to = null;
    });
    await _refresh();
  }

  String _title() => '${_type.label} report';

  String _subtitle() {
    final period = _from == null && _to == null
        ? 'Period: all dates'
        : 'Period: ${_from == null ? 'Any' : formatDate(_from!)}'
              ' – ${_to == null ? 'Any' : formatDate(_to!)}';
    final total = _result?.total ?? 0;
    final totalLabel = _type == ReportType.depedDraft
        ? '$total indicators'
        : '$total records';
    final draftNotice = _type == ReportType.depedDraft
        ? '  ·  DRAFT ONLY — verify against the official DepEd template'
        : '';
    return '$period  ·  $totalLabel$draftNotice  ·  '
        'Generated ${formatDateTime(DateTime.now())}';
  }

  String _fileBase() {
    final date = DateTime.now().toIso8601String().split('T').first;
    final reportName = _type == ReportType.clients ? 'students' : _type.name;
    return '$reportName-report-$date';
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exportCsv() async {
    final table = _result;
    if (table == null) return;
    final location = await getSaveLocation(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'CSV file', extensions: ['csv']),
      ],
      suggestedName: '${_fileBase()}.csv',
    );
    if (location == null || !mounted) return;
    try {
      await File(location.path).writeAsString(
        _exporter.exportCsv(table, title: _title(), subtitle: _subtitle()),
      );
    } catch (_) {
      if (mounted) _snack('The CSV file could not be written.');
      return;
    }
    if (mounted) _snack('CSV exported to ${location.path}');
  }

  Future<void> _exportPdf() async {
    final table = _result;
    if (table == null) return;
    final location = await getSaveLocation(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'PDF file', extensions: ['pdf']),
      ],
      suggestedName: '${_fileBase()}.pdf',
    );
    if (location == null || !mounted) return;
    try {
      final bytes = await _exporter.exportPdf(
        table: table,
        title: _title(),
        subtitle: _subtitle(),
      );
      await File(location.path).writeAsBytes(bytes);
    } catch (_) {
      if (mounted) _snack('The PDF file could not be written.');
      return;
    }
    if (mounted) _snack('PDF exported to ${location.path}');
  }

  Future<void> _print() async {
    final table = _result;
    if (table == null) return;
    final title = _title();
    final subtitle = _subtitle();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 1050,
          height: MediaQuery.sizeOf(context).height * .88,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Print preview',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: 'Close preview',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: PdfPreview(
                  pdfFileName: '${_fileBase()}.pdf',
                  initialPageFormat: PdfPageFormat.a4,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  allowSharing: false,
                  build: (_) => _exporter.exportPdf(
                    table: table,
                    title: title,
                    subtitle: subtitle,
                  ),
                  onPrinted: (previewContext) {
                    Navigator.of(previewContext).pop();
                  },
                  onPrintError: (previewContext, _) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('The report could not be printed.'),
                      ),
                    );
                  },
                  onError: (previewContext, _) => Center(
                    child: Text(
                      'The report preview could not be generated.',
                      style: Theme.of(previewContext).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(String dbValue) {
    for (final (value, label) in _statusOptions) {
      if (value == dbValue) return label;
    }
    return switch (dbValue) {
      'active' => 'Active',
      'archived' => 'Archived',
      'scheduled' => 'Scheduled',
      'completed' => 'Completed',
      'missed' => 'Missed',
      'cancelled' => 'Cancelled',
      _ => dbValue,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reports', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(
                      'Summarize guidance activity and export reports.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.tune_rounded,
                            size: 18,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Build a report',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (_type == ReportType.depedDraft) ...[
                      Text(
                        'Draft only — not an official DepEd report. Verify '
                        'the official template before submission.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final fieldWidth = constraints.maxWidth >= 680
                            ? ((constraints.maxWidth - (AppSpacing.md * 3)) / 4)
                                  .clamp(156.0, 280.0)
                                  .toDouble()
                            : 230.0;
                        return Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            SizedBox(
                              width: fieldWidth,
                              child: AppDropdownFormField<ReportType>(
                                initialValue: _type,
                                isExpanded: true,
                                menuMaxHeight:
                                    AppDropdownDefaults.menuMaxHeight,
                                decoration: const InputDecoration(
                                  labelText: 'Report',
                                ),
                                items: [
                                  for (final type in ReportType.values)
                                    DropdownMenuItem(
                                      value: type,
                                      child: Text(
                                        type.label,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _type = value;
                                    _status = null;
                                  });
                                  unawaited(_refresh());
                                },
                              ),
                            ),
                            if (_statusOptions.isNotEmpty)
                              SizedBox(
                                width: fieldWidth,
                                child: AppDropdownFormField<String>(
                                  initialValue: _status,
                                  isExpanded: true,
                                  menuMaxHeight:
                                      AppDropdownDefaults.menuMaxHeight,
                                  decoration: const InputDecoration(
                                    labelText: 'Status',
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('Any status'),
                                    ),
                                    for (final (value, label) in _statusOptions)
                                      DropdownMenuItem(
                                        value: value,
                                        child: Text(label),
                                      ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _status = value;
                                    });
                                    unawaited(_refresh());
                                  },
                                ),
                              ),
                            SizedBox(
                              width: fieldWidth,
                              child: PickerField(
                                label: 'From',
                                displayValue: _from == null
                                    ? 'Any date'
                                    : formatDate(_from!),
                                icon: Icons.calendar_today_outlined,
                                onTap: _pickFrom,
                                onClear: _from == null ? null : _clearDates,
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: PickerField(
                                label: 'To',
                                displayValue: _to == null
                                    ? 'Any date'
                                    : formatDate(_to!),
                                icon: Icons.event_outlined,
                                onTap: _pickTo,
                                onClear: _to == null ? null : _clearDates,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Divider(height: 1, color: scheme.outlineVariant),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Run report'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _actionsEnabled ? _exportCsv : null,
                          icon: const Icon(Icons.table_view_outlined),
                          label: const Text('Export CSV…'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _actionsEnabled ? _exportPdf : null,
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Export PDF…'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _actionsEnabled ? _print : null,
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('Print'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  bool get _actionsEnabled => !_loading && _result != null;

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _error;
    if (error != null) {
      return SingleChildScrollView(
        child: Column(
          children: [
            ErrorBanner(message: error),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ),
          ],
        ),
      );
    }
    return _ReportResult(
      table: _result!,
      reportType: _type,
      statusLabel: _statusLabel,
    );
  }
}

class _ReportResult extends StatelessWidget {
  const _ReportResult({
    required this.table,
    required this.reportType,
    required this.statusLabel,
  });

  final ReportTable table;
  final ReportType reportType;
  final String Function(String dbValue) statusLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.table_chart_outlined,
                    color: scheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${table.total}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      table.total == 1 ? 'record found' : 'records found',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.lg),
                Container(width: 1, height: 38, color: scheme.outlineVariant),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${reportType.label} report',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (table.breakdown != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: [
                            for (final entry in table.breakdown!.entries)
                              Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text(
                                  '${statusLabel(entry.key)}: '
                                  '${entry.value}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: scheme.primary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: table.rows.isEmpty
              ? Center(
                  child: Text(
                    'No records match the current filters.',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                )
              : Card(
                  clipBehavior: Clip.antiAlias,
                  child: AppDataTable(
                    columns: [
                      for (final column in table.columns)
                        DataColumn(label: Text(column)),
                    ],
                    rows: [
                      for (var i = 0; i < table.rows.length; i++)
                        DataRow(
                          key: ValueKey(i),
                          cells: [
                            for (final cell in table.rows[i])
                              DataCell(Text(cell)),
                          ],
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
