import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/simple_face_api_service.dart';
import 'camera_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isConnected = false;
  bool _loading = true;
  String _connectionMessage = 'Checking server connection...';
  late SimpleFaceApiService _apiService;
  
  @override
  void initState() {
    super.initState();
    _apiService = SimpleFaceApiService();
    _checkConnection();
  }
  
  Future<void> _checkConnection() async {
    setState(() => _loading = true);
    
    try {
      final result = await _apiService.checkConnection();
      
      if (mounted) {
        setState(() {
          _isConnected = result; // Result is now a boolean
          _connectionMessage = result ? 'Connected to server' : 'Failed to connect to server';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _connectionMessage = 'Error connecting to server: $e';
          _loading = false;
        });
      }
    }
  }
  
  void _navigateToCamera(CameraMode mode) {
    if (!_isConnected) {
      _showConnectionErrorDialog();
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(mode: mode),
      ),
    );
  }
  
  void _showConnectionErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 10),
            Text('Connection Error'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unable to connect to the server.'),
            SizedBox(height: 16),
            Text(_connectionMessage),
            SizedBox(height: 16),
            Text('Please check:'),
            SizedBox(height: 8),
            Text('• Server is running'),
            Text('• Network connection is active'),
            Text('• API configuration is correct'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _checkConnection();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // Force portrait mode for consistent UI
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Attendance'),
        actions: [
          _loading 
            ? Container(
                margin: const EdgeInsets.only(right: 16.0),
                width: 24,
                height: 24,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : IconButton(
                icon: Icon(
                  _isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: _isConnected ? Colors.white : Colors.red,
                ),
                onPressed: _checkConnection,
                tooltip: _isConnected ? 'Connected' : 'Not Connected',
              ),
        ],
      ),
      body: Center(
        child: Column(
          children: [
            // Status banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              color: _isConnected ? Colors.green.shade100 : Colors.red.shade100,
              child: Row(
                children: [
                  Icon(
                    _isConnected ? Icons.check_circle : Icons.error_outline,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _loading 
                        ? 'Checking connection...' 
                        : _isConnected 
                          ? 'Server connected' 
                          : 'Server disconnected',
                      style: TextStyle(
                        color: _isConnected ? Colors.green.shade900 : Colors.red.shade900,
                      ),
                    ),
                  ),
                  if (!_isConnected && !_loading)
                    TextButton(
                      onPressed: _checkConnection,
                      child: const Text('Retry'),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Logo or image
            Image.asset(
              'assets/sample_logo.png',
              height: 120,
              fit: BoxFit.contain,
            ),
            
            const SizedBox(height: 30),
            
            const Text(
              'Face Attendance System',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Register your face or mark attendance using face recognition',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
            
            const SizedBox(height: 60),
            
            // Main action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildActionButton(
                    context,
                    title: 'Register',
                    icon: Icons.person_add,
                    color: Colors.indigo,
                    onTap: () => _navigateToCamera(CameraMode.register),
                  ),
                  const SizedBox(width: 20),
                  _buildActionButton(
                    context,
                    title: 'Attendance',
                    icon: Icons.how_to_reg,
                    color: Colors.blue,
                    onTap: () => _navigateToCamera(CameraMode.mark),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildActionButton(
                    context,
                    title: 'Reports',
                    icon: Icons.assessment,
                    color: Colors.amber.shade800,
                    onTap: () => Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => const ReportsScreen())
                    ),
                  ),
                  const SizedBox(width: 20),
                  _buildActionButton(
                    context,
                    title: 'Settings',
                    icon: Icons.settings,
                    color: Colors.blueGrey,
                    onTap: () => Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => const SettingsScreen())
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
  
  Widget _buildActionButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withOpacity(0.3), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 40,
                color: color,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}