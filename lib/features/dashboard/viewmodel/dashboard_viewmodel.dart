import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/sync_service.dart';

class DashboardViewModel extends ChangeNotifier {
  final AppDatabase? db;
  
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  String? _syncMessage;
  String? get syncMessage => _syncMessage;

  int _receivedCount = 0;
  int get receivedCount => _receivedCount;

  int _readyCount = 0;
  int get readyCount => _readyCount;

  int _deliveredTodayCount = 0;
  int get deliveredTodayCount => _deliveredTodayCount;

  double _todayIncome = 0.0;
  double get todayIncome => _todayIncome;

  List<Order> _recentOrders = [];
  List<Order> get recentOrders => _recentOrders;

  Map<int, Customer> _customerCache = {};
  Map<int, Customer> get customerCache => _customerCache;

  DashboardViewModel({required this.db}) {
    _loadStats();
  }

  void _loadStats() async {
    if (db == null) return;

    // Watch all orders changes reactively
    db!.watchOrders().listen((ordersList) async {
      int rec = 0;
      int rdy = 0;
      int delToday = 0;
      double income = 0.0;
      final now = DateTime.now();

      for (final order in ordersList) {
        if (order.status == 'received') {
          rec++;
        } else if (order.status == 'ready') {
          rdy++;
        }

        // Today income and delivered today checks
        final orderDate = order.receivedDate;
        final isToday = orderDate.year == now.year &&
            orderDate.month == now.month &&
            orderDate.day == now.day;

        if (isToday) {
          income += order.totalPrice;
        }

        if (order.status == 'delivered' && isToday) {
          delToday++;
        }
      }

      _receivedCount = rec;
      _readyCount = rdy;
      _deliveredTodayCount = delToday;
      _todayIncome = income;

      // Sort and take top 5 recent orders
      final sortedOrders = List<Order>.from(ordersList)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _recentOrders = sortedOrders.take(5).toList();

      // Fetch customer cache for these orders
      for (final order in _recentOrders) {
        if (!_customerCache.containsKey(order.customerId)) {
          final cust = await db!.getCustomerById(order.customerId);
          if (cust != null) {
            _customerCache[order.customerId] = cust;
          }
        }
      }

      notifyListeners();
    });
  }

  // Trigger sync manually
  Future<void> triggerSync(String tenantId) async {
    if (db == null) return;
    
    _isSyncing = true;
    _syncMessage = 'جاري المزامنة مع السحابة...';
    notifyListeners();

    try {
      final syncService = SyncService(db: db!, tenantId: tenantId);
      await syncService.syncData();
      _syncMessage = 'تمت المزامنة بنجاح ✅';
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('ACCOUNT_DISABLED') || errorStr.contains('ACCOUNT_NOT_FOUND')) {
        _syncMessage = 'ACCOUNT_DISABLED';
      } else {
        _syncMessage = 'فشلت المزامنة: ${errorStr.replaceAll('Exception:', '').trim()}';
      }
    } finally {
      _isSyncing = false;
      notifyListeners();
      
      // Clear sync message after 3 seconds (unless account is disabled)
      if (_syncMessage != 'ACCOUNT_DISABLED') {
        Future.delayed(const Duration(seconds: 3), () {
          _syncMessage = null;
          notifyListeners();
        });
      }
    }
  }

  // Helper method to get customer info from cache
  Customer? getCachedCustomer(int id) => _customerCache[id];
}
