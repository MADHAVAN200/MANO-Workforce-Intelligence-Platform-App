import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/dar_models.dart';

class TaskEditDialog extends StatefulWidget {
  final DarItem? initialData;
  final String initialDate; // YYYY-MM-DD
  final List<String> categories;
  final Function(Map<String, dynamic> payload) onSave;
  final VoidCallback? onDelete;
  final bool isBottomSheet;

  const TaskEditDialog({
    super.key,
    this.initialData,
    required this.initialDate,
    required this.categories,
    required this.onSave,
    this.onDelete,
    this.isBottomSheet = false,
  });

  @override
  State<TaskEditDialog> createState() => _TaskEditDialogState();
}

class _TaskEditDialogState extends State<TaskEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  late String _dateStr;
  late String _startTime;
  late String _endTime;
  late String _selectedCategory;
  late bool _isEdit;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.initialData != null;
    
    _titleController.text = _isEdit ? widget.initialData!.title : '';
    _descController.text = _isEdit ? widget.initialData!.description : '';
    _dateStr = _isEdit ? widget.initialData!.date : widget.initialDate;
    _startTime = _isEdit ? widget.initialData!.startTime : _getRoundedTime(0);
    _endTime = _isEdit ? widget.initialData!.endTime : _getRoundedTime(60);
    
    final initialCat = _isEdit ? widget.initialData!.category : '';
    _selectedCategory = widget.categories.contains(initialCat)
        ? initialCat
        : (widget.categories.isNotEmpty ? widget.categories.first : 'General');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String _getRoundedTime(int addMinutes) {
    final now = DateTime.now().add(Duration(minutes: addMinutes));
    int min = now.minute;
    int hour = now.hour;

    if (min < 30) {
      min = 30;
    } else {
      min = 0;
      hour = (hour + 1) % 24;
    }

    return "${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}";
  }

  Future<void> _selectDate() async {
    if (_isEdit) return;
    final parsed = DateTime.parse(_dateStr);
    final picked = await showDatePicker(
      context: context,
      initialDate: parsed,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _dateStr = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final timeStr = isStart ? _startTime : _endTime;
    final parts = timeStr.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      setState(() {
        final formatted = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
        if (isStart) {
          _startTime = formatted;
        } else {
          _endTime = formatted;
        }
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_startTime.compareTo(_endTime) >= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("End time must be after start time.")),
      );
      return;
    }

    widget.onSave({
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'start_time': _startTime,
      'end_time': _endTime,
      'activity_date': _dateStr,
      'activity_type': _selectedCategory,
    });
    Navigator.of(context).pop();
  }

  Widget _buildFormContent(BuildContext context, bool isDark, String formattedDate) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isEdit ? "Edit Task" : "New Task",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 20),
              )
            ],
          ),
          const SizedBox(height: 16),

          // Title input
          TextFormField(
            controller: _titleController,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.grey[900],
            ),
            decoration: InputDecoration(
              hintText: 'Task Title',
              hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : Colors.grey[350]!)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF6366F1), width: 2)),
            ),
            validator: (val) => (val == null || val.trim().isEmpty) ? 'Title is required' : null,
          ),
          const SizedBox(height: 20),

          // Category selector
          Row(
            children: [
              const Icon(Icons.category_outlined, color: Colors.grey, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0D1117) : Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!),
                    ),
                  ),
                  style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white : Colors.grey[800]),
                  items: widget.categories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat,
                      child: Text(cat),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCategory = val;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Date & Time pickers
          Row(
            children: [
              const Icon(Icons.access_time_outlined, color: Colors.grey, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    // Date picker trigger
                    InkWell(
                      onTap: _selectDate,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Text(
                          formattedDate,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    // Start time trigger
                    InkWell(
                      onTap: () => _selectTime(true),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Text(
                          _startTime,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Text("–", style: TextStyle(color: Colors.grey[400])),
                    // End time trigger
                    InkWell(
                      onTap: () => _selectTime(false),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Text(
                          _endTime,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 20),

          // Description input
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.notes, color: Colors.grey, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  style: GoogleFonts.poppins(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'Add description / details...',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0D1117) : Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!),
                    ),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 24),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_isEdit && widget.onDelete != null)
                IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onDelete!();
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: 'Delete Task',
                )
              else
                const SizedBox.shrink(),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      "Cancel",
                      style: GoogleFonts.poppins(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      elevation: 0,
                    ),
                    child: Text(
                      _isEdit ? "Update" : "Save",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedDate = DateFormat('EEEE, d MMMM').format(DateTime.parse(_dateStr));

    if (widget.isBottomSheet) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: isDark ? Border.all(color: const Color(0xFF30363D), width: 1) : null,
        ),
        padding: EdgeInsets.only(
          top: 16,
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: _buildFormContent(context, isDark, formattedDate),
        ),
      );
    }

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: _buildFormContent(context, isDark, formattedDate),
        ),
      ),
    );
  }
}
