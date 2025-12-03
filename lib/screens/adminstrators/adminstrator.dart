import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:k_verse/screens/adminstrators/manageannouncement.dart';
import '../../screens/about.dart';
import '../../screens/profile.dart';
import '../../widgets/custom_drawer.dart';
import '../../screens/ai_chat.dart';
import '../../screens/notification.dart';
import '../../screens/wallpaper_creator.dart';
import '../../screens/widget_creator.dart';
import '../../screens/my_creations.dart';
import '../../screens/settings.dart';
import '../../constants/locale_keys.dart';
import '../comingsoon.dart';

class AdminstratorScreen extends StatefulWidget {
  const AdminstratorScreen({super.key});

  @override
  State<AdminstratorScreen> createState() => _AdminstratorScreenState();
}

class _AdminstratorScreenState extends State<AdminstratorScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const AdminstratorHomeContent(),
    const WallpaperCreator(),
    const WidgetCreator(),
    const MyCreations(),
    const SettingsScreen(),
    const HelpSupportScreen(),
    const ProfileScreen(),
    const NotificationsScreen(),
  ];

  void _onDrawerItemSelected(int index) {
    Navigator.of(context).pop();
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.appTitle.tr()),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
      ),
      drawer: CustomDrawer(onItemSelected: _onDrawerItemSelected),
      body: _screens[_currentIndex],
      floatingActionButton: _currentIndex == 0 ? _buildChatButton() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildChatButton() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            offset: const Offset(0, 3),
            blurRadius: 6,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(Icons.chat_bubble, color: Theme.of(context).colorScheme.onPrimary),
        iconSize: 28,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AIChatScreen()),
          );
        },
        padding: const EdgeInsets.all(14),
      ),
    );
  }
}

class AdminstratorHomeContent extends StatelessWidget {
  const AdminstratorHomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                LocaleKeys.welcomeBack.tr(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black, 
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.all(10),
            children: [
              _buildActionCard(
                LocaleKeys.managePage.tr(),
                Icons.edit_document,
                () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ManageAnnouncements()),
                ),
              ),
              _buildActionCard(
                LocaleKeys.reportAnalytics.tr(),
                Icons.analytics,
                () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ComingSoon()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black, 
              ),
            ),
          ],
        ),
      ),
    );
  }
}