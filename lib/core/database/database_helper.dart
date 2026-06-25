import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

part 'database_helper.g.dart';

class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serialNumber => integer().customConstraint('UNIQUE NOT NULL')();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get phone => text().withLength(min: 5, max: 20)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class Orders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer().references(Customers, #id)();
  RealColumn get totalPrice => real()();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  IntColumn get itemCount => integer()();
  TextColumn get status => text().withLength(min: 1, max: 20)(); // 'received', 'ready', 'delivered'
  DateTimeColumn get receivedDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deliveryDate => dateTime()();
  TextColumn get notes => text().nullable()();
  BoolColumn get whatsappSentReceived => boolean().withDefault(const Constant(false))();
  BoolColumn get whatsappSentReady => boolean().withDefault(const Constant(false))();
  BoolColumn get whatsappSentDelivered => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class CarpetTypes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get pricingType => text().withLength(min: 1, max: 20)(); // 'unit' or 'meter'
  RealColumn get price => real()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class OrderItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId => integer().references(Orders, #id)();
  IntColumn get carpetTypeId => integer().references(CarpetTypes, #id)();
  TextColumn get name => text().withLength(min: 1, max: 100)(); // snapshot of name
  TextColumn get pricingType => text().withLength(min: 1, max: 20)(); // 'unit' or 'meter'
  RealColumn get unitPrice => real()(); // snapshot of price
  IntColumn get quantity => integer().nullable()(); // null if meter
  RealColumn get length => real().nullable()(); // null if unit
  RealColumn get width => real().nullable()(); // null if unit
  RealColumn get area => real().nullable()(); // null if unit (length * width)
  RealColumn get totalPrice => real()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [Customers, Orders, CarpetTypes, OrderItems])
class AppDatabase extends _$AppDatabase {
  final String tenantId;

  AppDatabase(this.tenantId) : super(_openConnection(tenantId));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(carpetTypes);
            await m.createTable(orderItems);
          }
          if (from < 3) {
            await m.addColumn(orders, orders.paidAmount);
          }
        },
      );

  // --- CUSTOMER QUERIES ---
  
  // Get all active (non-deleted) customers
  Stream<List<Customer>> watchCustomers() {
    return (select(customers)..where((t) => t.isDeleted.equals(false))).watch();
  }

  Future<List<Customer>> getAllCustomers() {
    return (select(customers)..where((t) => t.isDeleted.equals(false))).get();
  }

  // Get customer by ID
  Future<Customer?> getCustomerById(int id) {
    return (select(customers)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // Get customer by Serial Number
  Future<Customer?> getCustomerBySerial(int serial) {
    return (select(customers)
          ..where((t) => t.serialNumber.equals(serial) & t.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  // Get last customer serial number (to auto-increment it)
  Future<int?> getLastCustomerSerial() async {
    final query = select(customers)
      ..orderBy([(t) => OrderingTerm(expression: t.serialNumber, mode: OrderingMode.desc)])
      ..limit(1);
    final result = await query.getSingleOrNull();
    return result?.serialNumber;
  }

  // Insert customer
  Future<int> insertCustomer(CustomersCompanion companion) {
    return into(customers).insert(companion);
  }

  // Update customer
  Future<bool> updateCustomerData(Customer customer) {
    return update(customers).replace(customer);
  }

  // Soft delete customer
  Future<int> softDeleteCustomer(int id) {
    return (update(customers)..where((t) => t.id.equals(id))).write(
      const CustomersCompanion(
        isDeleted: Value(true),
        synced: Value(false),
      ),
    );
  }

  // Hard delete customer (after sync)
  Future<int> hardDeleteCustomer(int id) {
    return (delete(customers)..where((t) => t.id.equals(id))).go();
  }

  // --- ORDER QUERIES ---

  // Get all active (non-deleted) orders
  Stream<List<Order>> watchOrders() {
    return (select(orders)..where((t) => t.isDeleted.equals(false))).watch();
  }

  Future<List<Order>> getAllOrders() {
    return (select(orders)..where((t) => t.isDeleted.equals(false))).get();
  }

  // Watch orders for a specific customer
  Stream<List<Order>> watchCustomerOrders(int customerId) {
    return (select(orders)
          ..where((t) => t.customerId.equals(customerId) & t.isDeleted.equals(false)))
        .watch();
  }

  // Get order by ID
  Future<Order?> getOrderById(int id) {
    return (select(orders)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // Insert order
  Future<int> insertOrder(OrdersCompanion companion) {
    return into(orders).insert(companion);
  }

  // Update order
  Future<bool> updateOrderData(Order order) {
    return update(orders).replace(order);
  }

  // Soft delete order
  Future<int> softDeleteOrder(int id) {
    return (update(orders)..where((t) => t.id.equals(id))).write(
      const OrdersCompanion(
        isDeleted: Value(true),
        synced: Value(false),
      ),
    );
  }

  // Hard delete order (after sync)
  Future<int> hardDeleteOrder(int id) {
    return (delete(orders)..where((t) => t.id.equals(id))).go();
  }

  // --- CARPET TYPE QUERIES ---

  Stream<List<CarpetType>> watchCarpetTypes() {
    return (select(carpetTypes)..where((t) => t.isDeleted.equals(false))).watch();
  }

  Future<List<CarpetType>> getAllCarpetTypes() {
    return (select(carpetTypes)..where((t) => t.isDeleted.equals(false))).get();
  }

  Future<CarpetType?> getCarpetTypeById(int id) {
    return (select(carpetTypes)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertCarpetType(CarpetTypesCompanion companion) {
    return into(carpetTypes).insert(companion);
  }

  Future<bool> updateCarpetTypeData(CarpetType carpetType) {
    return update(carpetTypes).replace(carpetType);
  }

  Future<int> softDeleteCarpetType(int id) {
    return (update(carpetTypes)..where((t) => t.id.equals(id))).write(
      const CarpetTypesCompanion(
        isDeleted: Value(true),
        synced: Value(false),
      ),
    );
  }

  Future<int> hardDeleteCarpetType(int id) {
    return (delete(carpetTypes)..where((t) => t.id.equals(id))).go();
  }

  // --- ORDER ITEMS QUERIES ---

  Stream<List<OrderItem>> watchOrderItems(int orderId) {
    return (select(orderItems)
          ..where((t) => t.orderId.equals(orderId) & t.isDeleted.equals(false)))
        .watch();
  }

  Future<List<OrderItem>> getOrderItems(int orderId) {
    return (select(orderItems)
          ..where((t) => t.orderId.equals(orderId) & t.isDeleted.equals(false)))
        .get();
  }

  Future<OrderItem?> getOrderItemById(int id) {
    return (select(orderItems)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertOrderItem(OrderItemsCompanion companion) {
    return into(orderItems).insert(companion);
  }

  Future<bool> updateOrderItemData(OrderItem orderItem) {
    return update(orderItems).replace(orderItem);
  }

  Future<int> softDeleteOrderItem(int id) {
    return (update(orderItems)..where((t) => t.id.equals(id))).write(
      const OrderItemsCompanion(
        isDeleted: Value(true),
        synced: Value(false),
      ),
    );
  }

  Future<int> hardDeleteOrderItem(int id) {
    return (delete(orderItems)..where((t) => t.id.equals(id))).go();
  }

  // --- SYNC SERVICES ---

  // Get all unsynced customers (new, updated, or soft-deleted)
  Future<List<Customer>> getUnsyncedCustomers() {
    return (select(customers)..where((t) => t.synced.equals(false))).get();
  }

  // Get all unsynced orders (new, updated, or soft-deleted)
  Future<List<Order>> getUnsyncedOrders() {
    return (select(orders)..where((t) => t.synced.equals(false))).get();
  }

  // Get all unsynced carpet types
  Future<List<CarpetType>> getUnsyncedCarpetTypes() {
    return (select(carpetTypes)..where((t) => t.synced.equals(false))).get();
  }

  // Get all unsynced order items
  Future<List<OrderItem>> getUnsyncedOrderItems() {
    return (select(orderItems)..where((t) => t.synced.equals(false))).get();
  }
}

LazyDatabase _openConnection(String tenantId) {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'sajjadtech_$tenantId.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
