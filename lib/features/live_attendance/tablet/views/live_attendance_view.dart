import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_date_picker.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../dashboard/tablet/widgets/stat_card.dart';
import '../../../employees/services/employee_service.dart';
import '../../../employees/models/employee_model.dart';
import '../../../attendance/services/attendance_service.dart';
import '../../../attendance/models/attendance_record.dart';
import '../../../attendance/models/live_attendance_item.dart';
import 'correction_requests_view.dart';

class LiveAttendanceView extends StatefulWidget {
  const LiveAttendanceView({super.key});

  @override
  State<LiveAttendanceView> createState() => _LiveAttendanceViewState();
}

class _LiveAttendanceViewState extends State<LiveAttendanceView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Data State
  DateTime _selectedDate = DateTime.now();
  List<LiveAttendanceItem> _items = [];
  bool _isLoading = false;
  
  // Cache
  final Map<String, List<LiveAttendanceItem>> _dashboardCache = {};
  
  // Stats
  int _present = 0;
  int _active = 0;
  int _absent = 0;
  int _late = 0;

  late EmployeeService _employeeService;
  late AttendanceService _attendanceService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    final authService = Provider.of<AuthService>(context, listen: false);
    _employeeService = EmployeeService(authService);
    _attendanceService = AttendanceService(authService.dio);
    
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData({bool forceRefresh = false}) async {
    if (!mounted) return;
    
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // 1. Check Cache
    if (!forceRefresh && _dashboardCache.containsKey(dateStr)) {
      _updateStateWithItems(_dashboardCache[dateStr]!);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dio = Provider.of<AuthService>(context, listen: false).dio;

      final results = await Future.wait([
        _employeeService.getEmployees(),  
        _attendanceService.getAdminAttendanceRecords(dateStr)
      ]);

      final users = results[0] as List<Employee>;
      final records = results[1] as List<AttendanceRecord>;

      final merged = mergeAttendanceData(users, records);
      
      merged.sort((a, b) {
        if (a.status == "Absent" && b.status != "Absent") return 1;
        if (a.status != "Absent" && b.status == "Absent") return -1;
        return 0;
      });

      // 2. Update Cache
      _dashboardCache[dateStr] = merged;

      if (mounted) {
        _updateStateWithItems(merged);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateStateWithItems(List<LiveAttendanceItem> items) {
    setState(() {
      _items = items;
      _present = items.where((i) => i.status == "Present").length;
      _active = items.where((i) => i.status == "Active").length;
      _absent = items.where((i) => i.status == "Absent").length;
      _late = items.where((i) => i.isLate).length;
    });
  }

  List<LiveAttendanceItem> mergeAttendanceData(List<Employee> users, List<AttendanceRecord> records) {
    return users.map((user) {
      final userRecs = records.where((r) => r.userId == user.userId).toList();
      final record = userRecs.isNotEmpty ? userRecs.first : null;
      return LiveAttendanceItem(user: user, record: record);
    }).toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tabs
        _buildTabs(context),
        
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Live Dashboard
              _buildLiveDashboard(context),
              
              // Tab 2: Correction Requests
              const CorrectionRequestsView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabs(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(32, 24, 32, 24),
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[300]!),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: primaryColor, 
          borderRadius: BorderRadius.circular(10),
          boxShadow: isDark ? [
            BoxShadow(
              color: primaryColor.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ] : [
            BoxShadow(
              color: primaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        labelColor: Colors.white, 
        unselectedLabelColor: isDark ? Colors.grey[500] : Colors.grey[600],
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        padding: const EdgeInsets.all(4), 
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: [
          const Tab(text: 'Live Dashboard'),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Correction Requests'),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red, 
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '5',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveDashboard(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Selector
          _buildDateSelector(context),
          const SizedBox(height: 12),
          
          // 1. KPIs
          _buildKPIGrid(),
          const SizedBox(height: 20),

          // 2. Filters 
          _buildFilters(context),
          const SizedBox(height: 20),

          // 3. List
          _buildMonitoringList(context),
        ],
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        InkWell(
          onTap: () async {
            await showDialog(
              context: context,
              builder: (context) => GlassDatePicker(
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                onDateSelected: (newDate) {
                  setState(() => _selectedDate = newDate);
                  _fetchDashboardData();
                },
              ),
            );
          },
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            borderRadius: 12,
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today, 
                  size: 16, 
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white 
                      : Theme.of(context).primaryColor
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEE, dd MMM yyyy').format(_selectedDate),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKPIGrid() {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final totalEmployees = _items.length;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isLandscape ? 4 : 2,
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      childAspectRatio: isLandscape ? 2.0 : 2.4,
      children: [
        StatCard(
          title: 'Total Present',
          value: '$_present',
          total: '/ $totalEmployees',
          percentage: '',
          contextText: 'For Selected Date',
          isPositive: true,
          icon: Icons.people_alt,
          baseColor: const Color(0xFF5B60F6),
        ),
        StatCard(
          title: 'Late Arrivals',
          value: '$_late',
          total: '',
          percentage: '',
          contextText: 'Late Check-ins',
          isPositive: false,
          icon: Icons.access_time_filled,
          baseColor: const Color(0xFFF59E0B),
        ),
        StatCard(
          title: 'Absent',
          value: '$_absent',
          total: '',
          percentage: '',
          contextText: 'Not checked in',
          isPositive: false,
          icon: Icons.person_off,
          baseColor: const Color(0xFFEF4444),
        ),
        StatCard(
          title: 'Active Now',
          value: '$_active',
          total: '',
          percentage: '',
          contextText: 'Currently clocked in',
          isPositive: true,
          icon: Icons.coffee,
          baseColor: const Color(0xFF10B981),
        ),
      ],
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Column(
      children: [
        // Search
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF161B22) 
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white.withOpacity(0.05) 
                  : Colors.grey[300]!,
            ),
          ),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search employee...',
              prefixIcon: Icon(Icons.search, size: 20, color: Theme.of(context).textTheme.bodySmall?.color),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            style: GoogleFonts.poppins(fontSize: 14),
          ),
        ),
        const SizedBox(height: 12),
        // Dropdown (Full width for easy touch)
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF161B22) 
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white.withOpacity(0.05) 
                  : Colors.grey[300]!,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: 'All Departments',
              icon: Icon(Icons.keyboard_arrow_down, color: Theme.of(context).textTheme.bodySmall?.color),
              dropdownColor: Theme.of(context).cardColor, 
              items: ['All Departments', 'Engineering', 'Design', 'Sales']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.poppins(fontSize: 14))))
                  .toList(),
              onChanged: (_) {},
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonitoringList(BuildContext context) {
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text('No attendance records found for this date.', style: GoogleFonts.poppins(color: Colors.grey)),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      separatorBuilder: (c, i) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        final item = _items[index];
        return _buildMonitoringCard(context, item);
      },
    );
  }

  Widget _buildMonitoringCard(BuildContext context, LiveAttendanceItem item) {
    Color color;
    switch (item.statusLabel) {
      case "Active": color = Colors.blue; break;
      case "Late Active": color = Colors.blueAccent; break; 
      case "Present": color = Colors.green; break;
      case "Late": color = Colors.orange; break;
      default: color = Colors.grey;
    }
    
    final inTime = item.record?.timeIn != null ? _formatTime(item.record!.timeIn) : '--';
    final outTime = item.record?.timeOut != null ? _formatTime(item.record!.timeOut) : '--';
    // Calc hours if both present? Or just raw
    final hrs = '--'; // Todo: calculate duration if needed

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        children: [
          // Row 1: Profile + Status
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withOpacity(0.1),
                child: Text(
                  item.name.isNotEmpty ? item.name[0].toUpperCase() : '?', 
                  style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name, // Use userName from LiveAttendanceItem
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    Text(
                      "${item.designation} • ${item.department}",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Text(
                  item.statusLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.5)),
          const SizedBox(height: 12),

          // Row 2: Metrics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricItem(context, 'Time In', inTime),
              _buildMetricItem(context, 'Time Out', outTime),
              _buildMetricItem(context, 'Shift', item.user.shift ?? 'General'),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '--';
    try {
      final dt = DateTime.parse(isoTime);
      return DateFormat('hh:mm a').format(dt);
    } catch (e) {
      return ''; 
    }
  }

  Widget _buildMetricItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }
}
