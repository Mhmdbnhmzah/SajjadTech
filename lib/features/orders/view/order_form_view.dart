import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../viewmodel/order_viewmodel.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';
import '../../customers/viewmodel/customer_viewmodel.dart';
import '../../carpet_types/viewmodel/carpet_type_viewmodel.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/database_helper.dart';
import '../view/order_details_view.dart';

class OrderFormView extends StatefulWidget {
  const OrderFormView({super.key});

  @override
  State<OrderFormView> createState() => _OrderFormViewState();
}

class _OrderFormViewState extends State<OrderFormView> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _priceController = TextEditingController();
  final _paidAmountController = TextEditingController(text: '0');
  final _countController = TextEditingController();
  final _notesController = TextEditingController();
  
  Customer? _selectedCustomer;
  DateTime _deliveryDate = DateTime.now().add(const Duration(days: 3));
  String? _customerError;

  final List<_CarpetItemFormState> _carpetItems = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {}); // Trigger rebuild to filter customers reactively
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _priceController.dispose();
    _paidAmountController.dispose();
    _countController.dispose();
    _notesController.dispose();
    for (var item in _carpetItems) {
      item.dispose();
    }
    super.dispose();
  }

  void _showQuickRegisterDialog({String? initialName}) {
    final nameController = TextEditingController(text: initialName);
    final phoneController = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          scrollable: true,
          title: const Text('تسجيل عميل جديد'),
          content: Form(
            key: dialogFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
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
                  controller: phoneController,
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
                if (dialogFormKey.currentState!.validate()) {
                  final customerVm = Provider.of<CustomerViewModel>(context, listen: false);
                  Navigator.pop(dialogCtx);
                  
                  final newCustomer = await customerVm.registerCustomer(
                    name: nameController.text.trim(),
                    phone: phoneController.text.trim(),
                  );

                  if (!mounted) return;
                  if (newCustomer != null) {
                    setState(() {
                      _selectedCustomer = newCustomer;
                      _customerError = null;
                      _searchController.clear();
                    });
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم تسجيل العميل واختياره: ${newCustomer.name}', textAlign: TextAlign.right),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                }
              },
              child: const Text('تسجيل واختيار'),
            ),
          ],
        ),
      ),
    );
  }

  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _deliveryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _deliveryDate) {
      setState(() {
        _deliveryDate = picked;
      });
    }
  }

  void _handleSubmit() async {
    if (_selectedCustomer == null) {
      setState(() {
        _customerError = 'يرجى اختيار العميل أولاً';
      });
      return;
    }

    if (_formKey.currentState!.validate()) {
      // Extra safety check: verify no carpet items are incomplete
      for (int i = 0; i < _carpetItems.length; i++) {
        if (_carpetItems[i].selectedType == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('يرجى اختيار نوع السجاد للقطعة رقم ${i + 1}', textAlign: TextAlign.right),
              backgroundColor: AppTheme.error,
            ),
          );
          return;
        }
      }

      final orderVm = Provider.of<OrderViewModel>(context, listen: false);
      final price = double.tryParse(_priceController.text) ?? 0.0;
      final paidAmount = double.tryParse(_paidAmountController.text) ?? 0.0;
      final count = int.tryParse(_countController.text) ?? 1;

      // Convert form items to view model inputs
      final List<OrderItemInput> itemsToSend = _carpetItems.map((item) {
        final pricingType = item.selectedType!.pricingType;
        final unitPrice = double.tryParse(item.priceController.text) ?? 0.0;
        final qty = int.tryParse(item.quantityController.text) ?? 1;
        final len = pricingType == 'meter' ? (double.tryParse(item.lengthController.text) ?? 0.0) : null;
        final wid = pricingType == 'meter' ? (double.tryParse(item.widthController.text) ?? 0.0) : null;
        final area = pricingType == 'meter' ? (len! * wid!) : null;

        return OrderItemInput(
          carpetTypeId: item.selectedType!.id,
          name: item.nameController.text,
          pricingType: pricingType,
          unitPrice: unitPrice,
          quantity: qty,
          length: len,
          width: wid,
          area: area,
          totalPrice: item.itemTotal,
        );
      }).toList();
      
      final newOrder = await orderVm.createOrder(
        customerId: _selectedCustomer!.id,
        totalPrice: price,
        paidAmount: paidAmount,
        itemCount: count,
        deliveryDate: _deliveryDate,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        items: itemsToSend,
      );

      if (!mounted) return;
      if (newOrder != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء الطلب بنجاح', textAlign: TextAlign.right),
            backgroundColor: AppTheme.success,
          ),
        );
        
        // Open order details directly and auto-trigger Whatsapp received message
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OrderDetailsView(
              order: newOrder,
              autoSendReceived: true,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل إنشاء الطلب، يرجى المحاولة لاحقاً', textAlign: TextAlign.right),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerVm = context.watch<CustomerViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final prefix = authVm.currentTenant?.laundryCode ?? 'أ';
    final query = _searchController.text.trim().toLowerCase();
    List<Customer> matchingCustomers = [];
    if (query.isNotEmpty) {
      String cleanQuery = query;
      if (query.contains('-')) {
        final parts = query.split('-');
        final possibleSerial = parts.last.trim();
        if (int.tryParse(possibleSerial) != null) {
          cleanQuery = possibleSerial;
        }
      }
      matchingCustomers = customerVm.allCustomers.where((cust) {
        final matchesName = cust.name.toLowerCase().contains(query);
        final matchesPhone = cust.phone.contains(query);
        final matchesSerial = cust.serialNumber.toString().contains(cleanQuery);
        return matchesName || matchesPhone || matchesSerial;
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة طلب جديد'),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 750),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- STEP 1: SELECT CUSTOMER ---
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '1. تحديد العميل',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (_selectedCustomer == null) ...[
                        TextFormField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'البحث عن عميل (الاسم، الجوال، أو الرقم التسلسلي)',
                            hintText: 'ابدأ بكتابة اسم العميل أو جواله...',
                            errorText: _customerError,
                            prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                    },
                                  )
                                : null,
                          ),
                        ),
                        
                        // Register new customer button (when search is empty)
                        if (_searchController.text.isEmpty) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => _showQuickRegisterDialog(),
                            icon: const Icon(Icons.person_add_alt_1_outlined),
                            label: const Text('تسجيل عميل جديد'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                        ],

                        // Matching results list
                        if (_searchController.text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 250),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: matchingCustomers.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'لا توجد نتائج مطابقة للبحث',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                        const SizedBox(height: 12),
                                        ElevatedButton.icon(
                                          onPressed: () => _showQuickRegisterDialog(
                                            initialName: _searchController.text.trim(),
                                          ),
                                          icon: const Icon(Icons.person_add_alt_1_outlined),
                                          label: Text('تسجيل "${_searchController.text.trim()}" كعميل جديد'),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    itemCount: matchingCustomers.length + 1,
                                    separatorBuilder: (context, index) => const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      if (index == matchingCustomers.length) {
                                        // "Register other customer" button at the bottom of the list
                                        return ListTile(
                                          leading: const Icon(Icons.person_add_alt_1_outlined, color: AppTheme.primaryColor),
                                          title: const Text(
                                            'تسجيل عميل جديد بالكامل',
                                            style: TextStyle(
                                              color: AppTheme.primaryColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          onTap: () => _showQuickRegisterDialog(
                                            initialName: _searchController.text.trim(),
                                          ),
                                        );
                                      }

                                      final cust = matchingCustomers[index];
                                      return ListTile(
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '$prefix-${cust.serialNumber}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          cust.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Text('الجوال: ${cust.phone}'),
                                        onTap: () {
                                          setState(() {
                                            _selectedCustomer = cust;
                                            _customerError = null;
                                            _searchController.clear();
                                          });
                                        },
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ] else ...[
                        // Selected customer card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.success.withOpacity(0.3), width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle, color: AppTheme.success, size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedCustomer!.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'رقم الجوال: ${_selectedCustomer!.phone}   |   رقم الملف: $prefix-${_selectedCustomer!.serialNumber}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24, thickness: 1),
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedCustomer = null;
                                    _customerError = null;
                                    _searchController.clear();
                                  });
                                },
                                icon: const Icon(Icons.swap_horiz_outlined, color: AppTheme.primaryColor),
                                label: const Text('تغيير العميل / بحث آخر', style: TextStyle(color: AppTheme.primaryColor)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppTheme.primaryColor),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- STEP 2: ORDER DETAILS ---
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '2. تفاصيل التكلفة والقطع',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Carpet Items Builder
                        const Text(
                          'قطع السجاد وتفاصيل أسعارها:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        
                        Consumer<CarpetTypeViewModel>(
                          builder: (context, carpetVm, child) {
                            final types = carpetVm.carpetTypes;
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_carpetItems.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: Text(
                                        'لم يتم إضافة أي قطع سجاد مخصصة. سيتم إدخال المجموع يدوياً.',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                      ),
                                    ),
                                  )
                                else
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _carpetItems.length,
                                    itemBuilder: (context, index) {
                                      return _buildCarpetItemRow(index, types);
                                    },
                                  ),
                                
                                OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _carpetItems.add(_CarpetItemFormState());
                                    });
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('أضف قطعة سجاد'),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppTheme.primaryColor),
                                  ),
                                ),
                                const Divider(height: 32),
                              ],
                            );
                          },
                        ),
                        
                        // Item Count Input
                        TextFormField(
                          controller: _countController,
                          keyboardType: TextInputType.number,
                          readOnly: _carpetItems.isNotEmpty,
                          decoration: InputDecoration(
                            labelText: 'عدد قطع السجاد في الطلب',
                            prefixIcon: const Icon(Icons.format_list_numbered_outlined),
                            filled: _carpetItems.isNotEmpty,
                            fillColor: _carpetItems.isNotEmpty ? Colors.grey.shade100 : null,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال عدد القطع';
                            }
                            if (int.tryParse(value) == null || int.parse(value) <= 0) {
                              return 'يرجى إدخال عدد صحيح أكبر من الصفر';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Price Input
                        TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          readOnly: _carpetItems.isNotEmpty,
                          decoration: InputDecoration(
                            labelText: 'التكلفة المالية الإجمالية (ريال)',
                            prefixIcon: const Icon(Icons.sell_outlined),
                            suffixText: 'ريال',
                            filled: _carpetItems.isNotEmpty,
                            fillColor: _carpetItems.isNotEmpty ? Colors.grey.shade100 : null,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال القيمة المالية';
                            }
                            if (double.tryParse(value) == null || double.parse(value) < 0) {
                              return 'يرجى إدخال قيمة مالية صحيحة';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Paid Amount Input
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _paidAmountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'المبلغ المدفوع حالياً (ريال)',
                                  prefixIcon: Icon(Icons.payments_outlined),
                                  suffixText: 'ريال',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'يرجى إدخال المبلغ المدفوع';
                                  }
                                  final paid = double.tryParse(value);
                                  final total = double.tryParse(_priceController.text) ?? 0.0;
                                  if (paid == null || paid < 0) {
                                    return 'يرجى إدخال قيمة صحيحة';
                                  }
                                  if (paid > total) {
                                    return 'المدفوع أكبر من الإجمالي';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _paidAmountController.text = _priceController.text;
                                });
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: AppTheme.primaryColor),
                                ),
                              ),
                              icon: const Icon(Icons.done_all, size: 18),
                              label: const Text('مدفوع بالكامل'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Delivery Date Picker
                        InkWell(
                          onTap: () => _selectDate(context),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'تاريخ التسليم المتوقع',
                              prefixIcon: Icon(Icons.calendar_today_outlined),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('yyyy-MM-dd').format(_deliveryDate),
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Notes Input
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظات إضافية (اختياري)',
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Create Button
              ElevatedButton(
                onPressed: _handleSubmit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'إنشاء الطلب وحفظه',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }

  Widget _buildCarpetItemRow(int index, List<CarpetType> types) {
    final item = _carpetItems[index];
    final isUnit = item.selectedType?.pricingType == 'unit';

    return Container(
      key: ObjectKey(item),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Dropdown & Delete
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<CarpetType>(
                  decoration: const InputDecoration(
                    labelText: 'نوع السجاد',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  value: item.selectedType,
                  hint: const Text('اختر نوع السجاد'),
                  validator: (value) {
                    if (value == null) {
                      return 'يرجى اختيار النوع';
                    }
                    return null;
                  },
                  items: types.map((type) {
                    return DropdownMenuItem<CarpetType>(
                      value: type,
                      child: Text(type.name),
                    );
                  }).toList(),
                  onChanged: (type) {
                    setState(() {
                      item.selectedType = type;
                      if (type != null) {
                        item.nameController.text = type.name;
                        item.priceController.text = type.price.toStringAsFixed(0);
                      }
                      _recalculateTotals();
                    });
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                onPressed: () {
                  setState(() {
                    _carpetItems.removeAt(index);
                    _recalculateTotals();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: Inputs (if selected)
          if (item.selectedType != null) ...[
            if (isUnit)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: item.quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الكمية (حبة)',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'الكمية مطلوبة';
                        }
                        if (int.tryParse(value) == null || int.parse(value) <= 0) {
                          return 'عدد غير صحيح';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() => _recalculateTotals()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: item.priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'السعر/الحبة',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'السعر مطلوب';
                        }
                        if (double.tryParse(value) == null || double.parse(value) < 0) {
                          return 'غير صحيح';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() => _recalculateTotals()),
                    ),
                  ),
                ],
              )
            else ...[
              // Row 1: Length, Width & Price/m² (No Quantity Field for Meter Items)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: item.lengthController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'الطول (م)',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'مطلوب';
                        }
                        if (double.tryParse(value) == null || double.parse(value) <= 0) {
                          return 'غير صحيح';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() => _recalculateTotals()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: item.widthController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'العرض (م)',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'مطلوب';
                        }
                        if (double.tryParse(value) == null || double.parse(value) <= 0) {
                          return 'غير صحيح';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() => _recalculateTotals()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: item.priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'السعر/م²',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'السعر مطلوب';
                        }
                        if (double.tryParse(value) == null || double.parse(value) < 0) {
                          return 'غير صحيح';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() => _recalculateTotals()),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Text(
                //   isUnit
                //       ? 'طريقة الحساب: بالحبة 📦'
                //       : 'المساحة للقطعة: ${((double.tryParse(item.lengthController.text) ?? 0.0) * (double.tryParse(item.widthController.text) ?? 0.0)).toStringAsFixed(1)} م²'
                //         '${(int.tryParse(item.quantityController.text) ?? 1) > 1 ? ' (الإجمالي: ${(((double.tryParse(item.lengthController.text) ?? 0.0) * (double.tryParse(item.widthController.text) ?? 0.0)) * (int.tryParse(item.quantityController.text) ?? 1)).toStringAsFixed(1)} م²)' : ''}',
                //   style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                // ),
                Text(
                  'التكلفة للنوع: ${item.itemTotal.toStringAsFixed(0)} ر.ي',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _recalculateTotals() {
    double totalP = 0.0;
    int totalC = 0;

    for (var item in _carpetItems) {
      if (item.selectedType == null) continue;

      final rate = double.tryParse(item.priceController.text) ?? 0.0;
      if (item.selectedType!.pricingType == 'unit') {
        final qty = int.tryParse(item.quantityController.text) ?? 0;
        item.itemTotal = (rate * qty).roundToDouble();
        totalC += qty;
      } else {
        final len = double.tryParse(item.lengthController.text) ?? 0.0;
        final wid = double.tryParse(item.widthController.text) ?? 0.0;
        item.itemTotal = (rate * len * wid).roundToDouble();
        totalC += 1; // Meter item represents exactly 1 piece
      }
      totalP += item.itemTotal;
    }

    if (_carpetItems.isNotEmpty) {
      _priceController.text = totalP.toStringAsFixed(0);
      _countController.text = totalC.toString();
    } else {
      _priceController.text = '0';
      _countController.text = '0';
    }
  }
}

class _CarpetItemFormState {
  CarpetType? selectedType;
  final nameController = TextEditingController();
  final priceController = TextEditingController();
  final quantityController = TextEditingController(text: '1');
  final lengthController = TextEditingController();
  final widthController = TextEditingController();
  double itemTotal = 0.0;

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    quantityController.dispose();
    lengthController.dispose();
    widthController.dispose();
  }
}
