import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';

class SafetyTip {
  final String id;
  final String category;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int steps;
  final String riskLevel;
  final List<String>? detailedSteps;
  final String? emergencyNumber;
  final bool isVideo;
  final String? videoPath;

  SafetyTip({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.steps,
    required this.riskLevel,
    this.detailedSteps,
    this.emergencyNumber,
    this.isVideo = false,
    this.videoPath,
  });
}

class SafetyTipsScreen extends StatefulWidget {
  const SafetyTipsScreen({super.key});

  @override
  State<SafetyTipsScreen> createState() => _SafetyTipsScreenState();
}

class _SafetyTipsScreenState extends State<SafetyTipsScreen> {
  SafetyTip? _selectedTip;
  bool _showDetailModal = false;
  
  // Map to store video controllers for each video tip
  Map<String, VideoPlayerController> _videoControllers = {};
  Map<String, bool> _videoInitialized = {};
  
  VideoPlayerController? _modalVideoController;
  bool _isModalVideoInitialized = false;

  final List<SafetyTip> safetyTips = [
    SafetyTip(
      id: '1',
      category: 'First Aid',
      title: 'Basic First Aid',
      description: 'Watch this video to learn essential first aid techniques',
      icon: Icons.medical_services,
      color: Color(0xFFDC2626),
      steps: 5,
      riskLevel: 'High Risk',
      emergencyNumber: '911',
      isVideo: true,
      videoPath: 'assets/videos/Firstaid.mp4',
      detailedSteps: [
        'Check the scene for safety',
        'Call emergency services',
        'Check the person for responsiveness',
        'Provide necessary first aid',
        'Stay with the person until help arrives',
      ],
    ),
    SafetyTip(
      id: '2',
      category: 'Typhoon',
      title: 'Typhoon Preparedness',
      description: 'Complete guide for typhoon season',
      icon: Icons.cloud,
      color: Color(0xFF3B82F6),
      steps: 10,
      riskLevel: 'High Risk',
      emergencyNumber: '911',
      isVideo: false,
      detailedSteps: [
        'Secure all windows and doors',
        'Trim trees and remove loose objects',
        'Stock 3-day supply of food and water',
        'Charge all electronic devices',
        'Prepare emergency lighting sources',
        'Stay indoors during the storm',
        'Stay away from windows',
        'Monitor official weather updates',
        'Evacuate if in flood-prone area',
        'Check on neighbors after storm passes',
      ],
    ),
    SafetyTip(
      id: '3',
      category: 'Earthquake',
      title: 'Earthquake Safety',
      description: 'Drop, Cover, and Hold On procedures',
      icon: Icons.warning,
      color: Color(0xFFF59E0B),
      steps: 10,
      riskLevel: 'High Risk',
      emergencyNumber: '911',
      isVideo: true,
      videoPath: 'assets/videos/Eartquake.mp4',
      detailedSteps: [
        'DROP to your hands and knees',
        'COVER your head and neck',
        'HOLD ON to sturdy furniture',
        'Stay away from windows and glass',
        'If outside, move to open area',
        'If driving, pull over and stay in car',
        'Stay indoors until shaking stops',
        'Check for injuries after shaking stops',
        'Expect aftershocks',
        'Listen to emergency broadcasts',
      ],
    ),
    SafetyTip(
      id: '4',
      category: 'Fire',
      title: 'Fire Emergency Guide',
      description: 'Prevention and response to fire hazards',
      icon: Icons.local_fire_department,
      color: Color(0xFFDC2626),
      steps: 8,
      riskLevel: 'High Risk',
      emergencyNumber: '8-281-0854',
      isVideo: false,
      detailedSteps: [
        'Install smoke detectors on every level',
        'Test smoke detectors monthly',
        'Create and practice fire escape plan',
        'Keep fire extinguishers accessible',
        'Stop, drop, and roll if clothes catch fire',
        'Crawl low under smoke',
        'Check doors for heat before opening',
        'Meet at designated outside location',
      ],
    ),
    SafetyTip(
      id: '5',
      category: 'Flood',
      title: 'Flood Safety Guide',
      description: 'Essential steps before, during, and after floods',
      icon: Icons.water_damage,
      color: Color(0xFF06B6D4),
      steps: 10,
      riskLevel: 'High Risk',
      emergencyNumber: '911',
      isVideo: true,
      videoPath: 'assets/videos/Flood.mp4',
      detailedSteps: [
        'Monitor weather updates and flood warnings',
        'Prepare emergency kit with food, water, and medications',
        'Move valuables to higher floors',
        'Turn off electricity at main switch',
        'Evacuate immediately if instructed',
        'Avoid walking or driving through floodwaters',
        'Stay away from downed power lines',
        'Listen to local news for updates',
        'Return only when authorities say it\'s safe',
        'Document damage for insurance claims',
      ],
    ),
    SafetyTip(
      id: '6',
      category: 'Evacuation',
      title: 'Evacuation Procedures',
      description: 'Safe evacuation routes and procedures',
      icon: Icons.directions_walk,
      color: Color(0xFF10B981),
      steps: 7,
      riskLevel: 'Medium Risk',
      emergencyNumber: '8-281-1111',
      isVideo: false,
      detailedSteps: [
        'Know your evacuation zone',
        'Plan multiple evacuation routes',
        'Prepare "go-bag" with essentials',
        'Follow official evacuation orders',
        'Take pets and medications',
        'Inform family of destination',
        'Use only designated evacuation routes',
      ],
    ),
    SafetyTip(
      id: '7',
      category: 'Heat',
      title: 'Heatwave Safety',
      description: 'Protection during extreme heat conditions',
      icon: Icons.thermostat,
      color: Color(0xFFDC2626),
      steps: 6,
      riskLevel: 'Medium Risk',
      emergencyNumber: '911',
      isVideo: false,
      detailedSteps: [
        'Stay hydrated with water',
        'Avoid outdoor activities during peak heat',
        'Wear lightweight, light-colored clothing',
        'Stay in air-conditioned places',
        'Check on elderly and vulnerable neighbors',
        'Know signs of heat exhaustion',
      ],
    ),
    SafetyTip(
      id: '8',
      category: 'Electrical',
      title: 'Electrical Safety',
      description: 'Preventing electrical hazards',
      icon: Icons.flash_on,
      color: Color(0xFFF59E0B),
      steps: 8,
      riskLevel: 'High Risk',
      emergencyNumber: '911',
      isVideo: false,
      detailedSteps: [
        'Keep electrical appliances away from water',
        'Do not overload outlets',
        'Use surge protectors',
        'Check cords for damage',
        'Turn off main breaker during floods',
        'Do not touch electrical equipment if wet',
        'Have electrical system inspected',
        'Know location of main electrical panel',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize videos for all tips that have videoPath
    _initializeAllVideos();
  }

  Future<void> _initializeAllVideos() async {
    for (var tip in safetyTips) {
      if (tip.isVideo && tip.videoPath != null) {
        await _initializeVideoForTip(tip.id, tip.videoPath!);
      }
    }
  }

  Future<void> _initializeVideoForTip(String id, String videoPath) async {
    final controller = VideoPlayerController.asset(videoPath);
    try {
      await controller.initialize();
      setState(() {
        _videoControllers[id] = controller;
        _videoInitialized[id] = true;
      });
    } catch (error) {
      print('Error loading video for $id: $error');
      setState(() {
        _videoInitialized[id] = false;
      });
    }
  }

  Future<void> _initializeModalVideo(String videoPath) async {
    _modalVideoController?.dispose();
    _modalVideoController = VideoPlayerController.asset(videoPath);
    
    try {
      await _modalVideoController!.initialize();
      setState(() {
        _isModalVideoInitialized = true;
      });
      _modalVideoController!.play();
    } catch (error) {
      print('Error loading modal video: $error');
      setState(() {
        _isModalVideoInitialized = false;
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    _modalVideoController?.dispose();
    super.dispose();
  }

  void _toggleVideoPlayback(String id) {
    final controller = _videoControllers[id];
    if (controller != null) {
      setState(() {
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
      });
    }
  }

  void _toggleModalVideoPlayback() {
    if (_modalVideoController != null) {
      setState(() {
        if (_modalVideoController!.value.isPlaying) {
          _modalVideoController!.pause();
        } else {
          _modalVideoController!.play();
        }
      });
    }
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return "00:00";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  Color getRiskLevelColor(String riskLevel) {
    switch (riskLevel) {
      case 'High Risk':
        return Color(0xFFDC2626);
      case 'Medium Risk':
        return Color(0xFFF59E0B);
      case 'Low Risk':
        return Color(0xFF10B981);
      default:
        return Colors.grey;
    }
  }

  void _handleSafetyTipPress(SafetyTip tip) {
    setState(() {
      _selectedTip = tip;
      _showDetailModal = true;
    });
    
    if (tip.isVideo && tip.videoPath != null) {
      _initializeModalVideo(tip.videoPath!);
    }
  }

  void _handleEmergencyCall(String number) async {
    final cleanNumber = number.replaceAll(RegExp(r'[^\d+]'), '');
    final url = 'tel:$cleanNumber';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Error'),
          content: Text('Unable to make call'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Separate video tips and text tips
    List<SafetyTip> videoTips = safetyTips.where((tip) => tip.isVideo).toList();
    List<SafetyTip> textTips = safetyTips.where((tip) => !tip.isVideo).toList();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Safety Tips',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: Container(
        color: Colors.grey[50],
        child: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // VIDEO TIPS SECTION
                    if (videoTips.isNotEmpty) ...[
                      Text(
                        'VIDEO GUIDES',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[500],
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 12),
                      ...videoTips.map((tip) => _buildVideoPlayerCard(tip)),
                      SizedBox(height: 24),
                    ],
                    
                    // TEXT GUIDES SECTION
                    if (textTips.isNotEmpty) ...[
                      Text(
                        'GUIDES & PROCEDURES',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[500],
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 12),
                      ...textTips.map((tip) => SafetyTipCard(
                        tip: tip,
                        onTap: () => _handleSafetyTipPress(tip),
                        getRiskLevelColor: getRiskLevelColor,
                      )),
                    ],
                  ],
                ),
              ),
            ),
            if (_showDetailModal && _selectedTip != null)
              SafetyTipDetailModal(
                tip: _selectedTip!,
                getRiskLevelColor: getRiskLevelColor,
                onClose: () {
                  _modalVideoController?.pause();
                  setState(() {
                    _showDetailModal = false;
                    _isModalVideoInitialized = false;
                  });
                },
                onEmergencyCall: _handleEmergencyCall,
                modalVideoController: _modalVideoController,
                isModalVideoInitialized: _isModalVideoInitialized,
                onToggleVideo: _toggleModalVideoPlayback,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayerCard(SafetyTip tip) {
    final isInitialized = _videoInitialized[tip.id] ?? false;
    final controller = _videoControllers[tip.id];
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tip.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(tip.icon, color: tip.color, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tip.category,
                        style: TextStyle(
                          fontSize: 12,
                          color: tip.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        tip.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: getRiskLevelColor(tip.riskLevel).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tip.riskLevel,
                    style: TextStyle(
                      fontSize: 11,
                      color: getRiskLevelColor(tip.riskLevel),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Video Player
          Container(
            height: 200,
            width: double.infinity,
            color: Colors.black,
            child: isInitialized && controller != null
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(controller),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: _buildVideoControlsForTip(tip.id, controller),
                      ),
                      if (!controller.value.isPlaying)
                        GestureDetector(
                          onTap: () => _toggleVideoPlayback(tip.id),
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                    ],
                  )
                : Center(
                    child: CircularProgressIndicator(color: tip.color),
                  ),
          ),
          // Description
          Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              tip.description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ),
          // View Details Button
          Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: GestureDetector(
              onTap: () => _handleSafetyTipPress(tip),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: tip.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'View Details',
                      style: TextStyle(
                        color: tip.color,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(width: 5),
                    Icon(Icons.arrow_forward, color: tip.color, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoControlsForTip(String id, VideoPlayerController controller) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(
              controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => _toggleVideoPlayback(id),
          ),
          Expanded(
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: ET_RED,
                backgroundColor: Colors.grey[800]!,
                bufferedColor: Colors.grey[600]!,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 12),
            child: Text(
              '${_formatDuration(controller.value.position)} / ${_formatDuration(controller.value.duration)}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// TEXT GUIDE CARD (for non-video tips)
class SafetyTipCard extends StatelessWidget {
  final SafetyTip tip;
  final VoidCallback onTap;
  final Color Function(String) getRiskLevelColor;

  const SafetyTipCard({
    super.key,
    required this.tip,
    required this.onTap,
    required this.getRiskLevelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: tip.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(tip.icon, color: tip.color, size: 28),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tip.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      tip.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: tip.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${tip.steps} steps',
                            style: TextStyle(
                              fontSize: 11,
                              color: tip.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: getRiskLevelColor(tip.riskLevel).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            tip.riskLevel,
                            style: TextStyle(
                              fontSize: 11,
                              color: getRiskLevelColor(tip.riskLevel),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// DETAIL MODAL
class SafetyTipDetailModal extends StatelessWidget {
  final SafetyTip tip;
  final Color Function(String) getRiskLevelColor;
  final VoidCallback onClose;
  final Function(String) onEmergencyCall;
  final VideoPlayerController? modalVideoController;
  final bool isModalVideoInitialized;
  final VoidCallback onToggleVideo;

  const SafetyTipDetailModal({
    super.key,
    required this.tip,
    required this.getRiskLevelColor,
    required this.onClose,
    required this.onEmergencyCall,
    this.modalVideoController,
    this.isModalVideoInitialized = false,
    required this.onToggleVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tip.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(tip.icon, color: tip.color, size: 28),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tip.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey),
                  onPressed: onClose,
                ),
              ],
            ),
            SizedBox(height: 16),
            if (tip.isVideo && modalVideoController != null) ...[
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isModalVideoInitialized
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          VideoPlayer(modalVideoController!),
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: _buildModalVideoControls(),
                          ),
                          if (!modalVideoController!.value.isPlaying)
                            GestureDetector(
                              onTap: onToggleVideo,
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.play_arrow,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            ),
                        ],
                      )
                    : Center(child: CircularProgressIndicator(color: ET_RED)),
              ),
              SizedBox(height: 16),
            ],
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!tip.isVideo && tip.detailedSteps != null) ...[
                      Text(
                        'Step-by-Step Guide',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: tip.color,
                        ),
                      ),
                      SizedBox(height: 12),
                      ...tip.detailedSteps!.asMap().entries.map((entry) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: tip.color.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${entry.key + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: tip.color,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  entry.value,
                                  style: TextStyle(fontSize: 13, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    if (tip.emergencyNumber != null) ...[
                      SizedBox(height: 20),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () => onEmergencyCall(tip.emergencyNumber!),
                          icon: Icon(Icons.phone),
                          label: Text('Call ${tip.emergencyNumber}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ET_RED,
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalVideoControls() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(
              modalVideoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 20,
            ),
            onPressed: onToggleVideo,
          ),
          Expanded(
            child: VideoProgressIndicator(
              modalVideoController!,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: ET_RED,
                backgroundColor: Colors.grey[800]!,
                bufferedColor: Colors.grey[600]!,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 12),
            child: Text(
              '${_formatDuration(modalVideoController!.value.position)} / ${_formatDuration(modalVideoController!.value.duration)}',
              style: TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return "00:00";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}