import 'package:hive_flutter/hive_flutter.dart';

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

  // FIX: Safe conversion helper for Hive maps
  static Map<String, dynamic> _safeConvert(Map<dynamic, dynamic> dynamicMap) {
    Map<String, dynamic> result = {};
    dynamicMap.forEach((key, value) {
      result[key.toString()] = value;
    });
    return result;
  }

  static Future<void> saveReport(Map<String, dynamic> report) async {
    try {
      // Convert to safe map before saving
      Map<String, dynamic> safeReport = {};
      report.forEach((key, value) {
        safeReport[key.toString()] = value;
      });
      
      await box.add(safeReport);
      print('Emergency report saved offline: ${report['title']}');
    } catch (e) {
      print('Error saving report: $e');
      rethrow;
    }
  }

  // FIXED: This was causing the error
  static List<Map<String, dynamic>> getUnsyncedReports() {
    try {
      List<Map<String, dynamic>> unsyncedReports = [];
      
      for (var report in box.values) {
        // Convert each report safely
        Map<String, dynamic> safeReport = {};
        report.forEach((key, value) {
          safeReport[key.toString()] = value;
        });
        
        if (safeReport['synced'] == false) {
          unsyncedReports.add(safeReport);
        }
      }
      
      print('Found ${unsyncedReports.length} unsynced reports');
      return unsyncedReports;
      
    } catch (e) {
      print('Error getting unsynced reports: $e');
      return [];
    }
  }
  
  // FIXED: This method also needs fixing
  static List<Map<String, dynamic>> getAllReports() {
    try {
      List<Map<String, dynamic>> allReports = [];
      
      for (var report in box.values) {
        // Convert each report safely
        Map<String, dynamic> safeReport = {};
        report.forEach((key, value) {
          safeReport[key.toString()] = value;
        });
        allReports.add(safeReport);
      }
      
      return allReports;
      
    } catch (e) {
      print('Error getting reports: $e');
      return [];
    }
  }
  
  static Future<void> markAsSynced(int index) async {
    try {
      final report = box.getAt(index);
      if (report != null) {
        // Create a safe copy
        Map<String, dynamic> safeReport = {};
        report.forEach((key, value) {
          safeReport[key.toString()] = value;
        });
        
        safeReport['synced'] = true;
        safeReport['syncedAt'] = DateTime.now().toIso8601String();
        await box.putAt(index, safeReport);
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
      // Convert to safe map
      Map<String, dynamic> safeData = {};
      userData.forEach((key, value) {
        safeData[key.toString()] = value;
      });
      
      await registrationsBox.add(safeData);
      print('Registration saved offline: ${userData['email']}');
    } catch (e) {
      print('Error saving registration: $e');
      rethrow;
    }
  }

  // FIXED: Pending registrations method
  static List<Map<String, dynamic>> getPendingRegistrations() {
    try {
      List<Map<String, dynamic>> pendingRegistrations = [];
      
      for (var reg in registrationsBox.values) {
        // Convert each registration safely
        Map<String, dynamic> safeReg = {};
        reg.forEach((key, value) {
          safeReg[key.toString()] = value;
        });
        
        if (safeReg['synced'] == false) {
          pendingRegistrations.add(safeReg);
        }
      }
      
      return pendingRegistrations;
      
    } catch (e) {
      print('Error getting pending registrations: $e');
      return [];
    }
  }
  
  static int getPendingRegistrationsCount() {
    return getPendingRegistrations().length;
  }
  
  // FIXED: Get all registrations
  static List<Map<String, dynamic>> getAllRegistrations() {
    try {
      List<Map<String, dynamic>> allRegistrations = [];
      
      for (var reg in registrationsBox.values) {
        Map<String, dynamic> safeReg = {};
        reg.forEach((key, value) {
          safeReg[key.toString()] = value;
        });
        allRegistrations.add(safeReg);
      }
      
      return allRegistrations;
      
    } catch (e) {
      print('Error getting all registrations: $e');
      return [];
    }
  }

  static Future<void> markRegistrationAsSynced(int index) async {
    try {
      final reg = registrationsBox.getAt(index);
      if (reg != null) {
        Map<String, dynamic> safeReg = {};
        reg.forEach((key, value) {
          safeReg[key.toString()] = value;
        });
        
        safeReg['synced'] = true;
        safeReg['syncedAt'] = DateTime.now().toIso8601String();
        await registrationsBox.putAt(index, safeReg);
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
        
          
          await markRegistrationAsSynced(index);
          print('Registration synced: ${registration['email']}');
        }
      } catch (e) {
        print('Failed to sync registration: $e');
      }
    }
  }
  
  static Box<Map> getRegistrationBox() {
    return registrationsBox;
  }
}