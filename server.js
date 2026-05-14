// server.js
const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const { MongoClient, ObjectId } = require('mongodb');
const cors = require('cors');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "http://localhost:3000", // React app URL
    methods: ["GET", "POST"],
    credentials: true
  }
});

app.use(cors());
app.use(express.json());

// Your MongoDB connection
const uri = "mongodb+srv://demo_user:demouser123@cluster0.4vcql9o.mongodb.net/?appName=Cluster0";
const client = new MongoClient(uri);

let db;
let reportsCollection;

async function connectDB() {
  try {
    await client.connect();
    console.log('✅ Connected to MongoDB Atlas');
    
    // Use your database name (e_telly_app or whatever you use)
    db = client.db('e_telly_app');
    reportsCollection = db.collection('emergency_reports');
    
    console.log('📊 Watching for new emergency reports...');
    
    // Watch for new reports
    watchReports();
    
  } catch (error) {
    console.error('❌ MongoDB connection error:', error);
  }
}

// Watch for new reports in real-time
function watchReports() {
  const changeStream = reportsCollection.watch();
  
  changeStream.on('change', (change) => {
    if (change.operationType === 'insert') {
      const newReport = change.fullDocument;
      console.log('🔔 NEW EMERGENCY REPORT DETECTED!');
      console.log('Type:', newReport.emergencyType);
      console.log('Severity:', newReport.severity);
      console.log('Location:', newReport.location?.barangay);
      
      // Emit to all connected React admin clients
      io.emit('new_emergency_report', {
        id: newReport._id.toString(),
        emergencyType: newReport.emergencyType,
        severity: newReport.severity,
        location: newReport.location?.exactAddress || 'Unknown',
        barangay: newReport.location?.barangay || 'Unknown',
        city: newReport.location?.city || 'Navotas',
        timestamp: newReport.timestamp,
        userName: newReport.userData?.fullName || 'Unknown',
        phoneNumber: newReport.userData?.phoneNumber || 'N/A',
        description: newReport.description || '',
        status: newReport.status || 'pending'
      });
      
      console.log('✅ Notification sent to React admin app');
    }
  });
}

// API: Get all reports
app.get('/api/reports', async (req, res) => {
  try {
    const { status, type } = req.query;
    let query = { isActive: true };
    
    if (status && status !== 'all') {
      query.status = status;
    }
    
    if (type && type !== 'all') {
      query.emergencyType = type;
    }
    
    const reports = await reportsCollection
      .find(query)
      .sort({ timestamp: -1 })
      .toArray();
    
    res.json({ success: true, reports });
  } catch (error) {
    console.error('Error fetching reports:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// API: Get single report
app.get('/api/reports/:id', async (req, res) => {
  try {
    const report = await reportsCollection.findOne({ 
      _id: new ObjectId(req.params.id) 
    });
    
    if (!report) {
      return res.status(404).json({ success: false, error: 'Report not found' });
    }
    
    res.json({ success: true, report });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// API: Update report status (Approve/Reject)
app.post('/api/reports/update-status', async (req, res) => {
  try {
    const { reportId, status, adminNotes, adminEmail } = req.body;
    
    const result = await reportsCollection.updateOne(
      { _id: new ObjectId(reportId) },
      { 
        $set: { 
          status: status,
          adminNotes: adminNotes,
          reviewedBy: adminEmail || 'admin@navotas.gov.ph',
          reviewedAt: new Date().toISOString(),
          updatedAt: new Date().toISOString()
        } 
      }
    );
    
    if (result.modifiedCount > 0) {
      // Notify all React admins about the update
      io.emit('report_updated', {
        reportId,
        status,
        adminNotes,
        updatedAt: new Date().toISOString()
      });
      
      res.json({ success: true, message: `Report ${status} successfully` });
    } else {
      res.json({ success: false, message: 'Failed to update report' });
    }
  } catch (error) {
    console.error('Error updating report:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// API: Get report statistics
app.get('/api/reports/statistics/summary', async (req, res) => {
  try {
    const total = await reportsCollection.countDocuments({ isActive: true });
    const pending = await reportsCollection.countDocuments({ status: 'pending', isActive: true });
    const approved = await reportsCollection.countDocuments({ status: 'approved', isActive: true });
    const rejected = await reportsCollection.countDocuments({ status: 'rejected', isActive: true });
    
    // Get counts by type
    const reports = await reportsCollection.find({ isActive: true }).toArray();
    const byType = {};
    reports.forEach(report => {
      const type = report.emergencyType;
      byType[type] = (byType[type] || 0) + 1;
    });
    
    // Get counts by barangay
    const byBarangay = {};
    reports.forEach(report => {
      const barangay = report.location?.barangay || 'Unknown';
      byBarangay[barangay] = (byBarangay[barangay] || 0) + 1;
    });
    
    res.json({
      success: true,
      statistics: {
        total,
        pending,
        approved,
        rejected,
        byType,
        byBarangay
      }
    });
  } catch (error) {
    console.error('Error getting statistics:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

io.on('connection', (socket) => {
  console.log('🟢 React admin connected:', socket.id);
  
  socket.on('disconnect', () => {
    console.log('🔴 React admin disconnected:', socket.id);
  });
});

app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

app.get('/api/disaster/:type', (req, res) => {
    try {
        const { type } = req.params;
        const lat = Number(req.query.lat ?? 14.6669);
        const lng = Number(req.query.lng ?? 120.9497);

        const validTypes = ['flood', 'typhoon', 'earthquake', 'fire'];
        if (!validTypes.includes(type)) {
            return res.status(400).json({ error: 'Invalid disaster type' });
        }

        const now = new Date().toISOString();
        const points = Array.from({ length: 8 }, (_, i) => {
            const angle = ((i + 1) * Math.PI) / 4;
            const distance = 0.003 + (i % 3) * 0.005;
            const intensityBase = type === 'earthquake' ? 0.45 : type === 'fire' ? 0.55 : 0.4;
            const rawIntensity = Number((intensityBase + i * 0.06).toFixed(2));
            const intensity = Math.min(1, Math.max(0, rawIntensity));

            return {
                lat: lat + Math.cos(angle) * distance,
                lng: lng + Math.sin(angle) * distance,
                intensity,
                type,
                source: 'node-api-simulated',
                timestamp: now,
            };
        });

        return res.json({
            type,
            points,
        });
    } catch (error) {
        return res.status(500).json({ error: error.message });
    }
});


const PORT = 5000;
server.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
  console.log(`📡 Socket.IO ready for real-time notifications`);
  connectDB();
});