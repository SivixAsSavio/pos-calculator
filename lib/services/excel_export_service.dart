import 'package:flutter/foundation.dart' show kIsWeb;
import 'cash_count_service.dart';

// Conditional imports for web vs desktop
import 'excel_export_stub.dart'
    if (dart.library.html) 'excel_export_web.dart'
    if (dart.library.io) 'excel_export_io.dart' as platform;

class ExcelExportService {
  /// Generate the Excel content as CSV matching the CALCULATOR SHEET layout
  static String generateExcelContent(CashCount count) {
    final buffer = StringBuffer();
    
    // Row 1: CALCULATOR SHEET header
    buffer.writeln(',CALCULATOR SHEET,,,,,,,,,,,');
    // Row 2: Empty
    buffer.writeln(',,,,,,,,,,,');
    
    // Row 3: USD Header row
    buffer.writeln('USD,\$100,\$50,\$20,\$10,\$5,\$1,TOTAL,,SEND TO HO,REMAINING BALANCE,');
    
    // Row 4: BRANCH row (your count data) - formulas calculate total
    final usdBranchTotal = count.usdQty[0] * 100 + count.usdQty[1] * 50 + count.usdQty[2] * 20 + 
                           count.usdQty[3] * 10 + count.usdQty[4] * 5 + count.usdQty[5] * 1;
    buffer.writeln('BRANCH,${count.usdQty[0]},${count.usdQty[1]},${count.usdQty[2]},${count.usdQty[3]},${count.usdQty[4]},${count.usdQty[5]},\$$usdBranchTotal,,,\$$usdBranchTotal,');
    
    // Row 5: COLLECTOR row (empty for manual entry)
    buffer.writeln('COLLECTOR,,,,,,,,,LBP 0,LBP 0,');
    
    // Row 6: Empty user row
    buffer.writeln(',,,,,,,,,,,');
    
    // Row 7: Another empty row
    buffer.writeln(',,,,,,,,,,,');
    
    // Row 8: Empty
    buffer.writeln(',,,,,,,,,,,');
    
    // Row 9: TOTAL row
    buffer.writeln('TOTAL,${count.usdQty[0]},${count.usdQty[1]},${count.usdQty[2]},${count.usdQty[3]},${count.usdQty[4]},${count.usdQty[5]},\$$usdBranchTotal,,,\$$usdBranchTotal,');
    
    // Row 10: Empty
    buffer.writeln(',,,,,,,,,,,');
    
    // Row 11: LBP Header row
    buffer.writeln('LBP,LBP 100000,LBP 50000,LBP 20000,LBP 10000,LBP 5000,LBP 1000,TOTAL,,SEND TO HO,REMAINING BALANCE,');
    
    // Row 12: BRANCH row for LBP
    final lbpBranchTotal = count.lbpQty[0] * 100000 + count.lbpQty[1] * 50000 + count.lbpQty[2] * 20000 + 
                           count.lbpQty[3] * 10000 + count.lbpQty[4] * 5000 + count.lbpQty[5] * 1000;
    buffer.writeln('BRANCH,${count.lbpQty[0]},${count.lbpQty[1]},${count.lbpQty[2]},${count.lbpQty[3]},${count.lbpQty[4]},${count.lbpQty[5]},LBP ${_formatNumber(lbpBranchTotal)},,,LBP ${_formatNumber(lbpBranchTotal)},');
    
    // Row 13: COLLECTOR row (empty)
    buffer.writeln('COLLECTOR,,,,,,,,,LBP 0,LBP 0,');
    
    // Row 14: Empty row
    buffer.writeln(',,,,,,,,,LBP 0,LBP 0,');
    
    // Row 15: Empty row
    buffer.writeln(',,,,,,,,,LBP 0,LBP 0,');
    
    // Row 16: Empty
    buffer.writeln(',,,,,,,,,,,');
    
    // Row 17: TOTAL row for LBP
    buffer.writeln('TOTAL,${count.lbpQty[0]},${count.lbpQty[1]},${count.lbpQty[2]},${count.lbpQty[3]},${count.lbpQty[4]},${count.lbpQty[5]},LBP ${_formatNumber(lbpBranchTotal)},,LBP 0,LBP ${_formatNumber(lbpBranchTotal)},');
    
    // Row 18: Empty
    buffer.writeln(',,,,,,,,,,,');
    
    // Row 19: DATE section
    buffer.writeln(',,,,,DATE :,${count.date},,,,');
    
    // Row 20: Empty
    buffer.writeln(',,,,,,,,,,,');
    
    // Row 21: TAJ info header
    buffer.writeln('TAJ,PERSON,USER,PASS,ACC #,,,,,,,');
    
    // Row 22: TAJ values
    buffer.writeln(',,,,,,,,,,,');
    
    // Row 23: Empty
    buffer.writeln(',,,,,,,,,,,');
    
    // Row 24: TAJ USD and LBP summary
    buffer.writeln('TAJ USD,${count.tajUsd.toStringAsFixed(0)},,,TAJ LBP,${_formatNumber(count.tajLbp)},,,,,,');
    
    // Row 25: TEST results
    buffer.writeln('TEST USD,${count.usdTest},,,TEST LBP,${count.lbpTest},,,,,,');
    
    return buffer.toString();
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
    return 'CashCount_$timestamp.csv';
  }
  
  /// Export to Excel format (works on both web and desktop)
  static Future<String?> exportToExcelFormat(CashCount count) async {
    try {
      final content = generateExcelContent(count);
      final filename = generateFilename(count);
      
      return await platform.saveFile(content, filename);
    } catch (e) {
      print('Error exporting to Excel format: $e');
      return null;
    }
  }
}
