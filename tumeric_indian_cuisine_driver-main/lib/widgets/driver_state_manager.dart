// import 'dart:ui';

// import 'package:flutter/foundation.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:tumeric_indian_cuisine_driver/pages/models/order_model.dart';
// import 'package:tumeric_indian_cuisine_driver/pages/services/order_services.dart';


// class DriverStateManager extends ChangeNotifier {
//   static final DriverStateManager _instance = DriverStateManager._internal();
//   factory DriverStateManager() => _instance;
//   DriverStateManager._internal();

//   // Driver Info
//   String _driverId = '';
//   String _personnelId = '';
//   String _driverName = '';
//   String _driverEmail = '';
//   bool _isOnline = false;
//   bool _isAuthenticated = false;

//   // Order Data
//   OrderModel? _currentOrder;
//   List<OrderModel> _availableOrders = [];
//   Map<String, dynamic> _driverStats = {};

//   // Services
//   final OrderService _orderService = OrderService();

//   // Getters
//   String get driverId => _driverId;
//   String get personnelId => _personnelId;
//   String get driverName => _driverName;
//   String get driverEmail => _driverEmail;
//   bool get isOnline => _isOnline;
//   bool get isAuthenticated => _isAuthenticated;
//   OrderModel? get currentOrder => _currentOrder;
//   List<OrderModel> get availableOrders => _availableOrders;
//   Map<String, dynamic> get driverStats => _driverStats;

//   // Initialize driver state from SharedPreferences
//   Future<void> initializeDriverState() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
      
//       _driverId = prefs.getString('driver_id') ?? '';
//       _personnelId = prefs.getString('personnel_id') ?? '';
//       _driverName = prefs.getString('full_name') ?? '';
//       _driverEmail = prefs.getString('user_email') ?? '';
//       _isOnline = prefs.getBool('driver_online_status') ?? false;
//       _isAuthenticated = prefs.getBool('is_logged_in') ?? false;

//       debugPrint('Driver state initialized: $_driverName ($_driverId) - Online: $_isOnline');
//       notifyListeners();

//       if (_isAuthenticated && _driverId.isNotEmpty) {
//         await refreshDriverData();
//       }
//     } catch (e) {
//       debugPrint('Error initializing driver state: $e');
//     }
//   }

//   // Refresh all driver data
//   Future<void> refreshDriverData() async {
//     try {
//       if (_driverId.isEmpty) return;

//       // Get driver statistics
//       final stats = await _orderService.getDriverStats(_driverId);
      
//       // Get current active order
//       final activeOrders = await _orderService.getDriverActiveOrders(_driverId);
//       final activeOrder = activeOrders.isNotEmpty ? activeOrders.first : null;

//       // Get available orders (only if no active order and online)
//       List<OrderModel> preparing = [];
//       if (activeOrder == null && _isOnline) {
//         preparing = await _orderService.getOrdersByStatus('preparing');
//       }

//       _currentOrder = activeOrder;
//       _availableOrders = preparing;
//       _driverStats = {
//         'todayDeliveries': stats['todayDeliveries'] ?? 0,
//         'todayEarnings': _calculateTodayEarnings(stats),
//         'totalDeliveries': stats['totalDeliveries'] ?? 0,
//         'rating': stats['rating'] ?? 4.5,
//       };

//       debugPrint('Driver data refreshed: current=${_currentOrder?.orderId}, available=${_availableOrders.length}');
//       notifyListeners();
//     } catch (e) {
//       debugPrint('Error refreshing driver data: $e');
//     }
//   }

//   // Toggle online status
//   Future<void> toggleOnlineStatus() async {
//     try {
//       if (_currentOrder != null && _isOnline) {
//         debugPrint('Cannot go offline with active order');
//         return;
//       }

//       _isOnline = !_isOnline;

//       // Persist online status
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setBool('driver_online_status', _isOnline);

//       debugPrint('Online status changed to: $_isOnline');
//       notifyListeners();

//       // Refresh available orders based on new status
//       if (_isOnline && _currentOrder == null) {
//         final preparing = await _orderService.getOrdersByStatus('preparing');
//         _availableOrders = preparing;
//       } else if (!_isOnline) {
//         _availableOrders = [];
//       }

//       notifyListeners();
//     } catch (e) {
//       debugPrint('Error toggling online status: $e');
//     }
//   }

//   // Accept order
//   Future<bool> acceptOrder(String orderId) async {
//     try {
//       if (_currentOrder != null) {
//         debugPrint('Driver already has an active order');
//         return false;
//       }

//       if (!_isOnline) {
//         debugPrint('Driver must be online to accept orders');
//         return false;
//       }

//       final success = await _orderService.assignOrderToDriver(orderId, _driverId, 'assigned_to_driver');
      
//       if (success) {
//         await refreshDriverData();
//         debugPrint('Order $orderId accepted successfully');
//       }

//       return success;
//     } catch (e) {
//       debugPrint('Error accepting order: $e');
//       return false;
//     }
//   }

//   // Update order status
//   Future<bool> updateOrderStatus(String orderId, String newStatus) async {
//     try {
//       final success = await _orderService.updateOrderStatus(orderId, newStatus);
      
//       if (success) {
//         await refreshDriverData();
//         debugPrint('Order $orderId status updated to $newStatus');
//       }

//       return success;
//     } catch (e) {
//       debugPrint('Error updating order status: $e');
//       return false;
//     }
//   }

//   // Update current order from stream
//   void updateCurrentOrder(OrderModel? order) {
//     final previousOrder = _currentOrder;
//     _currentOrder = order;
    
//     // If order was completed, refresh available orders
//     if (previousOrder != null && order == null && _isOnline) {
//       _refreshAvailableOrders();
//     }
    
//     notifyListeners();
//   }

//   // Update available orders from stream
//   void updateAvailableOrders(List<OrderModel> orders) {
//     // Only update if we don't have an active order and are online
//     if (_currentOrder == null && _isOnline) {
//       _availableOrders = orders;
//       notifyListeners();
//     }
//   }

//   // Refresh available orders
//   Future<void> _refreshAvailableOrders() async {
//     try {
//       if (_isOnline && _currentOrder == null) {
//         final preparing = await _orderService.getOrdersByStatus('preparing');
//         _availableOrders = preparing;
//         notifyListeners();
//       }
//     } catch (e) {
//       debugPrint('Error refreshing available orders: $e');
//     }
//   }

//   // Calculate today's earnings
//   double _calculateTodayEarnings(Map<String, dynamic> stats) {
//     final todayDeliveries = stats['todayDeliveries'] ?? 0;
//     final totalEarnings = stats['totalEarnings'] ?? 0.0;
//     if (totalEarnings > 0 && todayDeliveries > 0) {
//       final totalDeliveries = stats['totalDeliveries'] ?? 1;
//       return (totalEarnings / totalDeliveries) * todayDeliveries;
//     }
//     return todayDeliveries * 20.0;
//   }

//   // Update driver profile info (called after profile edit)
//   Future<void> updateDriverProfile({
//     String? fullName,
//     String? email,
//   }) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
      
//       if (fullName != null && fullName.isNotEmpty) {
//         _driverName = fullName;
//         await prefs.setString('full_name', fullName);
//       }
      
//       if (email != null && email.isNotEmpty) {
//         _driverEmail = email;
//         await prefs.setString('user_email', email);
//       }

//       debugPrint('Driver profile updated: $_driverName ($_driverEmail)');
//       notifyListeners();
//     } catch (e) {
//       debugPrint('Error updating driver profile: $e');
//     }
//   }

//   // Clear driver state (for logout)
//   Future<void> clearDriverState() async {
//     try {
//       _driverId = '';
//       _personnelId = '';
//       _driverName = '';
//       _driverEmail = '';
//       _isOnline = false;
//       _isAuthenticated = false;
//       _currentOrder = null;
//       _availableOrders = [];
//       _driverStats = {};

//       final prefs = await SharedPreferences.getInstance();
//       await prefs.remove('driver_online_status');
      
//       debugPrint('Driver state cleared');
//       notifyListeners();
//     } catch (e) {
//       debugPrint('Error clearing driver state: $e');
//     }
//   }

//   // Check if driver can go offline
//   bool canGoOffline() {
//     return _currentOrder == null;
//   }

//   // Get status display text
//   String getStatusDisplayText() {
//     if (!_isOnline) return 'OFFLINE';
//     if (_currentOrder != null) return 'BUSY';
//     return 'AVAILABLE';
//   }

//   // Get status color
//   Color getStatusColor() {
//     if (!_isOnline) return const Color(0xFFE53E3E);
//     if (_currentOrder != null) return const Color(0xFFED8936);
//     return const Color(0xFF38A169);
//   }
// }