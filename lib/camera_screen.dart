import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({required this.cameras});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  int selectedCameraIndex = 0;
  String selectedFilter = 'none';

  @override
  void initState() {
    super.initState();
    _initializeCamera(selectedCameraIndex);
    _checkPermissions();
  }

  Future<void> _initializeCamera(int cameraIndex) async {
    _controller = CameraController(
      widget.cameras[cameraIndex],
      ResolutionPreset.high,
    );
    _initializeControllerFuture = _controller.initialize();
    setState(() {});
  }

  Future<void> _checkPermissions() async {
    await Permission.camera.request();
    await Permission.storage.request();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _switchCamera() {
    selectedCameraIndex =
        (selectedCameraIndex + 1) % widget.cameras.length; // Toggle camera
    _initializeCamera(selectedCameraIndex);
  }

  Future<void> _takePhoto() async {
    await _initializeControllerFuture;

    final photo = await _controller.takePicture();
    final tempDir = await getTemporaryDirectory();
    final outputPath =
        '${tempDir.path}/filtered_${DateTime.now().millisecondsSinceEpoch}.jpg';

    // Apply the selected filter
    await _applyFilter(photo.path, outputPath);

    // Save to gallery
    final success = await GallerySaver.saveImage(outputPath) ?? false;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo saved to gallery!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save photo!')),
      );
    }
  }

  Future<void> _applyFilter(String inputPath, String outputPath) async {
    String filterCommand;
    switch (selectedFilter) {
      case 'grayscale':
        filterCommand = "-i $inputPath -vf format=gray $outputPath";
        break;
      case 'sepia':
        filterCommand =
            "-i $inputPath -vf colorchannelmixer=.393:.769:.189:0:.349:.686:.168:0:.272:.534:.131 $outputPath";
        break;
      case 'invert':
        filterCommand =
            "-i $inputPath -vf lutrgb=r=negval:g=negval:b=negval $outputPath";
        break;
      default:
        filterCommand = "-i $inputPath $outputPath";
    }
    await FFmpegKit.execute(filterCommand);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                // Full-screen Camera Preview
                Positioned.fill(
                  child: CameraPreview(_controller),
                ),
                if (selectedFilter != 'none')
                  Positioned.fill(
                    child: _buildFilterOverlay(selectedFilter),
                  ),
                // Top controls
                Positioned(
                  top: 40,
                  left: 20,
                  child: IconButton(
                    icon: Icon(Icons.switch_camera, color: Colors.white),
                    onPressed: _switchCamera,
                  ),
                ),
                // Filter options
                Positioned(
                  bottom: 120,
                  left: 0,
                  right: 0,
                  child: _buildFilterSelection(),
                ),
                // Capture button
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: IconButton(
                      onPressed: _takePhoto,
                      icon: Icon(Icons.camera),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: CircleBorder(),
                        padding: EdgeInsets.all(20),
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  Widget _buildFilterOverlay(String filter) {
    switch (filter) {
      case 'grayscale':
        return Container(
          color: Colors.grey.withOpacity(0.3),
        );
      case 'sepia':
        return Container(
          color: Color(0xFFC2A87A).withOpacity(0.3), // Sepia tone overlay
        );
      case 'invert':
        return ColorFiltered(
          colorFilter: ColorFilter.matrix([
            -1,
            0,
            0,
            0,
            255,
            0,
            -1,
            0,
            0,
            255,
            0,
            0,
            -1,
            0,
            255,
            0,
            0,
            0,
            1,
            0,
          ]),
          child: Container(color: Colors.transparent),
        );
      default:
        return SizedBox.shrink();
    }
  }

  Widget _buildFilterSelection() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildFilterButton('none', 'No Filter'),
          _buildFilterButton('grayscale', 'Grayscale'),
          _buildFilterButton('sepia', 'Sepia'),
          _buildFilterButton('invert', 'Invert'),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String filter, String label) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            selectedFilter = filter;
          });
        },
        child: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: selectedFilter == filter ? Colors.blue : Colors.grey,
        ),
      ),
    );
  }
}
