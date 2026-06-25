import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/database_helper.dart';
import '../../../core/services/whatsapp_service.dart';

class OrderItemInput {
  final int carpetTypeId;
  final String name;
  final String pricingType;
  final double unitPrice;
  final int? quantity;
  final double? length;
  final double? width;
  final double? area;
  final double totalPrice;

  OrderItemInput({
    required this.carpetTypeId,
    required this.name,
    required this.pricingType,
    required this.unitPrice,
    this.quantity,
    this.length,
    this.width,
    this.area,
    required this.totalPrice,
  });
}

class OrderViewModel extends ChangeNotifier {
  final AppDatabase? db;
  final String laundryName;

  List<Order> _orders = [];
  bool _isLoading = false;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;

  OrderViewModel({required this.db, required this.laundryName}) {
    _loadOrders();
  }

  void _loadOrders() {
    if (db == null) return;

    _isLoading = true;
    notifyListeners();

    db!.watchOrders().listen((list) {
      _orders = list;
      _isLoading = false;
      notifyListeners();
    });
  }

  // Create new order
  // Create new order
  Future<Order?> createOrder({
    required int customerId,
    required double totalPrice,
    double paidAmount = 0.0,
    required int itemCount,
    required DateTime deliveryDate,
    String? notes,
    List<OrderItemInput> items = const [],
  }) async {
    if (db == null) return null;

    try {
      _isLoading = true;
      notifyListeners();

      final now = DateTime.now();
      
      final orderId = await db!.transaction(() async {
        final companion = OrdersCompanion(
          customerId: drift.Value(customerId),
          totalPrice: drift.Value(totalPrice),
          paidAmount: drift.Value(paidAmount),
          itemCount: drift.Value(itemCount),
          status: drift.Value('received'),
          receivedDate: drift.Value(now),
          deliveryDate: drift.Value(deliveryDate),
          notes: drift.Value(notes),
          whatsappSentReceived: drift.Value(false),
          whatsappSentReady: drift.Value(false),
          whatsappSentDelivered: drift.Value(false),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
          synced: drift.Value(false),
          isDeleted: drift.Value(false),
        );

        final id = await db!.insertOrder(companion);

        // Insert each order item
        for (final item in items) {
          final itemCompanion = OrderItemsCompanion(
            orderId: drift.Value(id),
            carpetTypeId: drift.Value(item.carpetTypeId),
            name: drift.Value(item.name),
            pricingType: drift.Value(item.pricingType),
            unitPrice: drift.Value(item.unitPrice),
            quantity: drift.Value(item.quantity),
            length: drift.Value(item.length),
            width: drift.Value(item.width),
            area: drift.Value(item.area),
            totalPrice: drift.Value(item.totalPrice),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
            synced: drift.Value(false),
            isDeleted: drift.Value(false),
          );
          await db!.insertOrderItem(itemCompanion);
        }

        return id;
      });

      _isLoading = false;
      notifyListeners();

      return Order(
        id: orderId,
        customerId: customerId,
        totalPrice: totalPrice,
        paidAmount: paidAmount,
        itemCount: itemCount,
        status: 'received',
        receivedDate: now,
        deliveryDate: deliveryDate,
        notes: notes,
        whatsappSentReceived: false,
        whatsappSentReady: false,
        whatsappSentDelivered: false,
        createdAt: now,
        updatedAt: now,
        synced: false,
        isDeleted: false,
      );
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Create order error: $e');
      return null;
    }
  }

  // Update order status (received -> ready -> delivered)
  Future<bool> updateOrderStatus(Order order, String newStatus) async {
    if (db == null) return false;

    try {
      final updatedOrder = order.copyWith(
        status: newStatus,
        paidAmount: newStatus == 'delivered' ? order.totalPrice : order.paidAmount,
        updatedAt: DateTime.now(),
        synced: false,
      );
      await db!.updateOrderData(updatedOrder);
      notifyListeners();
      return true;
    } catch (e) {
      print('Update order status error: $e');
      return false;
    }
  }

  // Update order paid amount
  Future<bool> updateOrderPaidAmount(Order order, double newPaidAmount) async {
    if (db == null) return false;

    try {
      final updatedOrder = order.copyWith(
        paidAmount: newPaidAmount,
        updatedAt: DateTime.now(),
        synced: false,
      );
      await db!.updateOrderData(updatedOrder);
      notifyListeners();
      return true;
    } catch (e) {
      print('Update order paid amount error: $e');
      return false;
    }
  }

  // Soft delete order
  Future<bool> deleteOrder(int id) async {
    if (db == null) return false;

    try {
      await db!.softDeleteOrder(id);
      return true;
    } catch (e) {
      print('Delete order error: $e');
      return false;
    }
  }

  // Send WhatsApp message for received stage
  Future<void> sendWhatsAppReceived(Order order, Customer customer) async {
    if (db == null) return;
    final latestOrder = await db!.getOrderById(order.id);
    if (latestOrder == null) return;

    final msg = WhatsappService.getOrderReceivedMessage(
      customerName: customer.name,
      itemCount: latestOrder.itemCount,
      totalPrice: latestOrder.totalPrice,
      paidAmount: latestOrder.paidAmount,
      deliveryDate: latestOrder.deliveryDate,
      laundryName: laundryName,
    );

    final success = await WhatsappService.sendWhatsAppMessage(
      phone: customer.phone,
      message: msg,
    );

    if (success) {
      await db!.updateOrderData(latestOrder.copyWith(
        whatsappSentReceived: true,
        synced: false,
      ));
    }
  }

  // Send WhatsApp message for ready stage
  Future<void> sendWhatsAppReady(Order order, Customer customer) async {
    if (db == null) return;
    final latestOrder = await db!.getOrderById(order.id);
    if (latestOrder == null) return;

    final msg = WhatsappService.getOrderReadyMessage(
      customerName: customer.name,
      totalPrice: latestOrder.totalPrice,
      paidAmount: latestOrder.paidAmount,
      laundryName: laundryName,
    );

    final success = await WhatsappService.sendWhatsAppMessage(
      phone: customer.phone,
      message: msg,
    );

    if (success) {
      await db!.updateOrderData(latestOrder.copyWith(
        whatsappSentReady: true,
        synced: false,
      ));
    }
  }

  // Send WhatsApp message for delivered stage
  Future<void> sendWhatsAppDelivered(Order order, Customer customer) async {
    if (db == null) return;
    final latestOrder = await db!.getOrderById(order.id);
    if (latestOrder == null) return;

    final msg = WhatsappService.getOrderDeliveredMessage(
      customerName: customer.name,
      totalPrice: latestOrder.totalPrice,
      laundryName: laundryName,
    );

    final success = await WhatsappService.sendWhatsAppMessage(
      phone: customer.phone,
      message: msg,
    );

    if (success) {
      await db!.updateOrderData(latestOrder.copyWith(
        whatsappSentDelivered: true,
        synced: false,
      ));
    }
  }
}
