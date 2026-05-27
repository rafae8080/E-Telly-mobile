import 'package:flutter_dotenv/flutter_dotenv.dart';

String get MONGO_CONN_URL => dotenv.env['MONGO_CONN_URL'] ?? '';

const String DATABASE_NAME = "etelly";
const String USER_COLLECTION = "users";
const String REPORT_COLLECTION_NAME = "emergency_reports";
const String ALERT_COLLECTION_NAME = "alerts";
const String EVACUATIONCENTER_COLLECTION_NAME = "evacuationcenters";
const String INVENTORY_ITEMS_COLLECTION = "inventoryitems";
const String RESOURCE_DONATIONS_COLLECTION = "resourcedonations";
const String RESOURCE_REQUESTS_COLLECTION = "resourcerequests";
