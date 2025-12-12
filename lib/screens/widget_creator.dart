import 'dart:io';
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/widget_model.dart';
import '../services/firebase_service.dart';
import '../utils/date_formatter.dart';
import '../viewmodels/user_viewmodel.dart';
import '../widgets/color_picker.dart';

class WidgetCreator extends StatefulWidget {
  const WidgetCreator({super.key});

  @override
  State<WidgetCreator> createState() => _WidgetCreatorState();
}

class _WidgetCreatorState extends State<WidgetCreator> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quoteController = TextEditingController();
  final TextEditingController _countdownDateController = TextEditingController();

  String? _currentUserId;
  String _selectedType = 'clock';
  String? _uploadedImagePath;
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  final Map<String, dynamic> _style = {
    'backgroundColor': '#FF69B4',
    'textColor': '#FFFFFF',
    'backgroundImage': null,
    'fontSize': 16.0, // fixed at 16
  };

  Map<String, dynamic> _data = {};

  final List<Map<String, dynamic>> _widgetTypes = [
    {'type': 'clock', 'name': 'Digital Clock', 'icon': Icons.access_time},
    {
      'type': 'calendar',
      'name': 'Event Calendar',
      'icon': Icons.calendar_today,
    },
    {
      'type': 'quote',
      'name': 'Inspirational Quote',
      'icon': Icons.format_quote,
    },
    {'type': 'countdown', 'name': 'Countdown', 'icon': Icons.hourglass_bottom},
  ];

  void _getCurrentUser() async {
    final vm = Provider.of<UserViewModel>(context, listen: false);
    final user = await vm.getCurrentUser();
    if (user != null) {
      setState(() => _currentUserId = user.userId);
    }
  }

  Future<void> _pickColor({
    required String key,
    required Color currentColor,
  }) async {
    showDialog(
      context: context,
      builder: (_) => ColorPickerDialog(
        currentColor: currentColor,
        onColorSelected: (color) {
          setState(() {
            _style[key] = '#${color.value.toRadixString(16).substring(2)}';
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _pickBackgroundImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    final downloadUrl = await _firebaseService.uploadImage(
      "widget_images/${DateTime.now().millisecondsSinceEpoch}.jpg",
      bytes,
    );

    setState(() {
      _uploadedImagePath = downloadUrl;
      _style['backgroundImage'] = downloadUrl;
    });
  }

  Future<void> _saveWidget() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please enter widget name')));
      return;
    }

    if (_selectedType == "quote" && _quoteController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter quote text')));
      return;
    }

    if (_selectedType == "countdown" && _countdownDateController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter countdown date')));
      return;
    }

    _data = {
      'text': _quoteController.text,
      'countdownDate': _countdownDateController.text,
    };

    final widgetModel = KWidget(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: _currentUserId!,
      name: _nameController.text,
      type: _selectedType,
      style: _style,
      data: _data,
      createdAt: DateTime.now(),
    );

    await _firebaseService.saveWidget(widgetModel);

    final wid = widgetModel.id;

    await HomeWidget.saveWidgetData<String>('name_$wid', widgetModel.name);
    await HomeWidget.saveWidgetData<String>('type_$wid', widgetModel.type);
    await HomeWidget.saveWidgetData<String>('text_$wid', widgetModel.data['text'] ?? "");
    await HomeWidget.saveWidgetData<String>('countdownDate_$wid', widgetModel.data['countdownDate'] ?? "");
    await HomeWidget.saveWidgetData<String>('bgColor_$wid', widgetModel.style['backgroundColor']);
    await HomeWidget.saveWidgetData<String>('image_$wid', widgetModel.style['backgroundImage']);

    await HomeWidget.updateWidget(
      name: 'UserHomeClockWidgetProvider',
      iOSName: null,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Widget created successfully!')),
    );

    Navigator.pop(context);
  }

  Widget _buildStyleControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Style",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Background Color
        ListTile(
          title: const Text("Background Color"),
          trailing: CircleAvatar(
            backgroundColor: Color(
              int.parse(_style['backgroundColor'].substring(1), radix: 16) + 0xFF000000,
            ),
          ),
          onTap: () {
            _pickColor(
              key: 'backgroundColor',
              currentColor: Color(
                int.parse(_style['backgroundColor'].substring(1), radix: 16) + 0xFF000000,
              ),
            );
          },
        ),

        // Text Color
        ListTile(
          title: const Text("Text Color"),
          trailing: CircleAvatar(
            backgroundColor: Color(
              int.parse(_style['textColor'].substring(1), radix: 16) + 0xFF000000,
            ),
          ),
          onTap: () {
            _pickColor(
              key: 'textColor',
              currentColor: Color(
                int.parse(_style['textColor'].substring(1), radix: 16) + 0xFF000000,
              ),
            );
          },
        ),

        // Background Image
        ListTile(
          title: const Text("Background Image"),
          trailing: const Icon(Icons.upload),
          onTap: _pickBackgroundImage,
        ),
      ],
    );
  }

  Widget _buildPreview() {
    final bgColor = Color(
      int.parse(_style['backgroundColor'].substring(1), radix: 16) + 0xFF000000,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // LEFT SIDE: IMAGE BOX
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black.withOpacity(0.1),
              image: _uploadedImagePath != null
                  ? DecorationImage(
                      image: NetworkImage(_uploadedImagePath!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _uploadedImagePath == null
                ? const Icon(Icons.image, size: 40, color: Colors.white70)
                : null,
          ),

          const SizedBox(width: 16),

          // RIGHT SIDE: TEXT CONTENT
          Expanded(child: _buildRightTextContent()),
        ],
      ),
    );
  }

  Widget _buildRightTextContent() {
    final color = Color(
      int.parse(_style['textColor'].substring(1), radix: 16) + 0xFF000000,
    );

    switch (_selectedType) {
      case 'clock':
        return Center(
          child: Text(
          DateFormat('hh:mm:ss a').format(_now),
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        )
      );

      case 'quote':
        return Center(
          child: Text(
            _quoteController.text.isEmpty
                ? "Your Quote..."
                : _quoteController.text,
            style: TextStyle(color: color, fontSize: 16),
          )
        );

      case 'countdown':
        return Center( 
          child: Text(
            _countdownDateController.text.isEmpty
                ? "Countdown Date"
                : "Countdown to ${_countdownDateController.text}",
            style: TextStyle(color: color, fontSize: 16),
          )
        );

      case 'calendar':
        return Center(
          child: Text(
          DateFormatter.shortDate(_now),
          style: TextStyle(color: color, fontSize: 16),
        )
      );

      default:
        return const SizedBox();
    }
  }


  Widget _buildTypeFields() {
    switch (_selectedType) {
      case 'quote':
        return TextField(
          controller: _quoteController,
          decoration: const InputDecoration(
            labelText: "Quote Text",
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        );

      case 'countdown':
        return TextField(
          controller: _countdownDateController,
          decoration: const InputDecoration(
            labelText: "Countdown Date (YYYY-MM-DD)",
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        );

      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Widget"),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _saveWidget),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Widget Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              "Widget Type",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Wrap(
              spacing: 10,
              children: _widgetTypes.map((w) {
                return ChoiceChip(
                  avatar: Icon(w['icon']),
                  label: Text(w['name']),
                  selected: _selectedType == w['type'],
                  onSelected: (_) => setState(() => _selectedType = w['type']),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            _buildTypeFields(),
            _buildPreview(),
            _buildStyleControls(),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class EditWidgetScreen extends StatefulWidget {
  final KWidget widget;

  const EditWidgetScreen({super.key, required this.widget});

  @override
  State<EditWidgetScreen> createState() => _EditWidgetScreenState();
}

class _EditWidgetScreenState extends State<EditWidgetScreen> {
  final FirebaseService _firebase = FirebaseService();

  late TextEditingController _nameController;
  late TextEditingController _quoteController;
  late TextEditingController _countdownController;

  late Map<String, dynamic> _style;
  late Map<String, dynamic> _data;
  late String _selectedType;

  String? _uploadedImageUrl;
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();

    _selectedType = widget.widget.type;

    _style = Map<String, dynamic>.from(widget.widget.style);
    _data = Map<String, dynamic>.from(widget.widget.data);

    _uploadedImageUrl = _style['backgroundImage'];

    _nameController = TextEditingController(text: widget.widget.name);
    _quoteController = TextEditingController(text: _data['text'] ?? "");
    _countdownController = TextEditingController(text: _data['countdownDate'] ?? "");

    if (_selectedType == "clock") {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _now = DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _pickBackgroundImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    final url = await _firebase.uploadImage(
      "widget_images/${widget.widget.id}.jpg",
      bytes,
    );

    setState(() {
      _uploadedImageUrl = url;
      _style['backgroundImage'] = url;
    });
  }

  Future<void> _saveChanges() async {
    _data = {
      'text': _quoteController.text,
      'countdownDate': _countdownController.text,
    };

    final updated = widget.widget.copyWith(
      name: _nameController.text,
      type: _selectedType,
      data: _data,
      style: _style,
    );

    await _firebase.saveWidget(updated);

    final wid = updated.id;

    await HomeWidget.saveWidgetData<String>('name_$wid', updated.name);
    await HomeWidget.saveWidgetData<String>('type_$wid', updated.type);
    await HomeWidget.saveWidgetData<String>('text_$wid', updated.data['text'] ?? "");
    await HomeWidget.saveWidgetData<String>('countdownDate_$wid', updated.data['countdownDate'] ?? "");
    await HomeWidget.saveWidgetData<String>('bgColor_$wid', updated.style['backgroundColor']);
    await HomeWidget.saveWidgetData<String>('image_$wid', updated.style['backgroundImage']);

    await HomeWidget.updateWidget(
      name: 'UserHomeClockWidgetProvider',
      iOSName: null,
    );

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Widget updated")));

    Navigator.pop(context);
  }


  Widget _buildPreview() {
    final bgColor = Color(int.parse(_style['backgroundColor'].substring(1), radix: 16) + 0xFF000000);
    final textColor = Color(int.parse(_style['textColor'].substring(1), radix: 16) + 0xFF000000);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Image
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: _uploadedImageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(_uploadedImageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: Colors.black12,
            ),
            child: _uploadedImageUrl == null
                ? const Icon(Icons.image, color: Colors.white70)
                : null,
          ),

          const SizedBox(width: 16),

          Expanded(child: _buildPreviewRight(textColor)),
        ],
      ),
    );
  }

  Widget _buildPreviewRight(Color color) {
    switch (_selectedType) {
      case 'clock':
        return Text(DateFormat('hh:mm:ss a').format(_now), style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.bold));
      case 'quote':
        return Text(_quoteController.text.isNotEmpty ? _quoteController.text : "Your Quote...", style: TextStyle(color: color, fontSize: 16));
      case 'countdown':
        return Text(
            _countdownController.text.isEmpty
                ? "Countdown Date"
                : "Countdown to ${_countdownController.text}",
            style: TextStyle(color: color, fontSize: 16));
      case 'calendar':
        return Text(DateFormatter.shortDate(_now),
            style: TextStyle(color: color, fontSize: 16));
      default:
        return const SizedBox();
    }
  }

  Widget _buildFields() {
    switch (_selectedType) {
      case 'quote':
        return TextField(
          controller: _quoteController,
          decoration: const InputDecoration(labelText: "Quote Text"),
          onChanged: (_) => setState(() {}),
        );
      case 'countdown':
        return TextField(
          controller: _countdownController,
          decoration: const InputDecoration(labelText: "Countdown Date (YYYY-MM-DD)"),
          onChanged: (_) => setState(() {}),
        );
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Widget"),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _saveChanges),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Widget Name"),
            ),
            const SizedBox(height: 20),

            _buildFields(),
            const SizedBox(height: 20),
            _buildPreview(),
            const SizedBox(height: 20),

            // Background color picker
            ListTile(
              title: const Text("Background Color"),
              trailing: CircleAvatar(
                backgroundColor: Color(
                  int.parse(_style['backgroundColor'].substring(1), radix: 16) + 0xFF000000,
                ),
              ),
              onTap: () => showDialog(
                context: context,
                builder: (_) => ColorPickerDialog(
                  currentColor: Color(
                    int.parse(_style['backgroundColor'].substring(1), radix: 16) + 0xFF000000,
                  ),
                  onColorSelected: (c) {
                    setState(() => _style['backgroundColor'] = '#${c.value.toRadixString(16).substring(2)}');
                    Navigator.pop(context);
                  },
                ),
              ),
            ),

            // Text color picker
            ListTile(
              title: const Text("Text Color"),
              trailing: CircleAvatar(
                backgroundColor: Color(
                  int.parse(_style['textColor'].substring(1), radix: 16) + 0xFF000000,
                ),
              ),
              onTap: () => showDialog(
                context: context,
                builder: (_) => ColorPickerDialog(
                  currentColor: Color(
                    int.parse(_style['textColor'].substring(1), radix: 16) + 0xFF000000,
                  ),
                  onColorSelected: (c) {
                    setState(() => _style['textColor'] = '#${c.value.toRadixString(16).substring(2)}');
                    Navigator.pop(context);
                  },
                ),
              ),
            ),

            // Background image picker
            ListTile(
              title: const Text("Background Image"),
              trailing: const Icon(Icons.upload),
              onTap: _pickBackgroundImage,
            ),
          ],
        ),
      ),
    );
  }
}