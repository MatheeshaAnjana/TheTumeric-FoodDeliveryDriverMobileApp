import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../services/order_services.dart';

class HomePageNavigate extends StatefulWidget {
  const HomePageNavigate({super.key});

  @override
  State<HomePageNavigate> createState() => _HomePageNavigateState();
}

class _HomePageNavigateState extends State<HomePageNavigate> {
  // Driver Info
  String driverName = "Driver";
  String driverId = "";
  String personnelId = "";
  bool isOnline = false;

  // Data
  List<Map<String, dynamic>> preparingOrders = [];
  List<Map<String, dynamic>> currentOrders = [];
  Map<String, dynamic> driverStats = {'totalDeliveries': 0};

  // UI States
  bool isLoading = true;
  bool isAcceptingOrder = false;

  // Service
  final OrderService _orderService = OrderService();

  // Streams
  StreamSubscription? _preparingOrdersStream;
  StreamSubscription? _currentOrdersStream;

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  @override
  void dispose() {
    _preparingOrdersStream?.cancel();
    _currentOrdersStream?.cancel();
    super.dispose();
  }

  Future<void> _loadDriverData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        driverName = prefs.getString('full_name') ?? "Driver";
        driverId = prefs.getString('driver_id') ?? "";
        personnelId = prefs.getString('personnel_id') ?? "";
        isOnline = prefs.getBool('driver_online_status') ?? false;
      });

      if (personnelId.isNotEmpty) {
        await _loadData();
        await _fetchDriverStats(
          personnelId,
        ); // Call this after setting personnelId
        _setupStreams();
      } else {
        _showError('Please log in again');
      }
    } catch (e) {
      _showError('Error loading driver data: $e');
    }
  }

  Future<void> _fetchDriverStats(String personnelId) async {
    try {
      print("🔍 Fetching stats for personnelId: $personnelId");

      // Get driver document first to get totalDeliveries from driver record
      final driverQuery =
          await FirebaseFirestore.instance
              .collection('deliveryPersonnel')
              .where('personnelId', isEqualTo: personnelId)
              .get();

      int totalFromDriverRecord = 0;

      if (driverQuery.docs.isNotEmpty) {
        final driverData = driverQuery.docs.first.data();
        totalFromDriverRecord = driverData['totalDeliveries'] ?? 0;
        print("📊 Total deliveries from driver record: $totalFromDriverRecord");
      }

      // Also count delivered orders where this driver was assigned
      final deliveredOrders =
          await FirebaseFirestore.instance
              .collection('orders')
              .where(
                'driverId',
                isEqualTo: driverId,
              ) // Use driverId from SharedPreferences
              .where('status', isEqualTo: 'delivered')
              .get();

      int deliveredOrdersCount = deliveredOrders.docs.length;
      print("📦 Delivered orders count: $deliveredOrdersCount");

      // Use the maximum of both counts (in case there's inconsistency)
      int finalCount =
          deliveredOrdersCount > totalFromDriverRecord
              ? deliveredOrdersCount
              : totalFromDriverRecord;

      print("✅ Final delivery count: $finalCount");

      if (mounted) {
        setState(() {
          driverStats['totalDeliveries'] = finalCount;
        });
      }
    } catch (e) {
      print("❌ Error fetching driver stats: $e");
      if (mounted) {
        setState(() {
          driverStats['totalDeliveries'] = 0;
        });
      }
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() => isLoading = true);

      // Load preparing orders
      final preparing = await _orderService.getPreparingOrders();

      // Load driver's current orders
      final current = await _orderService.getDriverCurrentOrders(personnelId);

      setState(() {
        preparingOrders = preparing;
        currentOrders = current;
        isLoading = false;
      });

      debugPrint(
        'Loaded ${preparing.length} preparing orders, ${current.length} current orders',
      );
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Error loading data: $e');
    }
  }

  void _setupStreams() {
    // Stream for preparing orders
    _preparingOrdersStream = _orderService.getPreparingOrdersStream().listen((
      orders,
    ) {
      if (mounted) {
        setState(() {
          preparingOrders = orders;
        });
      }
    });

    // Stream for driver's current orders
    _currentOrdersStream = _orderService
        .getDriverCurrentOrdersStream(personnelId)
        .listen((orders) {
          if (mounted) {
            setState(() {
              currentOrders = orders;
            });
          }
        });
  }

  Future<void> _toggleOnlineStatus(String personnelId) async {
    try {
      final newStatus = !isOnline;

      setState(() {
        isOnline = newStatus;
      });

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('driver_online_status', newStatus);

      // 🔍 Search by personnelId (String)
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('deliveryPersonnel')
              .where('personnelId', isEqualTo: personnelId) // keep as String
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        final docId = querySnapshot.docs.first.id;
        await FirebaseFirestore.instance
            .collection('deliveryPersonnel')
            .doc(docId)
            .update({'isActive': newStatus});

        _showSuccess(isOnline ? 'You are now online!' : 'You are now offline!');
      } else {
        _showError('No driver found with personnelId: $personnelId');
      }
    } catch (e) {
      _showError('Error updating status: $e');
      // Revert the state if there was an error
      setState(() {
        isOnline = !isOnline;
      });
    }
  }

  Future<void> _acceptOrder(Map<String, dynamic> order) async {
    if (isAcceptingOrder || !isOnline) return;

    try {
      setState(() => isAcceptingOrder = true);

      final success = await _orderService.acceptOrder(
        order['id'],
        driverId,
        personnelId,
      );

      if (success) {
        _showSuccess('Order accepted successfully!');
      } else {
        _showError('Failed to accept order');
      }
    } catch (e) {
      _showError('Error accepting order: $e');
    } finally {
      setState(() => isAcceptingOrder = false);
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      // First, update the local state immediately for better UX
      setState(() {
        final orderIndex = currentOrders.indexWhere(
          (order) => order['id'] == orderId,
        );
        if (orderIndex != -1) {
          currentOrders[orderIndex]['status'] = newStatus;
        }
      });

      final success = await _orderService.updateOrderStatus(orderId, newStatus);
      if (success) {
        _showSuccess('Order status updated to $newStatus');

        // If order is delivered, add to driver's orderHistory
        if (newStatus == 'delivered') {
          await _addOrderToHistory(orderId);
          await _fetchDriverStats(personnelId);
        }
      } else {
        // If update failed, revert the local state
        setState(() {
          final orderIndex = currentOrders.indexWhere(
            (order) => order['id'] == orderId,
          );
          if (orderIndex != -1) {
            // Revert to previous status (this is a simple approach)
            if (newStatus == 'out_for_delivery') {
              currentOrders[orderIndex]['status'] = 'accepted';
            } else if (newStatus == 'delivered') {
              currentOrders[orderIndex]['status'] = 'out_for_delivery';
            }
          }
        });
        _showError('Failed to update order status');
      }
    } catch (e) {
      // If error occurred, revert the local state
      setState(() {
        final orderIndex = currentOrders.indexWhere(
          (order) => order['id'] == orderId,
        );
        if (orderIndex != -1) {
          // Revert to previous status
          if (newStatus == 'out_for_delivery') {
            currentOrders[orderIndex]['status'] = 'accepted';
          } else if (newStatus == 'delivered') {
            currentOrders[orderIndex]['status'] = 'out_for_delivery';
          }
        }
      });
      _showError('Error updating status: $e');
    }
  }

  // Add order to driver's orderHistory array
  Future<void> _addOrderToHistory(String orderId) async {
    try {
      print("📝 Adding order $orderId to driver's order history");

      // Find driver document by personnelId
      final driverQuery =
          await FirebaseFirestore.instance
              .collection('deliveryPersonnel')
              .where('personnelId', isEqualTo: personnelId)
              .get();

      if (driverQuery.docs.isNotEmpty) {
        final driverDocRef = driverQuery.docs.first.reference;

        // Add orderId to orderHistory array
        await driverDocRef.update({
          'orderHistory': FieldValue.arrayUnion([orderId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print("✅ Successfully added order $orderId to driver's history");
      } else {
        print("❌ Driver not found with personnelId: $personnelId");
      }
    } catch (e) {
      print("❌ Error adding order to history: $e");
      // Don't show error to user as this is a background operation
      // The main order status update already succeeded
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadData();
            await _fetchDriverStats(personnelId);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                _buildHeader(),
                if (isLoading) _buildLoadingState(),
                if (!isLoading) ...[
                  if (currentOrders.isNotEmpty) _buildCurrentOrdersSection(),
                  if (isOnline && preparingOrders.isNotEmpty)
                    _buildPreparingOrdersSection(),
                  if (!isOnline) _buildOfflineState(),
                  if (isOnline &&
                      preparingOrders.isEmpty &&
                      currentOrders.isEmpty)
                    _buildEmptyState(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF4A300), Color(0xFFFFD166)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: const Icon(Icons.person, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, $driverName',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'ID: $personnelId',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(),
            ],
          ),
          const SizedBox(height: 20),
          _buildOnlineToggle(),
          const SizedBox(height: 20),
          _buildStatsRow(),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color =
        !isOnline
            ? Colors.red
            : (currentOrders.isNotEmpty ? Colors.orange : Color(0xFFF4A300));
    String text =
        !isOnline
            ? 'OFFLINE'
            : (currentOrders.isNotEmpty ? 'BUSY' : 'AVAILABLE');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildOnlineToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isOnline ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              isOnline ? 'You are ONLINE' : 'You are OFFLINE',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: isOnline,
            onChanged: (value) => _toggleOnlineStatus(personnelId),
            activeColor: Colors.green,
            inactiveThumbColor: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatCard(
          'Total Deliveries',
          '${driverStats['totalDeliveries']}',
          Icons.local_shipping,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentOrdersSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Orders (${currentOrders.length})',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...currentOrders
              .map((order) => _buildCurrentOrderCard(order))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildCurrentOrderCard(Map<String, dynamic> order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order['orderId'] ?? order['id']}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Status: ${order['status']}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '\$${order['total']?.toStringAsFixed(2) ?? '0.00'}',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            order['deliveryAddress'] ?? 'No address',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          const SizedBox(height: 12),
          _buildStatusButtons(order),
        ],
      ),
    );
  }

  Widget _buildStatusButtons(Map<String, dynamic> order) {
    String status = order['status'];
    String orderId = order['id'];

    if (status == 'accepted' || status == 'pickup') {
      return ElevatedButton(
        onPressed: () {
          _updateOrderStatus(orderId, 'out_for_delivery');
        },
        child: const Text('Start Delivery'),
      );
    } else if (status == 'out_for_delivery') {
      return ElevatedButton(
        onPressed: () {
          _updateOrderStatus(orderId, 'delivered');
        },
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        child: const Text('Mark as Delivered'),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Completed', style: TextStyle(color: Colors.green)),
      );
    }
  }

  Widget _buildPreparingOrdersSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Orders (${preparingOrders.length})',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...preparingOrders
              .map((order) => _buildPreparingOrderCard(order))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildPreparingOrderCard(Map<String, dynamic> order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order['orderId'] ?? order['id']}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${(order['items'] as List?)?.length ?? 0} items',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    '\$${order['total']?.toStringAsFixed(2) ?? '0.00'}',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            order['deliveryAddress'] ?? 'No address',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isAcceptingOrder ? null : () => _acceptOrder(order),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child:
                  isAcceptingOrder
                      ? const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      )
                      : const Text('Accept Order'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildOfflineState() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.power_settings_new, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'You\'re offline',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Turn on your availability to start accepting orders',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No orders available',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'New orders will appear here when available',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // ElevatedButton.icon(
          //   onPressed: () async {
          //     await _orderService.createTestOrder();
          //     _loadData();
          //   },
          //   icon: const Icon(Icons.add),
          //   label: const Text('Create Test Order'),
          // ),
        ],
      ),
    );
  }
}
