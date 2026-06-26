import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodel/customer_viewmodel.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/database/database_helper.dart';

/// Embeddable body for use inside MainNavigation shell
typedef CustomerListBody = CustomerListView;

class CustomerListView extends StatefulWidget {
  final bool isEmbedded;
  const CustomerListView({super.key, this.isEmbedded = false});

  @override
  State<CustomerListView> createState() => _CustomerListViewState();
}

class _CustomerListViewState extends State<CustomerListView> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showAddCustomerDialog(BuildContext context) {
    _nameController.clear();
    _phoneController.clear();

    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسجيل عميل جديد'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم العميل كامل',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال اسم العميل';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم جوال العميل (واتساب)',
                    prefixIcon: Icon(Icons.phone_outlined),
                    hintText: '7xxxxxxxx أو 9677xxxxxxxx',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال رقم الجوال';
                    }
                    final phoneRegex = RegExp(r'^(00967|\+?967)?(7\d{8}|07\d{8})$');
                    final cleaned = value.trim().replaceAll(RegExp(r'[^\d\+]'), '');
                    if (!phoneRegex.hasMatch(cleaned)) {
                      return 'يرجى إدخال رقم هاتف يمني صحيح';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final customerVm = Provider.of<CustomerViewModel>(context, listen: false);
                  Navigator.pop(dialogCtx);
                  
                  final newCustomer = await customerVm.registerCustomer(
                    name: _nameController.text.trim(),
                    phone: _phoneController.text.trim(),
                  );

                  if (newCustomer != null && context.mounted) {
                    _showSuccessDialog(context, newCustomer);
                  }
                }
              },
              child: const Text('تسجيل وحفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, Customer customer) {
    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final prefix = authVm.currentTenant?.laundryCode ?? 'أ';

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          icon: const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 64),
          title: const Text('تم التسجيل بنجاح'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('تم حفظ العميل وتوليد رقم تسلسلي فريد له:'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryColor, width: 2),
                ),
                child: Text(
                  '$prefix-${customer.serialNumber}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'اكتب هذا الرقم على السجاد الخاص بالعميل: ${customer.name}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppTheme.lightTextSecondary),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('موافق'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCustomer(BuildContext context, Customer customer) {
    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final prefix = authVm.currentTenant?.laundryCode ?? 'أ';

    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف العميل'),
          content: Text('هل أنت متأكد من رغبتك في حذف العميل "${customer.name}" ورقم ملفه $prefix-${customer.serialNumber}؟ سيتم حذف بياناته من الفايربيس عند المزامنة القادمة.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () async {
                final customerVm = Provider.of<CustomerViewModel>(context, listen: false);
                Navigator.pop(dialogCtx);
                final success = await customerVm.deleteCustomer(customer.id);
                
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف العميل بنجاح (سيتم مزامنته سحابياً)', textAlign: TextAlign.right),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              },
              child: const Text(
                'حذف العميل',
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
    final customerVm = context.watch<CustomerViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final prefix = authVm.currentTenant?.laundryCode ?? 'أ';

    final bodyContent = Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: customerVm.searchCustomers,
              decoration: InputDecoration(
                hintText: 'ابحث باسم العميل أو رقم الجوال أو الرقم التسلسلي...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          customerVm.searchCustomers('');
                        },
                      )
                    : null,
              ),
            ),
          ),

            Expanded(
            child: customerVm.isLoading
                ? const Center(child: CircularProgressIndicator())
                : customerVm.customers.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: customerVm.customers.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final customer = customerVm.customers[index];
                          return Card(
                            elevation: 1.5,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$prefix-${customer.serialNumber}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              title: Text(
                                customer.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.phone_outlined, size: 14, color: AppTheme.lightTextSecondary),
                                      const SizedBox(width: 6),
                                      Text(customer.phone),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                                onPressed: () => _confirmDeleteCustomer(context, customer),
                              ),
                            ),
                          );
                        },
                      ),
          ),
            ],
          ),
        ),
      ),
    );

    if (widget.isEmbedded) {
      return Stack(
        children: [
          bodyContent,
          Positioned(
            bottom: 16,
            left: 16,
            child: FloatingActionButton(
              heroTag: 'customer_add_fab',
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              onPressed: () => _showAddCustomerDialog(context),
              child: const Icon(Icons.person_add_alt_1_outlined),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      drawer: const AppDrawer(currentRoute: 'customers'),
      appBar: AppBar(
        title: const Text('إدارة العملاء'),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'customer_fab',
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        onPressed: () => _showAddCustomerDialog(context),
        child: const Icon(Icons.person_add_alt_1_outlined),
      ),
      body: bodyContent,
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
              Icons.people_alt_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'لا يوجد عملاء مطابقين للبحث',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'اضغط على الزر بالأسفل لتسجيل أول عميل في النظام',
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
