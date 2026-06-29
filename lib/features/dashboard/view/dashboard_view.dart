import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodel/dashboard_viewmodel.dart';
import '../../../core/theme/app_theme.dart';
import '../../customers/view/customer_list_view.dart';
import '../../orders/view/order_form_view.dart';
import '../../orders/view/order_details_view.dart';
import '../../orders/view/order_list_view.dart';
import '../../../core/database/database_helper.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';

/// Embeddable body for use inside MainNavigation shell
class DashboardBody extends StatelessWidget {
  const DashboardBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DashboardContent();
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DashboardContent();
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent();


  @override
  Widget build(BuildContext context) {
    final dashboardViewModel = context.watch<DashboardViewModel>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- STATISTICS GRID ---
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final crossAxisCount = width > 750
                              ? 4
                              : (width > 500 ? 3 : 2);
                          final aspectRatio = width > 750
                              ? 1.5
                              : (width > 500 ? 1.35 : 1.15);

                          return GridView.count(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: aspectRatio,
                            children: [
                              _buildStatCard(
                                context,
                                title: 'طلبات قيد الغسيل',
                                value: '${dashboardViewModel.receivedCount}',
                                icon: Icons.local_laundry_service_outlined,
                                color: AppTheme.primaryColor,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const OrderListView(
                                        initialStatus: 'received',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              _buildStatCard(
                                context,
                                title: 'طلبات جاهزة للتسليم',
                                value: '${dashboardViewModel.readyCount}',
                                icon: Icons.check_circle_outline,
                                color: AppTheme.warning,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const OrderListView(initialStatus: 'ready'),
                                    ),
                                  );
                                },
                              ),
                              _buildStatCard(
                                context,
                                title: 'الطلبات المسلمة اليوم',
                                value: '${dashboardViewModel.deliveredTodayCount}',
                                icon: Icons.delivery_dining_outlined,
                                color: AppTheme.success,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const OrderListView(
                                        initialStatus: 'delivered',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              _buildStatCard(
                                context,
                                title: 'دخل اليوم المتوقع',
                                value: '${dashboardViewModel.todayIncome} ر.ي',
                                icon: Icons.payments_outlined,
                                color: AppTheme.secondaryColor,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const OrderListView(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // --- QUICK ACTIONS ---
                      const Text(
                        'إجراءات سريعة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const OrderFormView(),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.add_shopping_cart,
                                color: Colors.white,
                              ),
                              label: const Text('طلب جديد'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.success,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const CustomerListView(),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.people_outline,
                                color: Colors.white,
                              ),
                              label: const Text('العملاء'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // --- RECENT ORDERS ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'آخر الطلبات المضافة',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.lightTextPrimary,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const OrderListView(),
                                ),
                              );
                            },
                            child: const Text('عرض الكل'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      dashboardViewModel.recentOrders.isEmpty
                          ? _buildEmptyState(context)
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: dashboardViewModel.recentOrders.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final order =
                                    dashboardViewModel.recentOrders[index];
                                final customer = dashboardViewModel
                                    .getCachedCustomer(order.customerId);
                                return _buildOrderTile(context, order, customer);
                              },
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 24),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.lightTextSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderTile(
    BuildContext context,
    Order order,
    Customer? customer,
  ) {
    final authViewModel = context.read<AuthViewModel>();
    final prefix = authViewModel.currentTenant?.laundryCode ?? 'أ';
    Color statusColor;
    String statusText;
    switch (order.status) {
      case 'received':
        statusColor = AppTheme.primaryColor;
        statusText = 'مستلم';
        break;
      case 'ready':
        statusColor = AppTheme.warning;
        statusText = 'جاهز';
        break;
      case 'delivered':
        statusColor = AppTheme.success;
        statusText = 'تم التسليم';
        break;
      default:
        statusColor = Colors.grey;
        statusText = order.status;
    }

    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderDetailsView(order: order),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Status Indicator circle
              Container(
                width: 12,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 16),

              // Customer & Order Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer?.name ?? 'جاري التحميل...',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'ملف: ${customer != null ? "$prefix-${customer.serialNumber}" : "..."}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.lightTextSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${order.itemCount} قطع سجاد',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Order cost & Status Badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${order.totalPrice} ر.ي',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Column(
          children: [
            Icon(
              Icons.shopping_basket_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد طلبات مضافة حالياً',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'اضغط على زر "طلب جديد" بالأسفل لإضافة أول طلب',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }



}
