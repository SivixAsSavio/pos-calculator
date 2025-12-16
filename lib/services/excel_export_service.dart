import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'cash_count_service.dart';

// Conditional imports for web vs desktop
import 'excel_export_stub.dart'
    if (dart.library.html) 'excel_export_web.dart'
    if (dart.library.io) 'excel_export_io.dart' as platform;

class ExcelExportService {
  // Colors - Blue, Accent 1 variations
  static const String _blueAccent1Lighter40 = 'FF8FAADC';  // Blue, Accent 1, Lighter 40%
  static const String _blueAccent1Lighter80 = 'FFD6DCE5';  // Blue, Accent 1, Lighter 80%
  static const String _white = 'FFFFFFFF';
  static const String _black = 'FF000000';

  // Border style
  static Border get _thinBorder => Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString(_black));
  static Border get _noBorder => Border(borderStyle: BorderStyle.None);

  /// Generate proper Excel file with FORMULAS matching the exact layout
  static Uint8List generateExcelBytes(CashCount count) {
    final excel = Excel.createExcel();
    final sheetName = 'TOTAL';
    
    // Remove default sheet and create our sheet
    excel.delete('Sheet1');
    final sheet = excel[sheetName];
    
    // Title style - 16px font, bottom and right border only
    final titleStyle = CellStyle(
      bold: true,
      fontSize: 16,
      verticalAlign: VerticalAlign.Center,
      horizontalAlign: HorizontalAlign.Left,
      bottomBorder: _thinBorder,
      rightBorder: _thinBorder,
    );
    
    // Header style for denomination labels ($100, $50, LBP 100,000, etc.) - white background, black text
    final denomHeaderStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(_white),
      fontColorHex: ExcelColor.fromHexString(_black),
      bold: true,
      fontSize: 12,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: _thinBorder,
      rightBorder: _thinBorder,
      topBorder: _thinBorder,
      bottomBorder: _thinBorder,
    );
    
    // Section header style (USD, LBP, TOTAL, SEND TO HO, REMAINING BALANCE) - Blue Accent 1 Lighter 40%
    final sectionHeaderStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(_blueAccent1Lighter40),
      fontColorHex: ExcelColor.fromHexString(_black),
      bold: true,
      fontSize: 12,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: _thinBorder,
      rightBorder: _thinBorder,
      topBorder: _thinBorder,
      bottomBorder: _thinBorder,
    );
    
    // Data style for numbers - 12px font
    final dataStyleNumber = CellStyle(
      fontSize: 12,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: _thinBorder,
      rightBorder: _thinBorder,
      topBorder: _thinBorder,
      bottomBorder: _thinBorder,
    );
    
    // Data style for names (BRANCH, COLLECTOR, user) - 11px font
    final dataStyleName = CellStyle(
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: _thinBorder,
      rightBorder: _thinBorder,
      topBorder: _thinBorder,
      bottomBorder: _thinBorder,
    );
    
    // Total row style (bottom calculation rows) - Blue Accent 1 Lighter 80%
    final totalRowStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(_blueAccent1Lighter80),
      fontColorHex: ExcelColor.fromHexString(_black),
      bold: true,
      fontSize: 12,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: _thinBorder,
      rightBorder: _thinBorder,
      topBorder: _thinBorder,
      bottomBorder: _thinBorder,
    );
    
    final tajHeaderStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(_blueAccent1Lighter40),
      fontColorHex: ExcelColor.fromHexString(_black),
      bold: true,
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: _thinBorder,
      rightBorder: _thinBorder,
      topBorder: _thinBorder,
      bottomBorder: _thinBorder,
    );

    // ============ ROW 1: CALCULATOR SHEET HEADER - 30px height, 16px text ============
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('CALCULATOR SHEET - TOTAL NAHER IBRAHIM');
    sheet.cell(CellIndex.indexByString('B1')).cellStyle = titleStyle;
    sheet.merge(CellIndex.indexByString('B1'), CellIndex.indexByString('H1'));
    
    // ============ ROW 2: Empty ============
    
    // ============ ROW 3: USD HEADER ============
    _setCell(sheet, 'A3', 'USD', sectionHeaderStyle);
    _setCell(sheet, 'B3', '\$100', denomHeaderStyle);
    _setCell(sheet, 'C3', '\$50', denomHeaderStyle);
    _setCell(sheet, 'D3', '\$20', denomHeaderStyle);
    _setCell(sheet, 'E3', '\$10', denomHeaderStyle);
    _setCell(sheet, 'F3', '\$5', denomHeaderStyle);
    _setCell(sheet, 'G3', '\$1', denomHeaderStyle);
    _setCell(sheet, 'H3', 'TOTAL', sectionHeaderStyle);
    _setCell(sheet, 'J3', 'SEND TO HO', sectionHeaderStyle);
    _setCell(sheet, 'K3', 'REMAINING BALANCE', sectionHeaderStyle);
    
    // ============ ROW 4: BRANCH (Safe cash - from settings) ============
    _setCell(sheet, 'A4', 'BRANCH', dataStyleName);
    _setCellInt(sheet, 'B4', count.branchUsdQty[0], dataStyleNumber);
    _setCellInt(sheet, 'C4', count.branchUsdQty[1], dataStyleNumber);
    _setCellInt(sheet, 'D4', count.branchUsdQty[2], dataStyleNumber);
    _setCellInt(sheet, 'E4', count.branchUsdQty[3], dataStyleNumber);
    _setCellInt(sheet, 'F4', count.branchUsdQty[4], dataStyleNumber);
    _setCellInt(sheet, 'G4', count.branchUsdQty[5], dataStyleNumber);
    _setFormulaWithFormat(sheet, 'H4', 'B4*100+C4*50+D4*20+E4*10+F4*5+G4*1', dataStyleNumber);
    _setEmptyCell(sheet, 'J4', dataStyleNumber);
    _setFormulaWithFormat(sheet, 'K4', 'H4-J4', dataStyleNumber);
    
    // ============ ROW 5: COLLECTOR ============
    _setCell(sheet, 'A5', 'COLLECTOR', dataStyleName);
    _setEmptyCell(sheet, 'B5', dataStyleNumber);
    _setEmptyCell(sheet, 'C5', dataStyleNumber);
    _setEmptyCell(sheet, 'D5', dataStyleNumber);
    _setEmptyCell(sheet, 'E5', dataStyleNumber);
    _setEmptyCell(sheet, 'F5', dataStyleNumber);
    _setEmptyCell(sheet, 'G5', dataStyleNumber);
    _setFormulaWithFormat(sheet, 'H5', 'B5*100+C5*50+D5*20+E5*10+F5*5+G5*1', dataStyleNumber);
    _setEmptyCell(sheet, 'J5', dataStyleNumber);
    _setFormulaWithFormat(sheet, 'K5', 'H5-J5', dataStyleNumber);
    
    // ============ ROW 6: User's drawer cash ============
    final userName = count.userName.isNotEmpty ? count.userName : 'user';
    _setCell(sheet, 'A6', userName, dataStyleName);
    _setCellInt(sheet, 'B6', count.usdQty[0], dataStyleNumber);
    _setCellInt(sheet, 'C6', count.usdQty[1], dataStyleNumber);
    _setCellInt(sheet, 'D6', count.usdQty[2], dataStyleNumber);
    _setCellInt(sheet, 'E6', count.usdQty[3], dataStyleNumber);
    _setCellInt(sheet, 'F6', count.usdQty[4], dataStyleNumber);
    _setCellInt(sheet, 'G6', count.usdQty[5], dataStyleNumber);
    _setFormulaWithFormat(sheet, 'H6', 'B6*100+C6*50+D6*20+E6*10+F6*5+G6*1', dataStyleNumber);
    _setEmptyCell(sheet, 'J6', dataStyleNumber);
    _setFormulaWithFormat(sheet, 'K6', 'H6-J6', dataStyleNumber);
    
    // ============ ROW 7: Empty row ============
    _setEmptyCell(sheet, 'A7', dataStyleNumber);
    _setEmptyCell(sheet, 'B7', dataStyleNumber);
    _setEmptyCell(sheet, 'C7', dataStyleNumber);
    _setEmptyCell(sheet, 'D7', dataStyleNumber);
    _setEmptyCell(sheet, 'E7', dataStyleNumber);
    _setEmptyCell(sheet, 'F7', dataStyleNumber);
    _setEmptyCell(sheet, 'G7', dataStyleNumber);
    _setFormulaWithFormat(sheet, 'H7', 'B7*100+C7*50+D7*20+E7*10+F7*5+G7*1', dataStyleNumber);
    _setEmptyCell(sheet, 'J7', dataStyleNumber);
    _setFormulaWithFormat(sheet, 'K7', 'H7-J7', dataStyleNumber);
    
    // ============ ROW 8: USD TOTAL - Blue Accent 1 Lighter 80% ============
    _setCell(sheet, 'A8', 'TOTAL', totalRowStyle);
    _setFormulaWithFormat(sheet, 'B8', 'SUM(B4:B7)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'C8', 'SUM(C4:C7)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'D8', 'SUM(D4:D7)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'E8', 'SUM(E4:E7)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'F8', 'SUM(F4:F7)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'G8', 'SUM(G4:G7)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'H8', 'SUM(H4:H7)', totalRowStyle);
    // Send to H.O. - user input value
    if (count.sendToHoUsd > 0) {
      _setCellDouble(sheet, 'J8', count.sendToHoUsd, totalRowStyle);
    } else {
      _setEmptyCell(sheet, 'J8', totalRowStyle);
    }
    _setFormulaWithFormat(sheet, 'K8', 'H8-J8', totalRowStyle);
    
    // ============ ROW 9: Empty ============
    
    // ============ ROW 10: LBP HEADER ============
    _setCell(sheet, 'A10', 'LBP', sectionHeaderStyle);
    _setCell(sheet, 'B10', 'LBP 100,000', denomHeaderStyle);
    _setCell(sheet, 'C10', 'LBP 50,000', denomHeaderStyle);
    _setCell(sheet, 'D10', 'LBP 20,000', denomHeaderStyle);
    _setCell(sheet, 'E10', 'LBP 10,000', denomHeaderStyle);
    _setCell(sheet, 'F10', 'LBP 5,000', denomHeaderStyle);
    _setCell(sheet, 'G10', 'LBP 1,000', denomHeaderStyle);
    _setCell(sheet, 'H10', 'TOTAL', sectionHeaderStyle);
    _setCell(sheet, 'J10', 'SEND TO HO', sectionHeaderStyle);
    _setCell(sheet, 'K10', 'REMAINING BALANCE', sectionHeaderStyle);
    
    // ============ ROW 11: LBP BRANCH (Safe cash - from settings) ============
    _setCell(sheet, 'A11', 'BRANCH', dataStyleName);
    _setCellInt(sheet, 'B11', count.branchLbpQty[0], dataStyleNumber);
    _setCellInt(sheet, 'C11', count.branchLbpQty[1], dataStyleNumber);
    _setCellInt(sheet, 'D11', count.branchLbpQty[2], dataStyleNumber);
    _setCellInt(sheet, 'E11', count.branchLbpQty[3], dataStyleNumber);
    _setCellInt(sheet, 'F11', count.branchLbpQty[4], dataStyleNumber);
    _setCellInt(sheet, 'G11', count.branchLbpQty[5], dataStyleNumber);
    _setFormulaWithFormat(sheet, 'H11', 'B11*100000+C11*50000+D11*20000+E11*10000+F11*5000+G11*1000', dataStyleNumber);
    _setEmptyCell(sheet, 'J11', dataStyleNumber);
    _setFormulaWithFormat(sheet, 'K11', 'H11-J11', dataStyleNumber);
    
    // ============ ROW 12: LBP COLLECTOR ============
    _setCell(sheet, 'A12', 'COLLECTOR', dataStyleName);
    _setEmptyCell(sheet, 'B12', dataStyleNumber);
    _setEmptyCell(sheet, 'C12', dataStyleNumber);
    _setEmptyCell(sheet, 'D12', dataStyleNumber);
    _setEmptyCell(sheet, 'E12', dataStyleNumber);
    _setEmptyCell(sheet, 'F12', dataStyleNumber);
    _setEmptyCell(sheet, 'G12', dataStyleNumber);
    _setFormulaWithFormat(sheet, 'H12', 'B12*100000+C12*50000+D12*20000+E12*10000+F12*5000+G12*1000', dataStyleNumber);
    _setEmptyCell(sheet, 'J12', dataStyleNumber);
    _setFormulaWithFormat(sheet, 'K12', 'H12-J12', dataStyleNumber);
    
    // ============ ROW 13: LBP User's drawer cash ============
    _setCell(sheet, 'A13', userName, dataStyleName);
    _setCellInt(sheet, 'B13', count.lbpQty[0], dataStyleNumber);
    _setCellInt(sheet, 'C13', count.lbpQty[1], dataStyleNumber);
    _setCellInt(sheet, 'D13', count.lbpQty[2], dataStyleNumber);
    _setCellInt(sheet, 'E13', count.lbpQty[3], dataStyleNumber);
    _setCellInt(sheet, 'F13', count.lbpQty[4], dataStyleNumber);
    _setCellInt(sheet, 'G13', count.lbpQty[5], dataStyleNumber);
    _setFormulaWithFormat(sheet, 'H13', 'B13*100000+C13*50000+D13*20000+E13*10000+F13*5000+G13*1000', dataStyleNumber);
    _setEmptyCell(sheet, 'J13', dataStyleNumber);
    _setFormulaWithFormat(sheet, 'K13', 'H13-J13', dataStyleNumber);
    
    // ============ ROW 14: LBP Empty row ============
    _setEmptyCell(sheet, 'A14', dataStyleNumber);
    _setEmptyCell(sheet, 'B14', dataStyleNumber);
    _setEmptyCell(sheet, 'C14', dataStyleNumber);
    _setEmptyCell(sheet, 'D14', dataStyleNumber);
    _setEmptyCell(sheet, 'E14', dataStyleNumber);
    _setEmptyCell(sheet, 'F14', dataStyleNumber);
    _setEmptyCell(sheet, 'G14', dataStyleNumber);
    _setFormulaWithFormat(sheet, 'H14', 'B14*100000+C14*50000+D14*20000+E14*10000+F14*5000+G14*1000', dataStyleNumber);
    _setEmptyCell(sheet, 'J14', dataStyleNumber);
    _setFormulaWithFormat(sheet, 'K14', 'H14-J14', dataStyleNumber);
    
    // ============ ROW 15: LBP TOTAL - Blue Accent 1 Lighter 80% ============
    _setCell(sheet, 'A15', 'TOTAL', totalRowStyle);
    _setFormulaWithFormat(sheet, 'B15', 'SUM(B11:B14)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'C15', 'SUM(C11:C14)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'D15', 'SUM(D11:D14)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'E15', 'SUM(E11:E14)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'F15', 'SUM(F11:F14)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'G15', 'SUM(G11:G14)', totalRowStyle);
    _setFormulaWithFormat(sheet, 'H15', 'SUM(H11:H14)', totalRowStyle);
    // Send to H.O. - user input value
    if (count.sendToHoLbp > 0) {
      _setCellInt(sheet, 'J15', count.sendToHoLbp, totalRowStyle);
    } else {
      _setEmptyCell(sheet, 'J15', totalRowStyle);
    }
    _setFormulaWithFormat(sheet, 'K15', 'H15-J15', totalRowStyle);
    
    // ============ ROW 16: Empty ============
    
    // ============ ROW 17: DATE ============
    _setCell(sheet, 'G17', 'DATE :', dataStyleNumber);
    _setCell(sheet, 'H17', count.date, dataStyleNumber);
    
    // ============ ROW 18: Empty ============
    
    // ============ ROW 19: TAJ Header ============
    _setCell(sheet, 'A19', 'TAJ', tajHeaderStyle);
    _setCell(sheet, 'B19', 'PERSON', tajHeaderStyle);
    _setCell(sheet, 'C19', 'USER', tajHeaderStyle);
    _setCell(sheet, 'D19', 'PASS', tajHeaderStyle);
    _setCell(sheet, 'E19', 'ACC #', tajHeaderStyle);
    
    // ============ ROW 20: TAJ Data ============
    _setCell(sheet, 'A20', '1', dataStyleNumber);
    _setCell(sheet, 'B20', count.tajPerson, dataStyleNumber);
    _setCell(sheet, 'C20', count.tajUser, dataStyleNumber);
    _setCell(sheet, 'D20', count.tajPass, dataStyleNumber);
    _setCell(sheet, 'E20', count.tajAccNum, dataStyleNumber);
    
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
    
    // Set row heights
    sheet.setRowHeight(1, 30);  // Title row - 30 pixels
    for (int i = 2; i <= 20; i++) {
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
  
  // Helper to set double cell with number formatting
  static void _setCellDouble(Sheet sheet, String cellRef, double value, CellStyle style) {
    if (value > 0) {
      sheet.cell(CellIndex.indexByString(cellRef)).value = DoubleCellValue(value);
    }
    sheet.cell(CellIndex.indexByString(cellRef)).cellStyle = style.copyWith(
      numberFormat: NumFormat.custom(formatCode: '#,##0'),
    );
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
