import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io';
import '../models/driver.dart';
import '../sign_in_page.dart';

class ProfilePage extends StatefulWidget {
  final String personnelId;

  const ProfilePage({super.key, required this.personnelId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _imagePicker = ImagePicker();
  
  DeliveryPersonnelModel? _deliveryPersonnel;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isUploadingImage = false;

  // Online status from Firestore
  bool _isOnline = false;
  String _driverId = '';

  // Timer for periodic updates
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadDriverStatus();
    _loadProfileData();
    _startPeriodicRefresh();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  // Load basic driver info from SharedPreferences
  Future<void> _loadDriverStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _driverId = prefs.getString('driver_id') ?? '';
      });
      debugPrint('Loaded driverId: $_driverId');
    } catch (e) {
      debugPrint('Error loading driver status: $e');
    }
  }

  // Start periodic refresh instead of stream
  void _startPeriodicRefresh() {
    // Refresh every 10 seconds to get updated status
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _refreshOnlineStatus();
      }
    });
  }

  // Refresh online status from Firestore
  Future<void> _refreshOnlineStatus() async {
    if (_deliveryPersonnel == null) return;

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('deliveryPersonnel')
              .doc(_deliveryPersonnel!.id)
              .get();

      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        final newOnlineStatus = data['isActive'] ?? false;

        if (newOnlineStatus != _isOnline) {
          setState(() {
            _isOnline = newOnlineStatus;
          });
          debugPrint('Online status refreshed: $_isOnline');
        }
      }
    } catch (e) {
      debugPrint('Error refreshing online status: $e');
    }
  }

  Future<void> _loadProfileData() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
      });

      debugPrint('Loading profile for personnel ID: ${widget.personnelId}');

      bool isConnected = await _firestoreService.testConnection();
      if (!isConnected) {
        throw Exception('Failed to connect to Firestore');
      }

      final personnel = await _firestoreService
          .getDeliveryPersonnelByPersonnelId(widget.personnelId);

      if (personnel != null) {
        debugPrint('Personnel found: ${personnel.fullName}');
        if (mounted) {
          setState(() {
            _deliveryPersonnel = personnel;
            _isOnline = personnel.isActive; // Set initial online status
            _isLoading = false;
          });
          _animationController.forward();
        }
      } else {
        debugPrint('Personnel not found, checking all personnel...');
        final collectionInfo = await _firestoreService.getCollectionInfo();

        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage =
                'Profile not found for ID: ${widget.personnelId}.\n'
                'Available Personnel:\n'
                '${collectionInfo['documents'].map((doc) => '${doc['personnelId']} - ${doc['fullName']}').join('\n')}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error loading profile: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Profile image picker and upload functionality
  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose Profile Picture',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: Text('Take Photo', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: Text('Choose from Gallery', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_deliveryPersonnel?.profileImageUrl.isNotEmpty ?? false)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text('Remove Photo', style: GoogleFonts.poppins()),
                  onTap: () {
                    Navigator.pop(context);
                    _removeProfileImage();
                  },
                ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);
        await _uploadProfileImage(imageFile);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      _showErrorSnackBar('Failed to pick image: ${e.toString()}');
    }
  }

  Future<void> _uploadProfileImage(File imageFile) async {
    if (_deliveryPersonnel == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      // Upload image and get new URL
      final String? newImageUrl = await _firestoreService.updateProfileImage(
        widget.personnelId,
        imageFile,
      );

      if (newImageUrl != null) {
        // Update local state
        setState(() {
          _deliveryPersonnel = _deliveryPersonnel!.copyWith(
            profileImageUrl: newImageUrl,
          );
          _isUploadingImage = false;
        });

        _showSuccessSnackBar('Profile picture updated successfully!');
      } else {
        throw Exception('Failed to get image URL');
      }
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      setState(() {
        _isUploadingImage = false;
      });
      _showErrorSnackBar('Failed to update profile picture: ${e.toString()}');
    }
  }

  Future<void> _removeProfileImage() async {
    if (_deliveryPersonnel == null) return;

    bool confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Remove Profile Picture', style: GoogleFonts.poppins()),
            content: Text(
              'Are you sure you want to remove your profile picture?',
              style: GoogleFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: GoogleFonts.poppins()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Remove',
                  style: GoogleFonts.poppins(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      // Delete old image from storage
      if (_deliveryPersonnel!.profileImageUrl.isNotEmpty) {
        await _firestoreService.deleteProfileImage(
          _deliveryPersonnel!.profileImageUrl,
        );
      }

      // Update Firestore with empty image URL
      await _firestoreService.updateProfile(
        _deliveryPersonnel!.id,
        profileImageUrl: '',
      );

      // Update local state
      setState(() {
        _deliveryPersonnel = _deliveryPersonnel!.copyWith(
          profileImageUrl: '',
        );
        _isUploadingImage = false;
      });

      _showSuccessSnackBar('Profile picture removed successfully!');
    } catch (e) {
      debugPrint('Error removing profile image: $e');
      setState(() {
        _isUploadingImage = false;
      });
      _showErrorSnackBar('Failed to remove profile picture: ${e.toString()}');
    }
  }

  // Toggle online status and update Firestore
  Future<void> _toggleOnlineStatus() async {
    if (_deliveryPersonnel == null) return;

    try {
      final newStatus = !_isOnline;

      // Update Firestore
      await _firestoreService.updateActiveStatus(
        _deliveryPersonnel!.id,
        newStatus,
      );

      // Update SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('driver_online_status', newStatus);

      // Update local state (will also be updated by stream)
      setState(() {
        _isOnline = newStatus;
      });

      _showSuccessSnackBar(
        newStatus ? 'You are now online!' : 'You are now offline!',
      );

      debugPrint('Online status updated to: $newStatus');
    } catch (e) {
      debugPrint('Error updating online status: $e');
      _showErrorSnackBar('Failed to update online status');
    }
  }

  Future<void> _logout() async {
    try {
      bool shouldLogout = await _showLogoutConfirmation();
      if (!shouldLogout) return;

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // If user is online, set them offline before logout
      if (_isOnline && _deliveryPersonnel != null) {
        await _firestoreService.updateActiveStatus(
          _deliveryPersonnel!.id,
          false,
        );
      }

      // Sign out from Firebase Auth
      await _auth.signOut();

      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_logged_in');
      await prefs.remove('driver_id');
      await prefs.remove('firebase_uid');
      await prefs.remove('driver_online_status');
      await prefs.remove('personnel_id');
      await prefs.remove('full_name');
      await prefs.remove('user_email');

      if (mounted) Navigator.of(context).pop(); // Hide loading

      // Navigate to login page
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
        );
      }

      debugPrint('User successfully logged out');
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // Hide loading
      debugPrint('Error during logout: $e');
      _showErrorSnackBar('Failed to logout: ${e.toString()}');
    }
  }

  Future<bool> _showLogoutConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(
                  'Logout',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Are you sure you want to logout?',
                      style: GoogleFonts.poppins(),
                    ),
                    if (_isOnline) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning,
                              color: Colors.orange.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You are currently online. Logging out will set you offline.',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('Cancel', style: GoogleFonts.poppins()),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      'Logout',
                      style: GoogleFonts.poppins(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
        ) ??
        false;
  }

  Future<void> _editProfile() async {
    if (_deliveryPersonnel == null) return;

    final result = await _showEditProfileDialog();
    if (result != null && result.isNotEmpty) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => const Center(child: CircularProgressIndicator()),
        );

        // Update profile in Firestore
        await _firestoreService.updateProfile(
          _deliveryPersonnel!.id,
          fullName: result['fullName'],
          email: result['email'],
          phoneNumber: result['phoneNumber'],
          address: result['address'],
        );

        // Update SharedPreferences with new data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'full_name',
          result['fullName'] ?? _deliveryPersonnel!.fullName,
        );
        await prefs.setString(
          'user_email',
          result['email'] ?? _deliveryPersonnel!.email,
        );

        // Update local _deliveryPersonnel object to reflect changes
        setState(() {
          _deliveryPersonnel = _deliveryPersonnel!.copyWith(
            fullName:
                result['fullName']?.isNotEmpty == true
                    ? result['fullName']
                    : _deliveryPersonnel!.fullName,
            email:
                result['email']?.isNotEmpty == true
                    ? result['email']
                    : _deliveryPersonnel!.email,
            phoneNumber:
                result['phoneNumber']?.isNotEmpty == true
                    ? result['phoneNumber']
                    : _deliveryPersonnel!.phoneNumber,
            address:
                result['address']?.isNotEmpty == true
                    ? result['address']
                    : _deliveryPersonnel!.address,
          );
        });

        // Hide loading indicator
        if (mounted) Navigator.of(context).pop();

        _showSuccessSnackBar('Profile updated successfully');
      } catch (e) {
        // Hide loading indicator
        if (mounted) Navigator.of(context).pop();

        _showErrorSnackBar('Failed to update profile: ${e.toString()}');
      }
    }
  }

  Future<Map<String, String>?> _showEditProfileDialog() async {
    final fullNameController = TextEditingController(
      text: _deliveryPersonnel?.fullName ?? '',
    );
    final emailController = TextEditingController(
      text: _deliveryPersonnel?.email ?? '',
    );
    final phoneController = TextEditingController(
      text: _deliveryPersonnel?.phoneNumber ?? '',
    );
    final addressController = TextEditingController(
      text: _deliveryPersonnel?.address ?? '',
    );

    return showDialog<Map<String, String>>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Edit Profile',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: fullNameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      labelStyle: GoogleFonts.poppins(),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: GoogleFonts.poppins(),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      labelStyle: GoogleFonts.poppins(),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: addressController,
                    decoration: InputDecoration(
                      labelText: 'Address',
                      labelStyle: GoogleFonts.poppins(),
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.poppins()),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'fullName': fullNameController.text,
                    'email': emailController.text,
                    'phoneNumber': phoneController.text,
                    'address': addressController.text,
                  });
                },
                child: Text(
                  'Save',
                  style: GoogleFonts.poppins(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading profile...',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasError) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text('Profile Error', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Profile Not Found',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.red[700],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: _loadProfileData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Retry', style: GoogleFonts.poppins()),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _logout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Logout', style: GoogleFonts.poppins()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_deliveryPersonnel == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text('Profile', style: GoogleFonts.poppins()),
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'No profile data available',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _loadProfileData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Retry', style: GoogleFonts.poppins()),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Logout', style: GoogleFonts.poppins()),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF4A300), Color(0xFFFFD166)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.only(top: 20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 30),
                        _buildProfileCard(),
                        const SizedBox(height: 25),
                        _buildStatsRow(),
                        const SizedBox(height: 30),
                        _buildPersonalInfo(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(25),
      child: Row(
        children: [
          const Spacer(),
          Text(
            'My Profile',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF4A300), Color(0xFFFFD166)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile Picture with Upload functionality
          GestureDetector(
            onTap: _isUploadingImage ? null : _showImageSourceDialog,
            child: Stack(
              children: [
                // Profile image container
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: ClipOval(
                    child: _isUploadingImage
                        ? Container(
                            color: Colors.white,
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFF4A300),
                                ),
                              ),
                            ),
                          )
                        : (_deliveryPersonnel?.profileImageUrl?.isNotEmpty ?? false)
                            ? Image.network(
                                _deliveryPersonnel!.profileImageUrl,
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: Colors.white,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFFF4A300),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.white,
                                    child: const Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: Colors.white,
                                child: const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              ),
                  ),
                ),
                // Camera icon overlay
                if (!_isUploadingImage)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFF4A300), width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 14,
                        color: Color(0xFFF4A300),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Text(
            _deliveryPersonnel?.fullName ?? 'Unknown',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Driver ID: ${_deliveryPersonnel?.personnelId ?? 'Unknown'}',
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25),
      width: 200,
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.local_shipping,
              title: 'Total Deliveries',
              value: (_deliveryPersonnel?.totalDeliveries ?? 0).toString(),
              gradient: [Colors.blue.shade400, Colors.blue.shade600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Information',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 15),
          _buildInfoCard(
            Icons.email,
            'Email',
            _deliveryPersonnel?.email ?? 'Not provided',
          ),
          const SizedBox(height: 10),
          _buildInfoCard(
            Icons.phone,
            'Phone',
            _deliveryPersonnel?.phoneNumber ?? 'Not provided',
          ),
          const SizedBox(height: 10),
          _buildInfoCard(
            Icons.location_on,
            'Address',
            _deliveryPersonnel?.address ?? 'Not provided',
          ),
          const SizedBox(height: 10),
          _buildInfoCard(
            Icons.directions_bike,
            'Vehicle',
            (_deliveryPersonnel?.vehicleType ?? 'Not specified').toUpperCase(),
          ),
          const SizedBox(height: 10),
          _buildInfoCard(
            Icons.badge,
            'License Number',
            _deliveryPersonnel?.licenseNumber ?? 'Not provided',
          ),
          const SizedBox(height: 30),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _editProfile,
                  icon: const Icon(Icons.edit),
                  label: Text('Edit Profile', style: GoogleFonts.poppins()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: Text('Logout', style: GoogleFonts.poppins()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color(0xFFF4A300).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Color(0xFFF4A300), size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}