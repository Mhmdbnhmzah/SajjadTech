import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';

class CarpetTypeReportRow {
  final String name;
  final String pricingType;
  double totalQuantity;
  double totalArea;
  double totalRevenue;

  CarpetTypeReportRow({
    required this.name,
    required this.pricingType,
    this.totalQuantity = 0.0,
    this.totalArea = 0.0,
    this.totalRevenue = 0.0,
  });
}

class ReportsViewModel extends ChangeNotifier {
  AppDatabase? _db;
  bool _isLoading = false;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  List<Order> _orders = [];
  Map<int, Customer> _customerMap = {};
  double _totalSales = 0;
  double _totalPaid = 0;
  int _totalItemsCount = 0;
  int _newCustomersCount = 0;
  List<CarpetTypeReportRow> _carpetBreakdown = [];
  Map<int, List<OrderItem>> _orderItemsMap = {};

  // Getters
  AppDatabase? get db => _db;
  bool get isLoading => _isLoading;
  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;
  List<Order> get orders => _orders;
  Map<int, Customer> get customerMap => _customerMap;
  double get totalSales => _totalSales;
  double get totalPaid => _totalPaid;
  double get totalUnpaid => _totalSales - _totalPaid;
  int get totalItemsCount => _totalItemsCount;
  int get newCustomersCount => _newCustomersCount;
  List<CarpetTypeReportRow> get carpetBreakdown => _carpetBreakdown;
  Map<int, List<OrderItem>> get orderItemsMap => _orderItemsMap;

  ReportsViewModel({AppDatabase? db}) {
    updateDb(db);
  }

  void updateDb(AppDatabase? newDb) {
    if (_db == newDb) return;
    _db = newDb;
    if (_db != null) {
      loadReport();
    } else {
      _clearData();
    }
  }

  void _clearData() {
    _orders = [];
    _customerMap = {};
    _totalSales = 0;
    _totalPaid = 0;
    _totalItemsCount = 0;
    _newCustomersCount = 0;
    _carpetBreakdown = [];
    _orderItemsMap = {};
    _isLoading = false;
    notifyListeners();
  }

  // Update date range and refresh statistics
  void setDateRange(DateTime start, DateTime end) {
    _startDate = start;
    _endDate = end;
    loadReport();
  }

  Future<void> loadReport() async {
    if (_db == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Normalize dates: start from 00:00:00 of start date, end at 23:59:59 of end date
      final startNormalized = DateTime(_startDate.year, _startDate.month, _startDate.day, 0, 0, 0);
      final endNormalized = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);

      // 1. Fetch orders in range
      final ordersList = await _db!.getOrdersInDateRange(startNormalized, endNormalized);
      _orders = ordersList;

      // 2. Fetch new customers registered in range
      final newCusts = await _db!.getCustomersInDateRange(startNormalized, endNormalized);
      _newCustomersCount = newCusts.length;

      // 3. Fetch all customers to populate customer map (needed to show names of customers in orders list)
      final allCustomers = await _db!.getAllCustomers();
      _customerMap = {for (var c in allCustomers) c.id: c};

      // 4. Calculate aggregates
      _totalSales = 0;
      _totalPaid = 0;
      _totalItemsCount = 0;

      final Map<String, CarpetTypeReportRow> breakdownMap = {};

      _orderItemsMap = {};

      for (final order in _orders) {
        _totalSales += order.totalPrice;
        _totalPaid += order.paidAmount;
        _totalItemsCount += order.itemCount;

        // Fetch items for this order to build carpet type breakdown and details
        final items = await _db!.getOrderItems(order.id);
        _orderItemsMap[order.id] = items;
        for (final item in items) {
          final key = '${item.name}_${item.pricingType}';
          if (!breakdownMap.containsKey(key)) {
            breakdownMap[key] = CarpetTypeReportRow(
              name: item.name,
              pricingType: item.pricingType,
            );
          }

          final row = breakdownMap[key]!;
          if (item.pricingType == 'unit') {
            row.totalQuantity += (item.quantity ?? 1).toDouble();
          } else {
            row.totalArea += (item.area ?? 0.0);
            row.totalQuantity += (item.quantity ?? 1).toDouble();
          }
          row.totalRevenue += item.totalPrice;
        }
      }

      _carpetBreakdown = breakdownMap.values.toList();
      // Sort breakdown by revenue descending
      _carpetBreakdown.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Load reports error: $e');
    }
  }
}
