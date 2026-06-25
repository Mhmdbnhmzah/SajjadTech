import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import '../database/database_helper.dart';
import 'firebase_service.dart';

class SyncService {
  final AppDatabase db;
  final String tenantId;

  FirebaseFirestore? get _firestore => FirebaseService.isFirebaseInitialized ? FirebaseFirestore.instance : null;

  SyncService({required this.db, required this.tenantId});

  // Sync all data: 2-way sync (Pull from Firestore, then Push local changes)
  Future<void> syncData() async {
    if (!FirebaseService.isFirebaseInitialized) {
      throw Exception('المزامنة غير متاحة في الوضع التجريبي. يرجى تهيئة الفايربيس أولاً.');
    }

    // Verify tenant status before syncing to block disabled accounts
    final tenantDoc = await _firestore!.collection('tenants').doc(tenantId).get();
    if (tenantDoc.exists) {
      final data = tenantDoc.data()!;
      final bool isActive = data['isActive'] ?? false;
      if (!isActive) {
        throw Exception('ACCOUNT_DISABLED');
      }
    } else {
      throw Exception('ACCOUNT_NOT_FOUND');
    }

    // 1. Pull changes from cloud first
    await downloadData();
    
    // 2. Push unsynced local changes to cloud
    await _syncCustomers();
    await _syncCarpetTypes();
    await _syncOrders();
    await _syncOrderItems();
  }

  // Pull / Restore data from Cloud Firestore to local SQLite
  Future<void> downloadData() async {
    if (!FirebaseService.isFirebaseInitialized) return;
    await _downloadCustomers();
    await _downloadCarpetTypes();
    await _downloadOrders();
    await _downloadOrderItems();
  }

  Future<void> _downloadCustomers() async {
    try {
      final snapshot = await _firestore!
          .collection('tenants')
          .doc(tenantId)
          .collection('customers')
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final id = data['id'] as int;
        
        // Skip overwriting local records if they have unsynced changes
        final existing = await db.getCustomerById(id);
        if (existing != null && !existing.synced) {
          continue;
        }
        
        final customerCompanion = CustomersCompanion(
          id: Value(id),
          serialNumber: Value(data['serialNumber'] as int),
          name: Value(data['name'] as String),
          phone: Value(data['phone'] as String),
          createdAt: Value(DateTime.parse(data['createdAt'] as String)),
          updatedAt: Value(DateTime.parse(data['updatedAt'] as String)),
          synced: const Value(true),
          isDeleted: const Value(false),
        );

        // Insert or replace customer locally
        await db.into(db.customers).insert(
          customerCompanion,
          mode: InsertMode.insertOrReplace,
        );
      }
    } catch (e) {
      print('Download customers error: $e');
    }
  }

  Future<void> _downloadOrders() async {
    try {
      final snapshot = await _firestore!
          .collection('tenants')
          .doc(tenantId)
          .collection('orders')
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final id = data['id'] as int;

        // Skip overwriting local records if they have unsynced changes
        final existing = await db.getOrderById(id);
        if (existing != null && !existing.synced) {
          continue;
        }

        final orderCompanion = OrdersCompanion(
          id: Value(id),
          customerId: Value(data['customerId'] as int),
          totalPrice: Value((data['totalPrice'] as num).toDouble()),
          paidAmount: Value((data['paidAmount'] as num? ?? 0.0).toDouble()),
          itemCount: Value(data['itemCount'] as int),
          status: Value(data['status'] as String),
          receivedDate: Value(DateTime.parse(data['receivedDate'] as String)),
          deliveryDate: Value(DateTime.parse(data['deliveryDate'] as String)),
          notes: Value(data['notes'] as String?),
          whatsappSentReceived: Value(data['whatsappSentReceived'] as bool? ?? false),
          whatsappSentReady: Value(data['whatsappSentReady'] as bool? ?? false),
          whatsappSentDelivered: Value(data['whatsappSentDelivered'] as bool? ?? false),
          createdAt: Value(DateTime.parse(data['createdAt'] as String)),
          updatedAt: Value(DateTime.parse(data['updatedAt'] as String)),
          synced: const Value(true),
          isDeleted: const Value(false),
        );

        // Insert or replace order locally
        await db.into(db.orders).insert(
          orderCompanion,
          mode: InsertMode.insertOrReplace,
        );
      }
    } catch (e) {
      print('Download orders error: $e');
    }
  }

  Future<void> _syncCustomers() async {
    try {
      final unsynced = await db.getUnsyncedCustomers();
      for (final customer in unsynced) {
        final docRef = _firestore!
            .collection('tenants')
            .doc(tenantId)
            .collection('customers')
            .doc(customer.id.toString());

        if (customer.isDeleted) {
          // Delete from Firestore
          await docRef.delete();
          // Hard delete from SQLite locally
          await db.hardDeleteCustomer(customer.id);
        } else {
          // Upload / Update in Firestore
          await docRef.set({
            'id': customer.id,
            'serialNumber': customer.serialNumber,
            'name': customer.name,
            'phone': customer.phone,
            'createdAt': customer.createdAt.toIso8601String(),
            'updatedAt': customer.updatedAt.toIso8601String(),
          });
          // Update local status to synced = true
          await db.updateCustomerData(customer.copyWith(synced: true));
        }
      }
    } catch (e) {
      print('Sync customers error: $e');
    }
  }

  Future<void> _syncOrders() async {
    try {
      final unsynced = await db.getUnsyncedOrders();
      for (final order in unsynced) {
        final docRef = _firestore!
            .collection('tenants')
            .doc(tenantId)
            .collection('orders')
            .doc(order.id.toString());

        if (order.isDeleted) {
          // Delete from Firestore
          await docRef.delete();
          // Hard delete from SQLite locally
          await db.hardDeleteOrder(order.id);
        } else {
          // Upload / Update in Firestore
          await docRef.set({
            'id': order.id,
            'customerId': order.customerId,
            'totalPrice': order.totalPrice,
            'paidAmount': order.paidAmount,
            'itemCount': order.itemCount,
            'status': order.status,
            'receivedDate': order.receivedDate.toIso8601String(),
            'deliveryDate': order.deliveryDate.toIso8601String(),
            'notes': order.notes,
            'whatsappSentReceived': order.whatsappSentReceived,
            'whatsappSentReady': order.whatsappSentReady,
            'whatsappSentDelivered': order.whatsappSentDelivered,
            'createdAt': order.createdAt.toIso8601String(),
            'updatedAt': order.updatedAt.toIso8601String(),
          });
          // Update local status to synced = true
          await db.updateOrderData(order.copyWith(synced: true));
        }
      }
    } catch (e) {
      print('Sync orders error: $e');
    }
  }

  Future<void> _downloadCarpetTypes() async {
    try {
      final snapshot = await _firestore!
          .collection('tenants')
          .doc(tenantId)
          .collection('carpet_types')
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final id = data['id'] as int;

        final existing = await db.getCarpetTypeById(id);
        if (existing != null && !existing.synced) {
          continue;
        }

        final carpetTypeCompanion = CarpetTypesCompanion(
          id: Value(id),
          name: Value(data['name'] as String),
          pricingType: Value(data['pricingType'] as String),
          price: Value((data['price'] as num).toDouble()),
          createdAt: Value(DateTime.parse(data['createdAt'] as String)),
          updatedAt: Value(DateTime.parse(data['updatedAt'] as String)),
          synced: const Value(true),
          isDeleted: const Value(false),
        );

        await db.into(db.carpetTypes).insert(
          carpetTypeCompanion,
          mode: InsertMode.insertOrReplace,
        );
      }
    } catch (e) {
      print('Download carpet types error: $e');
    }
  }

  Future<void> _downloadOrderItems() async {
    try {
      final snapshot = await _firestore!
          .collection('tenants')
          .doc(tenantId)
          .collection('order_items')
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final id = data['id'] as int;

        final existing = await db.getOrderItemById(id);
        if (existing != null && !existing.synced) {
          continue;
        }

        final orderItemCompanion = OrderItemsCompanion(
          id: Value(id),
          orderId: Value(data['orderId'] as int),
          carpetTypeId: Value(data['carpetTypeId'] as int),
          name: Value(data['name'] as String),
          pricingType: Value(data['pricingType'] as String),
          unitPrice: Value((data['unitPrice'] as num).toDouble()),
          quantity: Value(data['quantity'] as int?),
          length: Value(data['length'] != null ? (data['length'] as num).toDouble() : null),
          width: Value(data['width'] != null ? (data['width'] as num).toDouble() : null),
          area: Value(data['area'] != null ? (data['area'] as num).toDouble() : null),
          totalPrice: Value((data['totalPrice'] as num).toDouble()),
          createdAt: Value(DateTime.parse(data['createdAt'] as String)),
          updatedAt: Value(DateTime.parse(data['updatedAt'] as String)),
          synced: const Value(true),
          isDeleted: const Value(false),
        );

        await db.into(db.orderItems).insert(
          orderItemCompanion,
          mode: InsertMode.insertOrReplace,
        );
      }
    } catch (e) {
      print('Download order items error: $e');
    }
  }

  Future<void> _syncCarpetTypes() async {
    try {
      final unsynced = await db.getUnsyncedCarpetTypes();
      for (final type in unsynced) {
        final docRef = _firestore!
            .collection('tenants')
            .doc(tenantId)
            .collection('carpet_types')
            .doc(type.id.toString());

        if (type.isDeleted) {
          await docRef.delete();
          await db.hardDeleteCarpetType(type.id);
        } else {
          await docRef.set({
            'id': type.id,
            'name': type.name,
            'pricingType': type.pricingType,
            'price': type.price,
            'createdAt': type.createdAt.toIso8601String(),
            'updatedAt': type.updatedAt.toIso8601String(),
          });
          await db.updateCarpetTypeData(type.copyWith(synced: true));
        }
      }
    } catch (e) {
      print('Sync carpet types error: $e');
    }
  }

  Future<void> _syncOrderItems() async {
    try {
      final unsynced = await db.getUnsyncedOrderItems();
      for (final item in unsynced) {
        final docRef = _firestore!
            .collection('tenants')
            .doc(tenantId)
            .collection('order_items')
            .doc(item.id.toString());

        if (item.isDeleted) {
          await docRef.delete();
          await db.hardDeleteOrderItem(item.id);
        } else {
          await docRef.set({
            'id': item.id,
            'orderId': item.orderId,
            'carpetTypeId': item.carpetTypeId,
            'name': item.name,
            'pricingType': item.pricingType,
            'unitPrice': item.unitPrice,
            'quantity': item.quantity,
            'length': item.length,
            'width': item.width,
            'area': item.area,
            'totalPrice': item.totalPrice,
            'createdAt': item.createdAt.toIso8601String(),
            'updatedAt': item.updatedAt.toIso8601String(),
          });
          await db.updateOrderItemData(item.copyWith(synced: true));
        }
      }
    } catch (e) {
      print('Sync order items error: $e');
    }
  }
}
