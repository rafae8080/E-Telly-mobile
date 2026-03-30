import 'dart:developer';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:e_telly_app/dbhelper/constant.dart';

class MongoDatabase {
  static Db? db;
  static DbCollection? userCollection;
  
  static Future<void> connect() async {
    try {
      print('Connecting to MongoDB Atlas...');
      print('Connection URL: ${MONGO_CONN_URL.substring(0, 60)}...');
      
      db = await Db.create(MONGO_CONN_URL);
      await db!.open();
      print('Database opened successfully');
      
      userCollection = db!.collection(USER_COLLECTION);
      print('User collection initialized');
      
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
      
      // Create a modifier map for update
      Map<String, dynamic> modifier = {
        r'$set': updatedData
      };
      
      // Perform the update
      var result = await userCollection!.updateOne(
        where.eq('email', email),
        modifier,
      );
      
      // Check if update was successful
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