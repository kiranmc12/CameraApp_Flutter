import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'gallery.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraScreen({
    Key? key,
    required this.cameras,
  }) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  List<File> capturedImages = [];
  SharedPreferences? preferences;

  @override
  void initState() {
    super.initState();
    initializeCamera(selectedCamera);
    loadImages();
  }

  int selectedCamera = 0;

  void loadImages() async {
    preferences = await SharedPreferences.getInstance();
    final List<String>? imagePaths = preferences!.getStringList('imagePaths');
    if (imagePaths != null) {
      setState(() {
        capturedImages = imagePaths.map((path) => File(path)).toList();
      });
    }
  }

  initializeCamera(int cameraIndex) async {
    _controller = CameraController(
      widget.cameras[cameraIndex],
      ResolutionPreset.high,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  Future<void> _takePicture() async {
    await _initializeControllerFuture;
    final Directory appDirectory = await getApplicationDocumentsDirectory();
    final String imageDirectoryName = 'captured_images';
    final Directory imageDirectory =
        Directory(path.join(appDirectory.path, imageDirectoryName));
    final String currentTimestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String filePath = path.join(imageDirectory.path, '$currentTimestamp.jpg');

    try {
      if (!await imageDirectory.exists()) {
        await imageDirectory.create(recursive: true);
      }

      XFile xFile = await _controller.takePicture();
      final File savedImage = File(xFile.path);
      savedImage.copySync(filePath);
      capturedImages.add(savedImage);
      saveImagesToPrefs();
      setState(() {});
    } catch (e) {
      print('Error taking picture: $e');
    }
  }

  Future<void> saveImagesToPrefs() async {
    final List<String> imagePaths = capturedImages.map((image) => image.path).toList();
    await preferences!.setStringList('imagePaths', imagePaths);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }                                                                                                                  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Camera"),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GalleryScreen(
                    images: capturedImages,
                  ),
                ),
              );
            },
            icon: Icon(Icons.photo_library),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return Container(
                    height: MediaQuery.of(context).size.height * 0.6,
                    width: double.infinity,
                    child: CameraPreview(_controller),
                  );
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
            Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      if (widget.cameras.length > 1) {
                        setState(() {
                          selectedCamera = 1 - selectedCamera;
                          initializeCamera(selectedCamera);
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('No secondary camera found'),
                          duration: const Duration(seconds: 2),
                        ));
                      }
                    },
                    icon: Icon(Icons.switch_camera_rounded, color: Colors.white),
                  ),
                  GestureDetector(
                    onTap: _takePicture,
                    child: Container(
                      height: 60,
                      width: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GalleryScreen(
                            images: capturedImages,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      height: 60,
                      width: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: capturedImages.isNotEmpty
                          ? Image.file(capturedImages.last, fit: BoxFit.cover)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            Spacer(),
          ],
        ),
      ),
    );
  }
}
