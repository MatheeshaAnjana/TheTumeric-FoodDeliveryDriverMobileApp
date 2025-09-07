import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _ordersCollection = 'orders';
  final String _driversCollection = 'deliveryPersonnel';

  // 1. Get all preparing orders (available for acceptance)
  Future<List<Map<String, dynamic>>> getPreparingOrders() async {
    try {
      debugPrint('Fetching preparing orders...');

      QuerySnapshot snapshot =
          await _firestore
              .collection(_ordersCollection)
              .where('status', isEqualTo: 'preparing')
              .get();

      List<Map<String, dynamic>> orders = [];
      for (var doc in snapshot.docs) {
        Map<String, dynamic> orderData = doc.data() as Map<String, dynamic>;
        orderData['id'] = doc.id; // Add document ID
        orders.add(orderData);
      }

      debugPrint('Found ${orders.length} preparing orders');
      return orders;
    } catch (e) {
      debugPrint('Error fetching preparing orders: $e');
      return [];
    }
  }

  // 2. Accept order - Update order driverId and add to driver's currentOrders
  Future<bool> acceptOrder(
    String orderId,
    String driverId,
    String personnelId,
  ) async {
    try {
      debugPrint('Accepting order $orderId for driver $driverId');

      // Use transaction to ensure both updates succeed
      return await _firestore.runTransaction((transaction) async {
        // Get order document
        DocumentReference orderRef = _firestore
            .collection(_ordersCollection)
            .doc(orderId);
        DocumentSnapshot orderDoc = await transaction.get(orderRef);

        if (!orderDoc.exists) {
          throw Exception('Order not found');
        }

        Map<String, dynamic> orderData =
            orderDoc.data() as Map<String, dynamic>;

        // Check if order is still preparing
        if (orderData['status'] != 'preparing') {
          throw Exception('Order no longer available');
        }

        // Update order with driverId and status
        transaction.update(orderRef, {
          'driverId': driverId,
          'status': 'accepted', // or 'pickup' - whatever your next status is
          'updatedAt': DateTime.now().toIso8601String(),
        });

        // Get driver document by personnelId
        QuerySnapshot driverQuery =
            await _firestore
                .collection(_driversCollection)
                .where('personnelId', isEqualTo: personnelId)
                .get();

        if (driverQuery.docs.isEmpty) {
          throw Exception('Driver not found');
        }

        DocumentReference driverRef = driverQuery.docs.first.reference;

        // Add order to driver's currentOrders array
        transaction.update(driverRef, {
          'currentOrders': FieldValue.arrayUnion([orderId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      debugPrint('Error accepting order: $e');
      return false;
    }
  }

  // 3. Update order status (pickup -> out_for_delivery -> delivered)
  Future<bool> updateOrderStatus(String orderId, String newStatus) async {
    try {
      debugPrint('Updating order $orderId to status: $newStatus');

      Map<String, dynamic> updateData = {
        'status': newStatus,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // Add specific timestamp if delivered
      if (newStatus == 'delivered') {
        updateData['deliveredAt'] = DateTime.now().toIso8601String();
      }

      await _firestore
          .collection(_ordersCollection)
          .doc(orderId)
          .update(updateData);

      // If delivered, remove from driver's currentOrders
      if (newStatus == 'delivered') {
        await _removeOrderFromDriverCurrentOrders(orderId);
      }

      debugPrint('Order status updated successfully');
      return true;
    } catch (e) {
      debugPrint('Error updating order status: $e');
      return false;
    }
  }

  // Helper: Remove order from driver's currentOrders when delivered
  Future<void> _removeOrderFromDriverCurrentOrders(String orderId) async {
    try {
      // Find driver who has this order
      QuerySnapshot driverQuery =
          await _firestore
              .collection(_driversCollection)
              .where('currentOrders', arrayContains: orderId)
              .get();

      if (driverQuery.docs.isNotEmpty) {
        DocumentReference driverRef = driverQuery.docs.first.reference;
        await driverRef.update({
          'currentOrders': FieldValue.arrayRemove([orderId]),
          'totalDeliveries': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('Removed order from driver currentOrders');
      }
    } catch (e) {
      debugPrint('Error removing order from driver: $e');
    }
  }

  // 4. Get driver's current orders
  Future<List<Map<String, dynamic>>> getDriverCurrentOrders(
    String personnelId,
  ) async {
    try {
      debugPrint('Getting current orders for driver: $personnelId');

      // Get driver document
      QuerySnapshot driverQuery =
          await _firestore
              .collection(_driversCollection)
              .where('personnelId', isEqualTo: personnelId)
              .get();

      if (driverQuery.docs.isEmpty) {
        debugPrint('Driver not found');
        return [];
      }

      Map<String, dynamic> driverData =
          driverQuery.docs.first.data() as Map<String, dynamic>;
      List<dynamic> currentOrderIds = driverData['currentOrders'] ?? [];

      if (currentOrderIds.isEmpty) {
        debugPrint('No current orders for driver');
        return [];
      }

      // Get order details for each order ID
      List<Map<String, dynamic>> orders = [];
      for (String orderId in currentOrderIds) {
        DocumentSnapshot orderDoc =
            await _firestore.collection(_ordersCollection).doc(orderId).get();
        if (orderDoc.exists) {
          Map<String, dynamic> orderData =
              orderDoc.data() as Map<String, dynamic>;
          orderData['id'] = orderDoc.id;
          orders.add(orderData);
        }
      }

      debugPrint('Found ${orders.length} current orders for driver');
      return orders;
    } catch (e) {
      debugPrint('Error getting driver current orders: $e');
      return [];
    }
  }

  // 5. Get specific order by ID
  Future<Map<String, dynamic>?> getOrderById(String orderId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection(_ordersCollection).doc(orderId).get();
      if (doc.exists) {
        Map<String, dynamic> orderData = doc.data() as Map<String, dynamic>;
        orderData['id'] = doc.id;
        return orderData;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting order by ID: $e');
      return null;
    }
  }

  // 6. Real-time stream of preparing orders
  Stream<List<Map<String, dynamic>>> getPreparingOrdersStream() {
    return _firestore
        .collection(_ordersCollection)
        .where('status', isEqualTo: 'preparing')
        .snapshots()
        .map((snapshot) {
          List<Map<String, dynamic>> orders = [];
          for (var doc in snapshot.docs) {
            Map<String, dynamic> orderData = doc.data() as Map<String, dynamic>;
            orderData['id'] = doc.id;
            orders.add(orderData);
          }
          return orders;
        });
  }

  // 7. Real-time stream of driver's current orders
  Stream<List<Map<String, dynamic>>> getDriverCurrentOrdersStream(
    String personnelId,
  ) {
    return _firestore
        .collection(_driversCollection)
        .where('personnelId', isEqualTo: personnelId)
        .snapshots()
        .asyncMap((driverSnapshot) async {
          if (driverSnapshot.docs.isEmpty) return <Map<String, dynamic>>[];

          Map<String, dynamic> driverData =
              driverSnapshot.docs.first.data() as Map<String, dynamic>;
          List<dynamic> currentOrderIds = driverData['currentOrders'] ?? [];

          if (currentOrderIds.isEmpty) return <Map<String, dynamic>>[];

          List<Map<String, dynamic>> orders = [];
          for (String orderId in currentOrderIds) {
            DocumentSnapshot orderDoc =
                await _firestore
                    .collection(_ordersCollection)
                    .doc(orderId)
                    .get();
            if (orderDoc.exists) {
              Map<String, dynamic> orderData =
                  orderDoc.data() as Map<String, dynamic>;
              orderData['id'] = orderDoc.id;
              orders.add(orderData);
            }
          }
          return orders;
        });
  }

  // 8. Create test order for testing
  Future<String?> createTestOrder() async {
    try {
      Map<String, dynamic> testOrder = {
        'createdAt': DateTime.now().toIso8601String(),
        'deliveryAddress': 'Test Address, Colombo',
        'driverId': '',
        'items': [
          {
            'foodId': 'test_food_1',
            'name': 'Test Curry',
            'price': 15.99,
            'qty': 1,
          },
        ],
        'orderId': '',
        'status': 'preparing',
        'total': 15.99,
        'updatedAt': DateTime.now().toIso8601String(),
        'userId': 'test_user',
      };

      DocumentReference docRef = await _firestore
          .collection(_ordersCollection)
          .add(testOrder);
      await docRef.update({'orderId': docRef.id});

      debugPrint('Test order created: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating test order: $e');
      return null;
    }
  }

  // 9. Get driver stats
  Future<Map<String, dynamic>> getDriverStats(String personnelId) async {
    try {
      // Get driver document
      QuerySnapshot driverQuery =
          await _firestore
              .collection(_driversCollection)
              .where('personnelId', isEqualTo: personnelId)
              .get();

      if (driverQuery.docs.isEmpty) {
        return {'totalDeliveries': 0, 'todayDeliveries': 0, 'rating': 4.5};
      }

      Map<String, dynamic> driverData =
          driverQuery.docs.first.data() as Map<String, dynamic>;

      // Get today's delivered orders count
      String todayStart = DateTime.now().toIso8601String().split('T')[0];
      QuerySnapshot todayOrders =
          await _firestore
              .collection(_ordersCollection)
              .where('driverId', isEqualTo: driverQuery.docs.first.id)
              .where('status', isEqualTo: 'delivered')
              .where('deliveredAt', isGreaterThanOrEqualTo: todayStart)
              .get();

      return {
        'totalDeliveries': driverData['totalDeliveries'] ?? 0,
        'todayDeliveries': todayOrders.docs.length,
        'rating': driverData['rating'] ?? 4.5,
        'currentOrders': (driverData['currentOrders'] ?? []).length,
      };
    } catch (e) {
      debugPrint('Error getting driver stats: $e');
      return {'totalDeliveries': 0, 'todayDeliveries': 0, 'rating': 4.5};
    }
  }

  // 10. NEW METHOD: Get driver's order history from orderHistory array
  Future<List<Map<String, dynamic>>> getDriverOrderHistory(String personnelId) async {
    try {
      debugPrint('🔍 Getting order history for driver: $personnelId');

      // Get driver document by personnelId
      QuerySnapshot driverQuery = await _firestore
          .collection(_driversCollection)
          .where('personnelId', isEqualTo: personnelId)
          .get();

      if (driverQuery.docs.isEmpty) {
        debugPrint('❌ Driver not found');
        return [];
      }

      Map<String, dynamic> driverData = driverQuery.docs.first.data() as Map<String, dynamic>;
      List<dynamic> orderHistoryIds = driverData['orderHistory'] ?? [];

      debugPrint('📋 Found ${orderHistoryIds.length} orders in history');

      if (orderHistoryIds.isEmpty) {
        debugPrint('📭 No order history for driver');
        return [];
      }

      // Get order details for each order ID in the history
      List<Map<String, dynamic>> orders = [];
      for (String orderId in orderHistoryIds) {
        try {
          DocumentSnapshot orderDoc = await _firestore
              .collection(_ordersCollection)
              .doc(orderId)
              .get();
          
          if (orderDoc.exists) {
            Map<String, dynamic> orderData = orderDoc.data() as Map<String, dynamic>;
            orderData['id'] = orderDoc.id;
            orders.add(orderData);
            debugPrint('✅ Added order: $orderId');
          } else {
            debugPrint('⚠️ Order not found: $orderId');
          }
        } catch (e) {
          debugPrint('❌ Error fetching order $orderId: $e');
        }
      }

      // Sort by deliveredAt in descending order (most recent first)
      orders.sort((a, b) {
        try {
          DateTime aDate = DateTime.parse(a['deliveredAt'] ?? a['updatedAt'] ?? '');
          DateTime bDate = DateTime.parse(b['deliveredAt'] ?? b['updatedAt'] ?? '');
          return bDate.compareTo(aDate);
        } catch (e) {
          return 0;
        }
      });

      debugPrint('📦 Successfully loaded ${orders.length} orders from history');
      return orders;
    } catch (e) {
      debugPrint('❌ Error getting driver order history: $e');
      return [];
    }
  }

  // 11. NEW METHOD: Get driver stats from orderHistory array
  Future<Map<String, dynamic>> getDriverStatsFromHistory(String personnelId) async {
    try {
      debugPrint('📊 Getting driver stats from history for: $personnelId');

      // Get driver document
      QuerySnapshot driverQuery = await _firestore
          .collection(_driversCollection)
          .where('personnelId', isEqualTo: personnelId)
          .get();

      if (driverQuery.docs.isEmpty) {
        return {'totalDeliveries': 0, 'todayDeliveries': 0, 'rating': 4.5};
      }

      Map<String, dynamic> driverData = driverQuery.docs.first.data() as Map<String, dynamic>;
      
      // Get totalDeliveries from driver record (not orderHistory length)
      int totalDeliveries = driverData['totalDeliveries'] ?? 0;

      // Count today's deliveries from orderHistory
      List<dynamic> orderHistoryIds = driverData['orderHistory'] ?? [];
      int todayDeliveries = 0;
      String todayStart = DateTime.now().toIso8601String().split('T')[0];

      for (String orderId in orderHistoryIds) {
        try {
          DocumentSnapshot orderDoc = await _firestore
              .collection(_ordersCollection)
              .doc(orderId)
              .get();
          
          if (orderDoc.exists) {
            Map<String, dynamic> orderData = orderDoc.data() as Map<String, dynamic>;
            String? deliveredAt = orderData['deliveredAt'];
            
            if (deliveredAt != null && deliveredAt.startsWith(todayStart)) {
              todayDeliveries++;
            }
          }
        } catch (e) {
          debugPrint('Error checking order $orderId for today count: $e');
        }
      }

      return {
        'totalDeliveries': totalDeliveries,
        'todayDeliveries': todayDeliveries,
        'rating': driverData['rating'] ?? 4.5,
        'currentOrders': (driverData['currentOrders'] ?? []).length,
      };
    } catch (e) {
      debugPrint('Error getting driver stats from history: $e');
      return {'totalDeliveries': 0, 'todayDeliveries': 0, 'rating': 4.5};
    }
  }

  // 12. NEW METHOD: Get user details by userId
  Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    try {
      debugPrint('👤 Getting user details for userId: $userId');
      
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        userData['id'] = userDoc.id;
        debugPrint('✅ Found user: ${userData['name'] ?? userData['full_name'] ?? 'Unknown'}');
        return userData;
      } else {
        debugPrint('❌ User not found: $userId');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error getting user details: $e');
      return null;
    }
  }

  // 13. NEW METHOD: Get driver order history with customer details
  Future<List<Map<String, dynamic>>> getDriverOrderHistoryWithCustomers(String personnelId) async {
    try {
      debugPrint('🔍 Getting order history with customer details for: $personnelId');

      // Get driver document by personnelId
      QuerySnapshot driverQuery = await _firestore
          .collection(_driversCollection)
          .where('personnelId', isEqualTo: personnelId)
          .get();

      if (driverQuery.docs.isEmpty) {
        debugPrint('❌ Driver not found');
        return [];
      }

      Map<String, dynamic> driverData = driverQuery.docs.first.data() as Map<String, dynamic>;
      List<dynamic> orderHistoryIds = driverData['orderHistory'] ?? [];

      debugPrint('📋 Found ${orderHistoryIds.length} orders in history');

      if (orderHistoryIds.isEmpty) {
        debugPrint('📭 No order history for driver');
        return [];
      }

      // Get order details with customer information
      List<Map<String, dynamic>> ordersWithCustomers = [];
      for (String orderId in orderHistoryIds) {
        try {
          DocumentSnapshot orderDoc = await _firestore
              .collection(_ordersCollection)
              .doc(orderId)
              .get();
          
          if (orderDoc.exists) {
            Map<String, dynamic> orderData = orderDoc.data() as Map<String, dynamic>;
            orderData['id'] = orderDoc.id;

            // Get customer details if userId exists
            String? userId = orderData['userId'];
            if (userId != null && userId.isNotEmpty) {
              Map<String, dynamic>? customerData = await getUserDetails(userId);
              if (customerData != null) {
                orderData['customer'] = customerData;
              }
            }
            
            ordersWithCustomers.add(orderData);
            debugPrint('✅ Added order with customer: $orderId');
          } else {
            debugPrint('⚠️ Order not found: $orderId');
          }
        } catch (e) {
          debugPrint('❌ Error fetching order $orderId: $e');
        }
      }

      // Sort by deliveredAt in descending order (most recent first)
      ordersWithCustomers.sort((a, b) {
        try {
          DateTime aDate = DateTime.parse(a['deliveredAt'] ?? a['updatedAt'] ?? '');
          DateTime bDate = DateTime.parse(b['deliveredAt'] ?? b['updatedAt'] ?? '');
          return bDate.compareTo(aDate);
        } catch (e) {
          return 0;
        }
      });

      debugPrint('📦 Successfully loaded ${ordersWithCustomers.length} orders with customer details');
      return ordersWithCustomers;
    } catch (e) {
      debugPrint('❌ Error getting driver order history with customers: $e');
      return [];
    }
  }
}