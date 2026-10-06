import 'dart:html' as html;

void exportCsv(String filename, List<List<String>> rows) {
  final StringBuffer buffer = StringBuffer();
  for (final List<String> row in rows) {
    buffer.writeln(
      row.map((String cell) => '"${cell.replaceAll('"', '""')}"').join(','),
    );
  }
  final html.Blob blob = html.Blob(<String>[buffer.toString()], 'text/csv');
  final String url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
