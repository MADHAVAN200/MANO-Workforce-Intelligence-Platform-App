import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../navigation/navigation_controller.dart';
import 'glass_container.dart';
import 'package:provider/provider.dart'; // Import Provider
import '../services/auth_service.dart'; // Import AuthService

class AppSidebar extends StatelessWidget {
  final VoidCallback? onLinkTap;

  const AppSidebar({
    super.key, 
    this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Solid Sidebar
    return GlassContainer(
      width: isMobile ? 240 : 280,
      height: double.infinity,
      blur: 0, // No blur
      color: Theme.of(context).brightness == Brightness.dark 
          ? const Color(0xFF0D1117) // Darker Sidebar (Slate 900)
          : const Color(0xFFFFFFFF), // Solid White for Light Mode
      borderRadius: 0,
      border: Border(
        right: BorderSide(
          color: isDark 
              ? const Color(0xFF30363D) // Slate 800 for subtle contrast
              : Colors.grey[300]!,
          width: 1,
        ),
      ), 
      child: ValueListenableBuilder<PageType>(
        valueListenable: navigationNotifier,
        builder: (context, currentPage, _) {
          return SingleChildScrollView(
            child: Column(
              children: [
              // Sidebar Header (Matches CustomAppBar)
              Container(
                height: 70,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark 
                          ? const Color(0xFF30363D) // Slate 800 for subtle contrast in black mode
                          : Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    // Optional Logo Icon
                    Icon(
                      Icons.change_history, // Placeholder logo icon
                      color: Theme.of(context).primaryColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'MANO',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white 
                            : Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32), // Matches typical page content padding
              
              // Menu Items
              ...PageType.values.where((p) {
                // 1. Role-based Filtering
                final user = context.read<AuthService>().user;
                if (user != null && user.isEmployee) {
                   // Employee Allowed Pages
                   final allowed = [
                     PageType.dashboard,
                     PageType.myAttendance,
                     PageType.myAttendance,
                     PageType.leavesAndHolidays,   // UPDATED
                     PageType.feedback, // ADDED
                     PageType.profile,
                   ];
                   if (!allowed.contains(p)) return false;
                }

                // 2. Mobile Logic
                if (isMobile) return true; // Show all (filtered) on mobile
                return p != PageType.profile; // Hide profile on tablet/desktop (sidebar)
              }).map((page) => _buildMenuItem(
                context, 
                page,
                currentPage == page,
              )),
            ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, PageType page, bool isActive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isActive 
            ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)) // Neutral grey for light mode active
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        horizontalTitleGap: 8,
        minLeadingWidth: 20,
        leading: Icon(
          page.icon,
          color: isActive 
              ? (isDark ? Colors.white : Colors.black) // Black for light mode active
              : (isDark ? Colors.grey : Colors.black54),
        ),
        title: Text(
          page.title,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive 
                ? (isDark ? Colors.white : Colors.black) // Black for light mode active
                : (isDark ? Colors.grey[400] : Colors.black87),
          ),
        ),
        onTap: () {
          navigateTo(page);
          onLinkTap?.call();
        },
      ),
    );
  }
}

