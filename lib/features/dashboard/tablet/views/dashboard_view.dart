import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/services/auth_service.dart';
import 'admin_dashboard_view.dart';
import 'employee_dashboard_view.dart';
import 'hr_dashboard_view.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch AuthService to react to role changes or initial load
    final authService = context.watch<AuthService>();
    final user = authService.user;
    
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (user.isEmployee) {
      return const EmployeeDashboardView();
    }

    if (user.isHr) {
      return const HrDashboardView();
    }

    // Default to Admin view
    return const AdminDashboardView();
  }
}
