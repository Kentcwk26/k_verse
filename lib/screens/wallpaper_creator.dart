import 'dart:io';
import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/wallpaper_model.dart';
import '../services/firebase_service.dart';
import '../utils/snackbar_helper.dart';
import '../viewmodels/user_viewmodel.dart';
import 'select_widget_wallpaper.dart';

class WallpaperCreator extends StatefulWidget {
  const WallpaperCreator({super.key});

  @override
  State<WallpaperCreator> createState() => _WallpaperCreatorState();
}

class _WallpaperCreatorState extends State<WallpaperCreator> {
  final FirebaseService _firebaseService = FirebaseService();
  final GlobalKey _previewKey = GlobalKey();

  String? _backgroundImage;
  final List<WidgetElement> _elements = [];

  bool _isModified = false;
  bool _isLoading = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  void _getCurrentUser() async {
    final vm = Provider.of<UserViewModel>(context, listen: false);
    final user = await vm.getCurrentUser();
    if (user != null) {
      setState(() => _currentUserId = user.userId);
    }
  }

  Future<void> _pickBackgroundImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() => _isLoading = true);

    try {
      final url = await _firebaseService.uploadImage(
        "wallpapers/${DateTime.now().millisecondsSinceEpoch}",
        bytes,
      );

      setState(() {
        _backgroundImage = url;
        _isModified = true;
      });
    } catch (e) {
      SnackBarHelper.showError(context, "Image upload failed: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveWallpaper() async {
    if (_backgroundImage == null) {
      SnackBarHelper.showError(context, "Select a background image");
      return;
    }

    if (_currentUserId == null) {
      SnackBarHelper.showError(context, "User not authenticated");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final wallpaper = KWallpaper(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: _currentUserId!,
        title: "My K-Hub Wallpaper",
        backgroundImage: _backgroundImage!,
        elements: _elements,
        createdAt: DateTime.now(),
      );

      await _firebaseService.saveWallpaper(wallpaper);

      SnackBarHelper.showSuccess(context, "Wallpaper saved!");

      if (mounted) Navigator.pop(context);
    } catch (e) {
      SnackBarHelper.showError(context, "Failed: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearBackground() {
    setState(() {
      _backgroundImage = null;
      _elements.clear();
      _isModified = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Wallpaper"),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyCollectionScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: RepaintBoundary(
                        key: _previewKey,
                        child: SizedBox(
                          width: double.infinity,
                          height: MediaQuery.of(context).size.width - 32, // square
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: GestureDetector(
                              onTap: _backgroundImage == null ? _pickBackgroundImage : null,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Container(color: Colors.grey[200]),
                                  if (_backgroundImage != null)
                                    Positioned.fill(
                                      child: CachedNetworkImage(
                                        imageUrl: _backgroundImage!,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                        errorWidget: (_, __, ___) => const Center(
                                          child: Icon(Icons.broken_image, size: 48),
                                        ),
                                      ),
                                    ),
                                  if (_backgroundImage == null)
                                    Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.add_photo_alternate, size: 64, color: Colors.grey),
                                          SizedBox(height: 12),
                                          Text("Tap to add background").tr(),
                                        ],
                                      ),
                                    ),
                                  if (_backgroundImage != null)
                                    Positioned(
                                      top: 10,
                                      right: 10,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.clear, color: Colors.white),
                                              onPressed: _clearBackground,
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.white),
                                              onPressed: _pickBackgroundImage,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_backgroundImage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _saveWallpaper,
                          icon: const Icon(Icons.save),
                          label: const Text("Save to My Collection"),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class MyCollectionScreen extends StatefulWidget {
  const MyCollectionScreen({super.key});

  @override
  State<MyCollectionScreen> createState() => _MyCollectionScreenState();
}

class _MyCollectionScreenState extends State<MyCollectionScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  List<KWallpaper> _wallpapers = [];
  bool _loading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final vm = Provider.of<UserViewModel>(context, listen: false);
    final user = await vm.getCurrentUser();

    if (user != null) {
      _userId = user.userId;
      _wallpapers = await _firebaseService.getWallpapersByUser(user.userId);
    }

    setState(() => _loading = false);
  }

  Future<String?> _downloadImage(String url) async {
    try {
      final request = await HttpClient().getUrl(Uri.parse(url));
      final response = await request.close();

      final buffer = BytesBuilder();
      await for (var chunk in response) {
        buffer.add(chunk);
      }

      final dir = await getExternalStorageDirectory();
      final path ="${dir!.path}/kverse_widget_${DateTime.now().millisecondsSinceEpoch}.png";

      final file = File(path);
      await file.writeAsBytes(buffer.takeBytes());

      return path;
    } catch (e) {
      print("DOWNLOAD ERROR: $e");
      return null;
    }
  }

  Future<List<int>> getWidgetIds() async {
    const channel = MethodChannel("kverse/widget");
    final ids = await channel.invokeMethod<List<dynamic>>("getWidgets");
    return ids?.map((e) => e as int).toList() ?? [];
  }

  void _showOptions(KWallpaper w) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.widgets),
              title: const Text("Export for Widget"),
              onTap: () async {
                Navigator.pop(context); 

                final widgetIds = await getWidgetIds();

                if (widgetIds.isEmpty) {
                  SnackBarHelper.showError(context, "No widgets found");
                  return;
                }

                final widgetId = widgetIds.reduce((a, b) => a > b ? a : b);

                final path = await _downloadImage(w.backgroundImage);
                if (path == null) {
                  SnackBarHelper.showError(context, "Image error");
                  return;
                }

                const channel = MethodChannel("kverse/widget");
                await channel.invokeMethod("updateWidget", {
                  "widgetId": widgetId,
                  "image": path,
                  "text": w.title,
                  "wallpaperId": w.id,
                });

                if (!mounted) return;
                SnackBarHelper.showSuccess(context, "Widget updated!");
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                "Delete",
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _firebaseService.deleteWallpaper(w.id);
                setState(() {
                  _wallpapers.removeWhere((x) => x.id == w.id);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_wallpapers.isEmpty) {
      return const Center(child: Text("No wallpapers yet"));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _wallpapers.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (context, i) {
        final w = _wallpapers[i];

        return GestureDetector(
          onTap: () => _showOptions(w),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: w.backgroundImage,
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Collection")),
      body: _grid(),
    );
  }
}