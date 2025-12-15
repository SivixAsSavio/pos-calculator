import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'cash_count_service.dart';

// Conditional imports for web vs desktop
import 'excel_export_stub.dart'
    if (dart.library.html) 'excel_export_web.dart'
    if (dart.library.io) 'excel_export_io.dart' as platform;

class ExcelExportService {
  // Colors matching the user's spreadsheet
  static const String _darkBlue = 'FF1F3864';      // Dark blue header
  static const String _lightBlue = 'FF2E75B6';     // Light blue for LBP
  static const String _headerGray = 'FFD0CECE';    // Gray for header row background
  static const String _lightGray = 'FFF2F2F2';     // Light gray for data rows
  static const String _white = 'FFFFFFFF';
  static const String _black = 'FF000000';
  static const String _greenText = 'FF00B050';     // Green for totals
  static const String _redText = 'FFFF0000';       // Red for LBP 0

  /// Generate proper Excel file with styling matching the CALCULATOR SHEET
  static Uint8List generateExcelBytes(CashCount count) {
    final excel = Excel.createExcel();
    final sheetName = 'TOTAL';
    
    // Remove default sheet and create our sheet
    excel.delete('Sheet1');
    final sheet = excel[sheetName];
    
    // Calculate totals
    final usdBranchTotal = count.usdQty[0] * 100 + count.usdQty[1] * 50 + count.usdQty[2] * 20 + 
                           count.usdQty[3] * 10 + count.usdQty[4] * 5 + count.usdQty[5] * 1;
    final lbpBranchTotal = count.lbpQty[0] * 100000 + count.lbpQty[1] * 50000 + count.lbpQty[2] * 20000 + 
                           count.lbpQty[3] * 10000 + count.lbpQty[4] * 5000 + count.lbpQty[5] * 1000;
    
    // Styles
    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(_darkBlue),
      fontColorHex: ExcelColor.fromHexString(_white),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );
    
    final usdHeaderStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(_darkBlue),
      fontColorHex: ExcelColor.fromHexString(_white),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );
    
    final lbpHeaderStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(_lightBlue),
      fontColorHex: ExcelColor.fromHexString(_white),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );
    
    final dataStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(_lightGray),
      horizontalAlign: HorizontalAlign.Center,
    );
    
    final totalRowStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(_headerGray),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );
    
    final greenTotalStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(_headerGray),
      fontColorHex: ExcelColor.fromHexString(_greenText),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );
    
    final redStyle = CellStyle(
      fontColorHex: ExcelColor.fromHexString(_redText),
      horizontalAlign: HorizontalAlign.Center,
    );
    
    int row = 0;
    
    // Row 0: CALCULATOR SHEET header (merged across columns B-H)
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue('CALCULATOR SHEET');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).cellStyle = CellStyle(bold: true, fontSize: 14);
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row), CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row));
    row++;
    
    // Row 1: Empty
    row++;
    
    // Row 2: USD Header row
    final usdHeaders = ['USD', '\$100', '\$50', '\$20', '\$10', '\$5', '\$1', 'TOTAL', '', 'SEND TO HO', 'REMAINING BALANCE'];
    for (int col = 0; col < usdHeaders.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      cell.value = TextCellValue(usdHeaders[col]);
      if (col <= 7) cell.cellStyle = usdHeaderStyle;
      else if (col >= 9) cell.cellStyle = usdHeaderStyle;
    }
    row++;
    
    // Row 3: BRANCH row for USD
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('BRANCH');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).cellStyle = dataStyle;
    for (int i = 0; i < 6; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i + 1, rowIndex: row));
      cell.value = IntCellValue(count.usdQty[i]);
      cell.cellStyle = dataStyle;
    }
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = TextCellValue('\$$usdBranchTotal');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).cellStyle = dataStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).value = TextCellValue('\$$usdBranchTotal');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).cellStyle = dataStyle;
    row++;
    
    // Row 4: COLLECTOR row for USD
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('COLLECTOR');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).cellStyle = dataStyle;
    for (int i = 1; i <= 7; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row)).cellStyle = dataStyle;
    }
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).value = TextCellValue('LBP 0');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).cellStyle = redStyle;
    row++;
    
    // Row 5: user row (empty)
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('user');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).cellStyle = dataStyle;
    for (int i = 1; i <= 7; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row)).cellStyle = dataStyle;
    }
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).value = TextCellValue('\$0');
    row++;
    
    // Row 6: Empty data row
    for (int i = 0; i <= 7; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row)).cellStyle = dataStyle;
    }
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).value = TextCellValue('\$0');
    row++;
    
    // Row 7: TOTAL row for USD
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('TOTAL');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).cellStyle = totalRowStyle;
    for (int i = 0; i < 6; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i + 1, rowIndex: row));
      cell.value = IntCellValue(count.usdQty[i]);
      cell.cellStyle = totalRowStyle;
    }
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = TextCellValue('\$$usdBranchTotal');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).cellStyle = greenTotalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row)).value = TextCellValue('\$0');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row)).cellStyle = totalRowStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).value = TextCellValue('\$$usdBranchTotal');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).cellStyle = totalRowStyle;
    row++;
    
    // Row 8: Empty
    row++;
    
    // Row 9: LBP Header row
    final lbpHeaders = ['LBP', 'LBP 100,000', 'LBP 50,000', 'LBP 20,000', 'LBP 10,000', 'LBP 5,000', 'LBP 1,000', 'TOTAL', '', 'SEND TO HO', 'REMAINING BALANCE'];
    for (int col = 0; col < lbpHeaders.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      cell.value = TextCellValue(lbpHeaders[col]);
      if (col <= 7) cell.cellStyle = lbpHeaderStyle;
      else if (col >= 9) cell.cellStyle = lbpHeaderStyle;
    }
    row++;
    
    // Row 10: BRANCH row for LBP
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('BRANCH');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).cellStyle = dataStyle;
    for (int i = 0; i < 6; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i + 1, rowIndex: row));
      cell.value = IntCellValue(count.lbpQty[i]);
      cell.cellStyle = dataStyle;
    }
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = TextCellValue('LBP ${_formatNumber(lbpBranchTotal)}');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).cellStyle = dataStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).value = TextCellValue('LBP ${_formatNumber(lbpBranchTotal)}');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).cellStyle = dataStyle;
    row++;
    
    // Row 11: COLLECTOR row for LBP
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('COLLECTOR');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).cellStyle = dataStyle;
    for (int i = 1; i <= 7; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row)).cellStyle = dataStyle;
    }
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).value = TextCellValue('LBP 0');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).cellStyle = redStyle;
    row++;
    
    // Row 12: Empty data row
    for (int i = 0; i <= 7; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row)).cellStyle = dataStyle;
    }
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).value = TextCellValue('LBP 0');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).cellStyle = redStyle;
    row++;
    
    // Row 13: Another empty data row
    for (int i = 0; i <= 7; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row)).cellStyle = dataStyle;
    }
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).value = TextCellValue('LBP 0');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).cellStyle = redStyle;
    row++;
    
    // Row 14: TOTAL row for LBP
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('TOTAL');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).cellStyle = totalRowStyle;
    for (int i = 0; i < 6; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i + 1, rowIndex: row));
      cell.value = IntCellValue(count.lbpQty[i]);
      cell.cellStyle = totalRowStyle;
    }
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = TextCellValue('LBP ${_formatNumber(lbpBranchTotal)}');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).cellStyle = greenTotalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row)).value = TextCellValue('LBP 0');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row)).cellStyle = totalRowStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).value = TextCellValue('LBP ${_formatNumber(lbpBranchTotal)}');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).cellStyle = totalRowStyle;
    row++;
    
    // Row 15: Empty
    row++;
    
    // Row 16: DATE section
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = TextCellValue('DATE :');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = TextCellValue(count.date);
    row++;
    
    // Row 17: Empty
    row++;
    
    // Row 18: TAJ info header
    final tajHeaders = ['TAJ', 'PERSON', 'USER', 'PASS', 'ACC #'];
    for (int col = 0; col < tajHeaders.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      cell.value = TextCellValue(tajHeaders[col]);
      cell.cellStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString(_headerGray),
        bold: true,
      );
    }
    row++;
    
    // Row 19: TAJ values row (empty for manual entry)
    for (int col = 0; col < 5; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row)).cellStyle = dataStyle;
    }
    row++;
    
    // Row 20: Empty
    row++;
    
    // Row 21: TAJ USD/LBP summary
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('TAJ USD');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue('\$${count.tajUsd.toStringAsFixed(0)}');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = TextCellValue('TAJ LBP');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = TextCellValue('LBP ${_formatNumber(count.tajLbp)}');
    row++;
    
    // Row 22: TEST results
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('TEST USD');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(count.usdTest);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).cellStyle = CellStyle(
      fontColorHex: count.usdTest == 'OK ✓' ? ExcelColor.fromHexString(_greenText) : ExcelColor.fromHexString(_redText),
    );
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = TextCellValue('TEST LBP');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = TextCellValue(count.lbpTest);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).cellStyle = CellStyle(
      fontColorHex: count.lbpTest == 'OK ✓' ? ExcelColor.fromHexString(_greenText) : ExcelColor.fromHexString(_redText),
    );
    
    // Set column widths
    sheet.setColumnWidth(0, 12);  // A - Labels
    sheet.setColumnWidth(1, 12);  // B - $100 / LBP 100,000
    sheet.setColumnWidth(2, 12);  // C - $50 / LBP 50,000
    sheet.setColumnWidth(3, 12);  // D - $20 / LBP 20,000
    sheet.setColumnWidth(4, 12);  // E - $10 / LBP 10,000
    sheet.setColumnWidth(5, 12);  // F - $5 / LBP 5,000
    sheet.setColumnWidth(6, 12);  // G - $1 / LBP 1,000
    sheet.setColumnWidth(7, 18);  // H - TOTAL
    sheet.setColumnWidth(8, 3);   // I - Gap
    sheet.setColumnWidth(9, 14);  // J - SEND TO HO
    sheet.setColumnWidth(10, 20); // K - REMAINING BALANCE
    
    return Uint8List.fromList(excel.encode()!);
  }
  
  /// Format number with commas
  static String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},'
    );
  }
  
  /// Generate filename from cash count
  static String generateFilename(CashCount count) {
    final timestamp = count.timestamp.replaceAll('/', '-').replaceAll(':', '-').replaceAll(' ', '_');
    return 'CashCount_$timestamp.xlsx';
  }
  
  /// Export to Excel format (works on both web and desktop)
  static Future<String?> exportToExcelFormat(CashCount count) async {
    try {
      final bytes = generateExcelBytes(count);
      final filename = generateFilename(count);
      
      return await platform.saveExcelFile(bytes, filename);
    } catch (e) {
      print('Error exporting to Excel format: $e');
      return null;
    }
  }
}
