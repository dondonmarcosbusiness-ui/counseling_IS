import 'package:csv/csv.dart';

final Csv _encoder = Csv(addBom: true);

/// Encodes [rows] as CSV text: comma-delimited fields, CRLF line endings
/// and a leading UTF-8 BOM so spreadsheet applications detect the
/// character encoding correctly.
String encodeCsv(List<List<dynamic>> rows) => _encoder.encode(rows);
