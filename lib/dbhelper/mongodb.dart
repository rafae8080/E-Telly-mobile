import 'dart:developer';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:e_telly_app/dbhelper/constant.dart';

class MongoDatabase {
  static Db? db;
  static DbCollection? userCollection;
  static DbCollection? reportsCollection; // Add reports collection
  
  static Future<void> connect() async {
    try {
      print('Connecting to MongoDB Atlas...');
      print('Connection URL: ${MONGO_CONN_URL.substring(0, 60)}...');
      
      db = await Db.create(MONGO_CONN_URL);
      await db!.open();
      print('Database opened successfully');
      
      userCollection = db!.collection(USER_COLLECTION);
      reportsCollection = db!.collection('emergency_reports'); // Initialize reports collection
      
      print('User collection initialized');
      print('Reports collection initialized');
      
      // Create indexes for reports collection
      await _createReportsIndexes();
      
      // Test connection by getting collection names
      var collections = await db!.getCollectionNames();
      print('Available collections: $collections');
      
      print('Connected to MongoDB successfully!');
      
    } catch (e) {
      print('Connection error: $e');
      print('Please check:');
      print('  1. IP whitelist in MongoDB Atlas');
      print('  2. Username and password are correct');
      print('  3. Database name is correct');
      print('  4. Internet connection is stable');
    }
  }
  
  // Create indexes for better query performance - CORRECTED VERSION
  static Future<void> _createReportsIndexes() async {
    try {
      if (reportsCollection != null) {
        // Index on timestamp for sorting
        await reportsCollection!.createIndex(
          key: 'timestamp', 
          unique: false
        );
        
        // Index on emergencyType for filtering
        await reportsCollection!.createIndex(
          key: 'emergencyType',
          unique: false
        );
        
        // Index on status for filtering
        await reportsCollection!.createIndex(
          key: 'status',
          unique: false
        );
        
        // Index on user email for finding user's reports
        await reportsCollection!.createIndex(
          key: 'userData.email',
          unique: false
        );
        
        print('Reports indexes created successfully');
      }
    } catch (e) {
      print('Error creating indexes: $e');
      // Don't throw error, indexes are not critical for functionality
    }
  }
  
  // Save emergency report to MongoDB
  static Future<bool> saveEmergencyReport(Map<String, dynamic> reportData) async {
    try {
      print('Saving emergency report...');
      print('Report data: $reportData');
      
      // Add additional metadata
      reportData['status'] = 'pending'; // pending, in_progress, resolved, rejected
      reportData['isActive'] = true;
      reportData['createdAt'] = DateTime.now().toIso8601String();
      reportData['updatedAt'] = DateTime.now().toIso8601String();
      
      // Insert the report
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
  
  // Get all emergency reports (for admin/DRRMO)
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
  
  // Get reports by status
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
  
  // Get reports by emergency type
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
  
  // Get reports by user email
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
  
  // Update report status
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
  
  // Delete/Deactivate a report
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
  
  // Get report statistics
  static Future<Map<String, dynamic>> getReportStatistics() async {
    try {
      var totalReports = await reportsCollection!.count();
      var pendingReports = await reportsCollection!.count(where.eq('status', 'pending'));
      var resolvedReports = await reportsCollection!.count(where.eq('status', 'resolved'));
      var inProgressReports = await reportsCollection!.count(where.eq('status', 'in_progress'));
      
      // Get counts by emergency type
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

  // Existing user methods remain the same...
  static Future<bool> insertUser(Map<String, dynamic> userData) async {
    try {
      print('Inserting user: ${userData['email']}');
      
      userData['createdAt'] = DateTime.now().toIso8601String();
      var result = await userCollection!.insertOne(userData);
      
      if (result.isSuccess) {
        print('User inserted successfully: ${userData['email']}');
        return true;
      } else {
        print('Failed to insert user');
        return false;
      }
    } catch (e) {
      print('Error inserting user: $e');
      return false;
    }
  }
  
  static Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    try {
      print('Looking for user: $email');
      var user = await userCollection!.findOne(where.eq('email', email));
      
      if (user != null) {
        print('User found: ${user['email']}');
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
      print('Data to update: $updatedData');
      
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

  static Future<void> close() async {
    if (db != null) {
      await db!.close();
      print('MongoDB connection closed');
    }
  }
}