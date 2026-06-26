import 'dart:async';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/database_helper.dart';

class CustomerViewModel extends ChangeNotifier {
  AppDatabase? _db;
  StreamSubscription? _subscription;

  AppDatabase? get db => _db;

  List<Customer> _allCustomers = [];
  List<Customer> _searchResults = [];
  bool _isLoading = false;

  String _searchQuery = '';

  List<Customer> get customers => _searchQuery.isEmpty ? _allCustomers : _searchResults;
  List<Customer> get allCustomers => _allCustomers;
  bool get isLoading => _isLoading;

  CustomerViewModel({AppDatabase? db}) {
    updateDb(db);
  }

  void updateDb(AppDatabase? newDb) {
    if (_db == newDb) return;

    _subscription?.cancel();
    _subscription = null;

    _db = newDb;

    if (_db != null) {
      _loadCustomers();
    } else {
      _allCustomers = [];
      _searchResults = [];
      _searchQuery = '';
      _isLoading = false;
      notifyListeners();
    }
  }

  void _loadCustomers() {
    if (_db == null) return;
    
    _isLoading = true;
    notifyListeners();

    _subscription = _db!.watchCustomers().listen((list) {
      _allCustomers = list;
      _isLoading = false;
      if (_searchQuery.isNotEmpty) {
        searchCustomers(_searchQuery);
      } else {
        _searchResults = [];
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // Search by Name, Phone, or Serial Number
  void searchCustomers(String query) {
    _searchQuery = query.trim();
    if (_searchQuery.isEmpty) {
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
