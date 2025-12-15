// Desktop/IO implementation using dart:io
import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String?> saveFile(String content, String filename) async {
  try {
    // Get downloads/documents directory
    Directory? directory;
    try {
      directory = await getDownloadsDirectory();
    } catch (_) {
      directory = await getApplicationDocumentsDirectory();
    }
    
    if (directory == null) {
      directory = await getApplicationDocumentsDirectory();
    }
    
    final filePath = '${directory.path}/$filename';
    
    // Write file
    final file = File(filePath);
    await file.writeAsString(content);
    
    return filePath;
  } catch (e) {
    print('IO export error: $e');
    return null;
  }
}
