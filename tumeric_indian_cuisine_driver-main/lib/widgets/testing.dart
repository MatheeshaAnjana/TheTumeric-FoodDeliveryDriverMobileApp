// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:tumeric_indian_cuisine_driver/pages/models/order_model.dart';
// import 'package:tumeric_indian_cuisine_driver/pages/services/order_services.dart';


// class FirestoreDebugWidget extends StatefulWidget {
//   const FirestoreDebugWidget({super.key});

//   @override
//   State<FirestoreDebugWidget> createState() => _FirestoreDebugWidgetState();
// }

// class _FirestoreDebugWidgetState extends State<FirestoreDebugWidget> {
//   final OrderService _orderService = OrderService();
//   bool isLoading = false;
//   String debugOutput = '';
//   List<OrderModel> testOrders = [];

//   void _addDebugLog(String message) {
//     setState(() {
//       debugOutput += '${DateTime.now().toString().substring(11, 19)}: $message\n';
//     });
//     print(message);
//   }

//   Future<void> _testFirestoreConnection() async {
//     setState(() {
//       isLoading = true;
//       debugOutput = '';
//     });

//     _addDebugLog('🔄 Testing Firestore connection...');

//     try {
//       Map<String, dynamic> result = await _orderService.testFirestoreConnection();
      
//       if (result['success']) {
//         _addDebugLog('✅ Firestore connection successful!');
//         _addDebugLog('📊 Orders found: ${result['orders_count']}');
//         _addDebugLog('👤 User authenticated: ${result['user_authenticated']}');
//         _addDebugLog('🆔 User ID: ${result['user_id']}');
        
//         if (result['orders_sample'] != null && result['orders_sample'].isNotEmpty) {
//           _addDebugLog('📝 Sample orders:');
//           for (var order in result['orders_sample']) {
//             _addDebugLog('  - ${order['id']}: ${order['data']['status'] ?? 'No status'}');
//           }
//         } else {
//           _addDebugLog('⚠️ No orders found in database');
//         }
//       } else {
//         _addDebugLog('❌ Firestore connection failed: ${result['error']}');
//       }
//     } catch (e) {
//       _addDebugLog('❌ Connection test error: $e');
//     }

//     setState(() {
//       isLoading = false;
//     });
//   }

//   Future<void> _checkSecurityRules() async {
//     setState(() {
//       isLoading = true;
//     });

//     _addDebugLog('🔄 Checking security rules...');

//     try {
//       Map<String, dynamic> result = await _orderService.checkSecurityRules();
      
//       _addDebugLog('📖 Can read: ${result['canRead']}');
//       _addDebugLog('✏️ Can write: ${result['canWrite']}');
//       _addDebugLog('👤 Current user: ${result['user']}');

//       if (!result['canRead']) {
//         _addDebugLog('⚠️ READ PERMISSION DENIED - Check Firestore rules!');
//       }
//       if (!result['canWrite']) {
//         _addDebugLog('⚠️ WRITE PERMISSION DENIED - Check Firestore rules!');
//       }
//     } catch (e) {
//       _addDebugLog('❌ Security check error: $e');
//     }

//     setState(() {
//       isLoading = false;
//     });
//   }

//   Future<void> _fetchAllOrders() async {
//     setState(() {
//       isLoading = true;
//     });

//     _addDebugLog('🔄 Fetching all orders...');

//     try {
//       List<OrderModel> orders = await _orderService.getAllOrders();
//       _addDebugLog('📊 Found ${orders.length} total orders');

//       setState(() {
//         testOrders = orders;
//       });

//       if (orders.isEmpty) {
//         _addDebugLog('⚠️ No orders found in database');
//       } else {
//         _addDebugLog('📝 Orders breakdown:');
//         Map<String, int> statusCount = {};
//         for (var order in orders) {
//           statusCount[order.status] = (statusCount[order.status] ?? 0) + 1;
//         }
//         statusCount.forEach((status, count) {
//           _addDebugLog('  - $status: $count orders');
//         });
//       }
//     } catch (e) {
//       _addDebugLog('❌ Fetch all orders error: $e');
//     }

//     setState(() {
//       isLoading = false;
//     });
//   }

//   Future<void> _fetchOutForDeliveryOrders() async {
//     setState(() {
//       isLoading = true;
//     });

//     _addDebugLog('🔄 Fetching out-for-delivery orders...');

//     try {
//       List<OrderModel> orders = await _orderService.getOrdersOutForDelivery();
//       _addDebugLog('📊 Found ${orders.length} out-for-delivery orders');

//       setState(() {
//         testOrders = orders;
//       });

//       if (orders.isEmpty) {
//         _addDebugLog('⚠️ No out-for-delivery orders found');
//         _addDebugLog('💡 Tip: Create a test order or check existing order statuses');
//       }
//     } catch (e) {
//       _addDebugLog('❌ Fetch out-for-delivery error: $e');
//     }

//     setState(() {
//       isLoading = false;
//     });
//   }

//   // Future<void> _createTestOrder() async {
//   //   setState(() {
//   //     isLoading = true;
//   //   });

//   //   _addDebugLog('🔄 Creating test order...');

//   //   try {
//   //     bool success = await _orderService.createTestOrder();
//   //     if (success) {
//   //       _addDebugLog('✅ Test order created successfully!');
//   //       _addDebugLog('💡 Now try fetching orders again');
//   //     } else {
//   //       _addDebugLog('❌ Failed to create test order');
//   //     }
//   //   } catch (e) {
//   //     _addDebugLog('❌ Create test order error: $e');
//   //   }

//   //   setState(() {
//   //     isLoading = false;
//   //   });
//   // }

//   Future<void> _cleanupTestOrders() async {
//     setState(() {
//       isLoading = true;
//     });

//     _addDebugLog('🔄 Cleaning up test orders...');

//     try {
//       bool success = await _orderService.cleanupTestOrders();
//       if (success) {
//         _addDebugLog('✅ Test orders cleaned up successfully!');
//       } else {
//         _addDebugLog('❌ Failed to cleanup test orders');
//       }
//     } catch (e) {
//       _addDebugLog('❌ Cleanup error: $e');
//     }

//     setState(() {
//       isLoading = false;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.all(20),
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(15),
//         border: Border.all(color: Colors.grey[300]!),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.1),
//             blurRadius: 10,
//             offset: const Offset(0, 5),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Header
//           Row(
//             children: [
//               Icon(Icons.bug_report, color: Colors.orange[600], size: 24),
//               const SizedBox(width: 10),
//               Text(
//                 'Firestore Debug & Test',
//                 style: GoogleFonts.poppins(
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.grey[800],
//                 ),
//               ),
//               const Spacer(),
//               if (isLoading)
//                 const SizedBox(
//                   width: 20,
//                   height: 20,
//                   child: CircularProgressIndicator(strokeWidth: 2),
//                 ),
//             ],
//           ),
//           const SizedBox(height: 20),

//           // Test Buttons
//           Wrap(
//             spacing: 10,
//             runSpacing: 10,
//             children: [
//               ElevatedButton.icon(
//                 onPressed: isLoading ? null : _testFirestoreConnection,
//                 icon: const Icon(Icons.wifi, size: 16),
//                 label: const Text('Test Connection'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue[600],
//                   foregroundColor: Colors.white,
//                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 ),
//               ),
//               ElevatedButton.icon(
//                 onPressed: isLoading ? null : _checkSecurityRules,
//                 icon: const Icon(Icons.security, size: 16),
//                 label: const Text('Check Rules'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.orange[600],
//                   foregroundColor: Colors.white,
//                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 ),
//               ),
//               ElevatedButton.icon(
//                 onPressed: isLoading ? null : _fetchAllOrders,
//                 icon: const Icon(Icons.list_alt, size: 16),
//                 label: const Text('All Orders'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.green[600],
//                   foregroundColor: Colors.white,
//                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 ),
//               ),
//               ElevatedButton.icon(
//                 onPressed: isLoading ? null : _fetchOutForDeliveryOrders,
//                 icon: const Icon(Icons.local_shipping, size: 16),
//                 label: const Text('Out for Delivery'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.purple[600],
//                   foregroundColor: Colors.white,
//                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 ),
//               ),
//               ElevatedButton.icon(
//                 onPressed: isLoading ? null : _createTestOrder,
//                 icon: const Icon(Icons.add, size: 16),
//                 label: const Text('Create Test'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.teal[600],
//                   foregroundColor: Colors.white,
//                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 ),
//               ),
//               ElevatedButton.icon(
//                 onPressed: isLoading ? null : _cleanupTestOrders,
//                 icon: const Icon(Icons.delete_sweep, size: 16),
//                 label: const Text('Cleanup'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.red[600],
//                   foregroundColor: Colors.white,
//                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),

//           // Debug Output
//           if (debugOutput.isNotEmpty) ...[
//             Text(
//               'Debug Output:',
//               style: GoogleFonts.poppins(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.grey[700],
//               ),
//             ),
//             const SizedBox(height: 10),
//             Container(
//               width: double.infinity,
//               height: 200,
//               padding: const EdgeInsets.all(15),
//               decoration: BoxDecoration(
//                 color: Colors.grey[100],
//                 borderRadius: BorderRadius.circular(10),
//                 border: Border.all(color: Colors.grey[300]!),
//               ),
//               child: SingleChildScrollView(
//                 child: Text(
//                   debugOutput,
//                   style: GoogleFonts.sourceCodePro(
//                     fontSize: 12,
//                     color: Colors.grey[800],
//                     height: 1.4,
//                   ),
//                 ),
//               ),
//             ),
//           ],

//           // Orders List
//           if (testOrders.isNotEmpty) ...[
//             const SizedBox(height: 20),
//             Text(
//               'Orders Found (${testOrders.length}):',
//               style: GoogleFonts.poppins(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.grey[700],
//               ),
//             ),
//             const SizedBox(height: 10),
//             Container(
//               height: 200,
//               child: ListView.builder(
//                 itemCount: testOrders.length,
//                 itemBuilder: (context, index) {
//                   final order = testOrders[index];
//                   return Container(
//                     margin: const EdgeInsets.only(bottom: 8),
//                     padding: const EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(8),
//                       border: Border.all(color: Colors.grey[300]!),
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           'Order ID: ${order.orderId}',
//                           style: GoogleFonts.sourceCodePro(
//                             fontSize: 12,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.blue[700],
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           'Status: ${order.status}',
//                           style: GoogleFonts.poppins(
//                             fontSize: 14,
//                             color: _getStatusColor(order.status),
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                         Text(
//                           'Total: \$${order.orderTotal.toStringAsFixed(2)}',
//                           style: GoogleFonts.poppins(
//                             fontSize: 12,
//                             color: Colors.grey[600],
//                           ),
//                         ),
//                         Text(
//                           'Address: ${order.deliveryAddress}',
//                           style: GoogleFonts.poppins(
//                             fontSize: 12,
//                             color: Colors.grey[600],
//                           ),
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ],
//                     ),
//                   );
//                 },
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Color _getStatusColor(String status) {
//     switch (status) {
//       case 'out_for_delivery':
//         return Colors.orange[600]!;
//       case 'delivered':
//         return Colors.green[600]!;
//       case 'pending':
//         return Colors.blue[600]!;
//       case 'cancelled':
//         return Colors.red[600]!;
//       default:
//         return Colors.grey[600]!;
//     }
//   }
// }