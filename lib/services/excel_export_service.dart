import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'cash_count_service.dart';

// Conditional imports for web vs desktop
import 'excel_export_stub.dart'
    if (dart.library.html) 'excel_export_web.dart'
    if (dart.library.io) 'excel_export_io.dart' as platform;

class ExcelExportService {
  // Colors matching the user's spreadsheet exactly
  static const String _darkBlue = 'FF1F3864';      // Dark blue header for USD
  static const String _lightBlue = 'FF2E75B6';     // Light blue for LBP header
  static const String _headerGray = 'FFD0CECE';    // Gray for TOTAL rows
  static const String _white = 'FFFFFFFF';
  static const String _black = 'FF000000';
  static const String _greenTotal = 'FF00B050';    // Green for TOTAL column values
  static const String _redText = 'FFFF0000';       // Red for LBP 0

  /// Generate proper Excel file with FORMULAS matching the exact layout
  static Uint8List generateExcelBytes(CashCount count) {
    final excel = Excel.createExcel();
    final sheetName = 'TOTAL';
    
    // Remove default sheet and create our sheet
    excel.delete('Sheet1');
    final sheet = excel[sheetName];
    
    // Styles
    final headerStyleUSD = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(_darkBlue),
      fontColorHex: ExcelColor.fromHexString(_white),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );
    
    final headerStyleLBP = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(_lightBlue),
      fontColorHex: ExcelColor.fromHexString(_white),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );
    
    final dataStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
    );
    
    final totalRowStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(_headerGray),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );
    
    final greenTotalStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(_headerGray),
      fontColorHex: ExcelColor.fromHexString(_greenTotal),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );
    
    final redStyle = CellStyle(
      fontColorHex: ExcelColor.fromHexString(_redText),
      horizontalAlign: HorizontalAlign.Center,
    );

    // ============ ROW 1: CALCULATOR SHEET HEADER ============
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('CALCULATOR SHEET - TOTAL NAHER IBRAHIM');
    sheet.cell(CellIndex.indexByString('B1')).cellStyle = CellStyle(bold: true, fontSize: 12);
    sheet.merge(CellIndex.indexByString('B1'), CellIndex.indexByString('H1'));
    
    // ============ ROW 2: Empty ============
    
    // ============ ROW 3: USD HEADER ============
    _setCell(sheet, 'A3', 'USD', headerStyleUSD);
    _setCell(sheet, 'B3', '\$100', headerStyleUSD);
    _setCell(sheet, 'C3', '\$50', headerStyleUSD);
    _setCell(sheet, 'D3', '\$20', headerStyleUSD);
    _setCell(sheet, 'E3', '\$10', headerStyleUSD);
    _setCell(sheet, 'F3', '\$5', headerStyleUSD);
    _setCell(sheet, 'G3', '\$1', headerStyleUSD);
    _setCell(sheet, 'H3', 'TOTAL', headerStyleUSD);
    _setCell(sheet, 'J3', 'SEND TO HO', headerStyleUSD);
    _setCell(sheet, 'K3', 'REMAINING BALANCE', headerStyleUSD);
    
    // ============ ROW 4: BRANCH (your data) ============
    _setCell(sheet, 'A4', 'BRANCH', dataStyle);
    _setCellInt(sheet, 'B4', count.usdQty[0], dataStyle);
    _setCellInt(sheet, 'C4', count.usdQty[1], dataStyle);
    _setCellInt(sheet, 'D4', count.usdQty[2], dataStyle);
    _setCellInt(sheet, 'E4', count.usdQty[3], dataStyle);
    _setCellInt(sheet, 'F4', count.usdQty[4], dataStyle);
    _setCellInt(sheet, 'G4', count.usdQty[5], dataStyle);
    // FORMULA: =B4*100+C4*50+D4*20+E4*10+F4*5+G4*1
    _setFormula(sheet, 'H4', 'B4*100+C4*50+D4*20+E4*10+F4*5+G4*1', dataStyle);
    // REMAINING BALANCE formula
    _setFormula(sheet, 'K4', 'H4-J4', dataStyle);
    
    // ============ ROW 5: COLLECTOR ============
    _setCell(sheet, 'A5', 'COLLECTOR', dataStyle);
    _setFormula(sheet, 'H5', 'B5*100+C5*50+D5*20+E5*10+F5*5+G5*1', dataStyle);
    _setFormula(sheet, 'K5', 'IF(H5=0,"LBP 0",H5-J5)', redStyle);
    
    // ============ ROW 6: JOSEPH (empty row for manual entry) ============
    _setCell(sheet, 'A6', 'JOSEPH', dataStyle);
    _setFormula(sheet, 'H6', 'B6*100+C6*50+D6*20+E6*10+F6*5+G6*1', dataStyle);
    _setFormula(sheet, 'K6', 'IF(H6=0,"$0",H6-J6)', dataStyle);
    
    // ============ ROW 7: SAVIO (empty row for manual entry) ============
    _setCell(sheet, 'A7', 'SAVIO', dataStyle);
    _setFormula(sheet, 'H7', 'B7*100+C7*50+D7*20+E7*10+F7*5+G7*1', dataStyle);
    _setFormula(sheet, 'K7', 'IF(H7=0,"$0",H7-J7)', dataStyle);
    
    // ============ ROW 8: Empty row ============
    _setFormula(sheet, 'H8', 'B8*100+C8*50+D8*20+E8*10+F8*5+G8*1', dataStyle);
    _setFormula(sheet, 'K8', 'IF(H8=0,"$0",H8-J8)', dataStyle);
    
    // ============ ROW 9: USD TOTAL ============
    _setCell(sheet, 'A9', 'TOTAL', totalRowStyle);
    _setFormula(sheet, 'B9', 'SUM(B4:B8)', totalRowStyle);
    _setFormula(sheet, 'C9', 'SUM(C4:C8)', totalRowStyle);
    _setFormula(sheet, 'D9', 'SUM(D4:D8)', totalRowStyle);
    _setFormula(sheet, 'E9', 'SUM(E4:E8)', totalRowStyle);
    _setFormula(sheet, 'F9', 'SUM(F4:F8)', totalRowStyle);
    _setFormula(sheet, 'G9', 'SUM(G4:G8)', totalRowStyle);
    _setFormula(sheet, 'H9', 'SUM(H4:H8)', greenTotalStyle);
    _setFormula(sheet, 'J9', 'SUM(J4:J8)', totalRowStyle);
    _setFormula(sheet, 'K9', 'SUM(K4:K8)', totalRowStyle);
    
    // ============ ROW 10: Empty ============
    
    // ============ ROW 11: LBP HEADER ============
    _setCell(sheet, 'A11', 'LBP', headerStyleLBP);
    _setCell(sheet, 'B11', 'LBP 100,000', headerStyleLBP);
    _setCell(sheet, 'C11', 'LBP 50,000', headerStyleLBP);
    _setCell(sheet, 'D11', 'LBP 20,000', headerStyleLBP);
    _setCell(sheet, 'E11', 'LBP 10,000', headerStyleLBP);
    _setCell(sheet, 'F11', 'LBP 5,000', headerStyleLBP);
    _setCell(sheet, 'G11', 'LBP 1,000', headerStyleLBP);
    _setCell(sheet, 'H11', 'TOTAL', headerStyleLBP);
    _setCell(sheet, 'J11', 'SEND TO HO', headerStyleLBP);
    _setCell(sheet, 'K11', 'REMAINING BALANCE', headerStyleLBP);
    
    // ============ ROW 12: LBP BRANCH (your data) ============
    _setCell(sheet, 'A12', 'BRANCH', dataStyle);
    _setCellInt(sheet, 'B12', count.lbpQty[0], dataStyle);
    _setCellInt(sheet, 'C12', count.lbpQty[1], dataStyle);
    _setCellInt(sheet, 'D12', count.lbpQty[2], dataStyle);
    _setCellInt(sheet, 'E12', count.lbpQty[3], dataStyle);
    _setCellInt(sheet, 'F12', count.lbpQty[4], dataStyle);
    _setCellInt(sheet, 'G12', count.lbpQty[5], dataStyle);
    // FORMULA: =B12*100000+C12*50000+D12*20000+E12*10000+F12*5000+G12*1000
    _setFormula(sheet, 'H12', 'B12*100000+C12*50000+D12*20000+E12*10000+F12*5000+G12*1000', dataStyle);
    _setFormula(sheet, 'K12', 'H12-J12', dataStyle);
    
    // ============ ROW 13: LBP COLLECTOR ============
    _setCell(sheet, 'A13', 'COLLECTOR', dataStyle);
    _setFormula(sheet, 'H13', 'B13*100000+C13*50000+D13*20000+E13*10000+F13*5000+G13*1000', dataStyle);
    _setFormula(sheet, 'K13', 'IF(H13=0,"LBP 0",H13-J13)', dataStyle);
    
    // ============ ROW 14: LBP JOSEPH ============
    _setCell(sheet, 'A14', 'JOSEPH', dataStyle);
    _setFormula(sheet, 'H14', 'B14*100000+C14*50000+D14*20000+E14*10000+F14*5000+G14*1000', dataStyle);
    _setFormula(sheet, 'K14', 'IF(H14=0,"LBP 0",H14-J14)', redStyle);
    
    // ============ ROW 15: LBP SAVIO ============
    _setCell(sheet, 'A15', 'SAVIO', dataStyle);
    _setFormula(sheet, 'H15', 'B15*100000+C15*50000+D15*20000+E15*10000+F15*5000+G15*1000', dataStyle);
    _setFormula(sheet, 'K15', 'IF(H15=0,"LBP 0",H15-J15)', dataStyle);
    
    // ============ ROW 16: LBP Empty row ============
    _setFormula(sheet, 'H16', 'B16*100000+C16*50000+D16*20000+E16*10000+F16*5000+G16*1000', dataStyle);
    _setFormula(sheet, 'K16', 'IF(H16=0,"LBP 0",H16-J16)', redStyle);
    
    // ============ ROW 17: LBP TOTAL ============
    _setCell(sheet, 'A17', 'TOTAL', totalRowStyle);
    _setFormula(sheet, 'B17', 'SUM(B12:B16)', totalRowStyle);
    _setFormula(sheet, 'C17', 'SUM(C12:C16)', totalRowStyle);
    _setFormula(sheet, 'D17', 'SUM(D12:D16)', totalRowStyle);
    _setFormula(sheet, 'E17', 'SUM(E12:E16)', totalRowStyle);
    _setFormula(sheet, 'F17', 'SUM(F12:F16)', totalRowStyle);
    _setFormula(sheet, 'G17', 'SUM(G12:G16)', totalRowStyle);
    _setFormula(sheet, 'H17', 'SUM(H12:H16)', greenTotalStyle);
    _setFormula(sheet, 'J17', 'SUM(J12:J16)', totalRowStyle);
    _setFormula(sheet, 'K17', 'SUM(K12:K16)', totalRowStyle);
    
    // ============ ROW 18: Empty ============
    
    // ============ ROW 19: DATE ============
    _setCell(sheet, 'G19', 'DATE :', dataStyle);
    _setCell(sheet, 'H19', count.date, dataStyle);
    
    // ============ ROW 20: Empty ============
    
    // ============ ROW 21: TAJ Header ============
    _setCell(sheet, 'A21', 'TAJ', CellStyle(backgroundColorHex: ExcelColor.fromHexString(_headerGray), bold: true));
    _setCell(sheet, 'B21', 'PERSON', CellStyle(backgroundColorHex: ExcelColor.fromHexString(_headerGray), bold: true));
    _setCell(sheet, 'C21', 'USER', CellStyle(backgroundColorHex: ExcelColor.fromHexString(_headerGray), bold: true));
    _setCell(sheet, 'D21', 'PASS', CellStyle(backgroundColorHex: ExcelColor.fromHexString(_headerGray), bold: true));
    _setCell(sheet, 'E21', 'ACC #', CellStyle(backgroundColorHex: ExcelColor.fromHexString(_headerGray), bold: true));
    
    // ============ ROW 22: TAJ Data (empty for manual entry) ============
    _setCell(sheet, 'A22', '1', dataStyle);
    
    // Set column widths
    sheet.setColumnWidth(0, 12);   // A
    sheet.setColumnWidth(1, 12);   // B
    sheet.setColumnWidth(2, 12);   // C
    sheet.setColumnWidth(3, 12);   // D
    sheet.setColumnWidth(4, 12);   // E
    sheet.setColumnWidth(5, 12);   // F
    sheet.setColumnWidth(6, 12);   // G
    sheet.setColumnWidth(7, 18);   // H - TOTAL
    sheet.setColumnWidth(8, 3);    // I - Gap
    sheet.setColumnWidth(9, 14);   // J - SEND TO HO
    sheet.setColumnWidth(10, 22);  // K - REMAINING BALANCE
    
    return Uint8List.fromList(excel.encode()!);
  }
  
  // Helper to set text cell
  static void _setCell(Sheet sheet, String cellRef, String value, CellStyle style) {
    sheet.cell(CellIndex.indexByString(cellRef)).value = TextCellValue(value);
    sheet.cell(CellIndex.indexByString(cellRef)).cellStyle = style;
  }
  
  // Helper to set integer cell
  static void _setCellInt(Sheet sheet, String cellRef, int value, CellStyle style) {
    if (value > 0) {
      sheet.cell(CellIndex.indexByString(cellRef)).value = IntCellValue(value);
    }
    sheet.cell(CellIndex.indexByString(cellRef)).cellStyle = style;
  }
  
  // Helper to set formula cell
  static void _setFormula(Sheet sheet, String cellRef, String formula, CellStyle style) {
    sheet.cell(CellIndex.indexByString(cellRef)).value = FormulaCellValue('=$formula');
    sheet.cell(CellIndex.indexByString(cellRef)).cellStyle = style;
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
