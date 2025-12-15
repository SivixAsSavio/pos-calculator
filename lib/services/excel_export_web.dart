// Web implementation using dart:html
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<String?> saveFile(String content, String filename) async {
  try {
    // Create blob with text/csv type for proper Excel handling
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    
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
    
    return filename; // Return filename as success indicator
  } catch (e) {
    print('Web export error: $e');
    return null;
  }
}
