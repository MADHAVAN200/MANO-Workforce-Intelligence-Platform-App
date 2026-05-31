import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/features/leave/providers/leave_provider.dart';
import 'package:flutter_application/features/leave/widgets/leave_history_item.dart';
import 'package:flutter_application/features/leave/widgets/leave_details_dialog.dart';

class AdminLeaveHistory extends StatefulWidget {
  const AdminLeaveHistory({super.key});

  @override
  State<AdminLeaveHistory> createState() => _AdminLeaveHistoryState();
}

class _AdminLeaveHistoryState extends State<AdminLeaveHistory> {
  String _selectedStatus = 'All';
  final List<String> _statuses = ['All', 'Approved', 'Rejected'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchHistory();
    });
  }

  void _fetchHistory() {
    context.read<LeaveProvider>().fetchAdminHistory(
      status: _selectedStatus == 'All' ? null : _selectedStatus,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Filter Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                "Filter Status:",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF30363D) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStatus,
                      isDense: true,
                      dropdownColor: isDark ? const Color(0xFF30363D) : Colors.white,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedStatus = val);
                          _fetchHistory();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: Consumer<LeaveProvider>(
            builder: (context, provider, _) {
              if (provider.isLoadingAdminHistory) {
                return const Center(child: CircularProgressIndicator());
              }

              if (provider.adminHistoryError != null) {
                return Center(child: Text('Error: ${provider.adminHistoryError}'));
              }

              if (provider.adminHistory.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text("No history found", style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => _fetchHistory(),
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 20),
                  itemCount: provider.adminHistory.length,
                  itemBuilder: (context, index) {
                    final request = provider.adminHistory[index];
                    return LeaveHistoryItem(
                      request: request,
                      onTap: () => LeaveDetailsDialog.showMobile(
                        context,
                        request: request,
                        isReviewMode: false, // Already processed
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
