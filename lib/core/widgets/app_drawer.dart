import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/auth/viewmodel/auth_viewmodel.dart';
import '../../features/dashboard/view/dashboard_view.dart';
import '../../features/orders/view/order_list_view.dart';
import '../../features/customers/view/customer_list_view.dart';
import '../../features/carpet_types/view/carpet_type_settings_view.dart';
import '../theme/app_theme.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;
  
  const AppDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final tenant = authViewModel.currentTenant;

    return Drawer(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // Header
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: AppTheme.secondaryColor.withOpacity(0.2),
                child: const Icon(
                  Icons.local_laundry_service_outlined,
                  color: AppTheme.secondaryColor,
                  size: 40,
                ),
              ),
              accountName: Text(
                tenant?.name ?? 'مغسلة سجاد',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              accountEmail: Text(
                'رمز المغسلة: ${tenant?.laundryCode ?? 'أ'} | ${tenant?.email ?? ''}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ),

            // Navigation Options
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('لوحة التحكم'),
              selected: currentRoute == 'dashboard',
              selectedColor: AppTheme.primaryColor,
              onTap: () {
                Navigator.pop(context); // Close drawer
                if (currentRoute != 'dashboard') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const DashboardView()),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_basket_outlined),
              title: const Text('إدارة الطلبات'),
              selected: currentRoute == 'orders',
              selectedColor: AppTheme.primaryColor,
              onTap: () {
                Navigator.pop(context); // Close drawer
                if (currentRoute != 'orders') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const OrderListView()),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('إدارة العملاء'),
              selected: currentRoute == 'customers',
              selectedColor: AppTheme.primaryColor,
              onTap: () {
                Navigator.pop(context); // Close drawer
                if (currentRoute != 'customers') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const CustomerListView()),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('إعدادات أسعار السجاد'),
              selected: currentRoute == 'carpet_types',
              selectedColor: AppTheme.primaryColor,
              onTap: () {
                Navigator.pop(context); // Close drawer
                if (currentRoute != 'carpet_types') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const CarpetTypeSettingsView()),
                  );
                }
              },
            ),

            const Spacer(),
            const Divider(),

            // Logout Option
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.error),
              title: const Text(
                'تسجيل الخروج',
                style: TextStyle(color: AppTheme.error),
              ),
              onTap: () {
                Navigator.pop(context); // Close drawer
                _showLogoutDialog(context, authViewModel);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthViewModel authViewModel) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟ سيتم إغلاق قاعدة البيانات المحلية لهذه المغسلة.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                authViewModel.logout();
              },
              child: const Text(
                'تسجيل خروج',
                style: TextStyle(color: AppTheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
