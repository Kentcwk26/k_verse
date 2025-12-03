import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:k_verse/screens/comingsoon.dart';
import '../screens/about.dart';
import '../screens/profile.dart';
import '../widgets/custom_drawer.dart';
import 'ai_chat.dart';
import 'notification.dart';
import 'wallpaper_creator.dart';
import 'widget_creator.dart';
import 'my_creations.dart';
import 'settings.dart';
import '../constants/locale_keys.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeContent(),
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

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

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
                LocaleKeys.welcome.tr(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black, 
                ),
              ),
              const SizedBox(height: 10),
              Text(
                LocaleKeys.welcomeSubtitle.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87, 
                ),
                textAlign: TextAlign.justify,
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
                LocaleKeys.createWallpaper.tr(),
                Icons.wallpaper,
                () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WallpaperCreator()),
                ),
              ),
              _buildActionCard(
                LocaleKeys.createWidget.tr(),
                Icons.widgets,
                () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WidgetCreator()),
                ),
              ),
              _buildActionCard(
                LocaleKeys.myCollection.tr(),
                Icons.collections,
                () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyCreations()),
                ),
              ),
              _buildActionCard(
                LocaleKeys.community.tr(),
                Icons.people,
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