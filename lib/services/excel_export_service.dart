import 'dart:typed_data';
import 'package:excel/excel.dart';
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

  // Border style
  static Border get _thinBorder => Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString(_black));

  /// Generate proper Excel file with FORMULAS matching the exact layout
  static Uint8List generateExcelBytes(CashCount count) {
    final excel = Excel.createExcel();
    final sheetName = 'TOTAL';
    
    // Remove default sheet and create our sheet
    excel.delete('Sheet1');
    final sheet = excel[sheetName];
    
    // Styles - all with vertical center alignment and borders
    final headerStyleUSD = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(_darkBlue),
      fontColorHex: ExcelColor.fromHexString(_white),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: _thinBorder,
      rightBorder: _thinBorder,
      topBorder: _thinBorder,
      bottomBorder: _thinBorder,
    );
    
    final headerStyleLBP = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(_lightBlue),
      fontColorHex: ExcelColor.fromHexString(_white),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: _thinBorder,
      rightBorder: _thinBorder,
      topBorder: _thinBorder,
      bottomBorder: _thinBorder,
    );
    
    final dataStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: _thinBorder,
      rightBorder: _thinBorder,
      topBorder: _thinBorder,
      bottomBorder: _thinBorder,
    );
    
    final totalRowStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(_headerGray),
      fontColorHex: ExcelColor.fromHexString(_black),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: _thinBorder,
      rightBorder: _thinBorder,
      topBorder: _thinBorder,
      bottomBorder: _thinBorder,
    );
    
    final tajHeaderStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(_headerGray),
      fontColorHex: ExcelColor.fromHexString(_black),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: _thinBorder,
      rightBorder: _thinBorder,
      topBorder: _thinBorder,
      bottomBorder: _thinBorder,
    );

    // ============ ROW 1: CALCULATOR SHEET HEADER ============
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('CALCULATOR SHEET - TOTAL NAHER IBRAHIM');
    sheet.cell(CellIndex.indexByString('B1')).cellStyle = CellStyle(bold: true, fontSize: 12, verticalAlign: VerticalAlign.Center);
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
    _setFormulaWithFormat(sheet, 'H4', 'B4*100+C4*50+D4*20+E4*10+F4*5+G4*1', dataStyle);
    _setEmptyCell(sheet, 'J4', dataStyle);
    _setFormulaWithFormat(sheet, 'K4', 'H4-J4', dataStyle);
    
    // ============ ROW 5: COLLECTOR ============
    _setCell(sheet, 'A5', 'COLLECTOR', dataStyle);
    _setEmptyCell(sheet, 'B5', dataStyle);
    _setEmptyCell(sheet, 'C5', dataStyle);
    _setEmptyCell(sheet, 'D5', dataStyle);
    _setEmptyCell(sheet, 'E5', dataStyle);
    _setEmptyCell(sheet, 'F5', dataStyle);
    _setEmptyCell(sheet, 'G5', dataStyle);
    _setFormulaWithFormat(sheet, 'H5', 'B5*100+C5*50+D5*20+E5*10+F5*5+G5*1', dataStyle);
    _setEmptyCell(sheet, 'J5', dataStyle);
    _setFormulaWithFormat(sheet, 'K5', 'H5-J5', dataStyle);
    
    // ============ ROW 6: user (empty row for manual entry) ============
    _setCell(sheet, 'A6', 'user', dataStyle);
    _setEmptyCell(sheet, 'B6', dataStyle);
    _setEmptyCell(sheet, 'C6', dataStyle);
    _setEmptyCell(sheet, 'D6', dataStyle);
    _setEmptyCell(sheet, 'E6', dataStyle);
    _setEmptyCell(sheet, 'F6', dataStyle);
    _setEmptyCell(sheet, 'G6', dataStyle);
    _setFormulaWithFormat(sheet, 'H6', 'B6*100+C6*50+D6*20+E6*10+F6*5+G6*1', dataStyle);
    _setEmptyCell(sheet, 'J6', dataStyle);
    _setFormulaWithFormat(sheet, 'K6', 'H6-J6', dataStyle);
    
    // ============ ROW 7: Empty row ============
    _setEmptyCell(sheet, 'A7', dataStyle);
    _setEmptyCell(sheet, 'B7', dataStyle);
    _setEmptyCell(sheet, 'C7', dataStyle);
    _setEmptyCell(sheet, 'D7', dataStyle);
    _setEmptyCell(sheet, 'E7', dataStyle);
    _setEmptyCell(sheet, 'F7', dataStyle);
    _setEmptyCell(sheet, 'G7', dataStyle);
    _setFormulaWithFormat(sheet, 'H7', 'B7*100+C7*50+D7*20+E7*10+F7*5+G7*1', dataStyle);
    _setEmptyCell(sheet, 'J7', dataStyle);
    _setFormulaWithFormat(sheet, 'K7', 'H7-J7', dataStyle);
    
    // ============ ROW 8: USD TOTAL ============
    _setCell(sheet, 'A8', 'TOTAL', totalRowStyle);
    _setFormulaWithFormat(sheet, 'B8', 'SUM(B4:B7)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'C8', 'SUM(C4:C7)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'D8', 'SUM(D4:D7)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'E8', 'SUM(E4:E7)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'F8', 'SUM(F4:F7)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'G8', 'SUM(G4:G7)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'H8', 'SUM(H4:H7)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'J8', 'SUM(J4:J7)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'K8', 'SUM(K4:K7)', totalRowStyle);
    
    // ============ ROW 9: Empty ============
    
    // ============ ROW 10: LBP HEADER ============
    _setCell(sheet, 'A10', 'LBP', headerStyleLBP);
    _setCell(sheet, 'B10', 'LBP 100,000', headerStyleLBP);
    _setCell(sheet, 'C10', 'LBP 50,000', headerStyleLBP);
    _setCell(sheet, 'D10', 'LBP 20,000', headerStyleLBP);
    _setCell(sheet, 'E10', 'LBP 10,000', headerStyleLBP);
    _setCell(sheet, 'F10', 'LBP 5,000', headerStyleLBP);
    _setCell(sheet, 'G10', 'LBP 1,000', headerStyleLBP);
    _setCell(sheet, 'H10', 'TOTAL', headerStyleLBP);
    _setCell(sheet, 'J10', 'SEND TO HO', headerStyleLBP);
    _setCell(sheet, 'K10', 'REMAINING BALANCE', headerStyleLBP);
    
    // ============ ROW 11: LBP BRANCH (your data) ============
    _setCell(sheet, 'A11', 'BRANCH', dataStyle);
    _setCellInt(sheet, 'B11', count.lbpQty[0], dataStyle);
    _setCellInt(sheet, 'C11', count.lbpQty[1], dataStyle);
    _setCellInt(sheet, 'D11', count.lbpQty[2], dataStyle);
    _setCellInt(sheet, 'E11', count.lbpQty[3], dataStyle);
    _setCellInt(sheet, 'F11', count.lbpQty[4], dataStyle);
    _setCellInt(sheet, 'G11', count.lbpQty[5], dataStyle);
    _setFormulaWithFormat(sheet, 'H11', 'B11*100000+C11*50000+D11*20000+E11*10000+F11*5000+G11*1000', dataStyle);
    _setEmptyCell(sheet, 'J11', dataStyle);
    _setFormulaWithFormat(sheet, 'K11', 'H11-J11', dataStyle);
    
    // ============ ROW 12: LBP COLLECTOR ============
    _setCell(sheet, 'A12', 'COLLECTOR', dataStyle);
    _setEmptyCell(sheet, 'B12', dataStyle);
    _setEmptyCell(sheet, 'C12', dataStyle);
    _setEmptyCell(sheet, 'D12', dataStyle);
    _setEmptyCell(sheet, 'E12', dataStyle);
    _setEmptyCell(sheet, 'F12', dataStyle);
    _setEmptyCell(sheet, 'G12', dataStyle);
    _setFormulaWithFormat(sheet, 'H12', 'B12*100000+C12*50000+D12*20000+E12*10000+F12*5000+G12*1000', dataStyle);
    _setEmptyCell(sheet, 'J12', dataStyle);
    _setFormulaWithFormat(sheet, 'K12', 'H12-J12', dataStyle);
    
    // ============ ROW 13: LBP user ============
    _setCell(sheet, 'A13', 'user', dataStyle);
    _setEmptyCell(sheet, 'B13', dataStyle);
    _setEmptyCell(sheet, 'C13', dataStyle);
    _setEmptyCell(sheet, 'D13', dataStyle);
    _setEmptyCell(sheet, 'E13', dataStyle);
    _setEmptyCell(sheet, 'F13', dataStyle);
    _setEmptyCell(sheet, 'G13', dataStyle);
    _setFormulaWithFormat(sheet, 'H13', 'B13*100000+C13*50000+D13*20000+E13*10000+F13*5000+G13*1000', dataStyle);
    _setEmptyCell(sheet, 'J13', dataStyle);
    _setFormulaWithFormat(sheet, 'K13', 'H13-J13', dataStyle);
    
    // ============ ROW 14: LBP Empty row ============
    _setEmptyCell(sheet, 'A14', dataStyle);
    _setEmptyCell(sheet, 'B14', dataStyle);
    _setEmptyCell(sheet, 'C14', dataStyle);
    _setEmptyCell(sheet, 'D14', dataStyle);
    _setEmptyCell(sheet, 'E14', dataStyle);
    _setEmptyCell(sheet, 'F14', dataStyle);
    _setEmptyCell(sheet, 'G14', dataStyle);
    _setFormulaWithFormat(sheet, 'H14', 'B14*100000+C14*50000+D14*20000+E14*10000+F14*5000+G14*1000', dataStyle);
    _setEmptyCell(sheet, 'J14', dataStyle);
    _setFormulaWithFormat(sheet, 'K14', 'H14-J14', dataStyle);
    
    // ============ ROW 15: LBP TOTAL ============
    _setCell(sheet, 'A15', 'TOTAL', totalRowStyle);
    _setFormulaWithFormat(sheet, 'B15', 'SUM(B11:B14)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'C15', 'SUM(C11:C14)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'D15', 'SUM(D11:D14)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'E15', 'SUM(E11:E14)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'F15', 'SUM(F11:F14)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'G15', 'SUM(G11:G14)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'H15', 'SUM(H11:H14)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'J15', 'SUM(J11:J14)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'K15', 'SUM(K11:K14)', totalRowStyle);
    
    // ============ ROW 16: Empty ============
    
    // ============ ROW 17: DATE ============
    _setCell(sheet, 'G17', 'DATE :', dataStyle);
    _setCell(sheet, 'H17', count.date, dataStyle);
    
    // ============ ROW 18: Empty ============
    
    // ============ ROW 19: TAJ Header ============
    _setCell(sheet, 'A19', 'TAJ', tajHeaderStyle);
    _setCell(sheet, 'B19', 'PERSON', tajHeaderStyle);
    _setCell(sheet, 'C19', 'USER', tajHeaderStyle);
    _setCell(sheet, 'D19', 'PASS', tajHeaderStyle);
    _setCell(sheet, 'E19', 'ACC #', tajHeaderStyle);
    
    // ============ ROW 20: TAJ Data (empty for manual entry) ============
    _setCell(sheet, 'A20', '1', dataStyle);
    
    // Set column widths
    sheet.setColumnWidth(0, 12);   // A
    sheet.setColumnWidth(1, 14);   // B
    sheet.setColumnWidth(2, 14);   // C
    sheet.setColumnWidth(3, 14);   // D
    sheet.setColumnWidth(4, 14);   // E
    sheet.setColumnWidth(5, 14);   // F
    sheet.setColumnWidth(6, 14);   // G
    sheet.setColumnWidth(7, 18);   // H - TOTAL
    sheet.setColumnWidth(8, 3);    // I - Gap
    sheet.setColumnWidth(9, 14);   // J - SEND TO HO
    sheet.setColumnWidth(10, 22);  // K - REMAINING BALANCE
    
    // Set row heights to 60 pixels (approximately 45 points)
    for (int i = 1; i <= 20; i++) {
      sheet.setRowHeight(i, 45);
    }
    
    return Uint8List.fromList(excel.encode()!);
  }
  
  // Helper to set text cell
  static void _setCell(Sheet sheet, String cellRef, String value, CellStyle style) {
    sheet.cell(CellIndex.indexByString(cellRef)).value = TextCellValue(value);
    sheet.cell(CellIndex.indexByString(cellRef)).cellStyle = style;
  }
  
  // Helper to set empty cell with style (for borders)
  static void _setEmptyCell(Sheet sheet, String cellRef, CellStyle style) {
    sheet.cell(CellIndex.indexByString(cellRef)).cellStyle = style;
  }
  
  // Helper to set integer cell
  static void _setCellInt(Sheet sheet, String cellRef, int value, CellStyle style) {
    if (value > 0) {
      sheet.cell(CellIndex.indexByString(cellRef)).value = IntCellValue(value);
    }
    sheet.cell(CellIndex.indexByString(cellRef)).cellStyle = style;
  }
  
  // Helper to set formula cell with number formatting (commas)
  static void _setFormulaWithFormat(Sheet sheet, String cellRef, String formula, CellStyle style) {
    final cell = sheet.cell(CellIndex.indexByString(cellRef));
    cell.value = FormulaCellValue('=$formula');
    cell.cellStyle = style.copyWith(
      numberFormat: NumFormat.custom(formatCode: '#,##0'),
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
