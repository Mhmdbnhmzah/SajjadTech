import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../viewmodel/reports_viewmodel.dart';

class PdfReportService {
  static Future<void> generateAndPrintReport({
    required DateTime startDate,
    required DateTime endDate,
    required List<Order> orders,
    required Map<int, Customer> customerMap,
    required Map<int, List<OrderItem>> orderItemsMap,
    required double totalSales,
    required double totalPaid,
    required int totalItemsCount,
    required int newCustomersCount,
    required List<CarpetTypeReportRow> carpetBreakdown,
    required String laundryName,
  }) async {
    final pdf = pw.Document();

    // Load beautiful Cairo fonts dynamically from Google Fonts using the printing package
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('yyyy-MM-dd HH:mm');

    // Layout configuration
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicFontBold,
        ),
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // --- HEADER ---
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            laundryName,
                            style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'المغسلة الحديثة للفرش والسجاد',
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'تقرير الأداء والمبيعات',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey900,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'تاريخ التوليد: ${timeFormat.format(DateTime.now())}',
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Divider(thickness: 1.5, color: PdfColors.blue900),
                  pw.SizedBox(height: 16),

                  // --- REPORT RANGE CARD ---
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          'فترة التقرير من: ',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          dateFormat.format(startDate),
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                        pw.Text(
                          '  إلى: ',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          dateFormat.format(endDate),
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 24),

                  // --- STATS SUMMARY TILES ---
                  pw.Text(
                    '1. الملخص العام للفترة',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    children: [
                      _buildPdfStatTile('المبالغ المحصلة', totalPaid.toStringAsFixed(0), 'ريال', PdfColors.green900),
                      pw.SizedBox(width: 10),
                      _buildPdfStatTile('إجمالي الطلبات', '${orders.length}', 'طلبات', PdfColors.cyan900),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    children: [
                      _buildPdfStatTile('إجمالي قطع السجاد', '$totalItemsCount', 'قطعة', PdfColors.amber900),
                      pw.SizedBox(width: 10),
                      _buildPdfStatTile('العملاء الجدد', '$newCustomersCount', 'عملاء', PdfColors.purple900),
                    ],
                  ),
                  pw.SizedBox(height: 24),

                  // --- ORDERS DETAILS TABLE ---
                  pw.Text(
                    '2. قائمة الفواتير المفصلة',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.TableHelper.fromTextArray(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                    cellStyle: const pw.TextStyle(fontSize: 8),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    cellAlignments: {
                      0: pw.Alignment.centerRight,
                      1: pw.Alignment.centerRight,
                      2: pw.Alignment.centerRight,
                      3: pw.Alignment.centerRight,
                      4: pw.Alignment.centerRight,
                      5: pw.Alignment.centerRight,
                      6: pw.Alignment.centerRight,
                    },
                    headers: <String>['رقم الطلب', 'العميل', 'التاريخ', 'تفاصيل القطع (الكمية × السعر)', 'الإجمالي', 'المدفوع', 'الحالة'].reversed.toList(),
                    data: orders.map((order) {
                      final customerName = customerMap[order.customerId]?.name ?? 'عميل غير معروف';
                      final statusStr = order.status == 'received' 
                          ? 'مستلم' 
                          : (order.status == 'ready' ? 'جاهز' : 'تم التسليم');
                      
                      final orderItems = orderItemsMap[order.id] ?? [];
                      final itemsSummary = orderItems.map((item) {
                        final isUnit = item.pricingType == 'unit';
                        final qtyStr = isUnit 
                            ? '${item.quantity} حبة' 
                            : '${item.area?.toStringAsFixed(1)} م²';
                        return '${item.name} ($qtyStr × ${item.unitPrice.toStringAsFixed(0)})';
                      }).join('\n');

                      return <String>[
                        order.id.toString(),
                        customerName,
                        dateFormat.format(order.receivedDate),
                        itemsSummary,
                        order.totalPrice.toStringAsFixed(0),
                        order.paidAmount.toStringAsFixed(0),
                        statusStr,
                      ].reversed.toList();
                    }).toList(),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    // Render print layout dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'تقرير_مبيعات_${dateFormat.format(startDate)}_إلى_${dateFormat.format(endDate)}.pdf',
    );
  }

  static pw.Widget _buildPdfStatTile(String label, String value, String unit, PdfColor themeColor) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.start,
              children: [
                pw.Text(
                  value,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: themeColor,
                  ),
                ),
                pw.SizedBox(width: 4),
                pw.Text(
                  unit,
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: themeColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
