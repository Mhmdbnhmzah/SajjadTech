import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/auth/viewmodel/auth_viewmodel.dart';
import '../../features/dashboard/view/dashboard_view.dart';
import '../../features/orders/view/order_list_view.dart';
import '../../features/customers/view/customer_list_view.dart';
import '../../features/carpet_types/view/carpet_type_settings_view.dart';
import '../theme/app_theme.dart';
import '../../main.dart';
import 'main_navigation.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;

  /// إذا كان موجوداً، يُستخدم للتنقل بين التبويبات بدلاً من Navigator.pushReplacement
  /// يُمرَّر إليه الـ index المطلوب (0=dashboard, 1=orders, 2=customers, 3=carpet_types)
  final void Function(int index)? onNavigate;

  const AppDrawer({
    super.key,
    required this.currentRoute,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.read<AuthViewModel>();
    final tenant = authViewModel.currentTenant;

    return Drawer(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Header
                  UserAccountsDrawerHeader(
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                    ),
                    currentAccountPicture: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Text(
                        tenant?.name.isNotEmpty == true
                            ? tenant!.name[0].toUpperCase()
                            : 'M',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    accountName: Text(
                      tenant?.name ?? 'المغسلة',
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
                  _DrawerItem(
                    icon: Icons.dashboard_outlined,
                    label: 'لوحة التحكم',
                    isSelected: currentRoute == 'dashboard',
                    onTap: () {
                      Navigator.pop(context);
                      if (currentRoute != 'dashboard') {
                        if (onNavigate != null) {
                          onNavigate!(0);
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const DashboardView()),
                          );
                        }
                      }
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.shopping_basket_outlined,
                    label: 'إدارة الطلبات',
                    isSelected: currentRoute == 'orders',
                    onTap: () {
                      Navigator.pop(context);
                      if (currentRoute != 'orders') {
                        if (onNavigate != null) {
                          onNavigate!(1);
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const OrderListView()),
                          );
                        }
                      }
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.people_outline,
                    label: 'إدارة العملاء',
                    isSelected: currentRoute == 'customers',
                    onTap: () {
                      Navigator.pop(context);
                      if (currentRoute != 'customers') {
                        if (onNavigate != null) {
                          onNavigate!(2);
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const CustomerListView()),
                          );
                        }
                      }
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    label: 'إعدادات أسعار السجاد',
                    isSelected: currentRoute == 'carpet_types',
                    onTap: () {
                      Navigator.pop(context);
                      if (currentRoute != 'carpet_types') {
                        if (onNavigate != null) {
                          onNavigate!(3);
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const CarpetTypeSettingsView()),
                          );
                        }
                      }
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.analytics_outlined,
                    label: 'التقارير والإحصائيات',
                    isSelected: currentRoute == 'reports',
                    onTap: () {
                      Navigator.pop(context);
                      if (currentRoute != 'reports') {
                        if (onNavigate != null) {
                          onNavigate!(4);
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MainNavigation(initialIndex: 4),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Logout Option
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.error),
              title: const Text(
                'تسجيل الخروج',
                style: TextStyle(color: AppTheme.error),
              ),
              onTap: () {
                Navigator.pop(context);
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
          content: const Text(
              'هل أنت متأكد من رغبتك في تسجيل الخروج؟ سيتم إغلاق قاعدة البيانات المحلية لهذه المغسلة.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                authViewModel.logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const AppHome()),
                  (route) => false,
                );
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

/// زر عنصر في الـ Drawer بتصميم موحد
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.primaryColor : null,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppTheme.primaryColor : null,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppTheme.primaryColor.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      onTap: onTap,
    );
  }
}
