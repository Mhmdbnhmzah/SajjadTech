import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../auth/viewmodel/auth_viewmodel.dart';
import '../viewmodel/reports_viewmodel.dart';
import '../services/pdf_report_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/database_helper.dart';

class ReportsView extends StatefulWidget {
  final bool isEmbedded;
  const ReportsView({super.key, this.isEmbedded = false});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  Future<void> _selectDateRange(BuildContext context, ReportsViewModel reportsVm) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: reportsVm.startDate,
        end: reportsVm.endDate,
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ar'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
    );

    if (picked != null) {
      reportsVm.setDateRange(picked.start, picked.end);
    }
  }

  void _printReport(BuildContext context, ReportsViewModel reportsVm, String laundryName) async {
    if (reportsVm.orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد فواتير في هذه الفترة لطباعتها', textAlign: TextAlign.right),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    try {
      await PdfReportService.generateAndPrintReport(
        startDate: reportsVm.startDate,
        endDate: reportsVm.endDate,
        orders: reportsVm.orders,
        customerMap: reportsVm.customerMap,
        orderItemsMap: reportsVm.orderItemsMap,
        totalSales: reportsVm.totalSales,
        totalPaid: reportsVm.totalPaid,
        totalItemsCount: reportsVm.totalItemsCount,
        newCustomersCount: reportsVm.newCustomersCount,
        carpetBreakdown: reportsVm.carpetBreakdown,
        laundryName: laundryName,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشلت عملية إنشاء ملف PDF: $e', textAlign: TextAlign.right),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportsVm = context.watch<ReportsViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final laundryName = authVm.currentTenant?.name ?? 'المغسلة الحديثة للفرش';

    final bodyContent = Directionality(
      textDirection: TextDirection.rtl,
      child: reportsVm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // --- DATE RANGE PICKER SECTION ---
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                              'تحديد فترة التقرير الإحصائي',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildDateDisplay('من تاريخ', reportsVm.startDate),
                                const Icon(Icons.arrow_back_rounded, color: AppTheme.lightTextSecondary, size: 20),
                                _buildDateDisplay('إلى تاريخ', reportsVm.endDate),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _selectDateRange(context, reportsVm),
                              icon: const Icon(Icons.date_range_rounded),
                              label: const Text('تغيير الفترة الزمنية'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.secondaryColor,
                                minimumSize: const Size(200, 48),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- OVERVIEW STATS GRID ---
                    const Text(
                      'الملخص المالي والعملي',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 3,
                      children: [
                        _buildSummaryCard(
                          title: 'المبالغ المحصلة',
                          value: '${reportsVm.totalPaid.toStringAsFixed(0)} ر.ي',
                          icon: Icons.check_circle_rounded,
                          color: AppTheme.success,
                        ),
                        _buildSummaryCard(
                          title: 'إجمالي الطلبات',
                          value: '${reportsVm.orders.length} طلب',
                          icon: Icons.receipt_long_rounded,
                          color: Colors.blueGrey,
                        ),
                        _buildSummaryCard(
                          title: 'قطع السجاد المغسول',
                          value: '${reportsVm.totalItemsCount} قطعة',
                          icon: Icons.local_laundry_service_rounded,
                          color: Colors.indigo,
                        ),
                        _buildSummaryCard(
                          title: 'العملاء الجدد',
                          value: '${reportsVm.newCustomersCount} زبون',
                          icon: Icons.person_add_rounded,
                          color: Colors.teal,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // --- ORDERS SUMMARY LIST ---
                    const Text(
                      'الفواتير الصادرة خلال الفترة',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(height: 12),
                    reportsVm.orders.isEmpty
                        ? _buildEmptySectionCard('لا توجد فواتير صادرة في هذا النطاق')
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: reportsVm.orders.length,
                            itemBuilder: (context, index) {
                              final order = reportsVm.orders[index];
                              final customerName = reportsVm.customerMap[order.customerId]?.name ?? 'عميل غير معروف';
                              final items = reportsVm.orderItemsMap[order.id] ?? [];

                              return Card(
                                  elevation: 1.5,
                                  margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2.0),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header row
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Text('فاتورة رقم #${order.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                                const SizedBox(width: 8),
                                                _buildStatusBadge(order.status),
                                              ],
                                            ),
                                            Text('${order.totalPrice.toStringAsFixed(0)} ر.ي',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor)),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text('العميل: $customerName  |  التاريخ: ${_dateFormat.format(order.receivedDate)}',
                                            style: const TextStyle(fontSize: 12, color: AppTheme.lightTextSecondary)),
                                        const SizedBox(height: 12),
                                        const Divider(height: 1),
                                        const SizedBox(height: 10),
                                        const Text(
                                          'تفاصيل قطع الطلب:',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryColor),
                                        ),
                                        const SizedBox(height: 6),
                                        ...items.map((OrderItem item) {
                                          final isUnit = item.pricingType == 'unit';
                                          final detailsStr = isUnit
                                              ? '${item.quantity} حبة × ${item.unitPrice.toStringAsFixed(0)}'
                                              : '${item.area?.toStringAsFixed(1)} م² (${item.length}×${item.width}) × ${item.unitPrice.toStringAsFixed(0)}';
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                                Text(detailsStr, style: const TextStyle(fontSize: 12, color: AppTheme.lightTextSecondary)),
                                                Text('${item.totalPrice.toStringAsFixed(0)} ر.ي',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.secondaryColor)),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                );
                            },
                          ),
                    const SizedBox(height: 80), // Padding to prevent FAB from overlapping list
                  ],
                ),
              ),
            ),
    );

    if (widget.isEmbedded) {
      return Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _printReport(context, reportsVm, laundryName),
          icon: const Icon(Icons.print_rounded, color: Colors.white),
          label: const Text('طباعة التقرير PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.primaryColor,
        ),
        body: bodyContent,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير والإحصائيات العامة'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _printReport(context, reportsVm, laundryName),
        icon: const Icon(Icons.print_rounded, color: Colors.white),
        label: const Text('طباعة التقرير PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: bodyContent,
    );
  }

  Widget _buildDateDisplay(String label, DateTime date) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.lightTextSecondary)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            _dateFormat.format(date),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: AppTheme.lightTextSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySectionCard(String text) {
    return Card(
      elevation: 0.5,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(color: AppTheme.lightTextSecondary, fontStyle: FontStyle.italic),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    String badgeText;

    switch (status) {
      case 'received':
        badgeColor = Colors.orange;
        badgeText = 'مستلم';
        break;
      case 'ready':
        badgeColor = AppTheme.secondaryColor;
        badgeText = 'جاهز';
        break;
      case 'delivered':
        badgeColor = AppTheme.success;
        badgeText = 'مسلم';
        break;
      default:
        badgeColor = Colors.grey;
        badgeText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        badgeText,
        style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
