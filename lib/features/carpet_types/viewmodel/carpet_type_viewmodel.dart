import 'dart:async';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/database_helper.dart';

class CarpetTypeViewModel extends ChangeNotifier {
  AppDatabase? _db;
  StreamSubscription? _subscription;

  AppDatabase? get db => _db;

  List<CarpetType> _allCarpetTypes = [];
  bool _isLoading = false;

  List<CarpetType> get carpetTypes => _allCarpetTypes;
  bool get isLoading => _isLoading;

  CarpetTypeViewModel({AppDatabase? db}) {
    updateDb(db);
  }

  void updateDb(AppDatabase? newDb) {
    if (_db == newDb) return;

    _subscription?.cancel();
    _subscription = null;

    _db = newDb;

    if (_db != null) {
      _loadCarpetTypes();
    } else {
      _allCarpetTypes = [];
      _isLoading = false;
      notifyListeners();
    }
  }

  void _loadCarpetTypes() {
    if (_db == null) return;

    _isLoading = true;
    notifyListeners();

    _subscription = _db!.watchCarpetTypes().listen((list) {
      _allCarpetTypes = list;
      _isLoading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<bool> addCarpetType({
    required String name,
    required String pricingType,
    required double price,
  }) async {
    if (db == null) return false;

    try {
      _isLoading = true;
      notifyListeners();

      final now = DateTime.now();
      final companion = CarpetTypesCompanion(
        name: drift.Value(name),
        pricingType: drift.Value(pricingType),
        price: drift.Value(price),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
        synced: const drift.Value(false),
        isDeleted: const drift.Value(false),
      );

      await db!.insertCarpetType(companion);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Add carpet type error: $e');
      return false;
    }
  }

  Future<bool> updateCarpetType({
    required int id,
    required String name,
    required String pricingType,
    required double price,
  }) async {
    if (db == null) return false;

    try {
      _isLoading = true;
      notifyListeners();

      final existing = await db!.getCarpetTypeById(id);
      if (existing == null) throw Exception('نوع السجاد غير موجود');

      final now = DateTime.now();
      final updated = existing.copyWith(
        name: name,
        pricingType: pricingType,
        price: price,
        updatedAt: now,
        synced: false,
      );

      await db!.updateCarpetTypeData(updated);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Update carpet type error: $e');
      return false;
    }
  }

  Future<bool> deleteCarpetType(int id) async {
    if (db == null) return false;

    try {
      await db!.softDeleteCarpetType(id);
      return true;
    } catch (e) {
      print('Delete carpet type error: $e');
      return false;
    }
  }
}
