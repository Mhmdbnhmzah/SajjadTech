import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/sync_service.dart';

class DashboardViewModel extends ChangeNotifier {
  AppDatabase? _db;
  StreamSubscription? _subscription;

  AppDatabase? get db => _db;
  
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

  List<Order> _urgentOrders = [];
  List<Order> get urgentOrders => _urgentOrders;

  final Map<int, Customer> _customerCache = {};
  Map<int, Customer> get customerCache => _customerCache;

  DashboardViewModel({AppDatabase? db}) {
    updateDb(db);
  }

  void updateDb(AppDatabase? newDb) {
    if (_db == newDb) return;

    _subscription?.cancel();
    _subscription = null;

    _db = newDb;

    if (_db != null) {
      _loadStats();
    } else {
      _receivedCount = 0;
      _readyCount = 0;
      _deliveredTodayCount = 0;
      _todayIncome = 0.0;
      _recentOrders = [];
      _urgentOrders = [];
      _customerCache.clear();
      notifyListeners();
    }
  }

  void _loadStats() async {
    if (_db == null) return;

    _subscription = _db!.watchOrders().listen((ordersList) async {
      int rec = 0;
      int rdy = 0;
      int delToday = 0;
      double income = 0.0;
      final now = DateTime.now();
      final todayDateOnly = DateTime(now.year, now.month, now.day);

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
          income += order.paidAmount;
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

      // Filter and sort urgent orders: status != 'delivered' and delivery date within today + 2 days
      final urgentList = <Order>[];
      for (final order in ordersList) {
        if (order.status != 'delivered') {
          final delivDateOnly = DateTime(order.deliveryDate.year, order.deliveryDate.month, order.deliveryDate.day);
          final diff = delivDateOnly.difference(todayDateOnly).inDays;
          if (diff <= 2) {
            urgentList.add(order);
          }
        }
      }
      urgentList.sort((a, b) => a.deliveryDate.compareTo(b.deliveryDate));
      _urgentOrders = urgentList;

      // Fetch customer cache for recent and urgent orders
      final ordersToCache = {..._recentOrders, ..._urgentOrders};
      final activeCustomerIds = ordersToCache.map((o) => o.customerId).toSet();
      _customerCache.removeWhere((id, _) => !activeCustomerIds.contains(id));
      
      for (final order in ordersToCache) {
        final cust = await _db!.getCustomerById(order.customerId);
        if (cust != null) {
          _customerCache[order.customerId] = cust;
        }
      }

      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
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
