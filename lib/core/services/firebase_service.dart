import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseService {
  static bool isFirebaseInitialized = false;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      isFirebaseInitialized = true;
      print('Firebase initialized successfully.');
    } catch (e) {
      print('Firebase initialization failed: $e. Running in Demo / Offline Mode.');
      isFirebaseInitialized = false;
    }
  }

  FirebaseAuth? get _auth => isFirebaseInitialized ? FirebaseAuth.instance : null;
  FirebaseFirestore? get _firestore => isFirebaseInitialized ? FirebaseFirestore.instance : null;

  // Sign in tenant using email/password
  Future<dynamic> signIn(String email, String password) async {
    if (!isFirebaseInitialized) {
      // Mock successful login in demo mode
      if (email.isEmpty || password.length < 6) {
        throw Exception('البريد الإلكتروني فارغ أو كلمة المرور قصيرة جداً (6 أحرف على الأقل)');
      }
      return MockUserCredential(email);
    }
    return await _auth!.signInWithEmailAndPassword(email: email, password: password);
  }

  // Sign out
  Future<void> signOut() async {
    if (!isFirebaseInitialized) return;
    await _auth!.signOut();
  }

  // Get current user ID
  String? get currentUserId {
    if (!isFirebaseInitialized) return 'demo_tenant_id';
    return _auth!.currentUser?.uid;
  }

  // Check if a tenant's account is active and retrieve the laundry name
  Future<Map<String, dynamic>> checkTenantStatus(String tenantId) async {
    if (!isFirebaseInitialized) {
      return {
        'isActive': true,
        'laundryName': 'مغسلة سجاد تجريبية (Demo Mode)',
        'laundryCode': 'أ',
        'activeDeviceId': null,
      };
    }
    try {
      final doc = await _firestore!.collection('tenants').doc(tenantId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final bool isActive = data['isActive'] ?? false;
        final String laundryName = data['laundryName'] ?? 'مغسلة سجاد';
        final String laundryCode = data['laundryCode'] ?? 'أ';
        final String? activeDeviceId = data['activeDeviceId'];
        return {
          'isActive': isActive,
          'laundryName': laundryName,
          'laundryCode': laundryCode,
          'activeDeviceId': activeDeviceId,
        };
      }
      return {
        'isActive': false,
        'laundryName': 'مغسلة غير مسجلة',
        'laundryCode': 'أ',
        'activeDeviceId': null,
      };
    } catch (e) {
      rethrow;
    }
  }

  // Update a tenant's active device ID in Firestore
  Future<void> updateActiveDeviceId(String tenantId, String? deviceId) async {
    if (!isFirebaseInitialized) return;
    try {
      await _firestore!.collection('tenants').doc(tenantId).update({
        'activeDeviceId': deviceId,
      });
    } catch (e) {
      print('Update active device ID error: $e');
      rethrow;
    }
  }
}

class MockUserCredential {
  final MockUser? user;
  MockUserCredential(String email) : user = MockUser(email);
}

class MockUser {
  final String uid = 'demo_tenant_id';
  final String email;
  MockUser(this.email);
}
