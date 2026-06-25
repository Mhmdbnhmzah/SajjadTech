import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/services/firebase_service.dart';
import 'features/auth/viewmodel/auth_viewmodel.dart';
import 'features/auth/view/login_view.dart';
import 'features/dashboard/viewmodel/dashboard_viewmodel.dart';
import 'features/dashboard/view/dashboard_view.dart';
import 'features/customers/viewmodel/customer_viewmodel.dart';
import 'features/orders/viewmodel/order_viewmodel.dart';
import 'features/carpet_types/viewmodel/carpet_type_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (safely catches exceptions and supports offline demo mode)
  await FirebaseService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>(create: (_) => AuthViewModel()),
        ChangeNotifierProxyProvider<AuthViewModel, DashboardViewModel>(
          create: (_) => DashboardViewModel(db: null),
          update: (_, auth, previous) => previous!..updateDb(auth.database),
        ),
        ChangeNotifierProxyProvider<AuthViewModel, CustomerViewModel>(
          create: (_) => CustomerViewModel(db: null),
          update: (_, auth, previous) => previous!..updateDb(auth.database),
        ),
        ChangeNotifierProxyProvider<AuthViewModel, OrderViewModel>(
          create: (_) => OrderViewModel(db: null, laundryName: 'مغسلة سجاد'),
          update: (_, auth, previous) => previous!
            ..updateDb(auth.database, auth.currentTenant?.name ?? 'مغسلة سجاد'),
        ),
        ChangeNotifierProxyProvider<AuthViewModel, CarpetTypeViewModel>(
          create: (_) => CarpetTypeViewModel(db: null),
          update: (_, auth, previous) => previous!..updateDb(auth.database),
        ),
      ],
      child: MaterialApp(
        title: 'المغسلة الحديثة للفرش',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: const AppHome(),
      ),
    );
  }
}

class AppHome extends StatelessWidget {
  const AppHome({super.key});

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();

    // Route logic:
    // If not logged in, show LoginView.
    // Otherwise, show DashboardView.
    if (authViewModel.currentTenant == null) {
      return const LoginView();
    } else {
      return const DashboardView();
    }
  }
}
