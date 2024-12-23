import 'dart:io';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';

class VideoRecordingScreen extends StatefulWidget {
  @override
  _VideoRecordingScreenState createState() => _VideoRecordingScreenState();
}

class _VideoRecordingScreenState extends State<VideoRecordingScreen> {
  late CameraController _cameraController;
  late List<CameraDescription> _cameras;
  bool _isRecording = false;
  XFile? _recordedVideo;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    _cameraController = CameraController(
      _cameras[0],
      ResolutionPreset.high,
    );
    await _cameraController.initialize();
    setState(() {});
  }

  Future<void> _startRecording() async {
    if (!_cameraController.value.isRecordingVideo) {
      try {
        await _cameraController.startVideoRecording();
        setState(() {
          _isRecording = true;
        });
      } catch (e) {
        print("Error starting recording: $e");
      }
    }
  }

  Future<void> _stopRecording() async {
    if (_cameraController.value.isRecordingVideo) {
      try {
        XFile video = await _cameraController.stopVideoRecording();
        setState(() {
          _isRecording = false;
          _recordedVideo = video;
        });
        _navigateToVideoPlayback();
      } catch (e) {
        print("Error stopping recording: $e");
      }
    }
  }

  void _navigateToVideoPlayback() {
    if (_recordedVideo != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              VideoPlaybackScreen(videoPath: _recordedVideo!.path),
        ),
      );
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Video Recording")),
      body: _cameraController.value.isInitialized
          ? Column(
              children: [
                AspectRatio(
                  aspectRatio: _cameraController.value.aspectRatio,
                  child: CameraPreview(_cameraController),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _isRecording ? null : _startRecording,
                      child: Text("Start Recording"),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _isRecording ? _stopRecording : null,
                      child: Text("Stop Recording"),
                    ),
                  ],
                ),
              ],
            )
          : Center(child: CircularProgressIndicator()),
    );
  }
}

class VideoPlaybackScreen extends StatelessWidget {
  final String videoPath;

  VideoPlaybackScreen({required this.videoPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Playback")),
      body: VideoOptionsScreen(videoPath: videoPath),
    );
  }
}

class VideoOptionsScreen extends StatefulWidget {
  final String videoPath;

  VideoOptionsScreen({required this.videoPath});

  @override
  _VideoOptionsScreenState createState() => _VideoOptionsScreenState();
}

class _VideoOptionsScreenState extends State<VideoOptionsScreen> {
  late VideoPlayerController _videoPlayerController;
  String? _audioPath;
  bool _isPlaying = true;
  bool _isMerging = false;

  @override
  void initState() {
    super.initState();
    _videoPlayerController = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() {});
        _videoPlayerController.play();
      });
  }

  Future<void> _pickAudioFile() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null) {
      setState(() {
        _audioPath = result.files.single.path;
      });
    }
  }

  Future<void> _mergeAudioAndVideo() async {
    if (_audioPath != null) {
      setState(() {
        _isMerging = true;
      });

      final outputDir =
          Directory('/storage/emulated/0/Download'); // Save to Downloads folder
      final outputFilePath = "${outputDir.path}/output_video.mp4";

      // Updated FFmpeg command
      final command =
          '-i "${widget.videoPath}" -i "$_audioPath" -map 0:v:0 -map 1:a:0 -c:v copy -c:a aac -shortest "$outputFilePath"';

      await FFmpegKit.execute(command).then((session) async {
        final returnCode = await session.getReturnCode();
        final output = await session.getOutput(); // Log output

        if (ReturnCode.isSuccess(returnCode)) {
          print("FFmpeg completed successfully: $output");
          setState(() {
            _videoPlayerController =
                VideoPlayerController.file(File(outputFilePath))
                  ..initialize().then((_) {
                    setState(() {
                      _isMerging = false;
                    });
                    _videoPlayerController.play();
                  });
          });
        } else {
          final errorLog = await session.getFailStackTrace();
          print("FFmpeg failed: $output");
          print("Error details: $errorLog");
          setState(() {
            _isMerging = false;
          });
        }
      });
    }
  }

  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        _videoPlayerController.pause();
      } else {
        _videoPlayerController.play();
      }
      _isPlaying = !_isPlaying;
    });
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            AspectRatio(
              aspectRatio: _videoPlayerController.value.aspectRatio,
              child: VideoPlayer(_videoPlayerController),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _togglePlayPause,
                  child: Text(_isPlaying ? "Pause" : "Play"),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _pickAudioFile,
                  child: Text("Change Audio"),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _mergeAudioAndVideo,
                  child: Text("Save Video"),
                ),
              ],
            ),
          ],
        ),
        if (_isMerging)
          Container(
            color: Colors.black54,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}
