import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/dar_models.dart';

class MultiDayTimelineWidget extends StatefulWidget {
  final List<DarItem> tasks;
  final String startDate; // YYYY-MM-DD
  final int daysToShow;
  final Map<String, Map<String, dynamic>>
  attendanceData; // date -> {hasTimedIn, timeIn, timeOut, intervals}
  final Map<String, String> holidays; // date -> holiday_name
  final ValueChanged<DarItem> onEditTask;
  final ValueChanged<String>? onDateTap;
  final int? propStartHour;
  final int? propEndHour;

  const MultiDayTimelineWidget({
    super.key,
    required this.tasks,
    required this.startDate,
    this.daysToShow = 7,
    required this.attendanceData,
    required this.holidays,
    required this.onEditTask,
    this.onDateTap,
    this.propStartHour,
    this.propEndHour,
  });

  @override
  State<MultiDayTimelineWidget> createState() => _MultiDayTimelineWidgetState();
}

class _MultiDayTimelineWidgetState extends State<MultiDayTimelineWidget> {
  late final ScrollController _horizontalController;
  String? _lastAutoScrollKey;

  @override
  void initState() {
    super.initState();
    _horizontalController = ScrollController();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  // Helper: Parse time "HH:MM" to total minutes from midnight
  int _getMinutes(String timeStr) {
    if (timeStr.isEmpty) return 0;
    final parts = timeStr.split(':');
    if (parts.isEmpty) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return h * 60 + m;
  }

  // Get start and end hours dynamically based on tasks
  Map<String, int> _getHourRange() {
    if (widget.propStartHour != null && widget.propEndHour != null) {
      return {'start': widget.propStartHour!, 'end': widget.propEndHour!};
    }
    int min = 8; // Default 8 AM
    int max = 19; // Default 7 PM

    for (var t in widget.tasks) {
      final startMin = _getMinutes(t.startTime);
      final endMin = _getMinutes(t.endTime);
      final hStart = startMin ~/ 60;
      final hEnd = (endMin + 59) ~/ 60; // Round up to next hour

      if (hStart < min) min = hStart;
      if (hEnd > max) max = hEnd;
    }

    // Add padding
    return {'start': (min - 1).clamp(0, 23), 'end': (max + 1).clamp(1, 24)};
  }

  // Stacking/overlap resolution algorithm
  List<DarItem> _arrangeTasks(
    List<DarItem> dayTasks,
    int startHour,
    double pixelsPerHour,
  ) {
    if (dayTasks.isEmpty) return [];

    // Sort by start time, then duration (longest first)
    final sorted = List<DarItem>.from(dayTasks)
      ..sort((a, b) {
        final startA = _getMinutes(a.startTime);
        final startB = _getMinutes(b.startTime);
        if (startA != startB) return startA.compareTo(startB);

        final durA = _getMinutes(a.endTime) - startA;
        final durB = _getMinutes(b.endTime) - startB;
        return durB.compareTo(durA); // Longest first
      });

    final List<int> lanes = []; // Stores end minutes of last item in each lane

    final arranged = sorted.map((task) {
      final startMin = _getMinutes(task.startTime);
      final endMin = _getMinutes(task.endTime);

      int laneIdx = -1;
      for (int i = 0; i < lanes.length; i++) {
        if (lanes[i] <= startMin) {
          lanes[i] = endMin;
          laneIdx = i;
          break;
        }
      }

      if (laneIdx == -1) {
        lanes.add(endMin);
        laneIdx = lanes.length - 1;
      }

      task.laneIndex = laneIdx;
      return task;
    }).toList();

    final totalLanes = lanes.length;
    for (var task in arranged) {
      task.totalLanes = totalLanes;
    }

    return arranged;
  }

  // Get offset in pixels from start hour
  double _getPositionFromTime(
    String timeStr,
    int startHour,
    double pixelsPerHour,
  ) {
    final minutes = _getMinutes(timeStr);
    final startMinutes = startHour * 60;
    final offsetMinutes = (minutes - startMinutes).clamp(0, 24 * 60);
    return (offsetMinutes / 60.0) * pixelsPerHour;
  }

  // Get width in pixels for duration
  double _getWidthFromDuration(
    String startStr,
    String endStr,
    double pixelsPerHour,
  ) {
    final startMin = _getMinutes(startStr);
    final endMin = _getMinutes(endStr);
    final duration = (endMin - startMin).clamp(15, 24 * 60);
    return (duration / 60.0) * pixelsPerHour;
  }

  void _scheduleDeviceTimeScroll({
    required int startHour,
    required int endHour,
    required double pixelsPerHour,
    required double viewportWidth,
    required double timelineWidth,
  }) {
    final now = DateTime.now();
    if (now.hour < startHour || now.hour >= endHour) return;

    final scrollKey =
        '${widget.startDate}-${widget.daysToShow}-$startHour-$endHour-${now.hour}';
    if (_lastAutoScrollKey == scrollKey) return;
    _lastAutoScrollKey = scrollKey;

    final minutesFromStart = ((now.hour - startHour) * 60) + now.minute;
    final currentPosition = (minutesFromStart / 60.0) * pixelsPerHour;
    final maxOffset = (timelineWidth - viewportWidth).clamp(
      0.0,
      double.infinity,
    );
    final targetOffset = (currentPosition - (viewportWidth * 0.35)).clamp(
      0.0,
      maxOffset,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_horizontalController.hasClients) return;
      _horizontalController.jumpTo(targetOffset);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Config
    const double pixelsPerHour = 80.0;
    const double rowHeight = 78.0;
    const double dateColumnWidth = 66.0;
    const double headerHeight = 40.0;

    final range = _getHourRange();
    final startHour = range['start']!;
    final endHour = range['end']!;
    final totalHours = endHour - startHour;

    final double timelineWidth = totalHours * pixelsPerHour;

    // Generate Dates
    final DateTime startDt = DateTime.parse(widget.startDate);
    final List<String> dates = List.generate(widget.daysToShow, (i) {
      final d = startDt.add(Duration(days: i));
      return DateFormat('yyyy-MM-dd').format(d);
    });

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final currentHour = now.hour;
    final currentMin = now.minute;
    final hasNowIndicator = now.hour >= startHour && now.hour < endHour;
    final double nowPosition = hasNowIndicator
        ? (((currentHour - startHour) * 60 + currentMin) / 60.0) * pixelsPerHour
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sticky Left Column: Date Labels
            Column(
              children: [
                // Header Corner Box
                Container(
                  width: dateColumnWidth,
                  height: headerHeight,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0D1117) : Colors.grey[50],
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? const Color(0xFF30363D)
                            : Colors.grey[200]!,
                      ),
                      right: BorderSide(
                        color: isDark
                            ? const Color(0xFF30363D)
                            : Colors.grey[200]!,
                      ),
                    ),
                  ),
                ),
                // Date rows
                ...dates.map((dateStr) {
                  final parsedDate = DateTime.parse(dateStr);
                  final isToday = dateStr == todayStr;
                  final holidayName = widget.holidays[dateStr];
                  final isHoliday = holidayName != null;

                  final att = widget.attendanceData[dateStr];
                  final hasTimedIn = att != null && att['hasTimedIn'] == true;
                  final isPast = parsedDate.isBefore(
                    DateTime(now.year, now.month, now.day),
                  );
                  final isAbsent = isPast && !isHoliday && !hasTimedIn;

                  Color rowBg = isDark ? const Color(0xFF161B22) : Colors.white;
                  if (isHoliday) {
                    rowBg = isDark
                        ? const Color(0xFF10B981).withValues(alpha: 0.1)
                        : const Color(0xFFF0FDFA);
                  } else if (isAbsent) {
                    rowBg = isDark
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.red[50]!;
                  }

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onDateTap == null
                        ? null
                        : () => widget.onDateTap!(dateStr),
                    child: Container(
                      width: dateColumnWidth,
                      height: rowHeight,
                      decoration: BoxDecoration(
                        color: rowBg,
                        border: Border(
                          bottom: BorderSide(
                            color: isDark
                                ? const Color(0xFF21262D)
                                : Colors.grey[100]!,
                          ),
                          right: BorderSide(
                            color: isDark
                                ? const Color(0xFF30363D)
                                : Colors.grey[200]!,
                          ),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('EEE').format(parsedDate).toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isToday
                                  ? const Color(0xFF6366F1)
                                  : (isDark
                                        ? Colors.grey[500]
                                        : Colors.grey[400]),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isToday
                                  ? const Color(0xFF6366F1)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              boxShadow: isToday
                                  ? [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF6366F1,
                                        ).withValues(alpha: 0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              parsedDate.day.toString(),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: isToday
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isToday
                                    ? Colors.white
                                    : (isDark
                                          ? Colors.grey[200]
                                          : Colors.grey[800]),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
            // Horizontally Scrollable Timeline content
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _scheduleDeviceTimeScroll(
                    startHour: startHour,
                    endHour: endHour,
                    pixelsPerHour: pixelsPerHour,
                    viewportWidth: constraints.maxWidth,
                    timelineWidth: timelineWidth,
                  );

                  return SingleChildScrollView(
                    controller: _horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: timelineWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hours Header Row
                          Container(
                            height: headerHeight,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0D1117)
                                  : Colors.grey[50],
                              border: Border(
                                bottom: BorderSide(
                                  color: isDark
                                      ? const Color(0xFF30363D)
                                      : Colors.grey[200]!,
                                ),
                              ),
                            ),
                            child: Stack(
                              children: List.generate(totalHours, (index) {
                                final h = startHour + index;
                                final isPM = h >= 12;
                                final displayHour = h > 12
                                    ? h - 12
                                    : (h == 0 ? 12 : h);
                                final suffix = isPM ? 'PM' : 'AM';

                                return Positioned(
                                  left: index * pixelsPerHour,
                                  top: 0,
                                  bottom: 0,
                                  width: pixelsPerHour,
                                  child: Container(
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.only(left: 8),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        left: BorderSide(
                                          color: isDark
                                              ? const Color(
                                                  0xFF21262D,
                                                ).withValues(alpha: 0.5)
                                              : Colors.grey[200]!.withValues(alpha: 
                                                  0.5,
                                                ),
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      "$displayHour $suffix",
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.grey[500]
                                            : Colors.grey[400],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          // Tracks Body
                          ...dates.map((dateStr) {
                            final parsedDate = DateTime.parse(dateStr);
                            final isToday = dateStr == todayStr;
                            final holidayName = widget.holidays[dateStr];
                            final isHoliday = holidayName != null;

                            final att = widget.attendanceData[dateStr];
                            final hasTimedIn =
                                att != null && att['hasTimedIn'] == true;
                            final isPast = parsedDate.isBefore(
                              DateTime(now.year, now.month, now.day),
                            );
                            final isAbsent =
                                isPast && !isHoliday && !hasTimedIn;

                            // Prep and stack tasks
                            final dayTasks = widget.tasks
                                .where((t) => t.date == dateStr)
                                .toList();
                            final stackedTasks = _arrangeTasks(
                              dayTasks,
                              startHour,
                              pixelsPerHour,
                            );
                            final maxLanes = stackedTasks.isNotEmpty
                                ? stackedTasks.first.totalLanes
                                : 1;

                            Color rowBg = isDark
                                ? const Color(0xFF161B22)
                                : Colors.white;
                            if (isHoliday) {
                              rowBg = isDark
                                  ? const Color(0xFF10B981).withValues(alpha: 0.08)
                                  : const Color(0xFFF0FDFA).withValues(alpha: 0.5);
                            } else if (isAbsent) {
                              rowBg = isDark
                                  ? Colors.red.withValues(alpha: 0.08)
                                  : Colors.red[50]!.withValues(alpha: 0.5);
                            }

                            return Container(
                              height: rowHeight,
                              decoration: BoxDecoration(
                                color: rowBg,
                                border: Border(
                                  bottom: BorderSide(
                                    color: isDark
                                        ? const Color(0xFF21262D)
                                        : Colors.grey[100]!,
                                  ),
                                ),
                              ),
                              child: Stack(
                                clipBehavior: Clip.antiAlias,
                                children: [
                                  // Background grid lines (vertical per hour)
                                  ...List.generate(totalHours, (index) {
                                    return Positioned(
                                      left: index * pixelsPerHour,
                                      top: 0,
                                      bottom: 0,
                                      width: 1,
                                      child: Container(
                                        color: isDark
                                            ? const Color(
                                                0xFF21262D,
                                              ).withValues(alpha: 0.3)
                                            : Colors.grey[200]!.withValues(alpha: 
                                                0.3,
                                              ),
                                      ),
                                    );
                                  }),

                                  // Holiday Banners
                                  if (isHoliday)
                                    Center(
                                      child: Text(
                                        holidayName.toUpperCase(),
                                        style: GoogleFonts.poppins(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          color: isDark
                                              ? const Color(
                                                  0xFF10B981,
                                                ).withValues(alpha: 0.06)
                                              : const Color(
                                                  0xFFCCFBF1,
                                                ).withValues(alpha: 0.4),
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ),

                                  // Absent Banners
                                  if (isAbsent)
                                    Center(
                                      child: Text(
                                        "ABSENT",
                                        style: GoogleFonts.poppins(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w900,
                                          color: isDark
                                              ? Colors.red.withValues(alpha: 0.06)
                                              : Colors.red[100]!.withValues(alpha: 
                                                  0.4,
                                                ),
                                          letterSpacing: 3,
                                        ),
                                      ),
                                    ),

                                  // Time-In Vertical Line
                                  if (hasTimedIn && att['timeIn'] != null)
                                    Positioned(
                                      left: _getPositionFromTime(
                                        att['timeIn'],
                                        startHour,
                                        pixelsPerHour,
                                      ),
                                      top: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 1.5,
                                        color: const Color(0xFF34D399),
                                        alignment: Alignment.topCenter,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF34D399),
                                            borderRadius:
                                                const BorderRadius.only(
                                                  bottomLeft: Radius.circular(
                                                    3,
                                                  ),
                                                  bottomRight: Radius.circular(
                                                    3,
                                                  ),
                                                ),
                                          ),
                                          child: Text(
                                            "IN ${att['timeIn']}",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 7,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.visible,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Time-Out Vertical Line
                                  if (hasTimedIn && att['timeOut'] != null)
                                    Positioned(
                                      left: _getPositionFromTime(
                                        att['timeOut'],
                                        startHour,
                                        pixelsPerHour,
                                      ),
                                      top: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 1.5,
                                        color: Colors.amber[400],
                                        alignment: Alignment.topCenter,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.amber[400],
                                            borderRadius:
                                                const BorderRadius.only(
                                                  bottomLeft: Radius.circular(
                                                    3,
                                                  ),
                                                  bottomRight: Radius.circular(
                                                    3,
                                                  ),
                                                ),
                                          ),
                                          child: Text(
                                            "OUT ${att['timeOut']}",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 7,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Current Time Indicator (vertical red line with NOW tag)
                                  if (isToday && hasNowIndicator)
                                    Positioned(
                                      left: nowPosition,
                                      top: 0,
                                      bottom: 0,
                                      child: Stack(
                                        alignment: Alignment.topCenter,
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            width: 1.5,
                                            color: Colors.red[500],
                                          ),
                                          Positioned(
                                            top: -3,
                                            child: Container(
                                              width: 7,
                                              height: 7,
                                              decoration: BoxDecoration(
                                                color: Colors.red[500],
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 1,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // Task Blocks
                                  ...stackedTasks.map((task) {
                                    final left = _getPositionFromTime(
                                      task.startTime,
                                      startHour,
                                      pixelsPerHour,
                                    );
                                    final width = _getWidthFromDuration(
                                      task.startTime,
                                      task.endTime,
                                      pixelsPerHour,
                                    );

                                    final double totalHeight =
                                        rowHeight -
                                        8.0; // 4px padding top & bottom
                                    final double itemHeight =
                                        totalHeight / maxLanes;
                                    final double top =
                                        4.0 + (task.laneIndex * itemHeight);

                                    Color blockBg;
                                    Color borderCol;
                                    Color textCol;

                                    switch (task.type) {
                                      case DarItemType.meeting:
                                        blockBg = isDark
                                            ? const Color(
                                                0xFF8B5CF6,
                                              ).withValues(alpha: 0.15)
                                            : const Color(
                                                0xFF8B5CF6,
                                              ).withValues(alpha: 0.08);
                                        borderCol = const Color(
                                          0xFF8B5CF6,
                                        ).withValues(alpha: 0.3);
                                        textCol = isDark
                                            ? const Color(0xFFA78BFA)
                                            : const Color(0xFF6D28D9);
                                        break;
                                      case DarItemType.event:
                                        blockBg = isDark
                                            ? const Color(
                                                0xFF3B82F6,
                                              ).withValues(alpha: 0.15)
                                            : const Color(
                                                0xFF3B82F6,
                                              ).withValues(alpha: 0.08);
                                        borderCol = const Color(
                                          0xFF3B82F6,
                                        ).withValues(alpha: 0.3);
                                        textCol = isDark
                                            ? const Color(0xFF60A5FA)
                                            : const Color(0xFF1D4ED8);
                                        break;
                                      case DarItemType.task:
                                        if (task.status == 'PLANNED') {
                                          blockBg = isDark
                                              ? const Color(
                                                  0xFF10B981,
                                                ).withValues(alpha: 0.05)
                                              : const Color(
                                                  0xFF10B981,
                                                ).withValues(alpha: 0.03);
                                          borderCol = const Color(
                                            0xFF10B981,
                                          ).withValues(alpha: 0.2);
                                          textCol = isDark
                                              ? const Color(0xFF34D399)
                                              : const Color(0xFF047857);
                                        } else {
                                          blockBg = isDark
                                              ? const Color(
                                                  0xFF10B981,
                                                ).withValues(alpha: 0.15)
                                              : const Color(
                                                  0xFF10B981,
                                                ).withValues(alpha: 0.08);
                                          borderCol = const Color(
                                            0xFF10B981,
                                          ).withValues(alpha: 0.3);
                                          textCol = isDark
                                              ? const Color(0xFF34D399)
                                              : const Color(0xFF047857);
                                        }
                                    }

                                    return Positioned(
                                      left: left,
                                      width: width,
                                      top: top,
                                      height:
                                          itemHeight -
                                          2.0, // 2px vertical gap between stacked blocks
                                      child: GestureDetector(
                                        onTap: () => widget.onEditTask(task),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: blockBg,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: borderCol,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 4,
                                          ),
                                          child: CustomPaint(
                                            painter: task.status == 'PLANNED'
                                                ? _PlannedPatternPainter(
                                                    color: isDark
                                                        ? Colors.grey[800]!
                                                              .withValues(alpha: 0.3)
                                                        : Colors.grey[300]!
                                                              .withValues(alpha: 0.3),
                                                  )
                                                : null,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  task.title.isEmpty
                                                      ? '(No Title)'
                                                      : task.title,
                                                  style: GoogleFonts.poppins(
                                                    fontSize:
                                                        maxLanes > 1 ||
                                                            width < 70
                                                        ? 8.5
                                                        : 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: textCol,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                if (itemHeight > 35 &&
                                                    width > 70) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    "${task.startTime} - ${task.endTime}",
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 8,
                                                      color: textCol
                                                          .withValues(alpha: 0.8),
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Draw diagonal stripes pattern for PLANNED status
class _PlannedPatternPainter extends CustomPainter {
  final Color color;
  _PlannedPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0;

    double spacing = 12.0;
    for (double i = -size.height; i < size.width; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
