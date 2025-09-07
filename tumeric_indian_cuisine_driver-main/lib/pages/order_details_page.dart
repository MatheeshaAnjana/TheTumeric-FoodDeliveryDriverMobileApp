import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tumeric_indian_cuisine_driver/pages/models/order_model.dart';
import 'package:tumeric_indian_cuisine_driver/pages/services/order_services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';



class OrderDetailsPage extends StatefulWidget {
  final String orderId;

  const OrderDetailsPage({super.key, required this.orderId});

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage>
    with TickerProviderStateMixin {
  OrderModel? order;
  bool isLoading = true;
  bool isUpdatingStatus = false;
  
  final OrderService _orderService = OrderService();
  StreamSubscription? _orderSubscription;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupOrderStream();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _orderSubscription?.cancel();
    super.dispose();
  }

  void _setupOrderStream() {
    // Set up real-time listener for this specific order
    _orderSubscription = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        try {
          final orderData = OrderModel.fromJson(snapshot.data()!, snapshot.id);
          setState(() {
            order = orderData;
            isLoading = false;
          });
          
          if (!_animationController.isCompleted) {
            _animationController.forward();
          }
          
          // If order is delivered, show success and navigate back after delay
          if (orderData.status == 'delivered') {
            _showSuccess('Order delivered successfully! Great job!');
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                Navigator.pop(context, true); // Return true to indicate completion
              }
            });
          }
          
        } catch (e) {
          debugPrint('Error parsing order in stream: $e');
          _showError('Error loading order details');
        }
      } else if (!snapshot.exists && mounted) {
        _showError('Order not found');
        Navigator.pop(context);
      }
    }, onError: (error) {
      debugPrint('Order stream error: $error');
      if (mounted) {
        _showError('Connection error: Unable to load order updates');
      }
    });
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    if (order == null || isUpdatingStatus) return;

    // Show confirmation for critical status changes
    if (newStatus == 'delivered') {
      bool confirm = await _showDeliveryConfirmation();
      if (!confirm) return;
    }

    try {
      setState(() => isUpdatingStatus = true);
      
      final success = await _orderService.updateOrderStatus(order!.orderId, newStatus);
      
      if (success) {
        _showSuccess(_getStatusMessage(newStatus));
      } else {
        _showError('Failed to update order status');
      }
      
    } catch (e) {
      _showError('Error updating status: ${e.toString()}');
    } finally {
      setState(() => isUpdatingStatus = false);
    }
  }

  Future<bool> _showDeliveryConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delivery'),
        content: const Text(
          'Are you sure you have delivered this order to the customer?\n\n'
          'This action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Delivery'),
          ),
        ],
      ),
    ) ?? false;
  }

  String _getStatusMessage(String status) {
    switch (status) {
      case 'picked_up':
        return 'Order picked up! Ready for delivery.';
      case 'out_for_delivery':
        return 'On your way to customer!';
      case 'delivered':
        return 'Order delivered successfully! You earned \$${_calculateEarnings().toStringAsFixed(2)}';
      default:
        return 'Status updated!';
    }
  }

  Future<void> _callCustomer() async {
    if (order?.customerPhone != null && order!.customerPhone!.isNotEmpty) {
      final phoneUrl = 'tel:${order!.customerPhone}';
      try {
        if (await canLaunchUrl(Uri.parse(phoneUrl))) {
          await launchUrl(Uri.parse(phoneUrl));
        } else {
          _showError('Unable to make phone call');
        }
      } catch (e) {
        _showError('Error making phone call: $e');
      }
    } else {
      _showError('No phone number available');
    }
  }

  Future<void> _openMaps() async {
    if (order?.deliveryAddress != null && order!.deliveryAddress.isNotEmpty) {
      final address = Uri.encodeComponent(order!.deliveryAddress);
      final mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$address';
      
      try {
        if (await canLaunchUrl(Uri.parse(mapsUrl))) {
          await launchUrl(Uri.parse(mapsUrl), mode: LaunchMode.externalApplication);
        } else {
          _showError('Unable to open maps');
        }
      } catch (e) {
        _showError('Error opening maps: $e');
      }
    } else {
      _showError('No address available');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          child: isLoading ? _buildLoadingState() : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF667eea)),
          SizedBox(height: 16),
          Text('Loading order details...'),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (order == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Order not found'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildAppBar(),
        _buildOrderSummary(),
        _buildCustomerDetails(),
        _buildOrderItems(),
        _buildDeliveryProgress(),
        _buildActionButtons(),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildAppBar() {
    return SliverToBoxAdapter(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_getStatusColor(), _getStatusColor().withOpacity(0.8)],
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Order Details',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusDisplayText(),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${order!.orderId.length > 8 ? order!.orderId.substring(0, 8).toUpperCase() : order!.orderId.toUpperCase()}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Total: \$${order!.orderTotal.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Your Earning',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '\$${_calculateEarnings().toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (order?.status) {
      case 'assigned_to_driver':
        return Colors.blue.shade600;
      case 'picked_up':
        return Colors.orange.shade600;
      case 'out_for_delivery':
        return Colors.purple.shade600;
      case 'delivered':
        return Colors.green.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _getStatusDisplayText() {
    switch (order?.status) {
      case 'assigned_to_driver':
        return 'READY FOR PICKUP';
      case 'picked_up':
        return 'PICKED UP';
      case 'out_for_delivery':
        return 'OUT FOR DELIVERY';
      case 'delivered':
        return 'DELIVERED';
      default:
        return order?.status.toUpperCase() ?? 'UNKNOWN';
    }
  }

  double _calculateEarnings() {
    if (order == null) return 0.0;
    return (order!.orderTotal * 0.15) + 5.0; // 15% commission + $5 delivery fee
  }

  Widget _buildOrderSummary() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.blue.shade600, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Order Summary',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('Order ID', order!.orderId),
            _buildSummaryRow('Order Total', '\$${order!.orderTotal.toStringAsFixed(2)}'),
            _buildSummaryRow('Delivery Fee', '\$5.00'),
            _buildSummaryRow('Commission (15%)', '\$${(order!.orderTotal * 0.15).toStringAsFixed(2)}'),
            const Divider(height: 24),
            _buildSummaryRow(
              'Your Total Earning', 
              '\$${_calculateEarnings().toStringAsFixed(2)}', 
              isHighlighted: true,
            ),
            const SizedBox(height: 8),
            _buildSummaryRow('Order Time', _formatDateTime(order!.createdAt)),
            if (order!.updatedAt != null)
              _buildSummaryRow('Last Updated', _formatDateTime(order!.updatedAt!)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: isHighlighted ? Colors.green.shade700 : Colors.grey.shade600,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isHighlighted ? Colors.green.shade700 : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerDetails() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.blue.shade600, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Customer Details',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Customer Name
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_outline, color: Colors.blue.shade600, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customer Name',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          order!.customerName ?? 'Customer',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // Customer Phone
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone, color: Colors.green.shade600, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Phone Number',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          order!.customerPhone ?? 'No phone number',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (order!.customerPhone != null && order!.customerPhone!.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: _callCustomer,
                      icon: const Icon(Icons.call, size: 16),
                      label: const Text('Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // Delivery Address
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.orange.shade600, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Delivery Address',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    order!.deliveryAddress,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openMaps,
                      icon: const Icon(Icons.directions, size: 16),
                      label: const Text('Open in Maps'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItems() {
    if (order!.items == null || order!.items!.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restaurant_menu, color: Colors.purple.shade600, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Order Items (${order!.items!.length})',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...order!.items!.map((item) => _buildOrderItem(item)).toList(),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                Text(
                  '\$${order!.orderTotal.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${item.quantity}x',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                if (item.description != null && item.description!.isNotEmpty)
                  Text(
                    item.description!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '\$${item.totalPrice.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryProgress() {
    final statuses = ['assigned_to_driver', 'picked_up', 'out_for_delivery', 'delivered'];
    final statusLabels = ['Order Assigned', 'Picked Up', 'Out for Delivery', 'Delivered'];
    final currentIndex = statuses.indexOf(order!.status);

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Colors.indigo.shade600, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Delivery Progress',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Progress indicators
            for (int i = 0; i < statuses.length; i++) ...[
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: i <= currentIndex ? Colors.green.shade600 : Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      i <= currentIndex ? Icons.check : Icons.circle,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      statusLabels[i],
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: i == currentIndex ? FontWeight.bold : FontWeight.w400,
                        color: i <= currentIndex ? Colors.green.shade700 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  if (i == currentIndex)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Current',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                ],
              ),
              if (i < statuses.length - 1) ...[
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.only(left: 12),
                  width: 2,
                  height: 20,
                  color: i < currentIndex ? Colors.green.shade600 : Colors.grey.shade300,
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Quick Action Buttons Row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (order!.customerPhone != null && order!.customerPhone!.isNotEmpty) 
                        ? _callCustomer 
                        : null,
                    icon: const Icon(Icons.call),
                    label: const Text('Call Customer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openMaps,
                    icon: const Icon(Icons.directions),
                    label: const Text('Navigate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Main Status Update Button
            _buildStatusUpdateButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusUpdateButton() {
    String buttonText = '';
    String nextStatus = '';
    Color buttonColor = Colors.grey;
    IconData buttonIcon = Icons.update;

    switch (order!.status) {
      case 'assigned_to_driver':
        buttonText = 'Mark as Picked Up';
        nextStatus = 'picked_up';
        buttonColor = Colors.orange.shade600;
        buttonIcon = Icons.shopping_bag;
        break;
      case 'picked_up':
        buttonText = 'Start Delivery';
        nextStatus = 'out_for_delivery';
        buttonColor = Colors.purple.shade600;
        buttonIcon = Icons.delivery_dining;
        break;
      case 'out_for_delivery':
        buttonText = 'Mark as Delivered';
        nextStatus = 'delivered';
        buttonColor = Colors.green.shade600;
        buttonIcon = Icons.check_circle;
        break;
      case 'delivered':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade400, Colors.green.shade600],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 48),
              const SizedBox(height: 12),
              Text(
                'Order Completed Successfully!',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You earned \$${_calculateEarnings().toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: isUpdatingStatus ? null : () => _updateOrderStatus(nextStatus),
        icon: Icon(buttonIcon),
        label: isUpdatingStatus
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(
                buttonText,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m ago';
    } else {
      return '${difference.inMinutes}m ago';
    }
  }
}