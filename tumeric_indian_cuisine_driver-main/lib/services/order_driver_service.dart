// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/foundation.dart';
// import 'package:tumeric_indian_cuisine_driver/pages/models/order_model.dart';
// import 'package:tumeric_indian_cuisine_driver/pages/services/order_services.dart';


// class OrderDriverService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final OrderService _orderService = OrderService();
//   final String _ordersCollection = 'orders';

//   // Accept an order (driver picks up an available order)
//   Future<bool> acceptOrder(String orderId, String driverId) async {
//     try {
//       debugPrint('🔄 Driver $driverId accepting order $orderId');

//       if (orderId.isEmpty || driverId.isEmpty) {
//         debugPrint('❌ Invalid order ID or driver ID');
//         return false;
//       }

//       // Use the existing OrderService method to assign order to driver
//       bool success = await _orderService.assignOrderToDriver(
//         orderId,
//         driverId,
//         'assigned_to_driver', // Status when driver accepts
//       );

//       if (success) {
//         debugPrint('✅ Order $orderId successfully accepted by driver $driverId');
//       } else {
//         debugPrint('❌ Failed to accept order $orderId');
//       }

//       return success;
//     } catch (e) {
//       debugPrint('❌ Error accepting order: $e');
//       return false;
//     }
//   }

//   // Update order status (picked up, out for delivery, delivered)
//   Future<bool> updateOrderStatus(String orderId, String newStatus) async {
//     try {
//       debugPrint('🔄 Updating order $orderId to status: $newStatus');

//       if (orderId.isEmpty || newStatus.isEmpty) {
//         debugPrint('❌ Invalid order ID or status');
//         return false;
//       }

//       // Use the existing OrderService method
//       bool success = await _orderService.updateOrderStatus(orderId, newStatus);

//       if (success) {
//         debugPrint('✅ Order $orderId status updated to: $newStatus');
//       } else {
//         debugPrint('❌ Failed to update order $orderId status');
//       }

//       return success;
//     } catch (e) {
//       debugPrint('❌ Error updating order status: $e');
//       return false;
//     }
//   }

//   // Get driver's current active order
//   Future<OrderModel?> getDriverActiveOrder(String driverId) async {
//     try {
//       debugPrint('🔄 Fetching active order for driver: $driverId');

//       if (driverId.isEmpty) {
//         debugPrint('❌ Driver ID is empty');
//         return null;
//       }

//       // Get active orders for this driver
//       List<OrderModel> activeOrders = await _orderService.getDriverActiveOrders(driverId);
      
//       if (activeOrders.isNotEmpty) {
//         // Return the first active order (should only be one at a time)
//         debugPrint('✅ Found active order for driver: ${activeOrders.first.orderId}');
//         return activeOrders.first;
//       }

//       debugPrint('ℹ️ No active orders found for driver: $driverId');
//       return null;
//     } catch (e) {
//       debugPrint('❌ Error fetching driver active order: $e');
//       return null;
//     }
//   }

//   // Get stream of available orders (orders ready for pickup)
//   Stream<List<OrderModel>> getAvailableOrdersStream() {
//     try {
//       debugPrint('🔄 Setting up available orders stream');

//       // Use the existing OrderService stream for preparing orders
//       return _orderService.getPreparingOrdersStream();
//     } catch (e) {
//       debugPrint('❌ Error setting up available orders stream: $e');
//       return Stream.value([]);
//     }
//   }

//   // Get stream of driver's active order
//   Stream<OrderModel?> getDriverActiveOrderStream(String driverId) {
//     try {
//       debugPrint('🔄 Setting up driver active order stream for: $driverId');

//       if (driverId.isEmpty) {
//         debugPrint('❌ Driver ID is empty for stream');
//         return Stream.value(null);
//       }

//       // Transform the list stream to single order stream
//       return _orderService.getDriverActiveOrdersStream(driverId).map((orders) {
//         if (orders.isNotEmpty) {
//           debugPrint('📊 Active order stream update: ${orders.first.orderId}');
//           return orders.first;
//         }
//         debugPrint('📊 No active orders in stream');
//         return null;
//       });
//     } catch (e) {
//       debugPrint('❌ Error setting up driver active order stream: $e');
//       return Stream.value(null);
//     }
//   }

//   // Get driver statistics
//   Future<Map<String, dynamic>> getDriverStatistics(String driverId) async {
//     try {
//       debugPrint('🔄 Fetching driver statistics for: $driverId');

//       if (driverId.isEmpty) {
//         debugPrint('❌ Driver ID is empty');
//         return _getEmptyStats();
//       }

//       // Use the existing OrderService method
//       Map<String, dynamic> stats = await _orderService.getDriverStats(driverId);
      
//       // Transform the data to match what the UI expects
//       return {
//         'todayDeliveries': stats['todayDeliveries'] ?? 0,
//         'todayEarnings': _calculateTodayEarnings(stats),
//         'totalDeliveries': stats['totalDeliveries'] ?? 0,
//         'weekDeliveries': stats['weekDeliveries'] ?? 0,
//         'rating': stats['rating'] ?? 4.5,
//         'totalEarnings': stats['totalEarnings'] ?? 0.0,
//       };
//     } catch (e) {
//       debugPrint('❌ Error fetching driver statistics: $e');
//       return _getEmptyStats();
//     }
//   }

//   // Calculate today's earnings from delivery count
//   double _calculateTodayEarnings(Map<String, dynamic> stats) {
//     final todayDeliveries = stats['todayDeliveries'] ?? 0;
//     final averageOrderValue = 25.0; // Estimate
//     final driverCommission = 0.15; // 15%
//     final baseDeliveryFee = 5.0;
    
//     return (todayDeliveries * ((averageOrderValue * driverCommission) + baseDeliveryFee));
//   }

//   Map<String, dynamic> _getEmptyStats() {
//     return {
//       'todayDeliveries': 0,
//       'todayEarnings': 0.0,
//       'totalDeliveries': 0,
//       'weekDeliveries': 0,
//       'rating': 4.5,
//       'totalEarnings': 0.0,
//     };
//   }

//   // Release an order back to available (if driver can't complete)
//   Future<bool> releaseOrder(String orderId) async {
//     try {
//       debugPrint('🔄 Releasing order $orderId back to available');

//       return await _orderService.releaseOrderFromDriver(orderId);
//     } catch (e) {
//       debugPrint('❌ Error releasing order: $e');
//       return false;
//     }
//   }

//   // Get order details by ID
//   Future<OrderModel?> getOrderById(String orderId) async {
//     try {
//       return await _orderService.getOrderById(orderId);
//     } catch (e) {
//       debugPrint('❌ Error fetching order by ID: $e');
//       return null;
//     }
//   }

//   // Get driver's delivery history
//   Future<List<OrderModel>> getDriverDeliveryHistory(String driverId, {int limit = 20}) async {
//     try {
//       debugPrint('🔄 Fetching delivery history for driver: $driverId');

//       if (driverId.isEmpty) {
//         debugPrint('❌ Driver ID is empty');
//         return [];
//       }

//       QuerySnapshot querySnapshot = await _firestore
//           .collection(_ordersCollection)
//           .where('driverId', isEqualTo: driverId)
//           .where('status', isEqualTo: 'delivered')
//           .orderBy('deliveredAt', descending: true)
//           .limit(limit)
//           .get();

//       List<OrderModel> orders = [];
//       for (var doc in querySnapshot.docs) {
//         try {
//           var data = doc.data() as Map<String, dynamic>;
//           OrderModel order = OrderModel.fromJson(data, doc.id);
//           orders.add(order);
//         } catch (e) {
//           debugPrint('❌ Error parsing delivery history order ${doc.id}: $e');
//         }
//       }

//       debugPrint('✅ Fetched ${orders.length} delivery history orders');
//       return orders;
//     } catch (e) {
//       debugPrint('❌ Error fetching delivery history: $e');
//       return [];
//     }
//   }

//   // Test connection and data availability
//   Future<Map<String, dynamic>> testDriverConnection(String driverId) async {
//     try {
//       debugPrint('🔧 Testing driver connection for: $driverId');

//       // Test 1: Basic Firestore connection
//       final connectionTest = await _orderService.testFirestoreConnection();
      
//       // Test 2: Check available orders
//       final availableOrders = await _orderService.getOrdersByStatus('preparing');
      
//       // Test 3: Check driver's active orders
//       final activeOrders = await _orderService.getDriverActiveOrders(driverId);
      
//       // Test 4: Check driver stats
//       final driverStats = await _orderService.getDriverStats(driverId);

//       return {
//         'connectionTest': connectionTest,
//         'availableOrdersCount': availableOrders.length,
//         'activeOrdersCount': activeOrders.length,
//         'driverStats': driverStats,
//         'testSuccessful': true,
//       };
//     } catch (e) {
//       debugPrint('❌ Driver connection test failed: $e');
//       return {
//         'testSuccessful': false,
//         'error': e.toString(),
//       };
//     }
//   }

//   // Create test data for development
//   Future<void> createTestOrdersForDevelopment() async {
//     try {
//       debugPrint('🔧 Creating test orders for development');
      
//       List<String> createdOrders = await _orderService.createMultipleTestOrders(count: 3);
      
//       if (createdOrders.isNotEmpty) {
//         debugPrint('✅ Created ${createdOrders.length} test orders');
//         debugPrint('Test order IDs: $createdOrders');
//       }
//     } catch (e) {
//       debugPrint('❌ Error creating test orders: $e');
//     }
//   }


// }