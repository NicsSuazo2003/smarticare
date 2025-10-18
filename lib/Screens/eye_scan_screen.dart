import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/Screens/latest_scan_cache.dart';
import 'package:flutter_application_1/audit_log_service.dart';
import 'package:flutter_application_1/eye_scan_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'scan_result_screen.dart';
import 'home_screen.dart';
import 'progress_screen.dart';
import 'reminder_screen.dart';
import 'profile_screen.dart';
import 'tflite_helper.dart'; // Your model helper
import 'package:provider/provider.dart';
import '../user_session_provider.dart';
import 'package:image/image.dart' as img;
import 'package:cloud_firestore/cloud_firestore.dart';

class EyeScanScreen extends StatefulWidget {
  final double symptomScore;
  const EyeScanScreen({super.key, required this.symptomScore});

  @override
  State<EyeScanScreen> createState() => _EyeScanScreenState();
}

class _EyeScanScreenState extends State<EyeScanScreen> {
  final EyeScanService _eyeScanService = EyeScanService();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  String _selectedEye = 'Left Eye';
  bool _isCameraActive = false;
  int _selectedNavIndex = 2;

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isCapturing = false;

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _setupCamera() async {
    await _initializeCamera();
    await _startCamera();
  }

  Future<void> _startCamera() async {
    final status = await Permission.camera.request();

    if (status.isGranted) {
      setState(() {
        _isCameraActive = true;
      });

      Future.delayed(const Duration(milliseconds: 300), () {
        _initializeCamera();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera permission is required for scanning'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<File> compressImage(File file) async {
    final bytes = await file.readAsBytes();
    img.Image? image = img.decodeImage(bytes);

    // Resize if too large
    if (image!.width > 1024 || image.height > 1024) {
      image = img.copyResize(image, width: 1024);
    }

    // Compress
    final compressed = img.encodeJpg(image, quality: 85);
    final compressedFile = File('${file.path}_compressed.jpg');
    await compressedFile.writeAsBytes(compressed);

    return compressedFile;
  }

  Future<File> _cropImageToSquare(File imageFile, double overlaySize,
      double previewW, double previewH) async {
    // Load the image using the image package
    final bytes = await imageFile.readAsBytes();
    img.Image? oriImage = img.decodeImage(bytes);
    if (oriImage == null) throw Exception('Cannot decode image');

    // Calculate crop region in image pixels
    // (Assume preview is full-screen, adjust if you use aspect ratio)
    int cropX = ((oriImage.width - overlaySize) / 2).round();
    int cropY = ((oriImage.height - overlaySize) / 2).round();
    int cropSize = overlaySize.round();

    // Clamp crop to image bounds
    cropX = cropX.clamp(0, oriImage.width - cropSize);
    cropY = cropY.clamp(0, oriImage.height - cropSize);

    img.Image cropped = img.copyCrop(
      oriImage,
      x: cropX,
      y: cropY,
      width: cropSize,
      height: cropSize,
    );

    // Save to temp file
    final tempDir = Directory.systemTemp;
    final croppedPath =
        '${tempDir.path}/cropped_eye_${DateTime.now().millisecondsSinceEpoch}.png';
    final croppedFile = File(croppedPath);
    await croppedFile.writeAsBytes(img.encodePng(cropped));
    return croppedFile;
  }

  Future<void> _initializeCamera() async {
    if (_cameras.isEmpty) {
      try {
        _cameras = await availableCameras();
      } catch (e) {
        print('Error fetching cameras: $e');
      }
      if (_cameras.isEmpty) {
        print('No cameras found');
        return;
      }
    }

    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null;
    }

    final CameraDescription camera = _cameras[0];

    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
      });
    } on CameraException catch (e) {
      print('Error initializing camera: ${e.description}');
    }
  }

  Future<void> _captureImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (_isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile image = await _cameraController!.takePicture();
      File imageFile = File(image.path);

      // Get preview size (pass to crop)
      final RenderBox box = context.findRenderObject() as RenderBox;
      double previewW = box.size.width;
      double previewH = box.size.height;

      // Crop to the square overlay before prediction
      File croppedImage =
          await _cropImageToSquare(imageFile, 220, previewW, previewH);

      final result = await CataractModel.predict(croppedImage);

      final isGuest =
          Provider.of<UserSessionProvider>(context, listen: false).isGuest;
      String scanId = "";
      String imageUrl = "";

      if (!isGuest) {
        // ✅ Check connectivity with timeout
        bool isOnline = false;
        try {
          final connectivityResult = await Connectivity()
              .checkConnectivity()
              .timeout(const Duration(milliseconds: 500));
          isOnline = connectivityResult != ConnectivityResult.none;
        } catch (_) {
          isOnline = false;
        }

        if (isOnline) {
          // Try to save with timeout
          try {
            LatestScanCache.updateLeftEye(
                result['predictedClass'], result['confidence']);

            scanId = await _eyeScanService
                .saveScanResult(
                  imageFile: croppedImage,
                  prediction: result['predictedClass'],
                  confidence: result['confidence'],
                  eye: _selectedEye,
                  symptomScore: widget.symptomScore,
                )
                .timeout(const Duration(seconds: 3));

            // Save notifications with timeout
            final userId = FirebaseAuth.instance.currentUser?.uid ?? "";
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('notifications')
                .add({
              "type": "scan",
              "title": "Eye Scan Result Ready",
              "message": "Your eye scan result is ready to view.",
              "timestamp": FieldValue.serverTimestamp(),
              "isRead": false,
            }).timeout(const Duration(seconds: 2));

            // Additional notifications (omitted for brevity)
            // ... (add similar timeout logic for other Firestore writes)

            await AuditLogService.logAction(
              action: 'eye_scan_performed',
              details:
                  'ScanId: $scanId, Eye: $_selectedEye, Prediction: ${result['predictedClass']}, Confidence: ${result['confidence']}',
            ).timeout(const Duration(seconds: 2));

            // Get imageUrl
            final doc = await FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser!.uid)
                .collection('scans')
                .doc(scanId)
                .get()
                .timeout(const Duration(seconds: 2));
            imageUrl = doc['imageUrl'];
          } catch (e) {
            print('⚠️ Failed to save scan online (proceeding anyway): $e');
            // Use local file path as fallback
            imageUrl = croppedImage.path;
          }
        } else {
          // ✅ Offline: Use local file path
          print('📴 Offline - using local image path');
          imageUrl = croppedImage.path;
        }
      } else {
        // For guest, just display the local file path as URL
        imageUrl = croppedImage.path;
      }

      // ✅ ALWAYS navigate, regardless of save success
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ScanResultScreen(
              imageUrl: imageUrl,
              prediction: result['predictedClass'],
              confidence: result['confidence'],
              eye: _selectedEye,
              scanDate: DateTime.now().toUtc().toString().split('.').first,
              scanId: scanId,
              symptomScore: widget.symptomScore,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error capturing and saving image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isCameraActive = false;
        _isCapturing = false;
        _isCameraInitialized = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening gallery...'),
          duration: Duration(seconds: 1),
        ),
      );

      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        // Define originalImage first
        File originalImage = File(image.path);

        // Then crop it
        File croppedImage = await _cropImageToCenterSquare(originalImage);

        setState(() {
          _selectedImage = croppedImage;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Processing image...'),
              duration: Duration(seconds: 2),
            ),
          );
        }

        try {
          print('Selected image path: ${croppedImage.path}');
          print('File exists: ${await croppedImage.exists()}');
          print('File size: ${await croppedImage.length()} bytes');

          final result = await CataractModel.predict(croppedImage);
          print(
              'Prediction result: ${result['predictedClass']}, confidence: ${result['confidence']}');

          if (_selectedEye == 'Left Eye') {
            LatestScanCache.updateLeftEye(
                result['predictedClass'], result['confidence']);
          } else {
            LatestScanCache.updateRightEye(
                result['predictedClass'], result['confidence']);
          }

          final isGuest =
              Provider.of<UserSessionProvider>(context, listen: false).isGuest;
          String scanId = "";
          String imageUrl = "";

          if (!isGuest) {
            // ✅ Check connectivity with timeout
            bool isOnline = false;
            try {
              final connectivityResult = await Connectivity()
                  .checkConnectivity()
                  .timeout(const Duration(milliseconds: 500));
              isOnline = connectivityResult != ConnectivityResult.none;
            } catch (_) {
              isOnline = false;
            }

            if (isOnline) {
              try {
                scanId = await _eyeScanService
                    .saveScanResult(
                      imageFile: croppedImage, // Use cropped image here too
                      prediction: result['predictedClass'],
                      confidence: result['confidence'],
                      eye: _selectedEye,
                      symptomScore: widget.symptomScore,
                    )
                    .timeout(const Duration(seconds: 3));

                await AuditLogService.logAction(
                  action: 'eye_scan_performed',
                  details:
                      'ScanId: $scanId, Eye: $_selectedEye, Prediction: ${result['predictedClass']}, Confidence: ${result['confidence']}',
                ).timeout(const Duration(seconds: 2));

                final doc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .collection('scans')
                    .doc(scanId)
                    .get()
                    .timeout(const Duration(seconds: 2));
                imageUrl = doc['imageUrl'];
              } catch (e) {
                print('⚠️ Failed to save scan online (proceeding anyway): $e');
                imageUrl = croppedImage.path;
              }
            } else {
              print('📴 Offline - using local image path');
              imageUrl = croppedImage.path;
            }
          } else {
            imageUrl = croppedImage.path;
          }

          // ✅ ALWAYS navigate
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ScanResultScreen(
                  imageUrl: imageUrl,
                  prediction: result['predictedClass'],
                  confidence: result['confidence'],
                  eye: _selectedEye,
                  scanDate: DateTime.now().toUtc().toString().split('.').first,
                  scanId: scanId,
                  symptomScore: widget.symptomScore,
                ),
              ),
            );
          }
        } catch (e) {
          print('Error processing image: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${e.toString()}'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No image selected')),
          );
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }

  Future<File> _cropImageToCenterSquare(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    img.Image? oriImage = img.decodeImage(bytes);
    if (oriImage == null) throw Exception('Cannot decode image');

    // Determine the size for square crop (use smaller dimension)
    int size =
        oriImage.width < oriImage.height ? oriImage.width : oriImage.height;

    // Calculate center crop coordinates
    int cropX = (oriImage.width - size) ~/ 2;
    int cropY = (oriImage.height - size) ~/ 2;

    img.Image cropped = img.copyCrop(
      oriImage,
      x: cropX,
      y: cropY,
      width: size,
      height: size,
    );

    // Save to temp file
    final tempDir = Directory.systemTemp;
    final croppedPath =
        '${tempDir.path}/gallery_cropped_${DateTime.now().millisecondsSinceEpoch}.png';
    final croppedFile = File(croppedPath);
    await croppedFile.writeAsBytes(img.encodePng(cropped));
    return croppedFile;
  }

  void _onNavItemTapped(int index) {
    if (_selectedNavIndex == index) {
      return;
    }

    setState(() {
      _selectedNavIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
        break;
      case 1:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ProgressScreen()),
          (route) => false,
        );
        break;
      case 2:
        break;
      case 3:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ReminderScreen()),
          (route) => false,
        );
        break;
      case 4:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
          (route) => false,
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFF6B6B);
    const Color secondaryColor = Color(0xFF4ECDC4);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () {
                      if (_isCameraActive) {
                        setState(() {
                          _isCameraActive = false;
                          _isCameraInitialized = false;
                        });
                      } else {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const HomeScreen()),
                          (route) => false,
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isCameraActive
                            ? Colors.black.withOpacity(0.5)
                            : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: _isCameraActive
                            ? []
                            : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        size: 24,
                        color: _isCameraActive ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  Text(
                    'Eye Scan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _isCameraActive ? Colors.white : Colors.black,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('About Eye Scanning'),
                          content: const Text(
                              'This feature uses computer vision to detect potential signs of cataracts. '
                              'For accurate results, please follow the guidelines and ensure good lighting conditions.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isCameraActive
                            ? Colors.black.withOpacity(0.5)
                            : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: _isCameraActive
                            ? []
                            : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Icon(
                        Icons.info_outline,
                        size: 24,
                        color: _isCameraActive ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isCameraActive
                  ? _buildCameraView()
                  : _buildInstructionsView(primaryColor, secondaryColor),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(primaryColor),
    );
  }

  Widget _buildCameraView() {
    if (!_isCameraInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    // Square overlay size
    double overlaySize = 220;

    return LayoutBuilder(
      builder: (context, constraints) {
        double width = constraints.maxWidth;
        double height = constraints.maxHeight;
        double left = (width - overlaySize) / 2;
        double top = (height - overlaySize) / 2;

        return Stack(
          children: [
            // Camera preview
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            ),
            // Masked overlay: darken everything outside the square
            Positioned.fill(
              child: Stack(
                children: [
                  // Top
                  Positioned(
                    left: 0,
                    top: 0,
                    right: 0,
                    height: top,
                    child: Container(color: Colors.black.withOpacity(0.5)),
                  ),
                  // Bottom
                  Positioned(
                    left: 0,
                    top: top + overlaySize,
                    right: 0,
                    bottom: 0,
                    child: Container(color: Colors.black.withOpacity(0.5)),
                  ),
                  // Left
                  Positioned(
                    left: 0,
                    top: top,
                    width: left,
                    height: overlaySize,
                    child: Container(color: Colors.black.withOpacity(0.5)),
                  ),
                  // Right
                  Positioned(
                    left: left + overlaySize,
                    top: top,
                    right: 0,
                    height: overlaySize,
                    child: Container(color: Colors.black.withOpacity(0.5)),
                  ),
                  // The square border
                  Positioned(
                    left: left,
                    top: top,
                    width: overlaySize,
                    height: overlaySize,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Overlay text
            Positioned(
              top: 32,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    "Position your eye in the square for best results.\n\nHold steady and avoid blinking.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            // Capture button
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _isCapturing ? null : _captureImage,
                  child: Container(
                    width: 70,
                    height: 70,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isCapturing ? Colors.grey : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Scanning eye label
            Positioned(
              bottom: 130,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Scanning $_selectedEye',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 80,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isCameraActive = false;
                    _isCameraInitialized = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
            // LOADING OVERLAY
            if (_isCapturing)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: Colors.white,
                        ),
                        SizedBox(height: 18),
                        Text(
                          'Processing...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildInstructionsView(Color primaryColor, Color secondaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Cataract Eye Scan',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Our system analyzes your eye for early signs of cataracts including lens opacity, clouding patterns, and light diffraction abnormalities.',
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'For best results:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInstructionItem(Icons.wb_sunny_outlined,
                    'Find a well-lit room, preferably with natural light'),
                _buildInstructionItem(Icons.remove_red_eye_outlined,
                    'Remove glasses or contact lenses before scanning'),
                _buildInstructionItem(Icons.center_focus_strong,
                    'Position your eye in the center of the square overlay'),
                _buildInstructionItem(Icons.phone_android,
                    'Hold the device 10-12 inches (25-30 cm) from your face'),
                _buildInstructionItem(Icons.visibility,
                    'Try to keep your eye open and avoid blinking during capture'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Select eye to scan:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedEye = 'Left Eye';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _selectedEye == 'Left Eye'
                          ? secondaryColor
                          : Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                      border: Border.all(
                        color: _selectedEye == 'Left Eye'
                            ? secondaryColor
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Left Eye',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _selectedEye == 'Left Eye'
                              ? Colors.white
                              : Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedEye = 'Right Eye';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _selectedEye == 'Right Eye'
                          ? secondaryColor
                          : Colors.white,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      border: Border.all(
                        color: _selectedEye == 'Right Eye'
                            ? secondaryColor
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Right Eye',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _selectedEye == 'Right Eye'
                              ? Colors.white
                              : Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.red.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Important Medical Notice',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'This scan provides preliminary assessment only and is not a substitute for professional medical examination. Always consult with an eye care specialist for proper diagnosis and treatment.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red.shade900,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildActionButton(
            icon: Icons.camera_alt_rounded,
            label: 'Start Camera',
            onTap: _startCamera,
            isPrimary: true,
            color: primaryColor,
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            icon: Icons.photo_library_rounded,
            label: 'Upload an existing eye photo',
            onTap: _pickImage,
            isPrimary: false,
            color: primaryColor,
          ),
          const SizedBox(height: 8),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Supported formats: JPG & PNG',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'By scanning or uploading an image, you agree to our Privacy Policy and Terms of Service. Images are processed securely and archived after analysis.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar(Color primaryColor) {
    final isGuest = Provider.of<UserSessionProvider>(context).isGuest;
    if (isGuest) {
      return BottomNavigationBar(
        currentIndex: 0,
        items: [
          BottomNavigationBarItem(
            icon: Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white),
            ),
            label: 'Eye Scan',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.info_outline),
            label: 'Info',
          ),
        ],
        onTap: (index) {}, // Optionally do nothing or show info
      );
    }
    return BottomNavigationBar(
      currentIndex: _selectedNavIndex,
      onTap: _onNavItemTapped,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey.shade600,
      selectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
      elevation: 12,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.trending_up_outlined),
          activeIcon: Icon(Icons.trending_up),
          label: 'Progress',
        ),
        BottomNavigationBarItem(
          icon: Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt,
              color: Colors.white,
            ),
          ),
          label: 'Eye Scan',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.notifications_outlined),
          activeIcon: Icon(Icons.notifications),
          label: 'Reminders',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }

  Widget _buildInstructionItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isPrimary ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary ? color : Colors.grey.shade400,
            width: isPrimary ? 0 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: isPrimary ? Colors.white : Colors.grey.shade800,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isPrimary ? Colors.white : Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
