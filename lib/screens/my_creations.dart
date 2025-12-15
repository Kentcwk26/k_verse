import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import '../models/wallpaper_model.dart';
import '../models/widget_model.dart';
import '../services/firebase_service.dart';
import '../utils/date_formatter.dart';
import '../utils/snackbar_helper.dart';
import '../viewmodels/user_viewmodel.dart';
import 'widget_creator.dart';

class MyCreations extends StatefulWidget {
  const MyCreations({super.key});

  @override
  State<MyCreations> createState() => _MyCreationsState();
}

class _MyCreationsState extends State<MyCreations> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  late TabController _tabController;
  
  List<KWallpaper> _wallpapers = [];
  List<KWidget> _widgets = [];
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _getCurrentUserAndLoadCreations();
  }

  Future<String?> _downloadImage(String url) async {
    try {
      final request = await HttpClient().getUrl(Uri.parse(url));
      final response = await request.close();

      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/wallpaper_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      debugPrint('Download failed: $e');
      return null;
    }
  }

  Future<List<int>> getWidgetIds() async {
    const channel = MethodChannel('kverse/widget');
    final result = await channel.invokeMethod<List<dynamic>>('getWidgets');

    return result?.map((e) => e as int).toList() ?? [];
  }

  void sendWidgetToHomeScreen(KWidget widget) async {
    final widgetId = widget.id;

    await HomeWidget.saveWidgetData("name_$widgetId", widget.name);
    await HomeWidget.saveWidgetData("type_$widgetId", widget.type);
    await HomeWidget.saveWidgetData("text_$widgetId", widget.data["text"] ?? "");
    await HomeWidget.saveWidgetData("countdownDate_$widgetId", widget.data["countdownDate"] ?? "");
    await HomeWidget.saveWidgetData("bgColor_$widgetId", widget.style["backgroundColor"]);
    await HomeWidget.saveWidgetData("image_$widgetId", widget.style["backgroundImage"]);

    await HomeWidget.updateWidget(
      name: 'UserHomeClockWidgetProvider',
      iOSName: 'UserHomeClockWidgetProvider',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Widget exported to Home Screen!")),
    );
  }

  Future<void> exportQuoteWidget(
    BuildContext context,
    KWidget widget,
  ) async {
    await HomeWidget.saveWidgetData(
      "quote_text",
      widget.data['text'] ?? '',
    );

    await HomeWidget.saveWidgetData(
      "quote_bg",
      widget.style['backgroundColor'] ?? '#303030',
    );

    await HomeWidget.saveWidgetData(
      "quote_image",
      widget.style['backgroundImage'],
    );

    await HomeWidget.updateWidget(
      name: 'UserHomeQuoteWidgetProvider',
      iOSName: null,
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Quote exported to Home Screen")),
    );
  }

  Future<void> sendWallpaperToHomeScreen(KWallpaper wallpaper) async {
    final path = await _downloadImage(wallpaper.backgroundImage);
    if (path == null) {
      if (!mounted) return;
      SnackBarHelper.showError(context, "Failed to download image");
      return;
    }

    final widgetIds = await getWidgetIds();
    if (widgetIds.isEmpty) {
      if (!mounted) return;
      SnackBarHelper.showError(context, "No widgets found. Add widget first.");
      return;
    }

    final widgetId = widgetIds.last;

    final channel = const MethodChannel('kverse/widget');
    await channel.invokeMethod('updateWidget', {
      'widgetId': widgetId,
      'image': path,
      'wallpaperId': wallpaper.id,
    });

    if (!mounted) return;
    SnackBarHelper.showSuccess(context, "Wallpaper exported to widget!");
  }

  void _getCurrentUserAndLoadCreations() async {
    try {
      final userViewModel = Provider.of<UserViewModel>(context, listen: false);
      final currentUser = await userViewModel.getCurrentUser();
      
      if (currentUser != null) {
        setState(() {
          _currentUserId = currentUser.userId;
        });
        await _loadCreations();
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User not authenticated')),
        );
      }
    } catch (e) {
      print('Error getting current user: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCreations() async {
    if (_currentUserId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final wallpapers = await _firebaseService.getUserWallpapers(_currentUserId!);
      final widgets = await _firebaseService.getUserWidgets(_currentUserId!);
      
      setState(() {
        _wallpapers = wallpapers;
        _widgets = widgets;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading creations: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _deleteWallpaper(String id) async {
    try {
      await _firebaseService.deleteWallpaper(id);
      
      setState(() {
        _wallpapers.removeWhere((wallpaper) => wallpaper.id == id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wallpaper deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete wallpaper: $e')),
      );
    }
  }

  void _deleteWidget(String id) async {
    try {
      await _firebaseService.deleteWidget(id);
      
      setState(() {
        _widgets.removeWhere((widget) => widget.id == id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Widget deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete widget: $e')),
      );
    }
  }

  Widget _buildWallpaperGrid() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    if (_wallpapers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wallpaper, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No wallpapers yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Create your first K-pop wallpaper!',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.7,
      ),
      itemCount: _wallpapers.length,
      itemBuilder: (context, index) {
        final wallpaper = _wallpapers[index];
        return _buildWallpaperCard(wallpaper);
      },
    );
  }

  Widget _buildWallpaperCard(KWallpaper wallpaper) {
    return GestureDetector(
      onTap: () => sendWallpaperToHomeScreen(wallpaper),
      child: Card(
        elevation: 4,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    child: Image.network(
                      wallpaper.backgroundImage,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    (loadingProgress.expectedTotalBytes ?? 1)
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),

            // DELETE BUTTON (still works)
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                onPressed: () => _deleteWallpaper(wallpaper.id),
              ),
            ),

            // EXPORT ICON OVERLAY (visual hint)
            Positioned(
              bottom: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.phone_android,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWidgetsList() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    if (_widgets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.widgets, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No widgets yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Create your first K-pop widget!',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _widgets.length,
      itemBuilder: (context, index) {
        final widget = _widgets[index];
        return _buildWidgetCard(widget);
      },
    );
  }

  Widget _buildWidgetCard(KWidget widget) {

    IconData getWidgetIcon(String type) {
      switch (type) {
        case 'clock': return Icons.access_time;
        case 'calendar': return Icons.calendar_today;
        case 'quote': return Icons.format_quote;
        case 'countdown': return Icons.hourglass_bottom;
        default: return Icons.widgets;
      }
    }

    final bgColor = Color(
      int.parse(widget.style['backgroundColor'].substring(1), radix: 16) + 0xFF000000,
    );

    final textColor = widget.style['textColor'] != null
        ? Color(int.parse(widget.style['textColor'].substring(1), radix: 16) + 0xFF000000)
        : Colors.white;

    final hasImage = widget.style['backgroundImage'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              bottomLeft: Radius.circular(14),
            ),
            child: Container(
              width: 90,
              height: 90,
              color: Colors.black.withOpacity(0.1),
              child: hasImage
                  ? Image.network(
                      widget.style['backgroundImage'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white),
                    )
                  : const Icon(Icons.image, color: Colors.white60, size: 40),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      getWidgetIcon(widget.type),
                      size: 18,
                      color: textColor,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        widget.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _getWidgetPreviewText(widget),
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withOpacity(0.8),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          IconButton(
            icon: const Icon(Icons.edit, color: Colors.grey),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditWidgetScreen(widget: widget),
                ),
              ).then((_) => _loadCreations());
            },
          ),

          IconButton(
            icon: const Icon(Icons.phone_android),
            onPressed: () {
              if (widget.type == 'quote') {
                exportQuoteWidget(context, widget);
              } else {
                sendWidgetToHomeScreen(widget);
              }
            },
          ),

          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deleteWidget(widget.id),
          ),
        ],
      ),
    );
  }

  String _getWidgetPreviewText(KWidget widget) {
    switch (widget.type) {
      case 'clock':
        return DateFormatter.format12Hour(DateTime.now());
      case 'calendar':
        return DateFormatter.fullDateTime(DateTime.now());
      case 'quote':
        return widget.data['text']?.toString() ?? 'Quote...';
      case 'countdown':
        final date = widget.data['countdownDate']?.toString() ?? '';
        return date.isEmpty ? 'Countdown' : 'Countdown to $date';
      default:
        return 'Widget';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Creations'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.wallpaper), text: 'Wallpapers'),
            Tab(icon: Icon(Icons.widgets), text: 'Widgets'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWallpaperGrid(),
          _buildWidgetsList(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}