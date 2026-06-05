/// Utility helpers for the role-based notification system.
///
/// Key responsibilities:
///   1. [NotificationHelper.relevantTypes] — Returns which notification types
///      are visible to a given role.
///   2. [NotificationCategory] — Typed categories for colour/icon look-up.
///   3. [NotificationHelper.categoryForType] — Maps a backend `type` string
///      to a [NotificationCategory].
library;

/// All roles that can exist in the system.
enum UserRole { employee, hr, admin }

/// Semantic categories used for icon / colour rendering.
enum NotificationCategory {
  checkinReminder,
  checkoutReminder,
  missedPunch,
  leaveStatus,
  correctionStatus,
  darReminder,
  announcement,
  leaveRequest,    // HR/Admin: new employee leave request
  correction,      // HR/Admin: new correction request
  pendingApprovals,
  teamAlert,
  systemAlert,
  general,
}

class NotificationHelper {
  // ── Role → visible notification types ──────────────────────────────────

  /// Returns the set of backend `type` strings that should be shown to [role].
  ///
  /// HR and Admins also see employee-level notifications because they are
  /// employees themselves. Additional privileged types are layered on top.
  static Set<String> relevantTypes(UserRole role) {
    // Every user sees these
    final base = <String>{
      'checkin_reminder',
      'checkout_reminder',
      'missed_punch',
      'leave_approved',
      'leave_rejected',
      'correction_approved',
      'correction_rejected',
      'dar_reminder',
      'announcement',
      'holiday',
      'info',
      'warning',
      'success',
      'error',
    };

    if (role == UserRole.employee) return base;

    // HR sees everything an employee sees + HR-specific types
    final hr = {
      ...base,
      'new_leave_request',
      'new_correction_request',
      'pending_approvals',
      'team_late_alert',
      'team_absent_alert',
      'bulk_reminder',
    };

    if (role == UserRole.hr) return hr;

    // Admins see everything HR sees + system/admin types
    return {
      ...hr,
      'system_alert',
      'user_created',
      'policy_change',
      'location_assignment',
      'report_ready',
    };
  }

  // ── Type → Category ────────────────────────────────────────────────────

  static NotificationCategory categoryForType(String type) {
    switch (type) {
      case 'checkin_reminder':
        return NotificationCategory.checkinReminder;
      case 'checkout_reminder':
        return NotificationCategory.checkoutReminder;
      case 'missed_punch':
        return NotificationCategory.missedPunch;
      case 'leave_approved':
      case 'leave_rejected':
        return NotificationCategory.leaveStatus;
      case 'correction_approved':
      case 'correction_rejected':
        return NotificationCategory.correctionStatus;
      case 'dar_reminder':
        return NotificationCategory.darReminder;
      case 'announcement':
      case 'holiday':
        return NotificationCategory.announcement;
      case 'new_leave_request':
        return NotificationCategory.leaveRequest;
      case 'new_correction_request':
      case 'correction':
        return NotificationCategory.correction;
      case 'pending_approvals':
        return NotificationCategory.pendingApprovals;
      case 'team_late_alert':
      case 'team_absent_alert':
      case 'bulk_reminder':
        return NotificationCategory.teamAlert;
      case 'system_alert':
      case 'policy_change':
      case 'user_created':
      case 'location_assignment':
      case 'report_ready':
        return NotificationCategory.systemAlert;
      default:
        return NotificationCategory.general;
    }
  }

  // ── Category metadata ──────────────────────────────────────────────────

  static String labelForCategory(NotificationCategory cat) {
    switch (cat) {
      case NotificationCategory.checkinReminder:   return 'Check-In Reminder';
      case NotificationCategory.checkoutReminder:  return 'Check-Out Reminder';
      case NotificationCategory.missedPunch:       return 'Missed Punch';
      case NotificationCategory.leaveStatus:       return 'Leave Update';
      case NotificationCategory.correctionStatus:  return 'Correction Update';
      case NotificationCategory.darReminder:       return 'DAR Reminder';
      case NotificationCategory.announcement:      return 'Announcement';
      case NotificationCategory.leaveRequest:      return 'Leave Request';
      case NotificationCategory.correction:        return 'Correction Request';
      case NotificationCategory.pendingApprovals:  return 'Pending Approvals';
      case NotificationCategory.teamAlert:         return 'Team Alert';
      case NotificationCategory.systemAlert:       return 'System Alert';
      case NotificationCategory.general:           return 'Notification';
    }
  }

  /// User-friendly role label for display.
  static String roleName(UserRole role) {
    switch (role) {
      case UserRole.employee: return 'Employee';
      case UserRole.hr:       return 'HR';
      case UserRole.admin:    return 'Admin';
    }
  }

  /// Parses a raw role string (from AuthService.user.role) to [UserRole].
  static UserRole parseRole(String? rawRole) {
    switch (rawRole?.toLowerCase()) {
      case 'admin':    return UserRole.admin;
      case 'hr':       return UserRole.hr;
      default:         return UserRole.employee;
    }
  }
}
