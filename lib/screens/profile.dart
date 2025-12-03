import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:k_verse/utils/date_formatter.dart';
import '../models/user.dart';
import '../repositories/user_repository.dart';
import '../utils/snackbar_helper.dart';
import '../../utils/image_responsive.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final UserRepository _repo = UserRepository();
  Users? _user;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await _repo.getCurrentUser();
    setState(() {
      _user = u;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
              ? const Center(child: Text("User data not found"))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: GestureDetector(
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              backgroundColor: Colors.black,
                              child: ResponsiveZoomableImage(
                                imagePath: _user!.photoUrl,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          child: SafeAvatar(
                            url: _user!.photoUrl,
                            size: 120,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _user!.name,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _openEditProfile(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      _tile(
                          label: "Email",
                          value: _user!.email,
                          icon: Icons.email),
                      _tile(
                          label: "Contact",
                          value: _user!.contact,
                          icon: Icons.phone),
                      _tile(
                          label: "Gender",
                          value: _user!.gender,
                          icon: Icons.person),
                      _tile(
                        label: "Created",
                        value: DateFormatter.fullDateTime(_user!.creationDateTime),
                        icon: Icons.calendar_month,
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _tile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(value),
        ],
      ),
    );
  }

  Future<void> _openEditProfile() async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(user: _user!),
      ),
    );

    if (updated == true) _load();
  }
}

class EditProfileScreen extends StatefulWidget {
  final Users user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => EditProfileScreenState();
}

class EditProfileScreenState extends State<EditProfileScreen> {
  final _repo = UserRepository();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController nameCtrl;
  late TextEditingController emailCtrl;
  late TextEditingController contactCtrl;

  String gender = "Male";
  String photoUrl = "";
  bool saving = false;

  // original values for dirty check
  late String originalName;
  late String originalGender;
  late String originalContact;
  late String originalPhoto;

  final genders = ["Male", "Female"];

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.user.name);
    emailCtrl = TextEditingController(text: widget.user.email);
    contactCtrl = TextEditingController(text: widget.user.contact);

    gender = widget.user.gender;
    photoUrl = widget.user.photoUrl;

    originalName = widget.user.name;
    originalGender = widget.user.gender;
    originalContact = widget.user.contact;
    originalPhoto = widget.user.photoUrl;

    nameCtrl.addListener(_triggerRebuild);
    contactCtrl.addListener(_triggerRebuild);
  }

  void _triggerRebuild() => setState(() {});

  bool get hasChanges =>
      nameCtrl.text.trim() != originalName ||
      gender != originalGender ||
      contactCtrl.text.trim() != originalContact ||
      photoUrl != originalPhoto;

  bool get formValid =>
      _validateName(nameCtrl.text) == null &&
      _validateContact(contactCtrl.text) == null;

  //─────────────────────── VALIDATION ───────────────────────//

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return "Enter your name";
    if (v.trim().length < 2) return "Name must be at least 2 characters";
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(v.trim())) {
      return "Only letters & spaces allowed";
    }
    return null;
  }

  String? _validateContact(String? v) {
    if (v == null || v.trim().isEmpty) return "Enter phone number";

    final digits = v.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.length < 9 || digits.length > 15) {
      return "Phone must be 9–15 digits";
    }
    return null;
  }

  //─────────────────────── IMAGE PICK + UPLOAD ───────────────────────//

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxHeight: 512,
      maxWidth: 512,
    );

    if (file == null) return;

    setState(() => saving = true);

    final uploaded = await _uploadImage(File(file.path));
    if (uploaded != null) {
      setState(() => photoUrl = uploaded);
      SnackBarHelper.showSuccess(context, "Photo updated");
    }

    setState(() => saving = false);
  }

  Future<String?> _uploadImage(File file) async {
    try {
      final ref = FirebaseStorage.instance.ref().child('profile/profile_${widget.user.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final snap = await ref.putFile(file);
      return await snap.ref.getDownloadURL();
    } catch (e) {
      SnackBarHelper.showError(context, "Upload failed: $e");
      return null;
    }
  }

  //─────────────────────── SAVE PROFILE ───────────────────────//

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (!hasChanges) {
      SnackBarHelper.showError(context, "No changes to save");
      return;
    }

    setState(() => saving = true);

    final updated = Users(
      userId: widget.user.userId,
      name: nameCtrl.text.trim(),
      email: emailCtrl.text.trim(),
      contact: contactCtrl.text.trim(),
      gender: gender,
      role: "Member",
      photoUrl: photoUrl,
      creationDateTime: widget.user.creationDateTime,
    );

    try {
      await _repo.updateUser(updated);
      SnackBarHelper.showSuccess(context, "Profile saved");
      Navigator.pop(context, true);
    } catch (e) {
      SnackBarHelper.showError(context, "Save failed: $e");
    }

    setState(() => saving = false);
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    contactCtrl.dispose();
    super.dispose();
  }

  //─────────────────────── UI ───────────────────────//

  @override
  Widget build(BuildContext context) {
    final saveEnabled = hasChanges && formValid && !saving;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              //────────── Avatar ──────────//
              Stack(
                children: [
                  SafeAvatar(
                    url: photoUrl,
                    size: 150,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        onPressed: saving ? null : _pickImage,
                      ),
                    ),
                  )
                ],
              ),

              const SizedBox(height: 24),

              //────────── Name ──────────//
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: "Full Name",
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: _validateName,
              ),

              const SizedBox(height: 16),

              //────────── Email (read-only) ──────────//
              TextFormField(
                controller: emailCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Email",
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              //────────── Contact ──────────//
              TextFormField(
                controller: contactCtrl,
                decoration: const InputDecoration(
                  labelText: "Contact Number",
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: _validateContact,
              ),

              const SizedBox(height: 16),

              //────────── Gender ──────────//
              DropdownButtonFormField<String>(
                value: gender,
                items: genders
                    .map((g) =>
                        DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => setState(() => gender = v!),
                decoration: const InputDecoration(
                  labelText: "Gender",
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 28),

              //────────── SAVE BUTTON ──────────//
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saveEnabled ? _save : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Save Changes",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              if (hasChanges && !formValid)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning,
                            color: Colors.orange.shade800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Fix errors before saving",
                            style: TextStyle(
                                color: Colors.orange.shade800),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}