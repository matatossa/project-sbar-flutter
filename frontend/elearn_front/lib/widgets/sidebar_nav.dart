import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class SidebarNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const SidebarNav({
    Key? key,
    required this.selectedIndex,
    required this.onItemSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Container(
      width: 250,
      color: const Color(0xFF1C1D1F),
      child: SafeArea(
        child: Column(
          children: [
            // Logo
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF6B35),
                          Color(0xFFFF8C42),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.school,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'e-Learn',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.grey, height: 1),

            // Navigation Items - Scrollable
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _NavItem(
                    icon: Icons.home_outlined,
                    label: 'Main',
                    isSelected: selectedIndex == 0,
                    onTap: () => onItemSelected(0),
                  ),
                  _NavItem(
                    icon: Icons.book_outlined,
                    label: 'Courses',
                    isSelected: selectedIndex == 1,
                    onTap: () => onItemSelected(1),
                  ),
                  _NavItem(
                    icon: Icons.workspace_premium_outlined,
                    label: 'Certificates',
                    isSelected: selectedIndex == 2,
                    onTap: () => onItemSelected(2),
                  ),
                  _NavItem(
                    icon: Icons.message_outlined,
                    label: 'Messages',
                    isSelected: selectedIndex == 3,
                    onTap: () => onItemSelected(3),
                  ),
                  _NavItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    isSelected: selectedIndex == 4,
                    onTap: () => onItemSelected(4),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.grey, height: 1),

            // Logout
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.grey),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.grey),
                ),
                onTap: () {
                  authService.logout();
                  Navigator.pushReplacementNamed(context, '/login');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFF6B35).withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: Icon(
              icon,
              color: isSelected
                  ? const Color(0xFFFF6B35)
                  : Colors.grey[400],
            ),
            title: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[400],
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


