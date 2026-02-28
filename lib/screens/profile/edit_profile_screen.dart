import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wealth_wise/models/user.dart';
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

class EditProfileScreen extends StatefulWidget {
  final User user;

  const EditProfileScreen({
    super.key,
    required this.user,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  String? _photoUrl;
  File? _selectedImage;
  bool _isUploading = false;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    _displayNameController =
        TextEditingController(text: widget.user.displayName ?? '');
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController =
        TextEditingController(text: widget.user.phoneNumber ?? '');
    _photoUrl = widget.user.photoUrl;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 500,
      maxHeight: 500,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return _photoUrl;

    try {
      setState(() {
        _isUploading = true;
      });

      // Create file path
      final fileName =
          'profile_${widget.user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'profile_images/$fileName';

      // Upload file
      final uploadTask =
          _storage.ref().child(filePath).putFile(_selectedImage!);
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Return URL
      return downloadUrl;
    } catch (e) {
      // Just log the error and return null instead of using ScaffoldMessenger
      debugPrint('Error uploading image: $e');
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // Store values and references before async operations
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final displayName = _displayNameController.text.trim();
    final phoneNumber = _phoneController.text.trim();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Show loading
    setState(() {
      _isUploading = true;
    });

    try {
      // Upload image if changed
      String? newPhotoUrl = _photoUrl;
      if (_selectedImage != null) {
        newPhotoUrl = await _uploadImage();
      }

      // Check if still mounted after image upload
      if (!mounted) return;

      // Update profile
      final success = await authProvider.updateProfile(
        displayName: displayName,
        photoUrl: newPhotoUrl,
        phoneNumber: phoneNumber,
      );

      // Check if still mounted after profile update
      if (!mounted) return;

      if (success) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        navigator.pop(true);
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
              content: Text('Error updating profile: ${authProvider.error}')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  DecorationImage? _profileDecorationImage() {
    if (_selectedImage != null) {
      return DecorationImage(
        image: FileImage(_selectedImage!),
        fit: BoxFit.cover,
      );
    }
    if (_photoUrl != null) {
      return DecorationImage(
        image: NetworkImage(_photoUrl!),
        fit: BoxFit.cover,
      );
    }
    return null;
  }

  Widget? _profilePlaceholder() {
    if (_photoUrl != null || _selectedImage != null) {
      return null;
    }
    final initial = widget.user.displayName != null &&
            widget.user.displayName!.isNotEmpty
        ? widget.user.displayName![0].toUpperCase()
        : 'U';
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _isUploading ? null : _saveProfile,
            child: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildProfilePicture(),
              const SizedBox(height: 32),
              _buildDisplayNameField(),
              const SizedBox(height: 16),
              _buildEmailField(),
              const SizedBox(height: 16),
              _buildPhoneField(),
              const SizedBox(height: 32),
              _buildProfileSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePicture() {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              image: _profileDecorationImage(),
            ),
            child: _profilePlaceholder(),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisplayNameField() {
    return TextFormField(
      controller: _displayNameController,
      decoration: const InputDecoration(
        labelText: 'Display Name',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.person),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your name';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      readOnly: true,
      decoration: const InputDecoration(
        labelText: 'Email',
        helperText: 'Email cannot be changed',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.email),
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      decoration: const InputDecoration(
        labelText: 'Phone Number',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.phone),
      ),
      keyboardType: TextInputType.phone,
      validator: (value) {
        if (value != null && value.isNotEmpty && value.length < 10) {
          return 'Please enter a valid phone number';
        }
        return null;
      },
    );
  }

  Widget _buildProfileSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _isUploading ? null : _saveProfile,
        child: _isUploading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white),
              )
            : const Text('Save Profile'),
      ),
    );
  }
}
