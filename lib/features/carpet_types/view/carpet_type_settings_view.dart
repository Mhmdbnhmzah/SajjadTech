import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodel/carpet_type_viewmodel.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/database_helper.dart';

/// Embeddable body for use inside MainNavigation shell
typedef CarpetTypeBody = CarpetTypeSettingsView;

class CarpetTypeSettingsView extends StatefulWidget {
  final bool isEmbedded;
  const CarpetTypeSettingsView({super.key, this.isEmbedded = false});


  @override
  State<CarpetTypeSettingsView> createState() => _CarpetTypeSettingsViewState();
}

class _CarpetTypeSettingsViewState extends State<CarpetTypeSettingsView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  String _pricingType = 'unit'; // 'unit' or 'meter'

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _showCarpetTypeDialog({CarpetType? carpetType}) {
    final isEditing = carpetType != null;
    
    if (isEditing) {
      _nameController.text = carpetType.name;
      _priceController.text = carpetType.price.toString();
      _pricingType = carpetType.pricingType;
    } else {
      _nameController.clear();
      _priceController.clear();
      _pricingType = 'unit';
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setStateBuilder) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            scrollable: true,
            title: Text(isEditing ? 'تعديل نوع السجاد' : 'إضافة نوع سجاد جديد'),
            content: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Carpet Name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم نوع السجاد',
                      hintText: 'مثال: سجاد تركي، موكيت، صوف...',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'يرجى إدخال اسم نوع السجاد';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Pricing Type Selector
                  const Text(
                    'طريقة احتساب السعر:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('بالحبة (وحدة)', style: TextStyle(fontSize: 13)),
                          value: 'unit',
                          groupValue: _pricingType,
                          onChanged: (val) {
                            setStateBuilder(() {
                              _pricingType = val!;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('بالمقاس (متر²)', style: TextStyle(fontSize: 13)),
                          value: 'meter',
                          groupValue: _pricingType,
                          onChanged: (val) {
                            setStateBuilder(() {
                              _pricingType = val!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Price Input
                  TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: _pricingType == 'unit' ? 'سعر الحبة (ريال)' : 'سعر المتر المربع (ريال)',
                      prefixIcon: const Icon(Icons.payments_outlined),
                      suffixText: 'ريال',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'يرجى إدخال السعر';
                      }
                      if (double.tryParse(value) == null || double.parse(value) < 0) {
                        return 'يرجى إدخال قيمة صحيحة';
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
                    final carpetVm = Provider.of<CarpetTypeViewModel>(context, listen: false);
                    Navigator.pop(dialogCtx);

                    bool success;
                    if (isEditing) {
                      success = await carpetVm.updateCarpetType(
                        id: carpetType.id,
                        name: _nameController.text.trim(),
                        pricingType: _pricingType,
                        price: double.parse(_priceController.text),
                      );
                    } else {
                      success = await carpetVm.addCarpetType(
                        name: _nameController.text.trim(),
                        pricingType: _pricingType,
                        price: double.parse(_priceController.text),
                      );
                    }

                    if (success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isEditing ? 'تم تحديث البيانات بنجاح' : 'تم إضافة نوع السجاد بنجاح',
                            textAlign: TextAlign.right,
                          ),
                          backgroundColor: AppTheme.success,
                        ),
                      );
                    }
                  }
                },
                child: Text(isEditing ? 'تعديل وحفظ' : 'إضافة وحفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteCarpetType(BuildContext context, CarpetType type) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف نوع السجاد'),
          content: Text('هل أنت متأكد من رغبتك في حذف "${type.name}"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () async {
                final carpetVm = Provider.of<CarpetTypeViewModel>(context, listen: false);
                Navigator.pop(dialogCtx);
                final success = await carpetVm.deleteCarpetType(type.id);

                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف نوع السجاد بنجاح', textAlign: TextAlign.right),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              },
              child: const Text(
                'حذف',
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
    final carpetVm = context.watch<CarpetTypeViewModel>();

    final body = Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750),
          child: carpetVm.isLoading
              ? const Center(child: CircularProgressIndicator())
              : carpetVm.carpetTypes.isEmpty
                  ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: carpetVm.carpetTypes.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final type = carpetVm.carpetTypes[index];
                    final isUnit = type.pricingType == 'unit';

                    return Card(
                      elevation: 1.5,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isUnit
                                ? AppTheme.primaryColor.withOpacity(0.1)
                                : AppTheme.secondaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isUnit ? Icons.inventory_2_outlined : Icons.straighten_outlined,
                            color: isUnit ? AppTheme.primaryColor : AppTheme.secondaryColor,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          type.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 10,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    isUnit ? '📦 بالحبة' : '📏 بالمتر المربع',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                  ),
                                ),
                                Text(
                                  isUnit
                                      ? '${type.price.toStringAsFixed(0)} ر.ي / حبة'
                                      : '${type.price.toStringAsFixed(0)} ر.ي / م²',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.secondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryColor),
                              onPressed: () => _showCarpetTypeDialog(carpetType: type),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                              onPressed: () => _confirmDeleteCarpetType(context, type),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ),
          ),
    );

    if (widget.isEmbedded) {
      return Stack(
        children: [
          body,
          Positioned(
            bottom: 16,
            left: 16,
            child: FloatingActionButton(
              heroTag: 'carpet_add_fab',
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              onPressed: () => _showCarpetTypeDialog(),
              child: const Icon(Icons.add_card_outlined),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      drawer: const AppDrawer(currentRoute: 'carpet_types'),
      appBar: AppBar(
        title: const Text('إعدادات أسعار السجاد'),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'carpet_fab',
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        onPressed: () => _showCarpetTypeDialog(),
        child: const Icon(Icons.add_card_outlined),
      ),
      body: body,
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
              Icons.style_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'لا توجد أنواع سجاد مضافة حالياً',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'اضغط على الزر بالأسفل لإضافة أول نوع سجاد وحدد سعره بالحبة أو بالمتر المربع',
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
