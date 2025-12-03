import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../models/wallpaper_model.dart';
import '../services/firebase_service.dart';
import '../utils/snackbar_helper.dart';
import '../viewmodels/user_viewmodel.dart';

class SelectWidgetWallpaperScreen extends StatefulWidget {
  final int widgetId;

  const SelectWidgetWallpaperScreen({super.key, required this.widgetId});

  @override
  State<SelectWidgetWallpaperScreen> createState() => _SelectWidgetWallpaperScreenState();
}

class _SelectWidgetWallpaperScreenState extends State<SelectWidgetWallpaperScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  static const MethodChannel _channel = MethodChannel("kverse/widget");

  KWallpaper? selectedWallpaper;
  bool loading = true;
  String widgetText = "";

  @override
  void initState() {
    super.initState();
    _loadWallpapers();
  }

  Future<void> _loadWallpapers() async {
    final userVM = Provider.of<UserViewModel>(context, listen: false);
    final user = await userVM.getCurrentUser();

    if (user == null) {
      setState(() => loading = false);
      return;
    }

    final wallpapers = await _firebaseService.getWallpapersByUser(user.userId);

    if (wallpapers.isNotEmpty) {
      selectedWallpaper = wallpapers.first;
      widgetText = selectedWallpaper!.title;
    }

    setState(() => loading = false);
  }

  Future<String?> _downloadImage(String url) async {
    try {
      final request = await HttpClient().getUrl(Uri.parse(url));
      final response = await request.close();

      final bytes = <int>[];
      await for (var chunk in response) {
        bytes.addAll(chunk);
      }

      final dir = await getExternalStorageDirectory();
      final path ="${dir!.path}/kverse_widget_${DateTime.now().millisecondsSinceEpoch}.png";

      final file = File(path);
      await file.writeAsBytes(bytes);

      return path;
    } catch (e) {
      debugPrint("Download failed: $e");
      return null;
    }
  }

  Future<void> _applyToWidget() async {
    if (selectedWallpaper == null) {
      SnackBarHelper.showError(context, "Select a wallpaper first");
      return;
    }

    final path = await _downloadImage(selectedWallpaper!.backgroundImage);
    if (path == null) {
      SnackBarHelper.showError(context, "Image processing failed");
      return;
    }

    await _channel.invokeMethod("updateWidget", {
      "widgetId": widget.widgetId,
      "image": path,
      "text": widgetText,
      "wallpaperId": selectedWallpaper!.id,
    });

    if (mounted) {
      SnackBarHelper.showSuccess(context, "Widget updated!");
      Navigator.pop(context);
    }
  }

  void _openSelector(List<KWallpaper> wallpapers) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => SizedBox(
        height: 350,
        child: GridView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: wallpapers.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, i) {
            final w = wallpapers[i];
            return GestureDetector(
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  selectedWallpaper = w;
                  widgetText = w.title;
                });
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: w.backgroundImage,
                  fit: BoxFit.cover,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Widget #${widget.widgetId}"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : selectedWallpaper == null
              ? const Center(child: Text("No wallpapers available"))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 1.6,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: CachedNetworkImage(
                                  imageUrl: selectedWallpaper!.backgroundImage,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                bottom: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    widgetText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Wallpaper selector
                      ElevatedButton.icon(
                        onPressed: () async {
                          final vm = Provider.of<UserViewModel>(context, listen: false);
                          final user = await vm.getCurrentUser();
                          if (user == null) return;
                          final wallpapers = await _firebaseService.getWallpapersByUser(user.userId);
                          _openSelector(wallpapers);
                        },
                        icon: const Icon(Icons.photo_library),
                        label: const Text("Change Wallpaper"),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: TextEditingController(text: widgetText),
                        onChanged: (v) => widgetText = v,
                        decoration: const InputDecoration(
                          labelText: "Widget Text",
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const Spacer(),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _applyToWidget,
                          child: const Padding(
                            padding: EdgeInsets.all(14),
                            child: Text(
                              "Apply to Widget",
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class WidgetPickerScreen extends StatefulWidget {
  const WidgetPickerScreen({super.key});

  @override
  State<WidgetPickerScreen> createState() => _WidgetPickerScreenState();
}

class _WidgetPickerScreenState extends State<WidgetPickerScreen> {
  static const MethodChannel _channel = MethodChannel("kverse/widget");

  List<int> widgetIds = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadWidgets();
  }

  Future<void> _loadWidgets() async {
    try {
      final ids = await _channel.invokeMethod<List<dynamic>>("getWidgets");
      setState(() {
        widgetIds = ids?.map((e) => e as int).toList() ?? [];
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      debugPrint("Error loading widget IDs: $e");
    }
  }

  void _selectWidget(int widgetId) {
    Navigator.pop(context, widgetId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Widget"),
        elevation: 1,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : widgetIds.isEmpty
              ? const Center(
                  child: Text(
                    "No widgets found.\nPlease add a widget on your home screen first.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.separated(
                  itemCount: widgetIds.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final id = widgetIds[index];
                    return ListTile(
                      leading: const Icon(Icons.widgets),
                      title: Text("Widget #$id"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _selectWidget(id),
                    );
                  },
                ),
    );
  }
}