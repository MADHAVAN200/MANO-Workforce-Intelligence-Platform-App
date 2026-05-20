import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../shared/services/dashboard_provider.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/navigation/navigation_controller.dart'; 
import '../../widgets/employee_dashboard_widgets.dart';

class MobileEmployeeDashboardContent extends StatelessWidget {
  const MobileEmployeeDashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        final stats = provider.stats;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               // 1. Hero
               EmployeeHero(
                userName: user?.name ?? 'Employee', 
                onAttendanceTap: () => navigateTo(PageType.myAttendance), 
                onHolidayTap: () => navigateTo(PageType.leavesAndHolidays),
                onLeaveTap: () => navigateTo(PageType.leavesAndHolidays),
              ),
              const SizedBox(height: 24),

              // 2. Stats Grid (2x2)
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3, // Adjust for portrait
                children: [
                  EmployeeStatCard(
                    label: 'Present Days',
                    value: stats.presentToday.toString(),
                    icon: Icons.check_circle_outline,
                    iconColor: const Color(0xFF10B981),
                  ),
                  EmployeeStatCard(
                    label: 'Absent Days',
                    value: stats.absentToday.toString(),
                    icon: Icons.cancel_outlined,
                    iconColor: const Color(0xFFEF4444),
                  ),
                  EmployeeStatCard(
                    label: 'Late Arrivals',
                    value: stats.lateCheckins.toString(),
                    icon: Icons.access_time,
                    iconColor: const Color(0xFFF59E0B),
                  ),
                  const EmployeeStatCard(
                    label: 'Leave Balance',
                    value: '8', // Mock
                    badgeText: 'Yearly',
                    icon: Icons.coffee,
                    iconColor: Color(0xFF3B82F6),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 3. Info Cards (Stacked)
              EmployeeInfoCard(
                title: 'Your Work Location',
                icon: Icons.location_on_outlined,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.white.withValues(alpha: 0.05) 
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white.withValues(alpha: 0.1) 
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Text(
                    'Standard locations. Ensure you are within the geofence.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.grey[400] 
                          : Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              EmployeeInfoCard(
                title: 'Policies & Reminders',
                icon: Icons.info_outline,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBulletPoint(context, 'Mark attendance before 09:30 AM.'),
                    const SizedBox(height: 12),
                    _buildBulletPoint(context, 'Apply for leave 2 days prior.'),
                  ],
                ),
              ),
               const SizedBox(height: 80), // Bottom padding
            ],
          ),
        );
      }
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: CircleAvatar(radius: 3, backgroundColor: Theme.of(context).primaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.grey[300] 
                  : Colors.grey[800],
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
