import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/sync_service.dart';
import '../model/auth_model.dart';

class AuthViewModel extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  LaundryTenant? _currentTenant;
  LaundryTenant? get currentTenant => _currentTenant;

  AppDatabase? _database;
  AppDatabase? get database => _database;

  AuthViewModel() {
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tenantId = prefs.getString('tenant_id');
      final laundryName = prefs.getString('laundry_name');
      final laundryCode = prefs.getString('laundry_code') ?? 'أ';
      final email = prefs.getString('email') ?? '';
      
      if (tenantId != null && laundryName != null) {
        _currentTenant = LaundryTenant(
          id: tenantId,
          name: laundryName,
          isActive: true,
          email: email,
          laundryCode: laundryCode,
        );
        _database = AppDatabase(tenantId);
        notifyListeners();

        // Background check to kick out deactivated accounts
        _checkStatusInBackground(tenantId);
      }
    } catch (e) {
      print('Auto login error: $e');
    }
  }

  Future<void> _checkStatusInBackground(String tenantId) async {
    // Wait slightly after startup so UI is fully rendered
    await Future.delayed(const Duration(seconds: 1));
    await checkAccountStatus();
  }

  Future<bool> checkAccountStatus() async {
    if (_currentTenant == null) return true;
    if (!FirebaseService.isFirebaseInitialized) return true;
    try {
      final statusMap = await _firebaseService.checkTenantStatus(_currentTenant!.id);
      final bool isActive = statusMap['isActive'] ?? false;
      if (!isActive) {
        await logout();
        return false; // Account deactivated
      }

      // Update local tenant details if they changed in Firebase
      final String laundryName = statusMap['laundryName'] ?? 'مغسلة سجاد';
      final String laundryCode = statusMap['laundryCode'] ?? 'أ';
      
      if (_currentTenant!.name != laundryName || _currentTenant!.laundryCode != laundryCode) {
        _currentTenant = LaundryTenant(
          id: _currentTenant!.id,
          name: laundryName,
          isActive: isActive,
          email: _currentTenant!.email,
          laundryCode: laundryCode,
        );
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('laundry_name', laundryName);
        await prefs.setString('laundry_code', laundryCode);
        notifyListeners();
      }
      
      return true; // Active
    } catch (e) {
      print('Background account check error: $e');
      return true; // Keep logged in on transient network error
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _firebaseService.signIn(email, password);
      final user = credential.user;
      if (user == null) {
        throw Exception('فشل تسجيل الدخول: المستخدم غير موجود');
      }

      final tenantId = user.uid;
      final statusMap = await _firebaseService.checkTenantStatus(tenantId);
      final bool isActive = statusMap['isActive'] ?? false;
      final String laundryName = statusMap['laundryName'] ?? 'مغسلة سجاد';
      final String laundryCode = statusMap['laundryCode'] ?? 'أ';

      if (!isActive) {
        await _firebaseService.signOut();
        throw Exception('حساب هذه المغسلة معطل حالياً. يرجى التواصل مع الإدارة.');
      }

      _currentTenant = LaundryTenant(
        id: tenantId,
        name: laundryName,
        isActive: true,
        email: email,
        laundryCode: laundryCode,
      );

      // Persist session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tenant_id', tenantId);
      await prefs.setString('laundry_name', laundryName);
      await prefs.setString('email', email);
      await prefs.setString('laundry_code', laundryCode);

      // Initialize tenant database
      _database = AppDatabase(tenantId);

      // Automatically download data from Firestore to populate the local database
      if (FirebaseService.isFirebaseInitialized) {
        final syncService = SyncService(db: _database!, tenantId: tenantId);
        await syncService.downloadData();
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      // User friendly formatting
      String errorMsg = e.toString().replaceAll('Exception:', '').trim();
      if (errorMsg.contains('invalid-credential') || errorMsg.contains('wrong-password') || errorMsg.contains('user-not-found')) {
        errorMsg = 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      } else if (errorMsg.contains('network-request-failed')) {
        errorMsg = 'فشل الاتصال بالشبكة. يرجى التأكد من اتصال الإنترنت.';
      }
      _errorMessage = errorMsg;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _firebaseService.signOut();
      
      // Clear persistence
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('tenant_id');
      await prefs.remove('laundry_name');
      await prefs.remove('email');
      await prefs.remove('laundry_code');

      // Close database reference
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
      _currentTenant = null;
      notifyListeners();
    } catch (e) {
      print('Logout error: $e');
    }
  }
}
