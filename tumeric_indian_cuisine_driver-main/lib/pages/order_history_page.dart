import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tumeric_indian_cuisine_driver/pages/models/order_model.dart';
import 'dart:async';

import 'package:tumeric_indian_cuisine_driver/pages/services/order_services.dart';

class OrderHistoryPage extends StatefulWidget {
  final String personnelId; // Changed from driverId to personnelId

  const OrderHistoryPage({super.key, required this.personnelId});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage>
    with TickerProviderStateMixin {
  List<OrderModel> allDeliveredOrders = [];
  List<OrderModel> filteredOrders = [];
  List<Map<String, dynamic>> _orderDataWithCustomers =
      []; // Store original data with customer details
  Map<String, dynamic> driverStats = {};
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';

  // Filter options
  String selectedPeriod = 'All Time';
  final List<String> periodOptions = [
    'Today',
    'This Week',
    'This Month',
    'All Time',
  ];

  final OrderService _orderService = OrderService();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadOrderHistory();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadOrderHistory() async {
    try {
      setState(() {
        isLoading = true;
        hasError = false;
        errorMessage = '';
      });

      debugPrint(
        'Loading order history for personnelId: ${widget.personnelId}',
      );

      // Get delivered orders from driver's orderHistory array
      final delivered = await _getDriverDeliveredOrdersFromHistory();

      // Get driver statistics from orderHistory
      final stats = await _orderService.getDriverStatsFromHistory(
        widget.personnelId,
      );

      setState(() {
        allDeliveredOrders = delivered;
        driverStats = stats;
        isLoading = false;
      });

      _applyPeriodFilter(selectedPeriod);
      _animationController.forward();

      debugPrint('Loaded ${delivered.length} delivered orders from history');
    } catch (e) {
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = e.toString();
      });
      debugPrint('Error loading order history: $e');
    }
  }

  Future<List<OrderModel>> _getDriverDeliveredOrdersFromHistory() async {
    try {
      debugPrint(
        '🔍 Fetching orders with customer details from orderHistory array...',
      );

      // Use the new method that gets orders with customer details
      final orderMaps = await _orderService.getDriverOrderHistoryWithCustomers(
        widget.personnelId,
      );

      List<OrderModel> orders = [];
      for (var orderData in orderMaps) {
        try {
          OrderModel order = OrderModel.fromJson(orderData, orderData['id']);

          // Add customer details to the order if available
          if (orderData.containsKey('customer')) {
            Map<String, dynamic> customerData = orderData['customer'];
            // You can store customer data in OrderModel or handle it separately
            // For now, we'll access it from the original data when displaying
          }

          orders.add(order);
        } catch (e) {
          debugPrint('❌ Error parsing order ${orderData['id']}: $e');
        }
      }

      // Store the original data for customer access
      _orderDataWithCustomers = orderMaps;

      debugPrint(
        '✅ Successfully parsed ${orders.length} orders with customer details',
      );
      return orders;
    } catch (e) {
      debugPrint('❌ Error fetching orders from history: $e');
      return [];
    }
  }

  void _applyPeriodFilter(String period) {
    setState(() {
      selectedPeriod = period;
    });

    final now = DateTime.now();
    DateTime filterDate;

    switch (period) {
      case 'Today':
        filterDate = DateTime(now.year, now.month, now.day);
        break;
      case 'This Week':
        filterDate = now.subtract(Duration(days: now.weekday - 1));
        filterDate = DateTime(
          filterDate.year,
          filterDate.month,
          filterDate.day,
        );
        break;
      case 'This Month':
        filterDate = DateTime(now.year, now.month, 1);
        break;
      default:
        setState(() {
          filteredOrders = allDeliveredOrders;
        });
        return;
    }

    setState(() {
      filteredOrders =
          allDeliveredOrders.where((order) {
            return order.deliveredAt != null &&
                order.deliveredAt!.isAfter(filterDate);
          }).toList();
    });
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    }
  }

  // Widget _buildFilterChips() {
  //   return Container(
  //     height: 50,
  //     margin: const EdgeInsets.symmetric(horizontal: 24),
  //     child: ListView.builder(
  //       scrollDirection: Axis.horizontal,
  //       itemCount: periodOptions.length,
  //       itemBuilder: (context, index) {
  //         final period = periodOptions[index];
  //         final isSelected = period == selectedPeriod;

  //         return Container(
  //           margin: const EdgeInsets.only(right: 12),
  //           child: FilterChip(
  //             label: Text(period),
  //             selected: isSelected,
  //             onSelected: (selected) => _applyPeriodFilter(period),
  //             backgroundColor: Colors.white,
  //             selectedColor: Color(0xFFF4A300).withOpacity(0.2),
  //             checkmarkColor: Color(0xFFF4A300),
  //             labelStyle: GoogleFonts.poppins(
  //               fontSize: 14,
  //               fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
  //               color: isSelected ? Color(0xFFF4A300) : Colors.grey.shade700,
  //             ),
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(20),
  //               side: BorderSide(
  //                 color:
  //                     isSelected
  //                         ? Color(0xFFF4A300).withOpacity(0.5)
  //                         : Colors.grey.shade300,
  //               ),
  //             ),
  //           ),
  //         );
  //       },
  //     ),
  //   );
  // }

  Widget _buildStatsHeader() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF4A300), Color(0xFFFFD166)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFF4A300).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                'Delivery Statistics',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Deliveries',
                  '${driverStats['totalDeliveries'] ?? 0}',
                  Icons.local_shipping,
                ),
              ),
              const SizedBox(width: 16),
              // Expanded(
              //   child: _buildStatCard(
              //     '$selectedPeriod Deliveries',
              //     '${filteredOrders.length}',
              //     selectedPeriod == 'Today'
              //         ? Icons.today
              //         : selectedPeriod == 'This Week'
              //         ? Icons.view_week
              //         : selectedPeriod == 'This Month'
              //         ? Icons.calendar_month
              //         : Icons.history,
              //   ),
              // ),
            ],
          ),
          if (selectedPeriod != 'All Time') ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'You have completed ${driverStats['totalDeliveries']} deliveries in total',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.9),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  double _calculateTotalLifetimeEarnings() {
    double total = 0.0;
    for (var order in allDeliveredOrders) {
      total += (order.orderTotal * 0.15) + 5.0;
    }
    return total;
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child:
                    isLoading
                        ? _buildLoadingState()
                        : hasError
                        ? _buildErrorState()
                        : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF4A300), Color(0xFFFFD166)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
        child: Row(
          children: [
            const Spacer(),
            Text(
              'Order History',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _loadOrderHistory,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.refresh, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFFF4A300)),
          SizedBox(height: 16),
          Text('Loading order history...'),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Failed to Load History',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadOrderHistory,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFF4A300).withOpacity(0.2),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadOrderHistory,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildStatsHeader()),
          SliverToBoxAdapter(child: const SizedBox(height: 16)),
          // SliverToBoxAdapter(child: _buildFilterChips()),
          SliverToBoxAdapter(child: const SizedBox(height: 16)),

          if (filteredOrders.isEmpty)
            SliverToBoxAdapter(child: _buildEmptyState())
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.delivery_dining,
                      color: Colors.grey.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Deliveries ',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xFFF4A300).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${filteredOrders.length}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF4A300),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final order = filteredOrders[index];
                return _buildOrderHistoryCard(order, index);
              }, childCount: filteredOrders.length),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    String subMessage;

    switch (selectedPeriod) {
      case 'Today':
        message = 'No Deliveries Today';
        subMessage = 'You haven\'t completed any deliveries today yet.';
        break;
      case 'This Week':
        message = 'No Deliveries This Week';
        subMessage = 'You haven\'t completed any deliveries this week yet.';
        break;
      case 'This Month':
        message = 'No Deliveries This Month';
        subMessage = 'You haven\'t completed any deliveries this month yet.';
        break;
      default:
        message = 'No Order History';
        subMessage =
            'Start accepting and completing orders to see your delivery history here. Orders will appear after you mark them as delivered.';
    }

    return Container(
      padding: const EdgeInsets.all(40),
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subMessage,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderHistoryCard(OrderModel order, int index) {
    // Find the corresponding order data with customer details
    Map<String, dynamic>? orderDataWithCustomer;
    try {
      orderDataWithCustomer = _orderDataWithCustomers.firstWhere(
        (data) => data['id'] == order.orderId,
        orElse: () => {},
      );
    } catch (e) {
      orderDataWithCustomer = null;
    }

    Map<String, dynamic>? customerData = orderDataWithCustomer?['customer'];

    return Container(
      margin: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        index == filteredOrders.length - 1 ? 24 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showOrderDetailsDialog(order, customerData),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFF4A300), Color(0xFFFFD166)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${order.orderId.length > 8 ? order.orderId.substring(0, 8).toUpperCase() : order.orderId.toUpperCase()}',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        'DELIVERED',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Customer Information
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(0xFFF4A300).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.person,
                          color: Color(0xFFF4A300),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customerData != null
                                  ? (customerData['name'] ??
                                      customerData['full_name'] ??
                                      customerData['firstName'] ??
                                      'Unknown Customer')
                                  : order.customerName ?? 'Unknown Customer',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFF4A300),
                              ),
                            ),
                            if (customerData != null &&
                                customerData['phone'] != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                customerData['phone'],
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Color(0xFFF4A300),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        '£${order.orderTotal.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF4A300),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Delivery Address
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order.deliveryAddress,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                if (order.items != null && order.items!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.restaurant_menu,
                        size: 14,
                        color: Color(0xFFF4A300),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${order.items!.length} items: ${order.items!.take(3).map((item) => item.name).join(', ')}${order.items!.length > 3 ? '...' : ''}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Color(0xFFF4A300),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOrderDetailsDialog(
    OrderModel order,
    Map<String, dynamic>? customerData,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Order #${order.orderId.length > 8 ? order.orderId.substring(0, 8).toUpperCase() : order.orderId.toUpperCase()}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'DELIVERED SUCCESSFULLY',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Customer Information
                  Text(
                    'Customer Details:',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow(
                          'Name',
                          customerData != null
                              ? (customerData['name'] ??
                                  customerData['full_name'] ??
                                  customerData['firstName'] ??
                                  'Unknown Customer')
                              : order.customerName ?? 'Unknown Customer',
                        ),
                        if (customerData != null &&
                            customerData['phone'] != null)
                          _buildDetailRow('Phone', customerData['phone']),
                        if (customerData != null &&
                            customerData['email'] != null)
                          _buildDetailRow('Email', customerData['email']),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  _buildDetailRow('Delivery Address', order.deliveryAddress),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Order Total',
                    '£${order.orderTotal.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  if (order.deliveredAt != null)
                    _buildDetailRow(
                      'Delivered On',
                      _formatDate(order.deliveredAt!),
                    ),

                  if (order.items != null && order.items!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Order Items:',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:
                            order.items!
                                .map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${item.quantity}x ${item.name}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '£${item.totalPrice.toStringAsFixed(2)}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: GoogleFonts.poppins(
                    color: Colors.purple.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
