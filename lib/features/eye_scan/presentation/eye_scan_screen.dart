import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/eye_scan/data/latest_scan_cache.dart';
import 'package:flutter_application_1/features/symptom_assessment/services/scoring_service.dart';
import 'package:flutter_application_1/audit_log_service.dart';
import 'package:flutter_application_1/eye_scan_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../services/offline_sync_service.dart';
import 'scan_result_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../../../Screens/progress_screen.dart';
import '../../../Screens/reminder_screen.dart';
import '../../../Screens/profile_screen.dart';
import '../../../Screens/tflite_helper.dart'; // Your model helper
import 'package:provider/provider.dart';
import '../../auth/providers/user_session_provider.dart';
import 'package:image/image.dart' as img;
import 'package:cloud_firestore/cloud_firestore.dart';

class EyeScanScreen extends StatefulWidget {
  final double symptomScore;
  final String? assessmentId;
  const EyeScanScreen(
      {super.key, required this.symptomScore, this.assessmentId});

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
  CameraDescription? _selectedCamera;
  bool _isFrontCamera = false;

  bool _poorLighting = false;

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

  Future<void> _checkLighting() async {
    if (!_isCameraInitialized || _cameraController == null) return;

    try {
      // Take a low-res frame for analysis
      XFile image = await _cameraController!.takePicture();
      File imageFile = File(image.path);

      // Load and analyze
      final bytes = await imageFile.readAsBytes();
      img.Image? capturedImage = img.decodeImage(bytes);
      if (capturedImage != null) {
        double luminance = _calculateAverageLuminance(capturedImage);

        // Update state based on thresholds
        setState(() {
          _poorLighting = luminance < 75 || luminance > 220;
        });
      }

      // Delete the temp file
      await imageFile.delete();
    } catch (e) {
      print('Error checking lighting: $e');
    }
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

    // REPLACE THIS SECTION:
    // final CameraDescription camera = _cameras[0];

    // WITH THIS:
    // Select camera based on preference
    final CameraDescription camera = _isFrontCamera
        ? _cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
            orElse: () =>
                _cameras.first, // Fallback to first camera if no front camera
          )
        : _cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
            orElse: () =>
                _cameras.first, // Fallback to first camera if no back camera
          );

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
      // Add this block - Start periodic lighting checks
      _checkLighting(); // Initial check
      Timer.periodic(Duration(seconds: 2), (timer) {
        if (!_isCameraInitialized || !_isCameraActive) {
          timer.cancel();
          return;
        }
        _checkLighting(); // Regular checks
      });
    } on CameraException catch (e) {
      print('Error initializing camera: ${e.description}');
    }
  }

  // ADD THIS NEW METHOD:
  Future<void> _toggleCamera() async {
    if (_cameras.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only one camera available')),
      );
      return;
    }

    setState(() {
      _isFrontCamera = !_isFrontCamera;
      _isCameraInitialized = false;
    });

    await _initializeCamera();
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

      // Get preview size
      final RenderBox box = context.findRenderObject() as RenderBox;
      double previewW = box.size.width;
      double previewH = box.size.height;

      // Crop to the square overlay
      File croppedImage =
          await _cropImageToSquare(imageFile, 220, previewW, previewH);

      final result = await CataractModel.predict(croppedImage);

      // Calculate health score
      final scoringService = ScoringService();
      final double computedHealthScore = scoringService.calculateHealthScore(
        imageScore: result['confidence'],
        symptomScore: widget.symptomScore,
        prediction: result['predictedClass'],
      );

      
      print('🔵 _captureImage: _selectedEye = $_selectedEye');
      if (_selectedEye == 'Left Eye') {
        await LatestScanCache.updateLeftEye(
            result['predictedClass'], computedHealthScore);
        print(
            ' Updated LEFT eye cache:  ${result['predictedClass']}, $computedHealthScore%');
      } else {
        await LatestScanCache.updateRightEye(
            result['predictedClass'], computedHealthScore);
        print(
            'Updated RIGHT eye cache: ${result['predictedClass']}, $computedHealthScore%');
      }
      print(
          '🔵 Cache status - Left:  ${LatestScanCache.leftEyePrediction} (${LatestScanCache.leftEyeHealthScore}%), Right: ${LatestScanCache.rightEyePrediction} (${LatestScanCache.rightEyeHealthScore}%)');

      final isGuest =
          Provider.of<UserSessionProvider>(context, listen: false).isGuest;

      String scanId =
          'scan_${DateTime.now().millisecondsSinceEpoch}_${FirebaseAuth.instance.currentUser?.uid ?? 'guest'}';
      String imageUrl = croppedImage.path; // Default fallback

      if (!isGuest) {
        try {
          // Check connectivity
          final connectivityResult = await Connectivity().checkConnectivity();

          if (connectivityResult != ConnectivityResult.none) {
            try {
              await _eyeScanService
                  .saveScanResult(
                    imageFile: croppedImage,
                    prediction: result['predictedClass'],
                    confidence: result['confidence'],
                    eye: _selectedEye,
                    symptomScore: widget.symptomScore,
                    scanId: scanId,
                    assessmentId: widget.assessmentId,
                  )
                  .timeout(const Duration(seconds: 60));

              // Verify the saved document
              final doc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser!.uid)
                  .collection('scans')
                  .doc(scanId)
                  .get()
                  .timeout(const Duration(seconds: 5));

              if (doc.exists && doc.data() != null) {
                final savedImageUrl = doc.data()!['imageUrl'];

                if (savedImageUrl != null &&
                    savedImageUrl.startsWith(
                        'https://firebasestorage.googleapis.com/')) {
                  imageUrl = savedImageUrl;
                  print(' Confirmed Storage URL: $imageUrl');
                } else {
                  print(
                      'ERROR:  Saved URL is not a Storage URL:  $savedImageUrl');
                  throw Exception('Image not properly uploaded to Storage');
                }
              } else {
                throw Exception('Scan document not found in Firestore');
              }
            } catch (e) {
              print(' Online save failed: $e');
              throw e;
            }
          } else {
            print('Offline - saving to offline queue');
            try {
              await OfflineSyncService().saveScanOffline({
                'scanId': scanId,
                'assessmentId': widget.assessmentId,
                'imageUrl': croppedImage.path,
                'prediction': result['predictedClass'],
                'confidence': result['confidence'],
                'eye': _selectedEye,
                'symptomScore': widget.symptomScore,
                'scanDate': DateTime.now().toUtc().toString().split('.').first,
                'userId': FirebaseAuth.instance.currentUser!.uid,
                'timestamp': DateTime.now().toUtc().toIso8601String(),
              });
              imageUrl = croppedImage.path;
              print(' Scan saved offline:  $scanId');
            } catch (e) {
              print(' Error saving scan offline: $e');
              imageUrl = croppedImage.path;
            }
          }
        } catch (e) {
          print(' Failed to save scan:  $e');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error saving scan: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          rethrow;
        }
      } else {
        scanId = 'guest_scan_${DateTime.now().millisecondsSinceEpoch}';
      }

      // Navigate with verified URL
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
      print('❌ Error capturing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error:  ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isCameraActive = false;
        _isCapturing = false;
        _isCameraInitialized = false;
      });
    }
  }

  // Add this method to check upload image quality
  Future<bool> _validateUploadImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot read image file')),
        );
        return false;
      }

      // Check image dimensions - ensure sufficient detail for analysis
      if (image.width < 200 || image.height < 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Image too small - please use a higher resolution image')),
        );
        return false;
      }

      // Ensure the image isn't too blurry for accurate analysis
      double blurScore = _calculateBlurScore(image);
      if (blurScore < 20) {
        // Arbitrary threshold - adjust based on testing
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Image is too blurry - please use a clearer image')),
        );
        return false;
      }

      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error validating image: $e')),
      );
      return false;
    }
  }

// Add this helper function to detect blurry images
  double _calculateBlurScore(img.Image image) {
    // Simple Laplacian variance as blur metric
    img.Image gray = img.grayscale(image);
    double variance = 0.0;
    double mean = 0.0;
    int count = 0;

    // Calculate mean value (sample every few pixels for performance)
    for (int y = 1; y < gray.height - 1; y += 3) {
      for (int x = 1; x < gray.width - 1; x += 3) {
        final pixel = gray.getPixel(x, y);
        mean += pixel.r;
        count++;
      }
    }
    mean /= count;

    // Calculate variance
    for (int y = 1; y < gray.height - 1; y += 3) {
      for (int x = 1; x < gray.width - 1; x += 3) {
        final c = gray.getPixel(x, y).r;
        final n = gray.getPixel(x, y - 1).r;
        final s = gray.getPixel(x, y + 1).r;
        final e = gray.getPixel(x + 1, y).r;
        final w = gray.getPixel(x - 1, y).r;

        // Simple Laplacian
        final laplacian = (c * 4) - n - s - e - w;
        variance += (laplacian - mean) * (laplacian - mean);
      }
    }

    return variance / count;
  }

  double _calculateAverageLuminance(img.Image image) {
    double totalLuminance = 0;
    int sampleCount = 0;

    // Sample pixels (every 10th pixel for performance)
    for (int y = 0; y < image.height; y += 10) {
      for (int x = 0; x < image.width; x += 10) {
        final pixel = image.getPixel(x, y);
        final luminance = (pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114);
        totalLuminance += luminance;
        sampleCount++;
      }
    }

    return sampleCount > 0 ? totalLuminance / sampleCount : 0;
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
        File originalImage = File(image.path);

        if (!await _validateUploadImage(originalImage)) {
          return;
        }

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


          final scoringService = ScoringService();
          final double computedHealthScore =
              scoringService.calculateHealthScore(
            imageScore: result['confidence'],
            symptomScore: widget.symptomScore,
            prediction: result['predictedClass'],
          );


          print('🔵 _captureImage: _selectedEye = $_selectedEye');
          if (_selectedEye == 'Left Eye') {
            await LatestScanCache.updateLeftEye(
                result['predictedClass'], computedHealthScore);
            print(
                ' Updated LEFT eye cache:   ${result['predictedClass']}, $computedHealthScore%');
          } else {
            await LatestScanCache.updateRightEye(
                result['predictedClass'], computedHealthScore);
            print(
                'Updated RIGHT eye cache:  ${result['predictedClass']}, $computedHealthScore%');
          }

          final isGuest =
              Provider.of<UserSessionProvider>(context, listen: false).isGuest;
          String scanId =
              'scan_${DateTime.now().millisecondsSinceEpoch}_${FirebaseAuth.instance.currentUser?.uid ?? 'guest'}';
          String imageUrl = "";

          if (!isGuest) {
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
                
                await _eyeScanService
                    .saveScanResult(
                      imageFile: croppedImage,
                      prediction: result['predictedClass'],
                      confidence: result['confidence'],
                      eye: _selectedEye,
                      symptomScore: widget.symptomScore,
                      scanId: scanId,
                    )
                    .timeout(const Duration(
                        seconds: 120));

                await AuditLogService.logAction(
                  action: 'eye_scan_performed',
                  details:
                      'ScanId: $scanId, Eye: $_selectedEye, Prediction: ${result['predictedClass']}, Confidence: ${result['confidence']}',
                ).timeout(const Duration(seconds: 10));

             
                final doc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .collection('scans')
                    .doc(scanId)
                    .get()
                    .timeout(const Duration(
                        seconds: 15)); 

                if (doc.exists && doc.data() != null) {
                  final savedImageUrl = doc.data()!['imageUrl'];

                 
                  if (savedImageUrl != null &&
                      savedImageUrl.startsWith(
                          'https://firebasestorage.googleapis.com/')) {
                    imageUrl = savedImageUrl;
                    print('✅ Storage URL confirmed: $imageUrl');
                  } else {
                    print(
                        '⚠️ WARNING: URL is not a Storage URL: $savedImageUrl');
                    throw Exception('Image not properly uploaded to Storage');
                  }
                } else {
                  throw Exception('Scan document not found in Firestore');
                }
              } catch (e) {
                print('⚠️ Failed to save scan online: $e');

                // Show error instead of silent fallback
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Upload failed: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
                rethrow;
              }
            } else {
              print(
                  '📴 Offline - saving scan to offline queue and using local image path');
              try {
                await OfflineSyncService().saveScanOffline({
                  'scanId': scanId,
                  'imageUrl': croppedImage.path,
                  'assessmentId': widget.assessmentId,
                  'prediction': result['predictedClass'],
                  'confidence': result['confidence'],
                  'eye': _selectedEye,
                  'symptomScore': widget.symptomScore,
                  'scanDate':
                      DateTime.now().toUtc().toString().split('.').first,
                  'userId': FirebaseAuth.instance.currentUser!.uid,
                  'timestamp': DateTime.now().toUtc().toIso8601String(),
                });
                imageUrl = croppedImage.path;
                print('✅ Scan saved offline: $scanId');
              } catch (e) {
                print('❌ Error saving scan offline: $e');
                imageUrl = croppedImage.path; // Still use local path
              }
            }
          } else {
            imageUrl = croppedImage.path;
          }

         
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
                backgroundColor: Colors.red,
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

    // STEP 1: Crop to center square (no processing)
    int size =
        oriImage.width < oriImage.height ? oriImage.width : oriImage.height;
    img.Image squareImage = img.copyCrop(
      oriImage,
      x: (oriImage.width - size) ~/ 2,
      y: (oriImage.height - size) ~/ 2,
      width: size,
      height: size,
    );

    // STEP 2: Resize to 224x224 (model expects this)
    img.Image resized = img.copyResize(
      squareImage,
      width: 224,
      height: 224,
      interpolation: img.Interpolation.cubic,
    );

    // STEP 3: Save file (normalization happens in tflite_helper.dart)
    final tempDir = Directory.systemTemp;
    final croppedPath =
        '${tempDir.path}/gallery_${DateTime.now().millisecondsSinceEpoch}.png';
    final croppedFile = File(croppedPath);
    await croppedFile.writeAsBytes(img.encodePng(resized));

    return croppedFile;
  }

// Helper function to add realistic camera noise

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
            if (_poorLighting)
              Positioned(
                top: 120,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.warning_amber_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Poor lighting detected',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
                  onTap: (_isCapturing || _poorLighting) ? null : _captureImage,
                  child: Container(
                    width: 70,
                    height: 70,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: (_isCapturing || _poorLighting)
                          ? Colors.grey.withOpacity(0.8)
                          : Colors.white.withOpacity(0.8),
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
            // ADD THIS CAMERA SWITCH BUTTON:
            // Camera switch button
            Positioned(
              top: 80,
              left: 20,
              child: GestureDetector(
                onTap: _toggleCamera,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cameraswitch_rounded,
                    color: Colors.white,
                    size: 24,
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
                    'Hold the device 1-3 inches from your eye target'),
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
