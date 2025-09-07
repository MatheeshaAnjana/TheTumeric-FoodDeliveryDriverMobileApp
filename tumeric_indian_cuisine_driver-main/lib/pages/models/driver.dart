import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class DeliveryPersonnelModel {
  final String id;
  final String address;
  final String availability;
  final DateTime createdAt;
  final List<String> currentOrders;
  final String email;
  final String fullName;
  final bool isActive;
  final DateTime joiningDate;
  final String licenseNumber;
  final String password;
  final String personnelId;
  final String phoneNumber;
  final String profileImageUrl;
  final double rating;
  final String status;
  final int totalDeliveries;
  final DateTime updatedAt;
  final String vehicleType;

  DeliveryPersonnelModel({
    required this.id,
    required this.address,
    required this.availability,
    required this.createdAt,
    required this.currentOrders,
    required this.email,
    required this.fullName,
    required this.isActive,
    required this.joiningDate,
    required this.licenseNumber,
    required this.password,
    required this.personnelId,
    required this.phoneNumber,
    required this.profileImageUrl,
    required this.rating,
    required this.status,
    required this.totalDeliveries,
    required this.updatedAt,
    required this.vehicleType,
  });

  factory DeliveryPersonnelModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return DeliveryPersonnelModel(
      id: doc.id,
      address: data['address'] ?? '',
      availability: data['availability'] ?? 'inactive',
      createdAt: _parseTimestamp(data['createdAt']),
      currentOrders: List<String>.from(data['currentOrders'] ?? []),
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      isActive: data['isActive'] ?? false,
      joiningDate: _parseTimestamp(data['joiningDate']),
      licenseNumber: data['licenseNumber'] ?? '',
      password: data['password'] ?? '',
      personnelId: data['personnelId'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
      rating: (data['rating'] ?? 0).toDouble(),
      status: data['status'] ?? 'unavailable',
      totalDeliveries: data['totalDeliveries'] ?? 0,
      updatedAt: _parseTimestamp(data['updatedAt']),
      vehicleType: data['vehicleType'] ?? '',
    );
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    return DateTime.now();
  }

  Map<String, dynamic> toFirestore() {
    return {
      'address': address,
      'availability': availability,
      'createdAt': Timestamp.fromDate(createdAt),
      'currentOrders': currentOrders,
      'email': email,
      'fullName': fullName,
      'isActive': isActive,
      'joiningDate': Timestamp.fromDate(joiningDate),
      'licenseNumber': licenseNumber,
      'password': password,
      'personnelId': personnelId,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'rating': rating,
      'status': status,
      'totalDeliveries': totalDeliveries,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'vehicleType': vehicleType,
    };
  }

  DeliveryPersonnelModel copyWith({
    String? address,
    String? availability,
    DateTime? createdAt,
    List<String>? currentOrders,
    String? email,
    String? fullName,
    bool? isActive,
    DateTime? joiningDate,
    String? licenseNumber,
    String? password,
    String? personnelId,
    String? phoneNumber,
    String? profileImageUrl,
    double? rating,
    String? status,
    int? totalDeliveries,
    DateTime? updatedAt,
    String? vehicleType,
  }) {
    return DeliveryPersonnelModel(
      id: id,
      address: address ?? this.address,
      availability: availability ?? this.availability,
      createdAt: createdAt ?? this.createdAt,
      currentOrders: currentOrders ?? this.currentOrders,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      isActive: isActive ?? this.isActive,
      joiningDate: joiningDate ?? this.joiningDate,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      password: password ?? this.password,
      personnelId: personnelId ?? this.personnelId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      rating: rating ?? this.rating,
      status: status ?? this.status,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      updatedAt: updatedAt ?? this.updatedAt,
      vehicleType: vehicleType ?? this.vehicleType,
    );
  }
}

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collectionName = 'deliveryPersonnel';

  // Upload profile image to Firebase Storage
  Future<String?> uploadProfileImage(String personnelId, File imageFile) async {
    try {
      print('Uploading profile image for personnel: $personnelId');

      // Create a reference to the location you want to upload to in Firebase Storage
      final String fileName =
          'profile_images/${personnelId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = _storage.ref().child(fileName);

      // Upload the file
      final UploadTask uploadTask = storageRef.putFile(imageFile);

      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;

      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      print('Profile image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading profile image: $e');
      throw Exception('Error uploading profile image: $e');
    }
  }

  // Delete old profile image from Firebase Storage
  Future<void> deleteProfileImage(String imageUrl) async {
    try {
      if (imageUrl.isEmpty || !imageUrl.contains('firebase')) return;

      final Reference storageRef = _storage.refFromURL(imageUrl);
      await storageRef.delete();
      print('Old profile image deleted successfully');
    } catch (e) {
      print('Error deleting old profile image: $e');
      // Don't throw error here as it's not critical
    }
  }

  // Update profile image
  Future<String?> updateProfileImage(String personnelId, File imageFile) async {
    try {
      // Get current personnel data to get old image URL
      final personnel = await getDeliveryPersonnelByPersonnelId(personnelId);
      if (personnel == null) {
        throw Exception('Personnel not found');
      }

      // Upload new image
      final String? newImageUrl = await uploadProfileImage(
        personnelId,
        imageFile,
      );
      if (newImageUrl == null) {
        throw Exception('Failed to upload new image');
      }

      // Update Firestore with new image URL
      await updateDeliveryPersonnel(personnel.id, {
        'profileImageUrl': newImageUrl,
      });

      // Delete old image if it exists
      if (personnel.profileImageUrl.isNotEmpty) {
        await deleteProfileImage(personnel.profileImageUrl);
      }

      print('Profile image updated successfully');
      return newImageUrl;
    } catch (e) {
      print('Error updating profile image: $e');
      throw Exception('Error updating profile image: $e');
    }
  }

  // Get delivery personnel by ID
  Future<DeliveryPersonnelModel?> getDeliveryPersonnel(String id) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection(_collectionName).doc(id).get();
      if (doc.exists) {
        return DeliveryPersonnelModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error fetching delivery personnel: $e');
      throw Exception('Error fetching delivery personnel: $e');
    }
  }

  // Get delivery personnel by personnel ID
  Future<DeliveryPersonnelModel?> getDeliveryPersonnelByPersonnelId(
    String personnelId,
  ) async {
    try {
      print('Searching for personnel ID: $personnelId');
      QuerySnapshot query =
          await _firestore
              .collection(_collectionName)
              .where('personnelId', isEqualTo: personnelId)
              .limit(1)
              .get();

      print(
        'Found ${query.docs.length} documents for personnel ID: $personnelId',
      );

      if (query.docs.isNotEmpty) {
        return DeliveryPersonnelModel.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      print('Error fetching delivery personnel by personnel ID: $e');
      throw Exception('Error fetching delivery personnel by personnel ID: $e');
    }
  }

  // Get delivery personnel by email
  Future<DeliveryPersonnelModel?> getDeliveryPersonnelByEmail(
    String email,
  ) async {
    try {
      print('Searching for email: $email');
      QuerySnapshot query =
          await _firestore
              .collection(_collectionName)
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

      print('Found ${query.docs.length} documents for email: $email');

      if (query.docs.isNotEmpty) {
        return DeliveryPersonnelModel.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      print('Error fetching delivery personnel by email: $e');
      throw Exception('Error fetching delivery personnel by email: $e');
    }
  }

  // LOGIN WITH EMAIL
  Future<DeliveryPersonnelModel?> loginWithEmail(
    String email,
    String password,
  ) async {
    try {
      print('Attempting login with email: $email');

      QuerySnapshot query =
          await _firestore
              .collection(_collectionName)
              .where('email', isEqualTo: email)
              .where('password', isEqualTo: password)
              .limit(1)
              .get();

      print('Login query returned ${query.docs.length} documents');

      if (query.docs.isNotEmpty) {
        DeliveryPersonnelModel personnel = DeliveryPersonnelModel.fromFirestore(
          query.docs.first,
        );
        print('Login successful for: ${personnel.fullName}');
        return personnel;
      }

      print('Login failed - no matching email/password combination');
      return null;
    } catch (e) {
      print('Error during email login: $e');
      throw Exception('Error during login: $e');
    }
  }

  // LOGIN WITH PERSONNEL ID
  Future<DeliveryPersonnelModel?> loginWithPersonnelId(
    String personnelId,
    String password,
  ) async {
    try {
      print('Attempting login with personnel ID: $personnelId');

      QuerySnapshot query =
          await _firestore
              .collection(_collectionName)
              .where('personnelId', isEqualTo: personnelId)
              .where('password', isEqualTo: password)
              .limit(1)
              .get();

      print('Login query returned ${query.docs.length} documents');

      if (query.docs.isNotEmpty) {
        DeliveryPersonnelModel personnel = DeliveryPersonnelModel.fromFirestore(
          query.docs.first,
        );
        print('Login successful for: ${personnel.fullName}');
        return personnel;
      }

      print('Login failed - no matching personnel ID/password combination');
      return null;
    } catch (e) {
      print('Error during personnel ID login: $e');
      throw Exception('Error during login: $e');
    }
  }

  // Create new delivery personnel
  Future<String> createDeliveryPersonnel(
    DeliveryPersonnelModel personnel,
  ) async {
    try {
      DocumentReference docRef = await _firestore
          .collection(_collectionName)
          .add(personnel.toFirestore());
      print('Created new delivery personnel with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error creating delivery personnel: $e');
      throw Exception('Error creating delivery personnel: $e');
    }
  }

  // Update delivery personnel
  Future<void> updateDeliveryPersonnel(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] = Timestamp.fromDate(DateTime.now());
      await _firestore.collection(_collectionName).doc(id).update(updates);
      print('Updated delivery personnel: $id');
    } catch (e) {
      print('Error updating delivery personnel: $e');
      throw Exception('Error updating delivery personnel: $e');
    }
  }

  // Update profile information
  Future<void> updateProfile(
    String id, {
    String? fullName,
    String? email,
    String? phoneNumber,
    String? address,
    String? profileImageUrl,
  }) async {
    Map<String, dynamic> updates = {};

    if (fullName != null) updates['fullName'] = fullName;
    if (email != null) updates['email'] = email;
    if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
    if (address != null) updates['address'] = address;
    if (profileImageUrl != null) updates['profileImageUrl'] = profileImageUrl;

    if (updates.isNotEmpty) {
      await updateDeliveryPersonnel(id, updates);
    }
  }

  // Update vehicle information
  Future<void> updateVehicleInfo(
    String id, {
    String? vehicleType,
    String? licenseNumber,
  }) async {
    Map<String, dynamic> updates = {};

    if (vehicleType != null) updates['vehicleType'] = vehicleType;
    if (licenseNumber != null) updates['licenseNumber'] = licenseNumber;

    if (updates.isNotEmpty) {
      await updateDeliveryPersonnel(id, updates);
    }
  }

  // Update availability status
  Future<void> updateAvailability(
    String id,
    String availability,
    String status,
  ) async {
    await updateDeliveryPersonnel(id, {
      'availability': availability,
      'status': status,
    });
  }

  // Update active status
  Future<void> updateActiveStatus(String id, bool isActive) async {
    await updateDeliveryPersonnel(id, {'isActive': isActive});
  }

  // Change password
  Future<void> changePassword(String id, String newPassword) async {
    await updateDeliveryPersonnel(id, {'password': newPassword});
  }

  // Delete delivery personnel
  Future<void> deleteDeliveryPersonnel(String id) async {
    try {
      await _firestore.collection(_collectionName).doc(id).delete();
      print('Deleted delivery personnel: $id');
    } catch (e) {
      print('Error deleting delivery personnel: $e');
      throw Exception('Error deleting delivery personnel: $e');
    }
  }

  // Get all delivery personnel (for debugging)
  Future<List<DeliveryPersonnelModel>> getAllDeliveryPersonnel() async {
    try {
      QuerySnapshot snapshot =
          await _firestore.collection(_collectionName).get();
      return snapshot.docs
          .map((doc) => DeliveryPersonnelModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error fetching all delivery personnel: $e');
      throw Exception('Error fetching all delivery personnel: $e');
    }
  }

  // Get all active delivery personnel
  Stream<List<DeliveryPersonnelModel>> getActiveDeliveryPersonnel() {
    return _firestore
        .collection(_collectionName)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => DeliveryPersonnelModel.fromFirestore(doc))
                  .toList(),
        );
  }

  // Get available delivery personnel
  Stream<List<DeliveryPersonnelModel>> getAvailableDeliveryPersonnel() {
    return _firestore
        .collection(_collectionName)
        .where('status', isEqualTo: 'available')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => DeliveryPersonnelModel.fromFirestore(doc))
                  .toList(),
        );
  }

  // TEST CONNECTION METHOD - For debugging
  Future<bool> testConnection() async {
    try {
      await _firestore.collection(_collectionName).limit(1).get();
      print('✅ Firestore connection successful');
      return true;
    } catch (e) {
      print('❌ Firestore connection failed: $e');
      return false;
    }
  }

  // GET COLLECTION INFO - For debugging
  Future<Map<String, dynamic>> getCollectionInfo() async {
    try {
      QuerySnapshot snapshot =
          await _firestore.collection(_collectionName).get();
      List<Map<String, dynamic>> docs = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        docs.add({
          'documentId': doc.id,
          'personnelId': data['personnelId'] ?? 'Unknown',
          'fullName': data['fullName'] ?? 'Unknown',
          'email': data['email'] ?? 'Unknown',
          'isActive': data['isActive'] ?? false,
          'status': data['status'] ?? 'Unknown',
        });
      }

      return {
        'collectionName': _collectionName,
        'documentCount': snapshot.docs.length,
        'documents': docs,
      };
    } catch (e) {
      throw Exception('Error getting collection info: $e');
    }
  }
}
