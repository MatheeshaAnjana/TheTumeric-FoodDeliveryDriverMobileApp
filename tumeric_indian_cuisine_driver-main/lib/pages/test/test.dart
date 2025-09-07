import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class DebugTestPage extends StatefulWidget {
  const DebugTestPage({super.key});

  @override
  State<DebugTestPage> createState() => _DebugTestPageState();
}

class _DebugTestPageState extends State<DebugTestPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String _result = 'Tap "Test Connection" to check Firestore';
  
  Future<void> _testFirestoreConnection() async {
    setState(() {
      _isLoading = true;
      _result = 'Testing connection...';
    });
    
    try {
      // Test basic Firestore connection
      await _firestore.collection('deliveryPersonnel').limit(1).get();
      
      // Get all documents to see what's available
      QuerySnapshot snapshot = await _firestore.collection('deliveryPersonnel').get();
      
      List<String> results = [];
      results.add('✅ Firestore connection successful!');
      results.add('📊 Found ${snapshot.docs.length} documents');
      results.add('');
      results.add('📋 Available personnel:');
      
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        results.add('');
        results.add('🔍 Document ID: ${doc.id}');
        results.add('👤 Name: ${data['fullName'] ?? 'Unknown'}');
        results.add('🏷️ Personnel ID: ${data['personnelId'] ?? 'Unknown'}');
        results.add('📧 Email: ${data['email'] ?? 'Unknown'}');
        results.add('🚲 Vehicle: ${data['vehicleType'] ?? 'Unknown'}');
        results.add('✨ Status: ${data['status'] ?? 'Unknown'}');
        results.add('─────────────────────');
      }
      
      if (snapshot.docs.isEmpty) {
        results.add('⚠️ No documents found in deliveryPersonnel collection');
        results.add('');
        results.add('💡 Make sure:');
        results.add('• Collection name is "deliveryPersonnel"');
        results.add('• Documents exist in Firestore');
        results.add('• Firestore rules allow read access');
      }
      
      setState(() {
        _result = results.join('\n');
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        _result = '❌ Error connecting to Firestore:\n\n$e\n\n💡 Check:\n• Internet connection\n• Firebase configuration\n• Firestore rules';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _testSpecificPersonnel(String personnelId) async {
    setState(() {
      _isLoading = true;
      _result = 'Searching for $personnelId...';
    });
    
    try {
      QuerySnapshot query = await _firestore
          .collection('deliveryPersonnel')
          .where('personnelId', isEqualTo: personnelId)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        Map<String, dynamic> data = query.docs.first.data() as Map<String, dynamic>;
        setState(() {
          _result = '✅ Found personnel!\n\nDocument ID: ${query.docs.first.id}\nName: ${data['fullName']}\nEmail: ${data['email']}\nPhone: ${data['phoneNumber']}\nVehicle: ${data['vehicleType']}\nStatus: ${data['status']}\nActive: ${data['isActive']}';
          _isLoading = false;
        });
      } else {
        setState(() {
          _result = '❌ Personnel "$personnelId" not found!\n\nDouble-check the personnel ID in your Firestore collection.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _result = '❌ Error searching for personnel:\n\n$e';
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Firestore Debug',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Test buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _testFirestoreConnection,
                    icon: const Icon(Icons.cloud),
                    label: const Text('Test Connection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _testSpecificPersonnel('DP001'),
                    icon: const Icon(Icons.search),
                    label: const Text('Find DP001'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Custom search
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Enter Personnel ID',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., DP001',
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        _testSpecificPersonnel(value.trim());
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    // You can implement custom search logic here
                  },
                  icon: const Icon(Icons.search),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Results display
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: _isLoading
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading...'),
                        ],
                      )
                    : SingleChildScrollView(
                        child: Text(
                          _result,
                          style: GoogleFonts.robotoMono(
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Quick actions
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Navigate to profile page with known ID
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfilePage(personnelId: 'DP001'),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Go to Profile (DP001)'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _result = 'Debug cleared';
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Clear'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📋 Debug Instructions:',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Click "Test Connection" to verify Firestore works\n'
                    '2. Click "Find DP001" to test the specific personnel\n'
                    '3. Check the results for any errors\n'
                    '4. Use "Go to Profile" to test the actual profile page',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.blue[700],
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
}

// Import this at the top of the file where you use it
class ProfilePage extends StatelessWidget {
  final String personnelId;
  
  const ProfilePage({super.key, required this.personnelId});
  
  @override
  Widget build(BuildContext context) {
    // This is a placeholder - replace with your actual ProfilePage
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile: $personnelId'),
      ),
      body: Center(
        child: Text('Profile page for $personnelId'),
      ),
    );
  }
}