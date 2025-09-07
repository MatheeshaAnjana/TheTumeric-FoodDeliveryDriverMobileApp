import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tumeric_indian_cuisine_driver/pages/navigate_pages/profile_page.dart';
import 'package:tumeric_indian_cuisine_driver/pages/order_details_page.dart';
import 'package:tumeric_indian_cuisine_driver/pages/order_history_page.dart';

// Updated OrderModel to match your actual Firestore structure
class OrderModel {
  final String orderId;
  final String status;
  final String deliveryAddress;
  final double orderTotal; // Maps to 'total' field
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deliveredAt;
  final String? customerName; // Will be null since you don't have this field
  final String? customerPhone; // Will be null since you don't have this field
  final String? driverId;
  final String? userId;
  final List<OrderItem>? items;
  final bool? isTestOrder;

  OrderModel({
    required this.orderId,
    required this.status,
    required this.deliveryAddress,
    required this.orderTotal,
    required this.createdAt,
    this.updatedAt,
    this.deliveredAt,
    this.customerName,
    this.customerPhone,
    this.driverId,
    this.userId,
    this.items,
    this.isTestOrder,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json, String docId) {
    try {
      debugPrint('🔍 Parsing order: $docId with data: ${json.toString()}');

      // Helper function to safely parse string timestamps from your format
      DateTime parseStringTimestamp(dynamic timestamp) {
        if (timestamp == null) return DateTime.now();

        if (timestamp is Timestamp) {
          return timestamp.toDate();
        }

        if (timestamp is String) {
          try {
            // Handle your string format: "2025-08-31T17:30:42.416165" or "2025-08-31T14:19:53.816Z"
            if (timestamp.endsWith('Z')) {
              return DateTime.parse(timestamp);
            } else {
              // Add Z if not present to make it proper ISO format
              return DateTime.parse(
                timestamp.endsWith('Z') ? timestamp : timestamp + 'Z',
              );
            }
          } catch (e) {
            debugPrint(
              '⚠️ Could not parse timestamp string: $timestamp, error: $e',
            );
            return DateTime.now();
          }
        }

        if (timestamp is DateTime) {
          return timestamp;
        }

        debugPrint('⚠️ Unknown timestamp type: ${timestamp.runtimeType}');
        return DateTime.now();
      }

      // Parse order total from 'total' field
      double parseOrderTotal(Map<String, dynamic> data) {
        final value = data['total'];
        debugPrint('📊 Found total: $value (${value.runtimeType})');

        if (value is num) {
          return value.toDouble();
        } else if (value is String) {
          final parsed = double.tryParse(value);
          if (parsed != null) return parsed;
        }

        debugPrint('❌ Could not parse total, defaulting to 0.0');
        return 0.0;
      }

      // Parse items if they exist
      List<OrderItem>? orderItems;
      if (json['items'] != null) {
        try {
          orderItems =
              (json['items'] as List)
                  .map(
                    (item) => OrderItem.fromJson(item as Map<String, dynamic>),
                  )
                  .toList();
          debugPrint('🍽️ Parsed ${orderItems.length} items');
        } catch (e) {
          debugPrint('⚠️ Error parsing order items: $e');
          orderItems = [];
        }
      }

      final orderTotal = parseOrderTotal(json);
      debugPrint('💰 Final orderTotal: $orderTotal');

      // Handle driverId - empty string means unassigned
      String? driverIdValue = json['driverId'];
      if (driverIdValue != null && driverIdValue.isEmpty) {
        driverIdValue = null; // Convert empty string to null
      }

      return OrderModel(
        orderId:
            json['orderId'] ??
            docId, // Use orderId field if available, fallback to docId
        status: json['status'] ?? 'unknown',
        deliveryAddress: json['deliveryAddress'] ?? 'No address',
        orderTotal: orderTotal,
        createdAt: parseStringTimestamp(json['createdAt']),
        updatedAt:
            json['updatedAt'] != null
                ? parseStringTimestamp(json['updatedAt'])
                : null,
        deliveredAt:
            json['deliveredAt'] != null
                ? parseStringTimestamp(json['deliveredAt'])
                : null,
        customerName: null, // You don't have this field
        customerPhone: null, // You don't have this field
        driverId: driverIdValue,
        userId: json['userId'],
        items: orderItems,
        isTestOrder: json['isTestOrder'] ?? false,
      );
    } catch (e) {
      debugPrint('❌ Error parsing OrderModel from JSON: $e');
      debugPrint('🔍 JSON data: $json');
      rethrow;
    }
  }
}

// Updated OrderItem to match your structure
class OrderItem {
  final String foodId;
  final String name;
  final int quantity; // Maps to 'qty' field
  final double price;
  final String? description;

  OrderItem({
    required this.foodId,
    required this.name,
    required this.quantity,
    required this.price,
    this.description,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      foodId: json['foodId'] ?? '',
      name: json['name'] ?? 'Unknown Item',
      quantity: json['qty'] ?? 1, // Note: using 'qty' from your data
      price: (json['price'] ?? 0).toDouble(),
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'foodId': foodId,
      'name': name,
      'qty': quantity, // Note: using 'qty' to match your data
      'price': price,
      'description': description,
    };
  }

  double get totalPrice => price * quantity;
}

// Navigation helper methods
class NavigationHelper {
  static void navigateToOrderDetails(BuildContext context, String orderId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailsPage(orderId: orderId),
      ),
    );
  }

  static void navigateToOrderHistory(BuildContext context, String driverId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderHistoryPage(personnelId: driverId),
      ),
    );
  }

  static void navigateToProfile(BuildContext context, String personnelId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(personnelId: personnelId),
      ),
    );
  }

  static void showErrorDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }
}
