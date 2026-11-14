import 'package:flutter/material.dart';

class AppDataTable extends StatelessWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.showCheckboxColumn = false,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final bool showCheckboxColumn;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: SingleChildScrollView(
            child: DataTable(
              columns: columns,
              rows: rows,
              showCheckboxColumn: showCheckboxColumn,
            ),
          ),
        ),
      ),
    );
  }
}
