import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../viewmodel/order_viewmodel.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';
import '../../customers/viewmodel/customer_viewmodel.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/database/database_helper.dart';
import 'order_details_view.dart';

/// Embeddable body for use inside MainNavigation shell
class OrderListBody extends StatefulWidget {
  const OrderListBody({super.key});

  @override
  State<OrderListBody> createState() => _OrderListBodyState();
}

class _OrderListBodyState extends State<OrderListBody> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() { if (!_tabController.indexIsChanging) setState(() {}); });
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderVm = context.watch<OrderViewModel>();
    final customerVm = context.watch<CustomerViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final prefix = authVm.currentTenant?.laundryCode ?? 'أ';
    final customerMap = {for (var c in customerVm.allCustomers) c.id: c};
    final query = _searchController.text.trim().toLowerCase();
    final filteredOrders = orderVm.orders.where((order) {
      if (_tabController.index == 1 && order.status != 'received') return false;
      if (_tabController.index == 2 && order.status != 'ready') return false;
      if (_tabController.index == 3 && order.status != 'delivered') return false;
      if (query.isNotEmpty) {
        final customer = customerMap[order.customerId];
        final matchesName = customer?.name.toLowerCase().contains(query) ?? false;
        final matchesPhone = customer?.phone.contains(query) ?? false;
        String cleanQuery = query;
        if (query.contains('-')) {
          final parts = query.split('-');
          final possibleSerial = parts.last.trim();
          if (int.tryParse(possibleSerial) != null) cleanQuery = possibleSerial;
        }
        final matchesSerial = customer?.serialNumber.toString().contains(cleanQuery) ?? false;
        final matchesId = order.id.toString().contains(cleanQuery);
        final matchesNotes = order.notes?.toLowerCase().contains(query) ?? false;
        return matchesName || matchesPhone || matchesSerial || matchesId || matchesNotes;
      }
      return true;
    }).toList();
    final totalOrdersCount = filteredOrders.length;
    final totalRevenue = filteredOrders.fold(0.0, (sum, o) => sum + o.totalPrice);
    final totalItemsCount = filteredOrders.fold(0, (sum, o) => sum + o.itemCount);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      children: [
        // Tab Bar
        Container(
          color: AppTheme.primaryColor,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: AppTheme.secondaryColor,
              tabs: const [
                Tab(text: 'الكل'),
                Tab(text: 'مستلم'),
                Tab(text: 'جاهز'),
                Tab(text: 'تم التسليم'),
              ],
            ),
          ),
        ),
        Expanded(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 700;
                    
                    final listView = orderVm.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : filteredOrders.isEmpty
                            ? _buildEmpty()
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: filteredOrders.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final order = filteredOrders[index];
                                  final customer = customerMap[order.customerId];
                                  final deliveryDateOnly = DateTime(order.deliveryDate.year, order.deliveryDate.month, order.deliveryDate.day);
                                  final isOverdue = order.status != 'delivered' && deliveryDateOnly.isBefore(today);
                                  bool waSent = false;
                                  if (order.status == 'received') waSent = order.whatsappSentReceived;
                                  else if (order.status == 'ready') waSent = order.whatsappSentReady;
                                  else if (order.status == 'delivered') waSent = order.whatsappSentDelivered;
                                  return _OrderCard(
                                    order: order,
                                    customer: customer,
                                    prefix: prefix,
                                    isOverdue: isOverdue,
                                    waSent: waSent,
                                  );
                                },
                              );

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sidebar: Search & Stats Card
                          SizedBox(
                            width: 290,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                    child: TextField(
                                      controller: _searchController,
                                      decoration: InputDecoration(
                                        hintText: 'ابحث برقم الطلب، الاسم...',
                                        prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
                                        suffixIcon: _searchController.text.isNotEmpty
                                            ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                                            : null,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Card(
                                      elevation: 1.5,
                                      color: AppTheme.primaryColor.withOpacity(0.06),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.15)),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          children: [
                                            _buildQuickStatRow('الطلبات', '$totalOrdersCount فاتورة', Icons.description_outlined),
                                            const Divider(height: 24),
                                            _buildQuickStatRow('إجمالي القطع', '$totalItemsCount سجاد', Icons.local_laundry_service_outlined),
                                            const Divider(height: 24),
                                            _buildQuickStatRow('الإجمالي المالي', '${totalRevenue.toStringAsFixed(0)} ر.ي', Icons.payments_outlined),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const VerticalDivider(width: 1, thickness: 1),
                          // List
                          Expanded(child: listView),
                        ],
                      );
                    } else {
                      // Standard vertical layout for mobile
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'ابحث برقم الطلب، اسم العميل، الجوال...',
                                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                                    : null,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildQuickStat('الطلبات', '$totalOrdersCount فاتورة', Icons.description_outlined),
                                  _buildQuickStat('إجمالي القطع', '$totalItemsCount سجاد', Icons.local_laundry_service_outlined),
                                  _buildQuickStat('الإجمالي المالي', '${totalRevenue.toStringAsFixed(0)} ر.ي', Icons.payments_outlined),
                                ],
                              ),
                            ),
                          ),
                          Expanded(child: listView),
                        ],
                      );
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.lightTextSecondary)),
      ],
    );
  }

  Widget _buildQuickStatRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: AppTheme.lightTextSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('لا توجد طلبات', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final Customer? customer;
  final String prefix;
  final bool isOverdue;
  final bool waSent;

  const _OrderCard({
    required this.order,
    required this.customer,
    required this.prefix,
    required this.isOverdue,
    required this.waSent,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;
    switch (order.status) {
      case 'received': statusColor = AppTheme.primaryColor; statusText = 'مستلم'; break;
      case 'ready': statusColor = AppTheme.warning; statusText = 'جاهز'; break;
      case 'delivered': statusColor = AppTheme.success; statusText = 'تم التسليم'; break;
      default: statusColor = Colors.grey; statusText = order.status;
    }
    return Card(
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsView(order: order))),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(width: 4, height: 48, decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer?.name ?? '...', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text('ملف: $prefix-${customer?.serialNumber ?? '?'} | ${order.itemCount} قطع', style: TextStyle(fontSize: 12, color: AppTheme.lightTextSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${order.totalPrice.toStringAsFixed(0)} ر.ي', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryColor)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text(statusText, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrderListView extends StatefulWidget {
  final String? initialStatus;
  const OrderListView({super.key, this.initialStatus});

  @override
  State<OrderListView> createState() => _OrderListViewState();
}

class _OrderListViewState extends State<OrderListView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    int initialIndex = 0;
    if (widget.initialStatus == 'received') initialIndex = 1;
    if (widget.initialStatus == 'ready') initialIndex = 2;
    if (widget.initialStatus == 'delivered') initialIndex = 3;

    _tabController = TabController(length: 4, vsync: this, initialIndex: initialIndex);
    _tabController.addListener(_onTabChanged);
    _searchController.addListener(_onSearchChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {}); // Rebuild to update statistics and filtered list
  }

  void _onSearchChanged() {
    setState(() {}); // Rebuild on search input
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _searchController.removeListener(_onSearchChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _updateOrderStatus(BuildContext context, Order order, String newStatus, Customer? customer) async {
    final orderVm = Provider.of<OrderViewModel>(context, listen: false);
    
    // Show a quick confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تحديث حالة الطلب'),
          content: Text(
            newStatus == 'ready'
                ? 'هل أنت متأكد من تغيير حالة الطلب إلى "جاهز للاستلام"؟ سيتم تحويلك لإرسال رسالة تنبيه للعميل.'
                : 'هل أنت متأكد من تغيير حالة الطلب إلى "تم التسليم"؟ سيتم تحويلك لإرسال رسالة تأكيد الاستلام ودفع الحساب.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: newStatus == 'ready' ? AppTheme.warning : AppTheme.success,
              ),
              child: const Text('تحديث'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final success = await orderVm.updateOrderStatus(order, newStatus);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'ready'
                  ? 'تم تحديث حالة الطلب إلى "جاهز للاستلام"'
                  : 'تم تحديث حالة الطلب إلى "تم التسليم"',
              textAlign: TextAlign.right,
            ),
            backgroundColor: AppTheme.success,
          ),
        );

        if (customer != null) {
          // Trigger WhatsApp trigger after status change
          Future.delayed(const Duration(milliseconds: 300), () async {
            final updatedOrder = order.copyWith(status: newStatus);
            if (newStatus == 'ready') {
              await orderVm.sendWhatsAppReady(updatedOrder, customer);
            } else if (newStatus == 'delivered') {
              await orderVm.sendWhatsAppDelivered(updatedOrder, customer);
            }
          });
        }
      }
    }
  }

  void _sendWhatsAppMessage(BuildContext context, Order order, Customer customer) async {
    final orderVm = Provider.of<OrderViewModel>(context, listen: false);
    if (order.status == 'received') {
      await orderVm.sendWhatsAppReceived(order, customer);
    } else if (order.status == 'ready') {
      await orderVm.sendWhatsAppReady(order, customer);
    } else if (order.status == 'delivered') {
      await orderVm.sendWhatsAppDelivered(order, customer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderVm = context.watch<OrderViewModel>();
    final customerVm = context.watch<CustomerViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final prefix = authVm.currentTenant?.laundryCode ?? 'أ';

    // Map customer list to a map for fast lookup
    final customerMap = {for (var c in customerVm.allCustomers) c.id: c};

    // Filter orders based on active Tab and Search query
    final query = _searchController.text.trim().toLowerCase();
    final filteredOrders = orderVm.orders.where((order) {
      // 1. Filter by status based on active tab index
      if (_tabController.index == 1 && order.status != 'received') return false;
      if (_tabController.index == 2 && order.status != 'ready') return false;
      if (_tabController.index == 3 && order.status != 'delivered') return false;

      // 2. Filter by search query
      if (query.isNotEmpty) {
        final customer = customerMap[order.customerId];
        final matchesName = customer?.name.toLowerCase().contains(query) ?? false;
        final matchesPhone = customer?.phone.contains(query) ?? false;
        
        // Clean query if it contains a hyphen prefix (e.g., A-1001 or أ-1001)
        String cleanQuery = query;
        if (query.contains('-')) {
          final parts = query.split('-');
          final possibleSerial = parts.last.trim();
          if (int.tryParse(possibleSerial) != null) {
            cleanQuery = possibleSerial;
          }
        }
        
        final matchesSerial = customer?.serialNumber.toString().contains(cleanQuery) ?? false;
        final matchesId = order.id.toString().contains(cleanQuery);
        final matchesNotes = order.notes?.toLowerCase().contains(query) ?? false;

        return matchesName || matchesPhone || matchesSerial || matchesId || matchesNotes;
      }

      return true;
    }).toList();

    // Calculate dynamic stats
    final totalOrdersCount = filteredOrders.length;
    final totalRevenue = filteredOrders.fold(0.0, (sum, o) => sum + o.totalPrice);
    final totalItemsCount = filteredOrders.fold(0, (sum, o) => sum + o.itemCount);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Scaffold(
      drawer: const AppDrawer(currentRoute: 'orders'),
      appBar: AppBar(
        title: const Text('إدارة الطلبات'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppTheme.secondaryColor,
          tabs: const [
            Tab(text: 'الكل'),
            Tab(text: 'مستلم'),
            Tab(text: 'جاهز'),
            Tab(text: 'تم التسليم'),
          ],
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                
                final listView = orderVm.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredOrders.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredOrders.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final order = filteredOrders[index];
                              final customer = customerMap[order.customerId];

                              // Overdue check
                              final deliveryDateOnly = DateTime(order.deliveryDate.year, order.deliveryDate.month, order.deliveryDate.day);
                              final isOverdue = order.status != 'delivered' && deliveryDateOnly.isBefore(today);

                              // WhatsApp Status details
                              bool waSent = false;
                              if (order.status == 'received') waSent = order.whatsappSentReceived;
                              if (order.status == 'ready') waSent = order.whatsappSentReady;
                              if (order.status == 'delivered') waSent = order.whatsappSentDelivered;

                              // Color & Text for order status
                              Color statusColor;
                              String statusText;
                              switch (order.status) {
                                case 'received':
                                  statusColor = AppTheme.primaryColor;
                                  statusText = 'مستلم وقيد الغسيل';
                                  break;
                                case 'ready':
                                  statusColor = AppTheme.warning;
                                  statusText = 'جاهز للاستلام';
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
                                elevation: 1.5,
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
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // Top Row: Client Name & Price
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Text(
                                                    customer?.name ?? 'جاري التحميل...',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  if (customer != null)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.primaryColor.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        '#$prefix-${customer.serialNumber}',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: AppTheme.primaryColor,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              '${order.totalPrice} ر.ي',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 17,
                                                color: AppTheme.secondaryColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        // Middle Row: Items, Date & Badges
                                        Row(
                                          children: [
                                            Icon(Icons.widgets_outlined, size: 14, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${order.itemCount} قطع سجاد',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                            ),
                                            const SizedBox(width: 16),
                                            Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text(
                                              'تسليم: ${DateFormat('yyyy-MM-dd').format(order.deliveryDate)}',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                            ),
                                            const Spacer(),
                                            if (isOverdue)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.error.withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                                                ),
                                                child: const Row(
                                                  children: [
                                                    Icon(Icons.warning_amber_rounded, size: 12, color: AppTheme.error),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      'متأخر',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: AppTheme.error,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                        const Divider(height: 24, thickness: 0.8),

                                        // Bottom Row: Status Badge & Actions
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            // Status Badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: statusColor.withOpacity(0.08),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(color: statusColor.withOpacity(0.2)),
                                              ),
                                              child: Text(
                                                statusText,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: statusColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),

                                            // Action buttons
                                            Row(
                                              children: [
                                                // WhatsApp Send Action
                                                if (customer != null)
                                                  IconButton(
                                                    icon: Icon(
                                                      waSent ? Icons.check_circle_outline : Icons.chat_bubble_outline,
                                                      color: waSent ? Colors.grey : const Color(0xFF25D366),
                                                    ),
                                                    tooltip: waSent ? 'تم إرسال التنبيه مسبقاً' : 'إرسال تنبيه واتساب',
                                                    onPressed: () => _sendWhatsAppMessage(context, order, customer),
                                                  ),

                                                // Quick change status button
                                                if (order.status == 'received') ...[
                                                  const SizedBox(width: 8),
                                                  ElevatedButton.icon(
                                                    onPressed: () => _updateOrderStatus(context, order, 'ready', customer),
                                                    icon: const Icon(Icons.check_circle, size: 14),
                                                    label: const Text('جاهز', style: TextStyle(fontSize: 12)),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: AppTheme.warning,
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                      minimumSize: const Size(60, 36),
                                                    ),
                                                  ),
                                                ] else if (order.status == 'ready') ...[
                                                  const SizedBox(width: 8),
                                                  ElevatedButton.icon(
                                                    onPressed: () => _updateOrderStatus(context, order, 'delivered', customer),
                                                    icon: const Icon(Icons.local_shipping, size: 14),
                                                    label: const Text('تسليم', style: TextStyle(fontSize: 12)),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: AppTheme.success,
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                      minimumSize: const Size(60, 36),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sidebar: Search & Stats Card
                      SizedBox(
                        width: 290,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'ابحث برقم الطلب، الاسم...',
                                    prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
                                    suffixIcon: _searchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () => _searchController.clear(),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Card(
                                  elevation: 1.5,
                                  color: AppTheme.primaryColor.withOpacity(0.06),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.15)),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      children: [
                                        _buildQuickStatItemRow('الطلبات', '$totalOrdersCount فاتورة', Icons.description_outlined),
                                        const Divider(height: 24),
                                        _buildQuickStatItemRow('إجمالي القطع', '$totalItemsCount سجاد', Icons.local_laundry_service_outlined),
                                        const Divider(height: 24),
                                        _buildQuickStatItemRow('الإجمالي المالي', '${totalRevenue.toStringAsFixed(0)} ر.ي', Icons.payments_outlined),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1, thickness: 1),
                      // List
                      Expanded(child: listView),
                    ],
                  );
                } else {
                  // Standard vertical layout for mobile
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'ابحث برقم الطلب، اسم العميل، الجوال...',
                            prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => _searchController.clear(),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildQuickStatItem('الطلبات', '$totalOrdersCount فاتورة', Icons.description_outlined),
                              _buildQuickStatItem('إجمالي القطع', '$totalItemsCount سجاد', Icons.local_laundry_service_outlined),
                              _buildQuickStatItem('الإجمالي المالي', '${totalRevenue.toStringAsFixed(0)} ر.ي', Icons.payments_outlined),
                            ],
                          ),
                        ),
                      ),
                      Expanded(child: listView),
                    ],
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStatItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildQuickStatItemRow(String title, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_basket_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'لا توجد طلبات مطابقة للبحث',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'اختر تبويباً آخر أو جرب عبارة بحث مختلفة',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
