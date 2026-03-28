import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class OfflineReportStorage {
  static const String boxName = 'emergency_reports';
  static const String registrationsBoxName = 'pending_registrations';
  static Box<Map>? _box;
  static Box<Map>? _registrationsBox;

  static Future<void> init() async {
    _box = await Hive.openBox<Map>(boxName);
    _registrationsBox = await Hive.openBox<Map>(registrationsBoxName);
    print('OfflineReportStorage initialized');
  }
  
  static Box<Map> get box {
    if (_box == null) {
      throw Exception('OfflineReportStorage not initialized. Call init() first.');
    }
    return _box!;
  }
  

  static Box<Map> get registrationsBox {
    if (_registrationsBox == null) {
      throw Exception('OfflineReportStorage not initialized. Call init() first.');
    }
    return _registrationsBox!;
  }
  

  
 
  static Future<void> saveReport(Map<String, dynamic> report) async {
    try {
      await box.add(report);
      print('Emergency report saved offline: ${report['title']}');
    } catch (e) {
      print('Error saving report: $e');
      rethrow;
    }
  }
  

  static List<Map<String, dynamic>> getUnsyncedReports() {
    try {
      return box.values
          .cast<Map<String, dynamic>>()
          .where((report) => report['synced'] == false)
          .toList();
    } catch (e) {
      print('Error getting unsynced reports: $e');
      return [];
    }
  }
  
 
  static List<Map<String, dynamic>> getAllReports() {
    try {
      return box.values.cast<Map<String, dynamic>>().toList();
    } catch (e) {
      print('Error getting reports: $e');
      return [];
    }
  }
  
  
  static Future<void> markAsSynced(int index) async {
    try {
      final report = box.getAt(index);
      if (report != null) {
        report['synced'] = true;
        report['syncedAt'] = DateTime.now().toIso8601String();
        await box.putAt(index, report);
        print('Report marked as synced at index $index');
      }
    } catch (e) {
      print('Error marking report as synced: $e');
    }
  }
  

  static Future<void> deleteReport(int index) async {
    try {
      await box.deleteAt(index);
      print('Report deleted at index $index');
    } catch (e) {
      print('Error deleting report: $e');
    }
  }
  

  static Future<void> clearAllReports() async {
    try {
      await box.clear();
      print('All reports cleared');
    } catch (e) {
      print('Error clearing reports: $e');
    }
  }

  static int getReportCount() {
    return box.length;
  }
  

  static int getPendingSyncCount() {
    return getUnsyncedReports().length;
  }
  

  static Future<void> syncReportsToServer() async {
    final unsynced = getUnsyncedReports();
    if (unsynced.isEmpty) return;
    
    print('Syncing ${unsynced.length} reports to server...');
    
    for (int i = 0; i < unsynced.length; i++) {
      final report = unsynced[i];
      try {
        final allReports = getAllReports();
        final index = allReports.indexWhere((r) => 
            r['id'] == report['id']);
        
        if (index != -1) {
          // TODO: Send to your backend/server
          // await sendToServer(report);
          
          await markAsSynced(index);
          print('Report synced: ${report['title']}');
        }
      } catch (e) {
        print('Failed to sync report: $e');
      }
    }
  }
  
 
  
  static Future<void> saveRegistration(Map<String, dynamic> userData) async {
    try {
      await registrationsBox.add(userData);
      print('Registration saved offline: ${userData['email']}');
    } catch (e) {
      print('Error saving registration: $e');
      rethrow;
    }
  }
  

  static List<Map<String, dynamic>> getPendingRegistrations() {
    try {
      return registrationsBox.values
          .cast<Map<String, dynamic>>()
          .where((reg) => reg['synced'] == false)
          .toList();
    } catch (e) {
      print('Error getting pending registrations: $e');
      return [];
    }
  }
  
  
  static int getPendingRegistrationsCount() {
    return getPendingRegistrations().length;
  }
  
 
  static List<Map<String, dynamic>> getAllRegistrations() {
    try {
      return registrationsBox.values.cast<Map<String, dynamic>>().toList();
    } catch (e) {
      print('Error getting all registrations: $e');
      return [];
    }
  }
  

  static Future<void> markRegistrationAsSynced(int index) async {
    try {
      final reg = registrationsBox.getAt(index);
      if (reg != null) {
        reg['synced'] = true;
        reg['syncedAt'] = DateTime.now().toIso8601String();
        await registrationsBox.putAt(index, reg);
        print('Registration marked as synced at index $index');
      }
    } catch (e) {
      print('Error marking registration as synced: $e');
    }
  }
  

  static Future<void> deleteRegistration(int index) async {
    try {
      await registrationsBox.deleteAt(index);
      print('Registration deleted at index $index');
    } catch (e) {
      print('Error deleting registration: $e');
    }
  }
  

  static Future<void> clearAllRegistrations() async {
    try {
      await registrationsBox.clear();
      print('All registrations cleared');
    } catch (e) {
      print('Error clearing registrations: $e');
    }
  }
  
  // Sync all pending registrations to server
  static Future<void> syncRegistrationsToServer() async {
    final pending = getPendingRegistrations();
    if (pending.isEmpty) return;
    
    print('Syncing ${pending.length} registrations to server...');
    
    for (int i = 0; i < pending.length; i++) {
      final registration = pending[i];
      try {
        final allRegistrations = getAllRegistrations();
        final index = allRegistrations.indexWhere((r) => 
            r['id'] == registration['id']);
        
        if (index != -1) {
          // TODO: Send to MongoDB
          // await MongoDatabase.insertUser(registration);
          
          await markRegistrationAsSynced(index);
          print('Registration synced: ${registration['email']}');
        }
      } catch (e) {
        print('Failed to sync registration: $e');
      }
    }
  }
  
  // Get registrations box for ValueListenableBuilder
  static Box<Map> getRegistrationBox() {
    return registrationsBox;
  }
}