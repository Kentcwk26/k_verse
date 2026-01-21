import 'package:flutter/material.dart';
import '../screens/login.dart';
import '../utils/snackbar_helper.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';

class CustomDrawer extends StatelessWidget {
  final Function(int) onItemSelected;

  const CustomDrawer({
    super.key,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: true);

    return Drawer(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset("assets/images/logo-removebg.png", height: 80),
                      SizedBox(height: 10),
                      Text(
                        'Create Your K-World',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildDrawerItem(icon: Icons.home, title: 'Home', index: 0),
                _buildDrawerItem(icon: Icons.notifications, title: 'Notifications', index: 7),
                _buildDrawerItem(icon: Icons.settings, title: 'Settings', index: 4),
                _buildDrawerItem(icon: Icons.help, title: 'Help & Support', index: 5),
              ],
            ),
          ),

          _buildSimpleAuthSection(context, authViewModel),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () => onItemSelected(index),
    );
  }

  Widget _buildSimpleAuthSection(BuildContext context, AuthViewModel authViewModel) {
    final isLoggedIn = authViewModel.currentUser != null;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[700]!, width: 1),
        ),
      ),
      child: isLoggedIn
          ? ElevatedButton.icon(
              onPressed: () => _showLogoutDialog(context, authViewModel),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              label: Text('Log Out'),
              icon: Icon(Icons.logout),
            )
          : ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Future.delayed(const Duration(milliseconds: 150), () {
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => LoginScreen()),
                    );
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              label: Text('Login / Register'),
              icon: Icon(Icons.login),
            ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthViewModel authViewModel) {
    Future.delayed(Duration.zero, () {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Log Out'),
          content: Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await authViewModel.signOut();
                  SnackBarHelper.showSuccess(context, 'Logged out successfully');
                } catch (e) {
                  SnackBarHelper.showError(context, 'Error logging out: $e');
                }
              },
              child: Text('Log Out', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    });
  }
}