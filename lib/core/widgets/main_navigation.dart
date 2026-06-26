import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/auth/viewmodel/auth_viewmodel.dart';
import '../../features/dashboard/viewmodel/dashboard_viewmodel.dart';
import '../../features/dashboard/view/dashboard_view.dart';
import '../../features/orders/view/order_list_view.dart';
import '../../features/customers/view/customer_list_view.dart';
import '../../features/carpet_types/view/carpet_type_settings_view.dart';
import '../../features/orders/view/order_form_view.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../../main.dart';

class MainNavigation extends StatefulWidget {
  final int initialIndex;
  const MainNavigation({super.key, this.initialIndex = 0});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with TickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _fabAnimController;
  late Animation<double> _fabScaleAnim;

  final List<_NavItem> _navItems = const [
    _NavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: 'الرئيسية',
    ),
    _NavItem(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      label: 'الطلبات',
    ),
    _NavItem(
      icon: Icons.people_outline_rounded,
      activeIcon: Icons.people_rounded,
      label: 'العملاء',
    ),
    _NavItem(
      icon: Icons.tune_outlined,
      activeIcon: Icons.tune_rounded,
      label: 'الانواع',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabScaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimController, curve: Curves.easeOutBack),
    );
    if (_currentIndex == 1) {
      _fabAnimController.forward();
    }
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
    if (index == 1) {
      _fabAnimController.forward();
    } else {
      _fabAnimController.reverse();
    }
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const DashboardBody();
      case 1:
        return const OrderListBody();
      case 2:
        return const CustomerListView(isEmbedded: true);
      case 3:
        return const CarpetTypeSettingsView(isEmbedded: true);
      default:
        return const DashboardBody();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final dashboardViewModel = context.watch<DashboardViewModel>();
    final tenant = authViewModel.currentTenant;

    // Kick out if account disabled
    if (dashboardViewModel.syncMessage == 'ACCOUNT_DISABLED') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم تعطيل حساب المغسلة من قبل الإدارة',
              textAlign: TextAlign.right,
            ),
            backgroundColor: AppTheme.error,
          ),
        );
        authViewModel.logout();
      });
    }

    final List<String> routeNames = ['dashboard', 'orders', 'customers', 'carpet_types'];

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      drawer: AppDrawer(
        currentRoute: routeNames[_currentIndex],
        onNavigate: (index) {
          _onTabTapped(index);
        },
      ),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: true,
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tenant?.name ?? 'المغسلة الحديثة',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          // Sync Button
          IconButton(
            icon: dashboardViewModel.isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.cloud_sync_outlined, color: Colors.white),
            tooltip: 'مزامنة السحابة',
            onPressed: dashboardViewModel.isSyncing
                ? null
                : () async {
                    if (tenant != null) {
                      final isActive = await authViewModel.checkAccountStatus();
                      if (isActive && context.mounted) {
                        await dashboardViewModel.triggerSync(tenant.id);
                      }
                    }
                  },
          ),
          // Logout
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'تسجيل الخروج',
            onPressed: () => _showLogoutDialog(context, authViewModel),
          ),
        ],
      ),
      body: Column(
        children: [
          // Sync Banner
          if (dashboardViewModel.syncMessage != null &&
              dashboardViewModel.syncMessage != 'ACCOUNT_DISABLED')
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              color: dashboardViewModel.syncMessage!.contains('فشلت')
                  ? AppTheme.error.withOpacity(0.9)
                  : AppTheme.success.withOpacity(0.9),
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    dashboardViewModel.syncMessage!.contains('فشلت')
                        ? Icons.cloud_off
                        : Icons.cloud_done_outlined,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dashboardViewModel.syncMessage!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          // Page Content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: child,
              ),
              child: KeyedSubtree(
                key: ValueKey<int>(_currentIndex),
                child: _buildPage(_currentIndex),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabScaleAnim,
        child: FloatingActionButton.extended(
          heroTag: 'main_nav_fab',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const OrderFormView(),
              ),
            );
          },
          backgroundColor: AppTheme.success,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add_rounded, size: 24),
          label: const Text(
            'طلب جديد',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildModernNavBar(),
    );
  }

  Widget _buildModernNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_navItems.length, (index) {
                final item = _navItems[index];
                final isSelected = _currentIndex == index;
                return _buildNavItem(item, index, isSelected);
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(_NavItem item, int index, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isSelected ? item.activeIcon : item.icon,
                  key: ValueKey<bool>(isSelected),
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.lightTextSecondary,
                  size: 26,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.lightTextSecondary,
                ),
                child: Text(item.label),
              ),
            ],
          ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: AppTheme.error),
              SizedBox(width: 8),
              Text('تسجيل الخروج'),
            ],
          ),
          content: const Text(
            'هل أنت متأكد من رغبتك في تسجيل الخروج؟\nسيتم إغلاق قاعدة البيانات المحلية لهذه المغسلة.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
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
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
