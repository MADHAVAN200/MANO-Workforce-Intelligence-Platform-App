import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/toast_helper.dart';
import '../../models/dar_models.dart';
import '../../services/dar_service.dart';
import '../../../holidays/services/holiday_service.dart';
import '../../../attendance/services/attendance_service.dart';
import '../../widgets/day_snapshot_card.dart';
import '../../widgets/multi_day_timeline_widget.dart';
import '../../widgets/mini_calendar_widget.dart';
import '../../widgets/event_meeting_dialog.dart';

class TabletDailyActivityView extends StatefulWidget {
  final bool isLandscape;

  const TabletDailyActivityView({super.key, required this.isLandscape});

  @override
  State<TabletDailyActivityView> createState() =>
      _TabletDailyActivityViewState();
}

class _TabletDailyActivityViewState extends State<TabletDailyActivityView> {
  late DarService _darService;
  late HolidayService _holidayService;
  late AttendanceService _attendanceService;

  // Calendar-driven date selection
  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String? _rangeEndDate; // null = single day; non-null = end of range
  String _focusedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  // Legacy field kept for MultiDayTimelineWidget — driven by calendar selection
  late String _startDate;

  bool _isLoading = false;
  List<DarItem> _tasks = [];
  Map<String, Map<String, dynamic>> _attendanceData = {};
  Map<String, String> _holidays = {};
  List<String> _categories = [
    'General',
    'Development',
    'Design',
    'Meeting',
    'Testing',
  ];

  // Right sidebar draft tasks state
  List<DarItem> _draftTasks = [];
  List<int> _deletedTaskIds = [];

  @override
  void initState() {
    super.initState();

    // Default timeline: today at center of a 7-day window
    final d = DateTime.now().subtract(const Duration(days: 3));
    _startDate = DateFormat('yyyy-MM-dd').format(d);

    final auth = Provider.of<AuthService>(context, listen: false);
    _darService = DarService(auth.dio);
    _holidayService = HolidayService(auth.dio);
    _attendanceService = AttendanceService(auth.dio);

    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch categories
      final cats = await _darService.getCategories();

      // 2. Fetch timeline tasks & attendance & holidays
      await _fetchTimelineData();

      setState(() {
        if (cats.isNotEmpty) _categories = cats;
        _isLoading = false;
      });

      // Load selected day's drafts
      _loadDraftsForSelectedDate();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted)
        context.showToast("Error loading initial data: $e", isError: true);
    }
  }

  Future<void> _fetchTimelineData() async {
    // Determine effective date range from calendar selection
    final effectiveStart = _selectedDate;
    final effectiveEnd = _rangeEndDate ?? _selectedDate;

    // Add buffer days around the range for the visual timeline
    final startDt = DateTime.parse(
      effectiveStart,
    ).subtract(const Duration(days: 1));
    final endDt = DateTime.parse(effectiveEnd).add(const Duration(days: 1));
    final dateFrom = DateFormat('yyyy-MM-dd').format(startDt);
    final dateTo = DateFormat('yyyy-MM-dd').format(endDt);

    // Keep _startDate aligned so timeline starts at the selected date
    _startDate = effectiveStart;

    final acts = await _darService.getActivities(
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
    final evts = await _darService.getEvents(
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
    final hols = await _holidayService.getHolidays();
    final atts = await _attendanceService.getMyRecords(
      fromDate: dateFrom,
      toDate: dateTo,
    );

    final List<DarItem> merged = [];
    merged.addAll(acts.map((a) => DarItem.fromActivity(a)));
    merged.addAll(evts.map((e) => DarItem.fromEvent(e)));

    final Map<String, String> mappedHols = {};
    for (var h in hols) {
      mappedHols[h.date] = h.name;
    }

    final Map<String, Map<String, dynamic>> mappedAtts = {};
    for (var a in atts) {
      if (a.timeIn != null) {
        final parsedTimeIn = DateTime.parse(a.timeIn!);
        final key = DateFormat('yyyy-MM-dd').format(parsedTimeIn);
        final String tIn = DateFormat('HH:mm').format(parsedTimeIn);
        String? tOut;
        if (a.timeOut != null) {
          tOut = DateFormat('HH:mm').format(DateTime.parse(a.timeOut!));
        }
        mappedAtts[key] = {'hasTimedIn': true, 'timeIn': tIn, 'timeOut': tOut};
      }
    }

    setState(() {
      _tasks = merged;
      _holidays = mappedHols;
      _attendanceData = mappedAtts;
    });
  }

  void _loadDraftsForSelectedDate() {
    final dayTasks = _tasks
        .where((t) => t.date == _selectedDate && t.type == DarItemType.task)
        .toList();
    setState(() {
      _draftTasks = dayTasks.map((t) => t.copyWith()).toList();
      _deletedTaskIds.clear();
    });
  }

  /// Called by MiniCalendarWidget whenever the user taps a date or completes a range.
  void _onCalendarRange(String startDate, String? endDate) {
    setState(() {
      _selectedDate = startDate;
      _rangeEndDate = endDate;
      _focusedDate = startDate;
      // Align timeline start to the selected date
      _startDate = startDate;
    });
    _fetchTimelineData().then((_) {
      _loadDraftsForSelectedDate();
    });
  }

  void _focusDay(String date) {
    setState(() {
      _focusedDate = date;
      if (_rangeEndDate == null) {
        _selectedDate = date;
        _startDate = date;
      }
    });
  }

  void _changeDateRange(int offsetDays) {
    setState(() {
      final current = DateTime.parse(_startDate);
      _startDate = DateFormat(
        'yyyy-MM-dd',
      ).format(current.add(Duration(days: offsetDays)));
      _selectedDate = _startDate;
      _rangeEndDate = null;
    });
    _fetchTimelineData();
  }

  // Right sidebar actions: Add Task Slot
  void _addDraftTaskSlot() {
    final now = DateTime.now();
    // Default times: 09:00 - 10:00 or similar based on existing drafts
    String startTime = "09:00";
    String endTime = "10:00";

    if (_draftTasks.isNotEmpty) {
      final last = _draftTasks.last;
      startTime = last.endTime;
      final endParts = last.endTime.split(':');
      final h = (int.tryParse(endParts[0]) ?? 9) + 1;
      endTime =
          "${h.toString().padLeft(2, '0')}:${endParts.length > 1 ? endParts[1] : '00'}";
    }

    setState(() {
      _draftTasks.add(
        DarItem(
          id: 'draft-${now.millisecondsSinceEpoch}',
          title: '',
          description: '',
          startTime: startTime,
          endTime: endTime,
          date: _selectedDate,
          type: DarItemType.task,
          category: _categories.first,
          isSaved: false,
        ),
      );
    });
  }

  void _removeDraftTaskSlot(int index) {
    final task = _draftTasks[index];
    setState(() {
      _draftTasks.removeAt(index);
      if (!task.id.startsWith('draft-')) {
        final id = int.tryParse(task.id.replaceFirst('act-', ''));
        if (id != null) {
          _deletedTaskIds.add(id);
        }
      }
    });
  }

  bool get _isPastDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel = DateTime.parse(_selectedDate);
    return sel.isBefore(today);
  }

  // Validates times and overlap
  bool _validateDrafts() {
    for (int i = 0; i < _draftTasks.length; i++) {
      final t = _draftTasks[i];
      if (t.title.trim().isEmpty) {
        if (mounted)
          context.showToast(
            "Task #${i + 1} title cannot be empty.",
            isWarning: true,
          );
        return false;
      }
      if (t.startTime.compareTo(t.endTime) >= 0) {
        if (mounted)
          context.showToast(
            "Task #${i + 1} end time must be after start time.",
            isWarning: true,
          );
        return false;
      }
    }
    return true;
  }

  Future<void> _saveDrafts() async {
    if (!_validateDrafts()) return;

    if (_isPastDate) {
      // Past date: Request justification modal
      _showJustificationDialog();
    } else {
      // Today or future date: Save changes directly
      setState(() => _isLoading = true);
      try {
        // 1. Delete tasks
        for (var id in _deletedTaskIds) {
          await _darService.deleteActivity(id);
        }

        // 2. Add / Update tasks
        for (var t in _draftTasks) {
          final isNew = t.id.startsWith('draft-');
          final act = DarActivity(
            activityId: isNew
                ? null
                : int.tryParse(t.id.replaceFirst('act-', '')),
            title: t.title,
            description: t.description,
            startTime: t.startTime,
            endTime: t.endTime,
            activityDate: _selectedDate,
            activityType: t.category,
            status: 'COMPLETED',
          );
          await _darService.saveActivity(act);
        }

        if (mounted)
          context.showToast("Activities saved successfully!", isSuccess: true);
        await _fetchTimelineData();
        _loadDraftsForSelectedDate();
      } catch (e) {
        if (mounted)
          context.showToast("Failed to save activities: $e", isError: true);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // Show dialog to request changes for a past date
  void _showJustificationDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            "Reason for Past Date Modification",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "You are modifying tasks for a past date. Please provide a justification for this correction request to be reviewed by HR/Admin.",
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                style: GoogleFonts.poppins(fontSize: 13),
                decoration: InputDecoration(
                  hintText: "Enter justification reason here...",
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0D1117) : Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                "Cancel",
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  if (mounted)
                    context.showToast(
                      "Please provide a reason.",
                      isWarning: true,
                    );
                  return;
                }
                Navigator.of(ctx).pop();
                _submitPastDateCorrectionRequest(reason);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
              ),
              child: Text(
                "Submit Request",
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitPastDateCorrectionRequest(String reason) async {
    setState(() => _isLoading = true);
    try {
      // Original data
      final original = _tasks
          .where((t) => t.date == _selectedDate && t.type == DarItemType.task)
          .map(
            (t) => {
              'title': t.title,
              'description': t.description,
              'start_time': t.startTime,
              'end_time': t.endTime,
              'activity_type': t.category,
              'status': t.status,
            },
          )
          .toList();

      // Proposed data
      final proposed = _draftTasks
          .map(
            (t) => {
              'title': t.title,
              'description': t.description,
              'start_time': t.startTime,
              'end_time': t.endTime,
              'activity_type': t.category,
              'status': 'COMPLETED',
            },
          )
          .toList();

      await _darService.submitRequest(
        date: _selectedDate,
        reason: reason,
        originalData: original,
        proposedData: proposed,
      );

      if (mounted)
        context.showToast(
          "Past date correction request submitted successfully!",
          isSuccess: true,
        );
      await _fetchTimelineData();
      _loadDraftsForSelectedDate();
    } catch (e) {
      if (mounted)
        context.showToast("Failed to submit request: $e", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Create or edit a Meeting / Event
  void _openEventMeetingDialog({
    DarItem? initialItem,
    String type = 'MEETING',
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        return EventMeetingDialog(
          initialData: initialItem,
          initialDate: _selectedDate,
          type: type,
          onSave: (payload) async {
            setState(() => _isLoading = true);
            try {
              final isEdit = initialItem != null;
              final id = isEdit
                  ? int.tryParse(initialItem.id.replaceFirst('evt-', ''))
                  : null;

              final evt = DarEvent(
                eventId: id,
                title: payload['title'],
                description: payload['description'],
                startTime: payload['start_time'],
                endTime: payload['end_time'],
                eventDate: payload['event_date'],
                type: payload['type'],
                location: payload['location'],
              );

              await _darService.saveEvent(evt);
              if (mounted)
                context.showToast(
                  isEdit
                      ? "Event updated successfully"
                      : "Event created successfully",
                  isSuccess: true,
                );
              _fetchTimelineData();
            } catch (e) {
              if (mounted)
                context.showToast("Failed to save event: $e", isError: true);
            } finally {
              setState(() => _isLoading = false);
            }
          },
          onDelete: initialItem == null
              ? null
              : () async {
                  setState(() => _isLoading = true);
                  try {
                    final id = int.tryParse(
                      initialItem.id.replaceFirst('evt-', ''),
                    );
                    if (id != null) {
                      await _darService.deleteEvent(id);
                      if (mounted)
                        context.showToast(
                          "Event deleted successfully",
                          isSuccess: true,
                        );
                      _fetchTimelineData();
                    }
                  } catch (e) {
                    if (mounted)
                      context.showToast(
                        "Failed to delete event: $e",
                        isError: true,
                      );
                  } finally {
                    setState(() => _isLoading = false);
                  }
                },
        );
      },
    );
  }

  void _onEditItemFromTimeline(DarItem item) {
    if (item.type == DarItemType.task) {
      _focusDay(item.date);
      if (_rangeEndDate == null) {
        // Highlight in edit sidebar when not showing a range.
        _loadDraftsForSelectedDate();
      }
    } else {
      // Open dialog
      _focusDay(item.date);
      _openEventMeetingDialog(
        initialItem: item,
        type: item.type == DarItemType.event ? 'EVENT' : 'MEETING',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Area: Timeline Header + Timeline Container (70% width)
          Expanded(
            flex: 7,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row header with prev/next navigation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Daily Activity Timeline",
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.grey[800],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _rangeEndDate != null
                                  ? '${DateFormat('d MMM').format(DateTime.parse(_selectedDate))} – ${DateFormat('d MMM yyyy').format(DateTime.parse(_rangeEndDate!))}'
                                  : DateFormat(
                                      'EEEE, d MMMM yyyy',
                                    ).format(DateTime.parse(_selectedDate)),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Horizontal Stack Timeline scrollable area
                  Expanded(
                    child: _isLoading && _tasks.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : Builder(
                            builder: (context) {
                              final daysToShow = _rangeEndDate != null
                                  ? DateTime.parse(_rangeEndDate!)
                                            .difference(
                                              DateTime.parse(_selectedDate),
                                            )
                                            .inDays +
                                        1
                                  : 1;
                              return MultiDayTimelineWidget(
                                tasks: _tasks,
                                startDate: _startDate,
                                daysToShow: daysToShow.clamp(1, 14),
                                holidays: _holidays,
                                attendanceData: _attendanceData,
                                onEditTask: _onEditItemFromTimeline,
                                onDateTap: _focusDay,
                                propStartHour: 0,
                                propEndHour: 24,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),

          // Divider
          Container(
            width: 1,
            color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!,
          ),

          // Right Area: MiniCalendar + Task Creation Panel (30% width)
          SizedBox(
            width: 270,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassContainer(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: MiniCalendarWidget(
                        selectedDate: _selectedDate,
                        rangeEndDate: _rangeEndDate,
                        onRangeSelect: _onCalendarRange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  DailyActivityDaySnapshotCard(
                    date: _focusedDate,
                    items: _tasks,
                    attendance: _attendanceData[_focusedDate],
                    holidayName: _holidays[_focusedDate],
                    isDark: isDark,
                    emptyMessage:
                        'Tap a date on the timeline to inspect its tasks and punches.',
                  ),
                  const SizedBox(height: 10),

                  // Selection Date / Range Banner
                  Text(
                    _rangeEndDate != null
                        ? '${DateFormat('EEE, d MMM').format(DateTime.parse(_selectedDate))} → ${DateFormat('EEE, d MMM yyyy').format(DateTime.parse(_rangeEndDate!))}'
                        : DateFormat(
                            'EEEE, MMM d, yyyy',
                          ).format(DateTime.parse(_selectedDate)),
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const SizedBox(height: 10),

                  // Quick Action Buttons (Add Meeting / Event)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _openEventMeetingDialog(type: 'MEETING'),
                          icon: const Icon(Icons.videocam_outlined, size: 16),
                          label: Text(
                            "Meeting",
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: const Color(0xFF8B5CF6).withOpacity(0.5),
                            ),
                            foregroundColor: const Color(0xFF8B5CF6),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _openEventMeetingDialog(type: 'EVENT'),
                          icon: const Icon(Icons.event_outlined, size: 16),
                          label: Text(
                            "Event",
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: const Color(0xFF3B82F6).withOpacity(0.5),
                            ),
                            foregroundColor: const Color(0xFF3B82F6),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tasks list header & Add task trigger
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Activities (${_draftTasks.length})",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addDraftTaskSlot,
                        icon: const Icon(Icons.add, size: 14),
                        label: Text(
                          "Add",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF6366F1),
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Draft rows
                  if (_draftTasks.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Text(
                          "No activities logged for this day.",
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ...List.generate(_draftTasks.length, (idx) {
                      final item = _draftTasks[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF161B22)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF30363D)
                                : Colors.grey[200]!,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row: Title & Remove
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: item.title,
                                    onChanged: (val) {
                                      _draftTasks[idx] = item.copyWith(
                                        title: val,
                                      );
                                    },
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'Task Title',
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _removeDraftTaskSlot(idx),
                                  icon: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.redAccent,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const Divider(height: 8),

                            // Category select & time window
                            Row(
                              children: [
                                // Category Select
                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF0D1117)
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value:
                                            _categories.contains(item.category)
                                            ? item.category
                                            : _categories.first,
                                        isDense: true,
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                        items: _categories.map((cat) {
                                          return DropdownMenuItem<String>(
                                            value: cat,
                                            child: Text(cat),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              _draftTasks[idx] = item.copyWith(
                                                category: val,
                                              );
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Timing inputs
                                Expanded(
                                  flex: 4,
                                  child: Row(
                                    children: [
                                      // Start
                                      Expanded(
                                        child: InkWell(
                                          onTap: () async {
                                            final parts = item.startTime.split(
                                              ':',
                                            );
                                            final tod = TimeOfDay(
                                              hour: int.tryParse(parts[0]) ?? 9,
                                              minute: parts.length > 1
                                                  ? int.tryParse(parts[1]) ?? 0
                                                  : 0,
                                            );
                                            final picked = await showTimePicker(
                                              context: context,
                                              initialTime: tod,
                                            );
                                            if (picked != null) {
                                              setState(() {
                                                final fmt =
                                                    "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
                                                _draftTasks[idx] = item
                                                    .copyWith(startTime: fmt);
                                              });
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 4,
                                            ),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: isDark
                                                    ? const Color(0xFF30363D)
                                                    : Colors.grey[300]!,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              item.startTime,
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 2.0,
                                        ),
                                        child: Text(
                                          "-",
                                          style: TextStyle(fontSize: 10),
                                        ),
                                      ),
                                      // End
                                      Expanded(
                                        child: InkWell(
                                          onTap: () async {
                                            final parts = item.endTime.split(
                                              ':',
                                            );
                                            final tod = TimeOfDay(
                                              hour:
                                                  int.tryParse(parts[0]) ?? 10,
                                              minute: parts.length > 1
                                                  ? int.tryParse(parts[1]) ?? 0
                                                  : 0,
                                            );
                                            final picked = await showTimePicker(
                                              context: context,
                                              initialTime: tod,
                                            );
                                            if (picked != null) {
                                              setState(() {
                                                final fmt =
                                                    "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
                                                _draftTasks[idx] = item
                                                    .copyWith(endTime: fmt);
                                              });
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 4,
                                            ),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: isDark
                                                    ? const Color(0xFF30363D)
                                                    : Colors.grey[300]!,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              item.endTime,
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Description field
                            TextFormField(
                              initialValue: item.description,
                              onChanged: (val) {
                                _draftTasks[idx] = item.copyWith(
                                  description: val,
                                );
                              },
                              style: GoogleFonts.poppins(fontSize: 11.5),
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: 'Enter task details...',
                                hintStyle: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey[400],
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF0D1117)
                                    : Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? const Color(0xFF30363D)
                                        : Colors.grey[200]!,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? const Color(0xFF30363D)
                                        : Colors.grey[200]!,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 8),

                  // Action Buttons: Save / Submit Change Request
                  if (_draftTasks.isNotEmpty || _deletedTaskIds.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveDrafts,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _isPastDate
                                    ? "Submit Correction Request"
                                    : "Save Activities",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
