import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tumeric_indian_cuisine_driver/pages/models/order_model.dart';
import 'package:tumeric_indian_cuisine_driver/pages/navigate_pages/home_page_navigate.dart';
import 'package:tumeric_indian_cuisine_driver/pages/navigate_pages/profile_page.dart';
import 'package:tumeric_indian_cuisine_driver/pages/services/order_services.dart';

import 'order_history_page.dart';

class HomePage extends StatefulWidget {
  final String personellId;

  const HomePage({super.key, required this.personellId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  String _driverId = '';
  String _driverName = '';
  bool _isOnline = false;
  OrderModel? _currentOrder;

  final OrderService _orderService = OrderService();

  final List<String> _pageTitles = ['Dashboard', 'Order History', 'Profile'];

  @override
  void initState() {
    super.initState();
    _loadDriverInfo();
    // _setupCurrentOrderListener();
  }

  Future<void> _loadDriverInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _driverId = prefs.getString('driver_id') ?? '';
      _driverName = prefs.getString('full_name') ?? 'Driver';
      _isOnline = prefs.getBool('driver_online_status') ?? false;
    });
  }

  // void _setupCurrentOrderListener() {
  //   if (_driverId.isNotEmpty) {
  //     _orderService.getDriverActiveOrdersStream(_driverId).listen((orders) {
  //       if (mounted) {
  //         setState(() {
  //           _currentOrder = orders.isNotEmpty ? orders.first : null;
  //         });
  //       }
  //     });
  //   }
  // }

  List<Widget> _getPages() {
    return [
      const HomePageNavigate(),
      OrderHistoryPage(personnelId: widget.personellId),
      ProfilePage(personnelId: widget.personellId),
    ];
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = _getPages();

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home,
                label: 'Home',
                index: 0,
                isActive: _currentIndex == 0,
              ),
              _buildNavItem(
                icon: Icons.history,
                label: 'History',
                index: 1,
                isActive: _currentIndex == 1,
              ),
              _buildNavItem(
                icon: Icons.person,
                label: 'Profile',
                index: 2,
                isActive: _currentIndex == 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Icon(
                  icon,
                  color: isActive ? Color(0xFFF4A300) : Colors.grey.shade600,
                  size: 24,
                ),
                // Show badge for current order on home tab
                if (index == 0 && _currentOrder != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade600,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isActive ? Color(0xFFF4A300) : Colors.grey.shade600,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
