import 'package:flutter/material.dart';
import '../../features/dashboard/tablet/views/dashboard_view.dart';
import '../../features/employees/tablet/views/employees_view.dart';
import '../../features/attendance/tablet/views/my_attendance_view.dart';
import '../../features/live_attendance/tablet/views/live_attendance_view.dart';
import '../../features/leave/tablet/views/leave_view.dart'; // ADDED
import '../../features/reports/tablet/views/reports_view.dart';
import '../../features/policy_engine/tablet/views/policy_engine_view.dart';
import '../../features/geo_fencing/tablet/views/geo_fencing_view.dart';
import '../../features/feedback/tablet/views/feedback_view.dart'; // ADDED
import '../../features/daily_activity/daily_activity_screen.dart'; // ADDED
import '../../features/profile/tablet/views/profile_view.dart';
import '../../features/collaboration/collaboration_screen.dart'; // ADDED
import '../navigation/navigation_controller.dart';
import '../widgets/sidebars/sidebar_tablet_landscape.dart';
import '../widgets/custom_app_bar.dart';

import 'package:flutter_application/shared/widgets/chatbot_fab.dart';

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
          // No gradient in dark mode
        ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SidebarTabletLandscape(),
            Expanded(
              child: ValueListenableBuilder<PageType>(
                valueListenable: navigationNotifier,
                builder: (context, currentPage, _) {
                  return Scaffold(
                    backgroundColor: Theme.of(context).brightness == Brightness.dark 
                        ? const Color(0xFF0D1117) 
                        : Colors.transparent,
                    appBar: CustomAppBar(
                      showDrawerButton: false,
                      title: currentPage.title,
                    ),
                    body: _buildPageContent(currentPage),
                    floatingActionButton: ChatbotFab(currentPageType: currentPage),
                    floatingActionButtonLocation: ChatbotFabLocation(currentPage),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent(PageType page) {
    switch (page) {
      case PageType.dashboard:
        return const DashboardView();
      case PageType.employees:
        return const EmployeesView();
      case PageType.myAttendance:
        return const MyAttendanceView();
      case PageType.liveAttendance:
        return const LiveAttendanceView();
      case PageType.leavesAndHolidays:
        return LeaveView(); // UPDATED
      case PageType.reports:
        return const ReportsView();
      case PageType.policyEngine:
        return const PolicyEngineView();
      case PageType.geoFencing:
        return const GeoFencingView();
      case PageType.dailyActivity:
        return const DailyActivityScreen(); // ADDED
      case PageType.feedback:
        return const FeedbackView(); // ADDED
      case PageType.collaboration:
        return const CollaborationScreen(); // ADDED
      case PageType.profile:
        return const ProfileView();
    }
  }
}
