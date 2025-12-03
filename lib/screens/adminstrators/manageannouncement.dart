import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../models/eventsActivities.dart';
import '../../../screens/notification.dart';
import '../../../repositories/announcement_repository.dart';
import '../../../viewmodels/announcement_viewmodel.dart';

class ManageAnnouncements extends StatelessWidget {
  const ManageAnnouncements({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ManageAnnouncementViewModel(
        Provider.of<AnnouncementRepository>(context, listen: false),
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('Manage Announcements')),
        body: const _ManageAnnouncementContent(),
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.add),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddEditAnnouncementPage(),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ManageAnnouncementContent extends StatelessWidget {
  const _ManageAnnouncementContent();

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ManageAnnouncementViewModel>(context);

    return StreamBuilder<List<Announcement>>(
      stream: viewModel.getAnnouncementsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final announcements = snapshot.data ?? [];

        if (announcements.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.announcement, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No announcements yet\nTap the + button to add your first announcement',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: announcements.length,
          itemBuilder: (context, index) {
            final announcement = announcements[index];
            return Dismissible(
              key: Key(announcement.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                return await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text("Confirm Delete"),
                      content: const Text("Are you sure you want to delete this announcement?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text("Delete", style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    );
                  },
                );
              },
              onDismissed: (direction) {
                viewModel.deleteAnnouncement(announcement.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Announcement deleted')),
                );
              },
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddEditAnnouncementPage(announcement: announcement),
                    ),
                  );
                },
                child: AnnouncementCard(
                  announcement: announcement,
                  showMenu: true,
                  onEdit: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddEditAnnouncementPage(announcement: announcement),
                      ),
                    );
                  },
                  onDelete: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Confirm Delete"),
                        content: const Text("Are you sure you want to delete this announcement?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () {
                              viewModel.deleteAnnouncement(announcement.id);
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Announcement deleted')),
                              );
                            },
                            child: const Text("Delete", style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class AddEditAnnouncementPage extends StatefulWidget {
  final Announcement? announcement;

  const AddEditAnnouncementPage({super.key, this.announcement});

  @override
  State<AddEditAnnouncementPage> createState() => _AddEditAnnouncementPageState();
}

class _AddEditAnnouncementPageState extends State<AddEditAnnouncementPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _linkController = TextEditingController();
  File? _selectedImage;
  String? _currentImageUrl;
  bool _isLoading = false;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    if (widget.announcement != null) {
      _titleController.text = widget.announcement!.announcementTitle;
      _contentController.text = widget.announcement!.announcementContent;
      _linkController.text = widget.announcement!.announcementLink;
      _currentImageUrl = widget.announcement!.announcementImage;
    }

    _titleController.addListener(_checkForChanges);
    _contentController.addListener(_checkForChanges);
    _linkController.addListener(_checkForChanges);
  }

  void _checkForChanges() {
    final hasTextChanges = widget.announcement == null 
        ? _titleController.text.isNotEmpty || 
          _contentController.text.isNotEmpty || 
          _linkController.text.isNotEmpty
        : _titleController.text != widget.announcement!.announcementTitle ||
          _contentController.text != widget.announcement!.announcementContent ||
          _linkController.text != widget.announcement!.announcementLink;

    final hasImageChanges = _selectedImage != null || 
        (_currentImageUrl != widget.announcement?.announcementImage && 
         widget.announcement != null);

    if (hasTextChanges || hasImageChanges) {
      if (!_hasUnsavedChanges) {
        setState(() {
          _hasUnsavedChanges = true;
        });
      }
    } else {
      if (_hasUnsavedChanges) {
        setState(() {
          _hasUnsavedChanges = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _currentImageUrl = null;
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _saveAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final viewModel = Provider.of<ManageAnnouncementViewModel>(context, listen: false);
      
      final announcement = Announcement(
        id: widget.announcement?.id ?? '',
        announcementTitle: _titleController.text,
        announcementContent: _contentController.text,
        announcementImage: _currentImageUrl ?? '',
        announcementLink: _linkController.text,
        createdTime: DateTime.now(),
      );

      if (widget.announcement != null) {
        await viewModel.updateAnnouncement(
          announcement, 
          imageFile: _selectedImage
        );
      } else {
        await viewModel.addAnnouncement(
          announcement, 
          imageFile: _selectedImage
        );
      }

      setState(() {
        _hasUnsavedChanges = false;
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.announcement != null 
                ? 'Announcement updated successfully' 
                : 'Announcement added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save announcement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showExitConfirmation() {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('You have unsaved changes. Are you sure you want to leave?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ).then((shouldExit) {
      if (shouldExit == true) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _titleController.removeListener(_checkForChanges);
    _contentController.removeListener(_checkForChanges);
    _linkController.removeListener(_checkForChanges);
    _titleController.dispose();
    _contentController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.announcement != null;

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        
        if (_hasUnsavedChanges) {
          _showExitConfirmation();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Edit Announcement' : 'Add Announcement'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_hasUnsavedChanges) {
                _showExitConfirmation();
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 500,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _selectedImage != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          _selectedImage = null;
                                          _hasUnsavedChanges = true;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : _currentImageUrl != null && _currentImageUrl!.isNotEmpty
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        _currentImageUrl!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                        errorBuilder: (context, error, stackTrace) {
                                          return _buildPlaceholderContent();
                                        },
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                          onPressed: () {
                                            setState(() {
                                              _currentImageUrl = null;
                                              _hasUnsavedChanges = true;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : _buildPlaceholderContent(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title *',
                      border: OutlineInputBorder(),
                      hintText: 'Enter announcement title',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      labelText: 'Content *',
                      border: OutlineInputBorder(),
                      hintText: 'Enter announcement content',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 6,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter content';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _linkController,
                    decoration: const InputDecoration(
                      labelText: 'Link URL (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveAnnouncement,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(isEditing ? 'Update Announcement' : 'Add Announcement'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderContent() {
    return Container(
      color: Colors.grey[200],
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text('Tap to select image', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}