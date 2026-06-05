import 'package:flutter_application/shared/navigation/navigation_controller.dart';

/// Helper to map App [PageType] to backend route paths and provide suggested context-aware questions.
class PagePathHelper {
  /// Maps a [PageType] to the exact route path expected by the backend chatbot API.
  static String getBackendPath(PageType pageType) {
    switch (pageType) {
      case PageType.dashboard:
        return '/dashboard';
      case PageType.employees:
        return '/employees';
      case PageType.myAttendance:
        return '/attendance';
      case PageType.liveAttendance:
        return '/attendance-monitoring';
      case PageType.dailyActivity:
        return '/daily-activity';
      case PageType.leavesAndHolidays:
        return '/apply-leave';
      case PageType.reports:
        return '/reports';
      case PageType.policyEngine:
        return '/shift-management';
      case PageType.geoFencing:
        return '/geofencing';
      case PageType.profile:
        return '/profile';
      case PageType.feedback:
        return '/feedback';
      case PageType.collaboration:
        return '/collaboration'; // ADDED
    }
  }

  /// Provides context-aware suggested questions for a given [PageType].
  static List<String> getSuggestedQuestions(PageType pageType) {
    switch (pageType) {
      case PageType.dashboard:
        return [
          'How do I check in or out?',
          'What stats are on my dashboard?',
          'How do I view recent activity logs?',
        ];
      case PageType.employees:
        return [
          'How do I add a new employee?',
          'How do I bulk import staff with Excel?',
          'How do I search the staff directory?',
        ];
      case PageType.myAttendance:
        return [
          'How do I request a correction?',
          'What is facial camera verification?',
          'Where do I see my check-in history?',
        ];
      case PageType.liveAttendance:
        return [
          'What is the Live Command Center?',
          'How do I view employee GPS locations?',
          'How does real-time monitoring work?',
        ];
      case PageType.dailyActivity:
        return [
          'What is a Daily Activity Report?',
          'How do I log a daily task or meeting?',
          'How does AI analyze vague DAR entries?',
        ];
      case PageType.leavesAndHolidays:
        return [
          'How do I apply for casual/sick leave?',
          'Where is the holiday calendar list?',
          'How do I check my remaining leave balances?',
        ];
      case PageType.reports:
        return [
          'What report formats are supported?',
          'How do I export lateness or overtime?',
          'Can I generate a payroll matrix report?',
        ];
      case PageType.policyEngine:
        return [
          'How do I create a new shift?',
          'What is the late threshold grace period?',
          'How do I assign shifts to staff?',
        ];
      case PageType.geoFencing:
        return [
          'What is geofencing location locking?',
          'How do I add a new work location zone?',
          'Can employees clock in from anywhere?',
        ];
      case PageType.profile:
        return [
          'How do I change my profile avatar?',
          'Can I update my password here?',
          'How do I configure security settings?',
        ];
      case PageType.feedback:
        return [
          'How do I submit a bug report?',
          'Where do I suggest new features?',
          'Who reviews the submitted feedback?',
        ];
      case PageType.collaboration:
        return [
          'How do I start a new direct message?',
          'How do I create a group channel?',
          'How do I manage group channel members?',
        ]; // ADDED
    }
  }
}
