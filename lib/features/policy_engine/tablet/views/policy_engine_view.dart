import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/widgets/loading_screen.dart';
import '../../models/shift_model.dart';
import '../../services/shift_service.dart';
import '../../widgets/shift_detail_bottom_sheet.dart';
import 'add_shift_dialog.dart';

class PolicyEngineView extends StatefulWidget {
  const PolicyEngineView({super.key});

  @override
  State<PolicyEngineView> createState() => _PolicyEngineViewState();
}

class _PolicyEngineViewState extends State<PolicyEngineView> {
  late ShiftService _shiftService;

  List<Shift> _shifts = [];
  bool _isLoadingShifts = true;

  @override
  void initState() {
    super.initState();
    // Initialize Services
    WidgetsBinding.instance.addPostFrameCallback((_) {
       final dio = Provider.of<AuthService>(context, listen: false).dio;
       _shiftService = ShiftService(dio);
       _fetchShifts();
    });
  }

  Future<void> _fetchShifts() async {
    setState(() => _isLoadingShifts = true);
    try {
      final data = await _shiftService.getShifts();
      if (mounted) setState(() => _shifts = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading shifts: $e")));
    } finally {
      if (mounted) setState(() => _isLoadingShifts = false);
    }
  }

  void _showAddShiftDialog({Shift? existingShift}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddShiftDialog(
        existingShift: existingShift,
        onSubmit: (shift) async {
          Navigator.pop(context);
          setState(() => _isLoadingShifts = true);
          try {
            if (existingShift == null) {
              await _shiftService.createShift(shift);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Shift created successfully")),
                );
              }
            } else {
              await _shiftService.updateShift(existingShift.id!, shift);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Shift updated successfully")),
                );
              }
            }
            _fetchShifts();
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Error saving shift: $e")),
              );
            }
            setState(() => _isLoadingShifts = false);
          }
        },
      ),
    );
  }

  Future<void> _deleteShift(Shift shift) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Shift', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${shift.name}"? This action will unassign all staff currently on this shift.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoadingShifts = true);
      try {
        await _shiftService.deleteShift(shift.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Shift deleted successfully")),
          );
        }
        _fetchShifts();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error deleting shift: $e")),
          );
        }
        setState(() => _isLoadingShifts = false);
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final horizontalPadding = isMobile ? 12.0 : 32.0;

    return LoadingScreen(
      isLoading: _isLoadingShifts,
      message: "Fetching policy rules...",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Section (padded horizontally and top)
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              isMobile ? 16 : 24,
              horizontalPadding,
              0,
            ),
            child: _buildHelperHeader(context),
          ),
          const SizedBox(height: 24),

          // Shifts Grid (occupies full width, scrolling area matches screen bounds)
          Expanded(
            child: _shifts.isEmpty 
              ? Center(child: Text("No shifts found", style: GoogleFonts.poppins(color: Colors.grey)))
              : LayoutBuilder(
              builder: (context, constraints) {
                // Determine if we should stack vertically or horizontally
                final isPortrait = constraints.maxWidth < 900; 
                final usableWidth = constraints.maxWidth - (2 * horizontalPadding);

                // We'll wrap in Wrap or Grid or ListView depending on layout.
                // Reusing _buildShiftCard for each item.
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    isMobile ? 24 : 32,
                  ),
                  child: Wrap(
                    spacing: isMobile ? 16 : 24,
                    runSpacing: isMobile ? 16 : 24,
                    alignment: WrapAlignment.start,
                    children: _shifts.map<Widget>((shift) {
                       final itemWidth = isPortrait ? usableWidth : (usableWidth - 48) / 3;
                       
                       return SizedBox(
                         width: itemWidth,
                         child: _buildShiftCard(
                             context,
                             shift: shift,
                         ),
                       );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelperHeader(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return GlassContainer(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 16 : 20,
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Active Shifts',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddShiftDialog(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1), // Indigo
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(
                        'Add Shift',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage work timings and grace periods',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Shifts',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage work timings and grace periods',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddShiftDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1), // Indigo
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    'Add Shift',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildShiftCard(BuildContext context, {required Shift shift}) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final color = Colors.indigoAccent;
    final icon = Icons.access_time_filled;
    
    // Calculate duration (simple approximation if needed, or pass from backend)
    // Display shift data
    final title = shift.name;
    final type = "Shift"; // Backend doesn't seem to have type yet, or maybe 'shift_name' implies it?
    final timing = "${shift.startTime} - ${shift.endTime}";
    final gracePeriod = "${shift.gracePeriodMins} Mins";
    final overtime = shift.isOvertimeEnabled ? "On (> ${shift.overtimeThresholdHours}h)" : "Off";
    
    
    return InkWell(
      onTap: () => ShiftDetailBottomSheet.show(
        context,
        shift: shift,
        onEdit: () => _showAddShiftDialog(existingShift: shift),
        onDelete: () => _deleteShift(shift),
      ),
      borderRadius: BorderRadius.circular(20),
      child: GlassContainer(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        type,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.indigoAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'View',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.indigoAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(height: 1, thickness: 1, color: Colors.white10),
            const SizedBox(height: 16),
  
            // Details List
            _buildDetailRow(context, 'Timing', timing, isBold: true),
            const SizedBox(height: 12),
            // _buildDetailRow(context, 'Duration', duration), // Duration omitted for simplicity or calculated
            // const SizedBox(height: 16),
            // const Divider(height: 1, thickness: 1, color: Colors.white10),
            // const SizedBox(height: 16),
            _buildDetailRow(context, 'Grace Period', gracePeriod, icon: Icons.warning_amber_rounded, iconColor: Colors.amber),
            const SizedBox(height: 12),
            _buildDetailRow(context, 'Overtime', overtime, icon: Icons.bolt, iconColor: const Color(0xFF5B60F6)),
            const SizedBox(height: 12),
            _buildDetailRow(
              context,
              'Correction Deadline',
              '${shift.correctionDeadline} Day${shift.correctionDeadline == 1 ? '' : 's'}',
              icon: Icons.edit_calendar_outlined,
              iconColor: Colors.deepOrangeAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, {bool isBold = false, IconData? icon, Color? iconColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
           mainAxisSize: MainAxisSize.min,
           children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: icon != null ? iconColor : Colors.grey,
                fontWeight: icon != null ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
           ],
        ),
        const SizedBox(width: 16), // Minimum gap
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: isBold || icon != null ? FontWeight.w600 : FontWeight.w500,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
