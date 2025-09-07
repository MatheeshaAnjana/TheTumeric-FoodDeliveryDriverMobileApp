import 'package:cloud_firestore/cloud_firestore.dart';

class OrderDriverModel {
  final String id; // Document ID
  final String orderId;
  final String driverId;
  final String
  orderStatus; // assigned, picked_up, out_for_delivery, delivered, cancelled
  final DateTime? acceptedAt;
  final DateTime? pickedUpAt;
  final DateTime? outForDeliveryAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final DateTime updatedAt;

  // Customer details (copied from original order)
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final double orderTotal;
  final Map<String, dynamic> customerLocation;

  // Order details
  final List<OrderItemModel> items;
  final String? specialInstructions;
  final String? restaurantNotes;

  // Driver tracking
  final Map<String, dynamic>? driverLocation;
  final double? estimatedDeliveryTime;
  final String? driverNotes;

  // Financial
  final double deliveryFee;
  final double driverEarnings;
  final bool isPaid;

  OrderDriverModel({
    required this.id,
    required this.orderId,
    required this.driverId,
    required this.orderStatus,
    required this.acceptedAt,
    this.pickedUpAt,
    this.outForDeliveryAt,
    this.deliveredAt,
    this.cancelledAt,
    required this.updatedAt,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.orderTotal,
    this.customerLocation = const {},
    required this.items,
    this.specialInstructions,
    this.restaurantNotes,
    this.driverLocation,
    this.estimatedDeliveryTime,
    this.driverNotes,
    this.deliveryFee = 5.0,
    this.driverEarnings = 0.0,
    this.isPaid = false,
  });

  factory OrderDriverModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return OrderDriverModel(
      id: doc.id,
      orderId: data['orderId'] ?? '',
      driverId: data['driverId'] ?? '',
      orderStatus: data['orderStatus'] ?? 'assigned',
      acceptedAt: _parseTimestamp(data['acceptedAt']),
      pickedUpAt: _parseTimestamp(data['pickedUpAt']),
      outForDeliveryAt: _parseTimestamp(data['outForDeliveryAt']),
      deliveredAt: _parseTimestamp(data['deliveredAt']),
      cancelledAt: _parseTimestamp(data['cancelledAt']),
      updatedAt: _parseTimestamp(data['updatedAt']) ?? DateTime.now(),
      customerName: data['customerName'] ?? 'Customer',
      customerPhone: data['customerPhone'] ?? '',
      deliveryAddress: data['deliveryAddress'] ?? '',
      orderTotal: (data['orderTotal'] ?? 0).toDouble(),
      customerLocation: Map<String, dynamic>.from(
        data['customerLocation'] ?? {},
      ),
      items: _parseItems(data['items'] ?? []),
      specialInstructions: data['specialInstructions'],
      restaurantNotes: data['restaurantNotes'],
      driverLocation:
          data['driverLocation'] != null
              ? Map<String, dynamic>.from(data['driverLocation'])
              : null,
      estimatedDeliveryTime: data['estimatedDeliveryTime']?.toDouble(),
      driverNotes: data['driverNotes'],
      deliveryFee: (data['deliveryFee'] ?? 5.0).toDouble(),
      driverEarnings: (data['driverEarnings'] ?? 0.0).toDouble(),
      isPaid: data['isPaid'] ?? false,
    );
  }

  static DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static List<OrderItemModel> _parseItems(List<dynamic> itemsData) {
    return itemsData.map((item) {
      if (item is Map<String, dynamic>) {
        return OrderItemModel.fromJson(item);
      }
      return OrderItemModel(name: 'Unknown Item', quantity: 1, price: 0.0);
    }).toList();
  }

  Map<String, dynamic> toFirestore() {
    return {
      'orderId': orderId,
      'driverId': driverId,
      'orderStatus': orderStatus,
      'acceptedAt': Timestamp.fromDate(acceptedAt!),
      'pickedUpAt': pickedUpAt != null ? Timestamp.fromDate(pickedUpAt!) : null,
      'outForDeliveryAt':
          outForDeliveryAt != null
              ? Timestamp.fromDate(outForDeliveryAt!)
              : null,
      'deliveredAt':
          deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'cancelledAt':
          cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'customerName': customerName,
      'customerPhone': customerPhone,
      'deliveryAddress': deliveryAddress,
      'orderTotal': orderTotal,
      'customerLocation': customerLocation,
      'items': items.map((item) => item.toJson()).toList(),
      'specialInstructions': specialInstructions,
      'restaurantNotes': restaurantNotes,
      'driverLocation': driverLocation,
      'estimatedDeliveryTime': estimatedDeliveryTime,
      'driverNotes': driverNotes,
      'deliveryFee': deliveryFee,
      'driverEarnings': driverEarnings,
      'isPaid': isPaid,
    };
  }

  // Helper methods
  bool get isActive =>
      ['assigned', 'picked_up', 'out_for_delivery'].contains(orderStatus);
  bool get isCompleted => orderStatus == 'delivered';
  bool get isCancelled => orderStatus == 'cancelled';

  Duration get timeSinceAccepted => DateTime.now().difference(acceptedAt!);

  String get statusDisplayText {
    switch (orderStatus) {
      case 'assigned':
        return 'Ready for Pickup';
      case 'picked_up':
        return 'Picked Up';
      case 'out_for_delivery':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return orderStatus.toUpperCase();
    }
  }

  // Calculate estimated earnings
  double get estimatedEarnings => (orderTotal * 0.15) + deliveryFee;

  // Create copy with updated status
  OrderDriverModel copyWithStatus(String newStatus) {
    final now = DateTime.now();

    return OrderDriverModel(
      id: id,
      orderId: orderId,
      driverId: driverId,
      orderStatus: newStatus,
      acceptedAt: acceptedAt,
      pickedUpAt:
          newStatus == 'picked_up' && pickedUpAt == null ? now : pickedUpAt,
      outForDeliveryAt:
          newStatus == 'out_for_delivery' && outForDeliveryAt == null
              ? now
              : outForDeliveryAt,
      deliveredAt:
          newStatus == 'delivered' && deliveredAt == null ? now : deliveredAt,
      cancelledAt:
          newStatus == 'cancelled' && cancelledAt == null ? now : cancelledAt,
      updatedAt: now,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      orderTotal: orderTotal,
      customerLocation: customerLocation,
      items: items,
      specialInstructions: specialInstructions,
      restaurantNotes: restaurantNotes,
      driverLocation: driverLocation,
      estimatedDeliveryTime: estimatedDeliveryTime,
      driverNotes: driverNotes,
      deliveryFee: deliveryFee,
      driverEarnings:
          newStatus == 'delivered' ? estimatedEarnings : driverEarnings,
      isPaid: isPaid,
    );
  }
}

class OrderItemModel {
  final String name;
  final int quantity;
  final double price;
  final String? description;
  final Map<String, dynamic>? customizations;

  OrderItemModel({
    required this.name,
    required this.quantity,
    required this.price,
    this.description,
    this.customizations,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      name: json['name'] ?? 'Unknown Item',
      quantity: json['quantity'] ?? 1,
      price: (json['price'] ?? 0).toDouble(),
      description: json['description'],
      customizations:
          json['customizations'] != null
              ? Map<String, dynamic>.from(json['customizations'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'price': price,
      'description': description,
      'customizations': customizations,
    };
  }

  double get totalPrice => price * quantity;
}
