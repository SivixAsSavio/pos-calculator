// Desktop/IO implementation using dart:io
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<String?> saveFile(String content, String filename) async {
  try {
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
    final file = File(filePath);
    await file.writeAsString(content);
    return filePath;
  } catch (e) {
    print('IO export error: $e');
    return null;
  }
}

Future<String?> saveExcelFile(Uint8List bytes, String filename) async {
  try {
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
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return filePath;
  } catch (e) {
    print('IO Excel export error: $e');
    return null;
  }
}
