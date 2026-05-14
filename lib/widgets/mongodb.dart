import 'dart:developer';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:e_telly_app/dbhelper/constant.dart';

class MongoDatabase {
  static Db? db;
  static DbCollection? userCollection;
  static DbCollection? reportsCollection;
  static DbCollection? alertsCollection;
  static DbCollection? evacuationCentersCollection;
  
  static Future<void> connect() async {
    try {
      print('Connecting to MongoDB Atlas...');
      String hiddenUrl = _hidePasswordInUrl(MONGO_CONN_URL);
      print('Connection URL: ${hiddenUrl.substring(0, 60)}...');
      
      db = await Db.create(MONGO_CONN_URL);
      await db!.open();
      print('Database opened successfully');
      print('Connection state: ${db!.isConnected}');
      
      // Use the database from the connection
      userCollection = db!.collection(USER_COLLECTION);
      reportsCollection = db!.collection(REPORT_COLLECTION_NAME);
      alertsCollection = db!.collection(ALERT_COLLECTION_NAME);
      evacuationCentersCollection = db!.collection(EVACUATIONCENTER_COLLECTION_NAME);
      
      print('User collection initialized');
      print('Reports collection initialized');
      print('Alerts collection initialized');
      print('Evacuation Centers collection initialized');
      
      await _createReportsIndexes();
      
      // Test connection by getting collection names from the database
      var collections = await db!.getCollectionNames();
      print('Available collections: $collections');
      
      print('Connected to MongoDB successfully!');
      
    } catch (e) {
      print('Connection error: $e');
      print('Error type: ${e.runtimeType}');
      print('Please check:');
      print('  1. IP whitelist in MongoDB Atlas');
      print('  2. Username and password are correct');
      print('  3. Database name is correct');
      print('  4. Internet connection is stable');
      
      if (e.toString().contains('Authentication failed')) {
        print('Username or password is incorrect in connection string');
      } else if (e.toString().contains('not authorized')) {
        print('User not authorized to access database');
      } else if (e.toString().contains('timed out')) {
        print('Connection timeout - check your internet and IP whitelist');
      } else if (e.toString().contains('Network is unreachable')) {
        print('Network unreachable - check your internet connection');
      }
      rethrow;
    }
  }
  
  static String _hidePasswordInUrl(String url) {
    try {
      RegExp regExp = RegExp(r'(mongodb(\+srv)?:\/\/[^:]+:)([^@]+)(@.+)');
      if (regExp.hasMatch(url)) {
        return url.replaceAllMapped(regExp, (match) {
          return '${match.group(1)}********${match.group(4)}';
        });
      }
      return url;
    } catch (e) {
      return 'URL (hidden for security)';
    }
  }
  
  static Future<void> _createReportsIndexes() async {
    try {
      if (reportsCollection != null) {
        await reportsCollection!.createIndex(
          key: 'timestamp', 
          unique: false
        );
        
        await reportsCollection!.createIndex(
          key: 'emergencyType',
          unique: false
        );
        
        await reportsCollection!.createIndex(
          key: 'status',
          unique: false
        );
        
        await reportsCollection!.createIndex(
          key: 'userData.email',
          unique: false
        );
        
        print('Reports indexes created successfully');
      }
    } catch (e) {
      print('Error creating indexes: $e');
    }
  }
  
  static Future<bool> saveEmergencyReport(Map<String, dynamic> reportData) async {
    try {
      print('Saving emergency report...');
      
      reportData['status'] = 'pending';
      reportData['isActive'] = true;
      reportData['createdAt'] = DateTime.now().toIso8601String();
      reportData['updatedAt'] = DateTime.now().toIso8601String();
      
      var result = await reportsCollection!.insertOne(reportData);
      
      if (result.isSuccess) {
        print('Emergency report saved successfully with id: ${result.id}');
        return true;
      } else {
        print('Failed to save emergency report');
        return false;
      }
    } catch (e) {
      print('Error saving emergency report: $e');
      return false;
    }
  }
  
  static Future<List<Map<String, dynamic>>> getAllEmergencyReports() async {
    try {
      print('Fetching all emergency reports...');
      
      var reports = await reportsCollection!
          .find(where.eq('isActive', true)
            ..sortBy('timestamp', descending: true))
          .toList();
      
      print('Found ${reports.length} reports');
      return reports;
    } catch (e) {
      print('Error fetching reports: $e');
      return [];
    }
  }
  
  static Future<List<Map<String, dynamic>>> getReportsByStatus(String status) async {
    try {
      print('Fetching reports with status: $status');
      
      var reports = await reportsCollection!
          .find(where.eq('status', status)
            ..sortBy('timestamp', descending: true))
          .toList();
      
      print('Found ${reports.length} reports with status: $status');
      return reports;
    } catch (e) {
      print('Error fetching reports by status: $e');
      return [];
    }
  }
  
  static Future<List<Map<String, dynamic>>> getReportsByType(String emergencyType) async {
    try {
      print('Fetching reports of type: $emergencyType');
      
      var reports = await reportsCollection!
          .find(where.eq('emergencyType', emergencyType)
            ..sortBy('timestamp', descending: true))
          .toList();
      
      print('Found ${reports.length} reports of type: $emergencyType');
      return reports;
    } catch (e) {
      print('Error fetching reports by type: $e');
      return [];
    }
  }
  
  static Future<List<Map<String, dynamic>>> getUserEmergencyReports(String email) async {
    try {
      print('Fetching reports for user: $email');
      
      var reports = await reportsCollection!
          .find(where.eq('userData.email', email)
            ..sortBy('timestamp', descending: true))
          .toList();
      
      print('Found ${reports.length} reports for user: $email');
      return reports;
    } catch (e) {
      print('Error fetching user reports: $e');
      return [];
    }
  }
  
  static Future<bool> updateReportStatus(String reportId, String newStatus) async {
    try {
      print('Updating report $reportId status to: $newStatus');
      
      var result = await reportsCollection!.updateOne(
        where.eq('_id', ObjectId.parse(reportId)),
        modify
            .set('status', newStatus)
            .set('updatedAt', DateTime.now().toIso8601String())
      );
      
      if (result.isSuccess) {
        print('Report status updated successfully');
        return true;
      } else {
        print('Failed to update report status');
        return false;
      }
    } catch (e) {
      print('Error updating report status: $e');
      return false;
    }
  }
  
  static Future<bool> deactivateReport(String reportId) async {
    try {
      print('Deactivating report: $reportId');
      
      var result = await reportsCollection!.updateOne(
        where.eq('_id', ObjectId.parse(reportId)),
        modify
            .set('isActive', false)
            .set('updatedAt', DateTime.now().toIso8601String())
      );
      
      if (result.isSuccess) {
        print('Report deactivated successfully');
        return true;
      } else {
        print('Failed to deactivate report');
        return false;
      }
    } catch (e) {
      print('Error deactivating report: $e');
      return false;
    }
  }
  
  static Future<Map<String, dynamic>> getReportStatistics() async {
    try {
      var totalReports = await reportsCollection!.count();
      var pendingReports = await reportsCollection!.count(where.eq('status', 'pending'));
      var resolvedReports = await reportsCollection!.count(where.eq('status', 'resolved'));
      var inProgressReports = await reportsCollection!.count(where.eq('status', 'in_progress'));
      
      var reportsByType = <String, int>{};
      var allReports = await reportsCollection!.find().toList();
      
      for (var report in allReports) {
        String type = report['emergencyType'] ?? 'unknown';
        reportsByType[type] = (reportsByType[type] ?? 0) + 1;
      }
      
      return {
        'total': totalReports,
        'pending': pendingReports,
        'resolved': resolvedReports,
        'inProgress': inProgressReports,
        'byType': reportsByType,
      };
    } catch (e) {
      print('Error getting report statistics: $e');
      return {
        'total': 0,
        'pending': 0,
        'resolved': 0,
        'inProgress': 0,
        'byType': {},
      };
    }
  }

  static Future<bool> insertUser(Map<String, dynamic> userData) async {
    try {
      print('========================================');
      print('Starting user insertion...');
      print('Email: ${userData['email']}');
      print('Name: ${userData['name']}');
      print('Password: [HIDDEN]');
      
      if (db == null) {
        print('ERROR: Database connection is null');
        print('Make sure connect() was called first');
        return false;
      }
      
      if (!db!.isConnected) {
        print('ERROR: Database is not connected');
        print('Current connection state: ${db!.isConnected}');
        return false;
      }
      
      print('Database connection verified');
      
      if (userCollection == null) {
        print('ERROR: User collection is null');
        return false;
      }
      
      userData['createdAt'] = DateTime.now().toIso8601String();
      userData['updatedAt'] = DateTime.now().toIso8601String();
      
      print('Attempting to insert user into MongoDB...');
      print('User data keys: ${userData.keys}');
      
      var result = await userCollection!.insertOne(userData);
      
      if (result.isSuccess) {
        print('SUCCESS: User inserted successfully: ${userData['email']}');
        print('Inserted ID: ${result.id}');
        print('========================================');
        return true;
      } else {
        print('ERROR: Insert operation failed');
        print('Result success: ${result.isSuccess}');
        print('========================================');
        return false;
      }
    } catch (e, stackTrace) {
      print('========================================');
      print('EXCEPTION in insertUser: $e');
      print('Error type: ${e.runtimeType}');
      print('Error details: ${e.toString()}');
      print('Stack trace: $stackTrace');
      print('========================================');
      return false;
    }
  }
  
  static Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    try {
      print('Looking for user: $email');
      
      if (db == null || !db!.isConnected) {
        print('Database not connected in findUserByEmail');
        return null;
      }
      
      if (userCollection == null) {
        print('User collection is null in findUserByEmail');
        return null;
      }
      
      var user = await userCollection!.findOne(where.eq('email', email));
      
      if (user != null) {
        print('User found: ${user['email']}');
        print('User name: ${user['name']}');
        return user;
      } else {
        print('User not found: $email');
        return null;
      }
    } catch (e) {
      print('Error finding user: $e');
      print('Error details: ${e.toString()}');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> findUserForLogin(String email, String password) async {
    try {
      print('Attempting login for email: $email');
      print('Password: [HIDDEN]');
      
      if (db == null || !db!.isConnected) {
        print('Database not connected');
        return null;
      }
      
      if (userCollection == null) {
        print('User collection is null');
        return null;
      }
      
      var user = await userCollection!.findOne(
        where.eq('email', email).and(where.eq('password', password))
      );
      
      if (user != null) {
        print('User found for login: ${user['email']}');
        return user;
      } else {
        print('No user found with these credentials');
        return null;
      }
    } catch (e) {
      print('Error finding user for login: $e');
      return null;
    }
  }

  static Future<bool> updateUser(String email, Map<String, dynamic> updatedData) async {
    try {
      print('Updating user with email: $email');
      print('Data to update: ${updatedData.keys}');
      
      if (db == null || !db!.isConnected) {
        print('Database not connected');
        return false;
      }
      
      if (userCollection == null) {
        print('User collection is null');
        return false;
      }
      
      updatedData.remove('_id');
      updatedData.remove('createdAt');
      updatedData.remove('email');
      updatedData.remove('password');
      
      updatedData['updatedAt'] = DateTime.now().toIso8601String();
      
      Map<String, dynamic> modifier = {
        r'$set': updatedData
      };
      
      var result = await userCollection!.updateOne(
        where.eq('email', email),
        modifier,
      );
      
      if (result.isSuccess) {
        print('User updated successfully: $email');
        return true;
      } else {
        print('Failed to update user');
        return false;
      }
    } catch (e) {
      print('Error updating user: $e');
      return false;
    }
  }

  // Get all evacuation centers from database
  static Future<List<Map<String, dynamic>>> getAllEvacuationCenters() async {
    try {
      print('Fetching all evacuation centers...');
      
      if (db == null || !db!.isConnected) {
        print('Database not connected in getAllEvacuationCenters');
        await connect();
      }
      
      if (evacuationCentersCollection == null) {
        print('Evacuation centers collection is null');
        return [];
      }
      
      var centers = await evacuationCentersCollection!.find().toList();
      
      print('Found ${centers.length} evacuation centers');
      return centers;
    } catch (e) {
      print('Error fetching evacuation centers: $e');
      return [];
    }
  }

  // Get evacuation center by ID
  static Future<Map<String, dynamic>?> getEvacuationCenterById(String id) async {
    try {
      print('Fetching evacuation center with id: $id');
      
      if (db == null || !db!.isConnected) {
        print('Database not connected in getEvacuationCenterById');
        return null;
      }
      
      if (evacuationCentersCollection == null) {
        print('Evacuation centers collection is null');
        return null;
      }
      
      var center = await evacuationCentersCollection!.findOne(
        where.eq('_id', ObjectId.parse(id))
      );
      
      return center;
    } catch (e) {
      print('Error fetching evacuation center by id: $e');
      return null;
    }
  }

  // Get active alerts
  static Future<List<Map<String, dynamic>>> getActiveAlerts() async {
    try {
      print('Fetching active alerts...');
      
      if (db == null || !db!.isConnected) {
        print('Database not connected in getActiveAlerts');
        return [];
      }
      
      if (alertsCollection == null) {
        print('Alerts collection is null');
        return [];
      }
      
      var alerts = await alertsCollection!
          .find(where.eq('isActive', true))
          .toList();
      
      print('Found ${alerts.length} active alerts');
      return alerts;
    } catch (e) {
      print('Error fetching active alerts: $e');
      return [];
    }
  }

  // ============ RESOURCE MANAGEMENT METHODS ============

  // Get all inventory items
  static Future<List<Map<String, dynamic>>> getInventoryItems() async {
    try {
      print('Fetching inventory items...');
      
      if (db == null || !db!.isConnected) {
        print('Database not connected, attempting to connect...');
        await connect();
      }
      
      var inventoryCollection = db!.collection('inventoryitems');
      var items = await inventoryCollection.find().toList();
      
      print('Found ${items.length} inventory items');
      return items;
    } catch (e) {
      print('Error fetching inventory items: $e');
      return [];
    }
  }

  // Get inventory item by ID
  static Future<Map<String, dynamic>?> getInventoryItemById(String itemId) async {
    try {
      print('Fetching inventory item with id: $itemId');
      
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      var inventoryCollection = db!.collection('inventoryitems');
      var item = await inventoryCollection.findOne(where.eq('_id', ObjectId.parse(itemId)));
      
      return item;
    } catch (e) {
      print('Error fetching inventory item: $e');
      return null;
    }
  }

  // Update inventory quantity after donation or request
  static Future<bool> updateInventoryQuantity(String itemId, int newQuantity) async {
    try {
      print('Updating inventory item $itemId to quantity: $newQuantity');
      
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      var inventoryCollection = db!.collection('inventoryitems');
      var result = await inventoryCollection.updateOne(
        where.eq('_id', ObjectId.parse(itemId)),
        modify
            .set('quantity', newQuantity)
            .set('updatedAt', DateTime.now().toIso8601String())
      );
      
      if (result.isSuccess) {
        print('Inventory updated successfully');
        return true;
      } else {
        print('Failed to update inventory');
        return false;
      }
    } catch (e) {
      print('Error updating inventory: $e');
      return false;
    }
  }

  // Submit donation
  static Future<bool> submitDonation(Map<String, dynamic> donationData) async {
    try {
      print('Submitting donation...');
      
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      // Add timestamps
      donationData['createdAt'] = DateTime.now().toIso8601String();
      donationData['updatedAt'] = DateTime.now().toIso8601String();
      
      var donationsCollection = db!.collection('donations');
      var result = await donationsCollection.insertOne(donationData);
      
      if (result.isSuccess) {
        print('Donation submitted successfully with id: ${result.id}');
        return true;
      } else {
        print('Failed to submit donation');
        return false;
      }
    } catch (e) {
      print('Error submitting donation: $e');
      return false;
    }
  }

  // Submit request
  static Future<bool> submitRequest(Map<String, dynamic> requestData) async {
    try {
      print('Submitting request...');
      
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      // Add timestamps
      requestData['createdAt'] = DateTime.now().toIso8601String();
      requestData['updatedAt'] = DateTime.now().toIso8601String();
      
      var requestsCollection = db!.collection('requests');
      var result = await requestsCollection.insertOne(requestData);
      
      if (result.isSuccess) {
        print('Request submitted successfully with id: ${result.id}');
        return true;
      } else {
        print('Failed to submit request');
        return false;
      }
    } catch (e) {
      print('Error submitting request: $e');
      return false;
    }
  }

  // Get user's requests and donations
  static Future<List<Map<String, dynamic>>> getUserRequests(String userId) async {
    try {
      print('Fetching requests for user: $userId');
      
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      var requestsCollection = db!.collection('requests');
      var requests = await requestsCollection
          .find(where.eq('userId', userId)
            ..sortBy('createdAt', descending: true))
          .toList();
      
      print('Found ${requests.length} requests for user: $userId');
      return requests;
    } catch (e) {
      print('Error fetching user requests: $e');
      return [];
    }
  }

  // Get user's donations
  static Future<List<Map<String, dynamic>>> getUserDonations(String userId) async {
    try {
      print('Fetching donations for user: $userId');
      
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      var donationsCollection = db!.collection('donations');
      var donations = await donationsCollection
          .find(where.eq('userId', userId)
            ..sortBy('createdAt', descending: true))
          .toList();
      
      print('Found ${donations.length} donations for user: $userId');
      return donations;
    } catch (e) {
      print('Error fetching user donations: $e');
      return [];
    }
  }

  // Cancel a request
  static Future<bool> cancelRequest(String requestId) async {
    try {
      print('Cancelling request: $requestId');
      
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      var requestsCollection = db!.collection('requests');
      var result = await requestsCollection.updateOne(
        where.eq('_id', ObjectId.parse(requestId)),
        modify
            .set('status', 'cancelled')
            .set('updatedAt', DateTime.now().toIso8601String())
      );
      
      if (result.isSuccess) {
        print('Request cancelled successfully');
        return true;
      } else {
        print('Failed to cancel request');
        return false;
      }
    } catch (e) {
      print('Error cancelling request: $e');
      return false;
    }
  }

  // Cancel a donation
  static Future<bool> cancelDonation(String donationId) async {
    try {
      print('Cancelling donation: $donationId');
      
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      var donationsCollection = db!.collection('donations');
      var result = await donationsCollection.updateOne(
        where.eq('_id', ObjectId.parse(donationId)),
        modify
            .set('status', 'cancelled')
            .set('updatedAt', DateTime.now().toIso8601String())
      );
      
      if (result.isSuccess) {
        print('Donation cancelled successfully');
        return true;
      } else {
        print('Failed to cancel donation');
        return false;
      }
    } catch (e) {
      print('Error cancelling donation: $e');
      return false;
    }
  }

  // Get all requests (for admin)
  static Future<List<Map<String, dynamic>>> getAllRequests() async {
    try {
      print('Fetching all requests...');
      
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      var requestsCollection = db!.collection('requests');
      var requests = await requestsCollection
          .find(where.sortBy('createdAt', descending: true))
          .toList();
      
      print('Found ${requests.length} total requests');
      return requests;
    } catch (e) {
      print('Error fetching all requests: $e');
      return [];
    }
  }

  // Get all donations (for admin)
  static Future<List<Map<String, dynamic>>> getAllDonations() async {
    try {
      print('Fetching all donations...');
      
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      var donationsCollection = db!.collection('donations');
      var donations = await donationsCollection
          .find(where.sortBy('createdAt', descending: true))
          .toList();
      
      print('Found ${donations.length} total donations');
      return donations;
    } catch (e) {
      print('Error fetching all donations: $e');
      return [];
    }
  }

  // Update request status (for admin)
  static Future<bool> updateRequestStatus(String requestId, String newStatus) async {
    try {
      print('Updating request $requestId status to: $newStatus');
      
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      var requestsCollection = db!.collection('requests');
      var result = await requestsCollection.updateOne(
        where.eq('_id', ObjectId.parse(requestId)),
        modify
            .set('status', newStatus)
            .set('updatedAt', DateTime.now().toIso8601String())
      );
      
      if (result.isSuccess) {
        print('Request status updated successfully');
        return true;
      } else {
        print('Failed to update request status');
        return false;
      }
    } catch (e) {
      print('Error updating request status: $e');
      return false;
    }
  }

  // Get inventory statistics
  static Future<Map<String, dynamic>> getInventoryStatistics() async {
    try {
      print('Fetching inventory statistics...');
      
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      var inventoryCollection = db!.collection('inventoryitems');
      var allItems = await inventoryCollection.find().toList();
      
      int totalItems = 0;
      int lowStockItems = 0;
      var categories = <String, int>{};
      
      for (var item in allItems) {
        int quantity = item['quantity'] ?? 0;
        int minQuantity = item['minQuantity'] ?? 0;
        String category = item['category'] ?? 'Other';
        
        totalItems += quantity;
        if (quantity <= minQuantity) {
          lowStockItems++;
        }
        
        categories[category] = (categories[category] ?? 0) + quantity;
      }
      
      return {
        'totalInventory': totalItems,
        'lowStockItems': lowStockItems,
        'totalProducts': allItems.length,
        'categories': categories,
      };
    } catch (e) {
      print('Error getting inventory statistics: $e');
      return {
        'totalInventory': 0,
        'lowStockItems': 0,
        'totalProducts': 0,
        'categories': {},
      };
    }
  }

  static Future<void> close() async {
    if (db != null) {
      await db!.close();
      print('MongoDB connection closed');
    }
  }
}