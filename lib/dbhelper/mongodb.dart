import 'dart:developer';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:e_telly_app/dbhelper/constant.dart';

class MongoDatabase {
  static Db? db;
  static DbCollection? userCollection;
  static DbCollection? reportsCollection;
  static DbCollection? alertsCollection;
  static DbCollection? evacuationCentersCollection;
  static DbCollection? inventoryItemsCollection;
  static DbCollection? resourceDonationsCollection;
  static DbCollection? resourceRequestsCollection;
  
  // Getter for isConnected
  static bool get isConnected => db != null && db!.isConnected;
  
  static Future<void> connect() async {
    try {
      print('Connecting to MongoDB Atlas...');
      String hiddenUrl = _hidePasswordInUrl(MONGO_CONN_URL);
      print('Connection URL: ${hiddenUrl.substring(0, 60)}...');
      
      db = await Db.create(MONGO_CONN_URL);
      await db!.open();
      print('Database opened successfully');
      print('Connection state: ${db!.isConnected}');
      
      // Initialize all collections
      userCollection = db!.collection(USER_COLLECTION);
      reportsCollection = db!.collection(REPORT_COLLECTION_NAME);
      alertsCollection = db!.collection(ALERT_COLLECTION_NAME);
      evacuationCentersCollection = db!.collection(EVACUATIONCENTER_COLLECTION_NAME);
      inventoryItemsCollection = db!.collection(INVENTORY_ITEMS_COLLECTION);
      resourceDonationsCollection = db!.collection(RESOURCE_DONATIONS_COLLECTION);
      resourceRequestsCollection = db!.collection(RESOURCE_REQUESTS_COLLECTION);
      
      print('✓ User collection initialized');
      print('✓ Reports collection initialized');
      print('✓ Alerts collection initialized');
      print('✓ Evacuation Centers collection initialized');
      print('✓ Inventory Items collection initialized');
      print('✓ Resource Donations collection initialized');
      print('✓ Resource Requests collection initialized');
      
      await _createReportsIndexes();
      await _createInventoryIndexes();
      
      var collections = await db!.getCollectionNames();
      print('Available collections: $collections');
      
      print('✅ Connected to MongoDB successfully!');
      
    } catch (e) {
      print('❌ Connection error: $e');
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
        await reportsCollection!.createIndex(key: 'timestamp', unique: false);
        await reportsCollection!.createIndex(key: 'emergencyType', unique: false);
        await reportsCollection!.createIndex(key: 'status', unique: false);
        await reportsCollection!.createIndex(key: 'userData.email', unique: false);
        print('✓ Reports indexes created successfully');
      }
    } catch (e) {
      print('Error creating reports indexes: $e');
    }
  }
  
  static Future<void> _createInventoryIndexes() async {
    try {
      if (inventoryItemsCollection != null) {
        await inventoryItemsCollection!.createIndex(key: 'name', unique: false);
        await inventoryItemsCollection!.createIndex(key: 'category', unique: false);
        await inventoryItemsCollection!.createIndex(key: 'barangay', unique: false);
        print('✓ Inventory indexes created successfully');
      }
    } catch (e) {
      print('Error creating inventory indexes: $e');
    }
  }

  // ============ USER METHODS ============
  
  static Future<bool> insertUser(Map<String, dynamic> userData) async {
    try {
      print('Starting user insertion...');
      print('Email: ${userData['email']}');
      print('Name: ${userData['name']}');
      
      if (db == null || !db!.isConnected) {
        print('Database not connected');
        await connect();
      }
      
      userData['createdAt'] = DateTime.now().toIso8601String();
      userData['updatedAt'] = DateTime.now().toIso8601String();
      
      var result = await userCollection!.insertOne(userData);
      
      if (result.isSuccess) {
        print('✅ User inserted successfully: ${userData['email']}');
        return true;
      } else {
        print('❌ Insert operation failed');
        return false;
      }
    } catch (e) {
      print('❌ Exception in insertUser: $e');
      return false;
    }
  }
  
  static Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    try {
      print('Looking for user: $email');
      
      if (db == null || !db!.isConnected) {
        print('Database not connected');
        await connect();
      }
      
      var user = await userCollection!.findOne(where.eq('email', email));
      
      if (user != null) {
        print('✅ User found: ${user['email']}');
        return user;
      } else {
        print('User not found: $email');
        return null;
      }
    } catch (e) {
      print('Error finding user: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> findUserForLogin(String email, String password) async {
    try {
      print('Attempting login for email: $email');
      
      if (db == null || !db!.isConnected) {
        print('Database not connected');
        await connect();
      }
      
      var user = await userCollection!.findOne(
        where.eq('email', email).and(where.eq('password', password))
      );
      
      if (user != null) {
        print('✅ User found for login: ${user['email']}');
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

  // UPDATE USER METHOD - FIXED (no setAll)
  static Future<bool> updateUser(String email, Map<String, dynamic> updatedData) async {
    try {
      print('Updating user with email: $email');
      print('Data to update: ${updatedData.keys}');
      
      if (db == null || !db!.isConnected) {
        print('Database not connected');
        await connect();
      }
      
      // Remove fields that shouldn't be updated directly
      updatedData.remove('_id');
      updatedData.remove('createdAt');
      updatedData.remove('email');
      updatedData.remove('password');
      
      updatedData['updatedAt'] = DateTime.now().toIso8601String();
      
      // Build modifier dynamically
      var modifierBuilder = modify;
      for (var entry in updatedData.entries) {
        modifierBuilder = modifierBuilder.set(entry.key, entry.value);
      }
      
      var result = await userCollection!.updateOne(
        where.eq('email', email),
        modifierBuilder,
      );
      
      if (result.isSuccess) {
        print('✅ User updated successfully: $email');
        return true;
      } else {
        print('❌ Failed to update user');
        return false;
      }
    } catch (e) {
      print('Error updating user: $e');
      return false;
    }
  }

  // ============ REPORT METHODS ============
  
  static Future<bool> saveEmergencyReport(Map<String, dynamic> reportData) async {
    try {
      print('Saving emergency report...');
      
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      reportData['status'] = 'pending';
      reportData['isActive'] = true;
      reportData['createdAt'] = DateTime.now().toIso8601String();
      reportData['updatedAt'] = DateTime.now().toIso8601String();
      
      var result = await reportsCollection!.insertOne(reportData);
      
      if (result.isSuccess) {
        print('✅ Emergency report saved successfully');
        return true;
      } else {
        print('❌ Failed to save emergency report');
        return false;
      }
    } catch (e) {
      print('Error saving emergency report: $e');
      return false;
    }
  }
  
  static Future<List<Map<String, dynamic>>> getAllEmergencyReports() async {
    try {
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      var reports = await reportsCollection!
          .find(where.eq('isActive', true)
            ..sortBy('timestamp', descending: true))
          .toList();
      
      print('✅ Found ${reports.length} reports');
      return reports;
    } catch (e) {
      print('Error fetching reports: $e');
      return [];
    }
  }
  
  static Future<List<Map<String, dynamic>>> getUserEmergencyReports(String email) async {
    try {
      print('Fetching reports for user: $email');
      
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      var reports = await reportsCollection!
          .find(where.eq('userData.email', email)
            ..sortBy('timestamp', descending: true))
          .toList();
      
      print('✅ Found ${reports.length} reports for user: $email');
      return reports;
    } catch (e) {
      print('Error fetching user reports: $e');
      return [];
    }
  }
  
  static Future<List<Map<String, dynamic>>> getReportsByStatus(String status) async {
    try {
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      var reports = await reportsCollection!
          .find(where.eq('status', status)
            ..sortBy('timestamp', descending: true))
          .toList();
      
      return reports;
    } catch (e) {
      print('Error fetching reports by status: $e');
      return [];
    }
  }
  
  static Future<List<Map<String, dynamic>>> getReportsByType(String emergencyType) async {
    try {
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      var reports = await reportsCollection!
          .find(where.eq('emergencyType', emergencyType)
            ..sortBy('timestamp', descending: true))
          .toList();
      
      return reports;
    } catch (e) {
      print('Error fetching reports by type: $e');
      return [];
    }
  }
  
  static Future<bool> updateReportStatus(String reportId, String newStatus) async {
    try {
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      var result = await reportsCollection!.updateOne(
        where.eq('_id', ObjectId.parse(reportId)),
        modify
            .set('status', newStatus)
            .set('updatedAt', DateTime.now().toIso8601String())
      );
      
      return result.isSuccess;
    } catch (e) {
      print('Error updating report status: $e');
      return false;
    }
  }
  
  static Future<bool> deactivateReport(String reportId) async {
    try {
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      var result = await reportsCollection!.updateOne(
        where.eq('_id', ObjectId.parse(reportId)),
        modify
            .set('isActive', false)
            .set('updatedAt', DateTime.now().toIso8601String())
      );
      
      return result.isSuccess;
    } catch (e) {
      print('Error deactivating report: $e');
      return false;
    }
  }
  
  static Future<Map<String, dynamic>> getReportStatistics() async {
    try {
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
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

  // ============ ALERT METHODS ============
  
  static Future<List<Map<String, dynamic>>> getAllAlerts() async {
    try {
      print('Fetching all alerts...');
      
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      var alerts = await alertsCollection!
          .find(where.sortBy('createdAt', descending: true))
          .toList();
      
      print('✅ Found ${alerts.length} alerts');
      return alerts;
    } catch (e) {
      print('Error fetching alerts: $e');
      return [];
    }
  }
  
  static Future<List<Map<String, dynamic>>> getActiveAlerts() async {
    try {
      print('Fetching active alerts...');
      
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      var alerts = await alertsCollection!
          .find(where.eq('isActive', true))
          .toList();
      
      print('✅ Found ${alerts.length} active alerts');
      return alerts;
    } catch (e) {
      print('Error fetching active alerts: $e');
      return [];
    }
  }
  
  static Future<bool> dismissAlert(String alertId) async {
    try {
      print('Dismissing alert: $alertId');
      
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      var result = await alertsCollection!.updateOne(
        where.eq('_id', ObjectId.parse(alertId)),
        modify
            .set('isActive', false)
            .set('dismissedAt', DateTime.now().toIso8601String())
      );
      
      if (result.isSuccess) {
        print('✅ Alert dismissed successfully');
        return true;
      } else {
        print('❌ Failed to dismiss alert');
        return false;
      }
    } catch (e) {
      print('Error dismissing alert: $e');
      return false;
    }
  }

  // ============ EVACUATION CENTER METHODS ============
  
  static Future<List<Map<String, dynamic>>> getAllEvacuationCenters() async {
    try {
      print('Fetching all evacuation centers...');
      
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      var centers = await evacuationCentersCollection!.find().toList();
      
      print('✅ Found ${centers.length} evacuation centers');
      return centers;
    } catch (e) {
      print('Error fetching evacuation centers: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getEvacuationCenterById(String id) async {
    try {
      print('Fetching evacuation center with id: $id');
      
      if (db == null || !db!.isConnected) {
        await connect();
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

  // ============ INVENTORY METHODS ============
  
  static Future<List<Map<String, dynamic>>> getInventoryItems() async {
    try {
      print('Fetching inventory items...');
      
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      var items = await inventoryItemsCollection!.find().toList();
      
      print('✅ Found ${items.length} inventory items');
      return items;
    } catch (e) {
      print('❌ Error fetching inventory items: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getInventoryItemById(String itemId) async {
    try {
      print('Fetching inventory item with id: $itemId');
      
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      var item = await inventoryItemsCollection!.findOne(where.eq('_id', ObjectId.parse(itemId)));
      return item;
    } catch (e) {
      print('Error fetching inventory item: $e');
      return null;
    }
  }

  static Future<bool> updateInventoryQuantity(String itemId, int newQuantity) async {
    try {
      print('Updating inventory item $itemId to quantity: $newQuantity');
      
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      var result = await inventoryItemsCollection!.updateOne(
        where.eq('_id', ObjectId.parse(itemId)),
        modify
            .set('quantity', newQuantity)
            .set('updatedAt', DateTime.now().toIso8601String())
      );
      
      if (result.isSuccess) {
        print('✅ Inventory updated successfully');
        return true;
      } else {
        print('❌ Failed to update inventory');
        return false;
      }
    } catch (e) {
      print('Error updating inventory: $e');
      return false;
    }
  }

  // ============ DONATION METHODS ============
  
  static Future<bool> submitDonation(Map<String, dynamic> donationData) async {
    try {
      print('Submitting donation...');
      
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      donationData['createdAt'] = DateTime.now().toIso8601String();
      donationData['updatedAt'] = DateTime.now().toIso8601String();
      donationData['status'] = 'pending';
      
      var result = await resourceDonationsCollection!.insertOne(donationData);
      
      if (result.isSuccess) {
        print('✅ Donation submitted successfully with id: ${result.id}');
        return true;
      } else {
        print('❌ Failed to submit donation');
        return false;
      }
    } catch (e) {
      print('Error submitting donation: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getUserDonations(String userId) async {
    try {
      print('Fetching donations for user: $userId');
      
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      var donations = await resourceDonationsCollection!
          .find(where.eq('userId', userId)
            ..sortBy('createdAt', descending: true))
          .toList();
      
      print('✅ Found ${donations.length} donations for user: $userId');
      return donations;
    } catch (e) {
      print('Error fetching user donations: $e');
      return [];
    }
  }

  static Future<bool> cancelDonation(String donationId) async {
    try {
      print('Cancelling donation: $donationId');
      
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      var result = await resourceDonationsCollection!.updateOne(
        where.eq('_id', ObjectId.parse(donationId)),
        modify
            .set('status', 'cancelled')
            .set('updatedAt', DateTime.now().toIso8601String())
      );
      
      if (result.isSuccess) {
        print('✅ Donation cancelled successfully');
        return true;
      } else {
        print('❌ Failed to cancel donation');
        return false;
      }
    } catch (e) {
      print('Error cancelling donation: $e');
      return false;
    }
  }

  // ============ REQUEST METHODS ============
  
  static Future<bool> submitRequest(Map<String, dynamic> requestData) async {
    try {
      print('Submitting request...');
      
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      requestData['createdAt'] = DateTime.now().toIso8601String();
      requestData['updatedAt'] = DateTime.now().toIso8601String();
      requestData['status'] = 'pending';
      
      var result = await resourceRequestsCollection!.insertOne(requestData);
      
      if (result.isSuccess) {
        print('✅ Request submitted successfully with id: ${result.id}');
        return true;
      } else {
        print('❌ Failed to submit request');
        return false;
      }
    } catch (e) {
      print('Error submitting request: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getUserRequests(String userId) async {
    try {
      print('Fetching requests for user: $userId');
      
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      var requests = await resourceRequestsCollection!
          .find(where.eq('userId', userId)
            ..sortBy('createdAt', descending: true))
          .toList();
      
      print('✅ Found ${requests.length} requests for user: $userId');
      return requests;
    } catch (e) {
      print('Error fetching user requests: $e');
      return [];
    }
  }

  static Future<bool> cancelRequest(String requestId) async {
    try {
      print('Cancelling request: $requestId');
      
      if (db == null || !db!.isConnected) {
        await connect();
      }
      
      var result = await resourceRequestsCollection!.updateOne(
        where.eq('_id', ObjectId.parse(requestId)),
        modify
            .set('status', 'cancelled')
            .set('updatedAt', DateTime.now().toIso8601String())
      );
      
      if (result.isSuccess) {
        print('✅ Request cancelled successfully');
        return true;
      } else {
        print('❌ Failed to cancel request');
        return false;
      }
    } catch (e) {
      print('Error cancelling request: $e');
      return false;
    }
  }

  static Future<void> close() async {
    if (db != null) {
      await db!.close();
      print('MongoDB connection closed');
    }
  }
}