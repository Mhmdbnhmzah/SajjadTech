import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/database_helper.dart';

class CustomerViewModel extends ChangeNotifier {
  final AppDatabase? db;

  List<Customer> _allCustomers = [];
  List<Customer> _searchResults = [];
  bool _isLoading = false;

  List<Customer> get customers => _searchResults.isEmpty && _allCustomers.isNotEmpty ? _allCustomers : _searchResults;
  List<Customer> get allCustomers => _allCustomers;
  bool get isLoading => _isLoading;

  CustomerViewModel({required this.db}) {
    _loadCustomers();
  }

  void _loadCustomers() {
    if (db == null) return;
    
    _isLoading = true;
    notifyListeners();

    db!.watchCustomers().listen((list) {
      _allCustomers = list;
      _searchResults = [];
      _isLoading = false;
      notifyListeners();
    });
  }

  // Search by Name, Phone, or Serial Number
  void searchCustomers(String query) {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    final lowerQuery = query.toLowerCase();

    // Clean query if it contains a hyphen prefix (e.g., A-1001 or أ-1001)
    String cleanQuery = lowerQuery;
    if (lowerQuery.contains('-')) {
      final parts = lowerQuery.split('-');
      final possibleSerial = parts.last.trim();
      if (int.tryParse(possibleSerial) != null) {
        cleanQuery = possibleSerial;
      }
    }

    _searchResults = _allCustomers.where((cust) {
      final matchesName = cust.name.toLowerCase().contains(lowerQuery);
      final matchesPhone = cust.phone.contains(lowerQuery);
      final matchesSerial = cust.serialNumber.toString().contains(cleanQuery);
      return matchesName || matchesPhone || matchesSerial;
    }).toList();

    notifyListeners();
  }

  // Register a new customer
  Future<Customer?> registerCustomer({
    required String name,
    required String phone,
  }) async {
    if (db == null) return null;

    try {
      _isLoading = true;
      notifyListeners();

      // Generate Serial Number
      final lastSerial = await db!.getLastCustomerSerial();
      final nextSerial = (lastSerial == null) ? 1001 : lastSerial + 1;

      final now = DateTime.now();
      final companion = CustomersCompanion(
        serialNumber: drift.Value(nextSerial),
        name: drift.Value(name),
        phone: drift.Value(phone),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
        synced: drift.Value(false),
        isDeleted: drift.Value(false),
      );

      final customerId = await db!.insertCustomer(companion);
      _isLoading = false;
      notifyListeners();

      return Customer(
        id: customerId,
        serialNumber: nextSerial,
        name: name,
        phone: phone,
        createdAt: now,
        updatedAt: now,
        synced: false,
        isDeleted: false,
      );
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Register customer error: $e');
      return null;
    }
  }

  // Delete Customer
  Future<bool> deleteCustomer(int id) async {
    if (db == null) return false;
    
    try {
      await db!.softDeleteCustomer(id);
      return true;
    } catch (e) {
      print('Delete customer error: $e');
      return false;
    }
  }
}
