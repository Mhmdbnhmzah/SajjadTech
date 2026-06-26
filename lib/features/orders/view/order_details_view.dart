import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../viewmodel/order_viewmodel.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/database_helper.dart';

class OrderDetailsView extends StatefulWidget {
  final Order order;
  final bool autoSendReceived;
  const OrderDetailsView({
    super.key,
    required this.order,
    this.autoSendReceived = false,
  });

  @override
  State<OrderDetailsView> createState() => _OrderDetailsViewState();
}

class _OrderDetailsViewState extends State<OrderDetailsView> {
  late Order _currentOrder;
  Customer? _customer;
  bool _loadingCustomer = false;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _fetchCustomer();
  }

  void _fetchCustomer() async {
    setState(() {
      _loadingCustomer = true;
    });

    final orderVm = Provider.of<OrderViewModel>(context, listen: false);
    final customer = await orderVm.db?.getCustomerById(_currentOrder.customerId);

    if (mounted) {
      setState(() {
        _customer = customer;
        _loadingCustomer = false;
      });

      // Auto-trigger WhatsApp message for Received state on launch
      if (widget.autoSendReceived && customer != null && !_currentOrder.whatsappSentReceived) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            orderVm.sendWhatsAppReceived(_currentOrder, customer);
          }
        });
      }
    }
  }

  void _updateStatus(String newStatus) async {
    final orderVm = Provider.of<OrderViewModel>(context, listen: false);
    final success = await orderVm.updateOrderStatus(_currentOrder, newStatus);
    
    if (success && mounted) {
      setState(() {
        _currentOrder = _currentOrder.copyWith(
          status: newStatus,
          paidAmount: newStatus == 'delivered' ? _currentOrder.totalPrice : _currentOrder.paidAmount,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديث حالة الطلب إلى "$newStatus"', textAlign: TextAlign.right),
          backgroundColor: AppTheme.success,
        ),
      );

      // Auto-trigger WhatsApp for the new stage
      if (_customer != null) {
        Future.delayed(const Duration(milliseconds: 300), () async {
          if (mounted) {
            if (newStatus == 'ready') {
              await orderVm.sendWhatsAppReady(_currentOrder, _customer!);
            } else if (newStatus == 'delivered') {
              await orderVm.sendWhatsAppDelivered(_currentOrder, _customer!);
            }
          }
        });
      }
    }
  }

  void _payRemainingAmount() async {
    final remaining = _currentOrder.totalPrice - _currentOrder.paidAmount;
    if (remaining <= 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسديد المبلغ المتبقي'),
          content: Text('هل أنت متأكد من تسديد المبلغ المتبقي بالكامل ($remaining ر.ي) لتصبح الفاتورة مدفوعة بالكامل؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
              child: const Text('تأكيد السداد'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final orderVm = Provider.of<OrderViewModel>(context, listen: false);
      final success = await orderVm.updateOrderPaidAmount(_currentOrder, _currentOrder.totalPrice);
      if (success && mounted) {
        setState(() {
          _currentOrder = _currentOrder.copyWith(paidAmount: _currentOrder.totalPrice);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسديد المبلغ المتبقي وتحديث الفاتورة بنجاح', textAlign: TextAlign.right),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    }
  }

  void _deleteOrder() async {
    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الطلب'),
          content: const Text('هل أنت متأكد من رغبتك في حذف هذا الطلب؟ سيتم مزامنة عملية الحذف وحذفه من السحابة كذلك.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () async {
                final orderVm = Provider.of<OrderViewModel>(context, listen: false);
                Navigator.pop(dialogCtx);
                final success = await orderVm.deleteOrder(_currentOrder.id);
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف الطلب بنجاح', textAlign: TextAlign.right),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text(
                'حذف الطلب',
                style: TextStyle(color: AppTheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderVm = context.watch<OrderViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final prefix = authVm.currentTenant?.laundryCode ?? 'أ';

    // Find the latest order dynamically from provider to ensure reactivity
    final order = orderVm.orders.firstWhere(
      (o) => o.id == widget.order.id,
      orElse: () => _currentOrder,
    );
    _currentOrder = order;

    // Determine status badge color
    Color statusColor;
    String statusText;
    switch (_currentOrder.status) {
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
        statusText = 'تم التسليم والتحصيل';
        break;
      default:
        statusColor = Colors.grey;
        statusText = _currentOrder.status;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('طلب رقم #${_currentOrder.id}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'حذف الطلب',
            onPressed: _deleteOrder,
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _loadingCustomer
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- STATUS BANNER ---
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: statusColor),
                              const SizedBox(width: 12),
                              Text(
                                'حالة الطلب: $statusText',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                          
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- CUSTOMER DETAILS CARD ---
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'معلومات العميل',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const Divider(height: 24),
                            if (_customer != null) ...[
                              _buildInfoRow(Icons.person_outline, 'اسم العميل:', _customer!.name),
                              _buildInfoRow(Icons.phone_outlined, 'رقم الجوال:', _customer!.phone),
                              _buildInfoRow(
                                Icons.pin_outlined,
                                'الرقم التسلسلي (Tag):',
                                '$prefix-${_customer!.serialNumber}',
                                isBoldValue: true,
                              ),
                            ] else
                              const Text('لم يتم العثور على معلومات العميل'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- ORDER DETAILS CARD ---
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'تفاصيل الطلب والمالية',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const Divider(height: 24),
                            _buildInfoRow(
                              Icons.money,
                              'التكلفة الإجمالية:',
                              '${_currentOrder.totalPrice} ر.ي',
                              valueColor: AppTheme.secondaryColor,
                              isBoldValue: true,
                            ),
                            _buildInfoRow(
                              Icons.payments_outlined,
                              'المبلغ المدفوع:',
                              '${_currentOrder.paidAmount} ر.ي',
                              valueColor: AppTheme.success,
                            ),
                            _buildInfoRow(
                              Icons.hourglass_empty,
                              'المبلغ المتبقي:',
                              '${_currentOrder.totalPrice - _currentOrder.paidAmount} ر.ي',
                              valueColor: (_currentOrder.totalPrice - _currentOrder.paidAmount) > 0 
                                  ? AppTheme.error 
                                  : AppTheme.success,
                              isBoldValue: true,
                            ),
                            _buildInfoRow(Icons.format_list_numbered, 'عدد قطع السجاد:', '${_currentOrder.itemCount} قطع'),
                            _buildInfoRow(
                              Icons.calendar_today,
                              'تاريخ الاستلام:',
                              DateFormat('yyyy-MM-dd HH:mm').format(_currentOrder.receivedDate),
                            ),
                            _buildInfoRow(
                              Icons.event,
                              'تاريخ التسليم المتوقع:',
                              DateFormat('yyyy-MM-dd').format(_currentOrder.deliveryDate),
                            ),
                            if (_currentOrder.notes != null)
                              _buildInfoRow(Icons.notes, 'ملاحظات:', _currentOrder.notes!),
                            
                            const Divider(height: 24),
                            if (_currentOrder.totalPrice - _currentOrder.paidAmount > 0) ...[
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _payRemainingAmount,
                                  icon: const Icon(Icons.check_circle_outline, color: AppTheme.success),
                                  label: const Text('تسديد المبلغ المتبقي', style: TextStyle(color: AppTheme.success)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppTheme.success),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.success.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle, color: AppTheme.success, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'الفاتورة مدفوعة بالكامل',
                                      style: TextStyle(
                                        color: AppTheme.success,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- ORDER ITEMS DETAILS SECTION ---
                    StreamBuilder<List<OrderItem>>(
                      stream: orderVm.db?.watchOrderItems(order.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final items = snapshot.data ?? [];
                        if (items.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'تفاصيل قطع الفاتورة',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                const Divider(height: 24),
                                Table(
                                  columnWidths: const {
                                    0: FlexColumnWidth(2),
                                    1: FlexColumnWidth(2.5),
                                    2: FlexColumnWidth(1.5),
                                    3: FlexColumnWidth(1.5),
                                  },
                                  children: [
                                    const TableRow(
                                      children: [
                                        Text('نوع السجاد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        Text('الكمية/المقاس', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        Text('سعر الوحدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ],
                                    ),
                                    const TableRow(
                                      children: [
                                        Divider(height: 12),
                                        Divider(height: 12),
                                        Divider(height: 12),
                                        Divider(height: 12),
                                      ],
                                    ),
                                    ...items.map((item) {
                                      final isUnit = item.pricingType == 'unit';
                                      final specs = isUnit 
                                          ? '${item.quantity} حبة' 
                                          : '${item.length}×${item.width} م (${item.area?.toStringAsFixed(1)} م²)'
                                            '${item.quantity != null && item.quantity! > 1 ? ' × ${item.quantity}' : ''}';
                                      
                                      return TableRow(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                                            child: Text(item.name, style: const TextStyle(fontSize: 13)),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                                            child: Text(specs, style: const TextStyle(fontSize: 13)),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                                            child: Text('${item.unitPrice.toStringAsFixed(0)} ر.ي', style: const TextStyle(fontSize: 13)),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                                            child: Text(
                                              '${item.totalPrice.toStringAsFixed(0)} ر.ي', 
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryColor, fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // --- STATUS WORKFLOW CONTROLS ---
                    const Text(
                      'العمليات على الطلب',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (_currentOrder.status == 'received')
                      ElevatedButton.icon(
                        onPressed: () => _updateStatus('ready'),
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text('تغيير الحالة إلى: جاهز للاستلام'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.warning,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    if (_currentOrder.status == 'ready')
                      ElevatedButton.icon(
                        onPressed: () => _updateStatus('delivered'),
                        icon: const Icon(Icons.done_all, color: Colors.white),
                        label: const Text('تغيير الحالة إلى: تم التسليم والتحصيل'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    if (_currentOrder.status == 'delivered')
                      const Card(
                        color: Color(0xFFE8F5E9),
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: AppTheme.success),
                              SizedBox(width: 12),
                              Text(
                                'الطلب منتهٍ وتم تسليمه بنجاح',
                                style: TextStyle(
                                  color: AppTheme.success,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // --- WHATSAPP MESSAGES AUTOMATION ---
                    const Text(
                      'مراسلة العميل بالواتساب',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    
                    if (_customer != null) ...[
                      // Stage 1 WhatsApp Button
                      _buildWhatsAppButton(
                        context,
                        label: 'إرسال رسالة استلام السجاد 📦',
                        isSent: _currentOrder.whatsappSentReceived,
                        onPressed: () async {
                          await orderVm.sendWhatsAppReceived(_currentOrder, _customer!);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Stage 2 WhatsApp Button (visible once ready)
                      if (_currentOrder.status == 'ready' || _currentOrder.status == 'delivered') ...[
                        _buildWhatsAppButton(
                          context,
                          label: 'إرسال رسالة جاهزية السجاد 🧼',
                          isSent: _currentOrder.whatsappSentReady,
                          onPressed: () async {
                            await orderVm.sendWhatsAppReady(_currentOrder, _customer!);
                          },
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Stage 3 WhatsApp Button (visible once delivered)
                      if (_currentOrder.status == 'delivered') ...[
                        _buildWhatsAppButton(
                          context,
                          label: 'إرسال رسالة تأكيد الاستلام والدفع ❤️',
                          isSent: _currentOrder.whatsappSentDelivered,
                          onPressed: () async {
                            await orderVm.sendWhatsAppDelivered(_currentOrder, _customer!);
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
    bool isBoldValue = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor.withOpacity(0.7)),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.lightTextSecondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: valueColor ?? AppTheme.lightTextPrimary,
                fontWeight: isBoldValue ? FontWeight.bold : FontWeight.normal,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatsAppButton(
    BuildContext context, {
    required String label,
    required bool isSent,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF25D366),
        side: BorderSide(
          color: isSent ? Colors.grey : const Color(0xFF25D366),
          width: 1.5,
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.send, size: 18),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSent ? Colors.grey : const Color(0xFF25D366),
            ),
          ),
          if (isSent) ...[
            const SizedBox(width: 12),
            const Icon(Icons.check_circle, color: AppTheme.success, size: 18),
            const SizedBox(width: 4),
            const Text(
              'تم الإرسال مسبقاً',
              style: TextStyle(fontSize: 11, color: AppTheme.success),
            ),
          ],
        ],
      ),
    );
  }
}

// Extension to allow quick colors
extension ColorOpacity on Colors {
  static Color get greenOpacity => const Color(0xFFE8F5E9);
}
