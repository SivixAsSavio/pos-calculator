// Web implementation using dart:html
import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<String?> saveFile(String content, String filename) async {
  try {
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';
    html.document.body!.children.add(anchor);
    anchor.click();
    html.document.body!.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
    return filename;
  } catch (e) {
    print('Web export error: $e');
    return null;
  }
}

Future<String?> saveExcelFile(Uint8List bytes, String filename) async {
  try {
    // Create blob with Excel MIME type
    final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    
    // Create download link
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';
    
    // Add to DOM, click, and remove
    html.document.body!.children.add(anchor);
    anchor.click();
    
    // Cleanup
    html.document.body!.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
    
    return filename;
  } catch (e) {
    print('Web Excel export error: $e');
    return null;
  }
}
