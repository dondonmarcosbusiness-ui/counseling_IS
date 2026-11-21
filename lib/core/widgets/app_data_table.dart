import 'package:flutter/material.dart';

class AppDataTable extends StatelessWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.showCheckboxColumn = false,
    this.dataRowMaxHeight,
    this.sortColumnIndex,
    this.sortAscending = true,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final bool showCheckboxColumn;

  /// Rows grow to fit their cells when set; otherwise `DataTable` clamps a
  /// row to the standard control height and multi-line cells overflow.
  final double? dataRowMaxHeight;

  /// Index of the column the table is currently sorted by, or `null` to keep
  /// the rows in their original order.
  ///
  /// Give that column a non-null [DataColumn.onSort] so its header becomes
  /// tappable and `DataTable` paints the ascending/descending arrow.
  final int? sortColumnIndex;

  /// Whether the column at [sortColumnIndex] is sorted ascending instead of
  /// descending.
  final bool sortAscending;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: SingleChildScrollView(
            child: DataTable(
              columns: [
                for (var i = 0; i < columns.length; i++)
                  _withSortHint(
                    columns[i],
                    showHint: columns[i].onSort != null && i != sortColumnIndex,
                  ),
              ],
              rows: rows,
              showCheckboxColumn: showCheckboxColumn,
              dataRowMaxHeight: dataRowMaxHeight,
              sortColumnIndex: sortColumnIndex,
              sortAscending: sortAscending,
            ),
          ),
        ),
      ),
    );
  }
}

/// Marks a sortable column by hinting at it with a small
/// [Icons.unfold_more] next to its label, so headers look tappable before
/// the first tap. The hint is dropped while the column is the active sort
/// column, where `DataTable` draws its own arrow instead.
DataColumn _withSortHint(DataColumn column, {required bool showHint}) {
  if (!showHint) return column;
  return DataColumn(
    label: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        column.label,
        const SizedBox(width: 4),
        const Icon(Icons.unfold_more, size: 14),
      ],
    ),
    columnWidth: column.columnWidth,
    tooltip: column.tooltip,
    numeric: column.numeric,
    onSort: column.onSort,
    mouseCursor: column.mouseCursor,
    headingRowAlignment: column.headingRowAlignment,
  );
}

/// Sort key for one table column: the value of [row] that the column sorts
/// by, or `null` when the row has no value for it.
typedef TableSortKey<T> = Object? Function(T row);

/// Sorts [rows] by the column at [columnIndex] with the matching getter from
/// [keys] — one entry per column, where `null` marks a column that cannot be
/// sorted (e.g. an actions column).
///
/// Rows keep their original order when [columnIndex] is `null` or points at a
/// column without a getter. Rows whose key is `null` always sort last, no
/// matter the direction. Strings compare case-insensitively, and strings that
/// hold a number compare as numbers.
List<T> sortTableRows<T>(
  List<T> rows,
  int? columnIndex,
  bool ascending,
  List<TableSortKey<T>?> keys,
) {
  if (columnIndex == null || columnIndex < 0 || columnIndex >= keys.length) {
    return rows;
  }
  final keyOf = keys[columnIndex];
  if (keyOf == null) return rows;

  final sorted = List<T>.of(rows);
  sorted.sort((a, b) {
    final keyA = keyOf(a);
    final keyB = keyOf(b);
    if (keyA == null && keyB == null) return 0;
    if (keyA == null) return 1;
    if (keyB == null) return -1;
    final result = _compareSortKeys(keyA, keyB);
    return ascending ? result : -result;
  });
  return sorted;
}

int _compareSortKeys(Object a, Object b) {
  if (a is num && b is num) return a.compareTo(b);
  if (a is DateTime && b is DateTime) return a.compareTo(b);
  if (a is String && b is String) {
    final numberA = num.tryParse(a.replaceAll(',', ''));
    final numberB = num.tryParse(b.replaceAll(',', ''));
    if (numberA != null && numberB != null) return numberA.compareTo(numberB);
    return a.toLowerCase().compareTo(b.toLowerCase());
  }
  if (a.runtimeType == b.runtimeType && a is Comparable<Object?>) {
    return a.compareTo(b);
  }
  return a.toString().toLowerCase().compareTo(b.toString().toLowerCase());
}
