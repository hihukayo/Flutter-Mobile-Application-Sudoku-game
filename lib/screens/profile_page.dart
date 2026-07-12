import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'login_page.dart';
import 'settings_page.dart';

class ProfilePage extends StatefulWidget {
  final String username;
  final String phone;

  const ProfilePage({super.key, required this.username, required this.phone});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Uint8List? _avatarBytes;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 256, maxHeight: 256);
    if (xfile != null) {
      final bytes = await xfile.readAsBytes();
      setState(() => _avatarBytes = bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _pickImage,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Theme.of(context).colorScheme.primary,
                backgroundImage: _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                child: _avatarBytes == null
                    ? Text(
                        widget.username.isNotEmpty ? widget.username[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 32, color: Colors.white),
                      )
                    : null,
              ),
              CircleAvatar(
                radius: 14,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(widget.username, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(widget.phone, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        const SizedBox(height: 32),
        Card(
          child: Column(
            children: [
              ListTile(leading: const Icon(Icons.sports_esports), title: const Text('总局数'), trailing: const Text('0')),
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.check_circle), title: const Text('完成数'), trailing: const Text('0')),
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.trending_up), title: const Text('胜率'), trailing: const Text('0%')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_upload),
                title: const Text('云存档'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('设置'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsPage(username: widget.username, phone: widget.phone),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
              (_) => false,
            ),
            icon: const Icon(Icons.logout),
            label: const Text('退出登录'),
          ),
        ),
      ],
    );
  }
}
