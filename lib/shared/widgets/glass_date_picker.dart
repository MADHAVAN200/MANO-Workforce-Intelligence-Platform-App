import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'glass_container.dart';

class GlassDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onDateSelected;
  final bool isLarge; // true for Tablet

  const GlassDatePicker({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onDateSelected,
    this.isLarge = false,
  });

  @override
  State<GlassDatePicker> createState() => _GlassDatePickerState();
}

class _GlassDatePickerState extends State<GlassDatePicker> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
    _selectedDate = widget.initialDate;
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + offset);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final accentColor = const Color(0xFF10B981);
    
    // Size Constants
    final width = widget.isLarge ? 420.0 : 320.0;
    final padding = widget.isLarge ? 24.0 : 16.0;
    final headerSize = widget.isLarge ? 20.0 : 16.0;
    final dayLabelSize = widget.isLarge ? 14.0 : 11.0;
    final gridSize = widget.isLarge ? 8.0 : 4.0;
    final dayNumSize = widget.isLarge ? 15.0 : 12.0;
    final aspectRatio = widget.isLarge ? 1.0 : 1.2;
    final iconSize = widget.isLarge ? 24.0 : 20.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: GlassContainer(
          borderRadius: 20,
          padding: EdgeInsets.all(padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    iconSize: iconSize,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _currentMonth.isAfter(DateTime(widget.firstDate.year, widget.firstDate.month)) 
                        ? () => _changeMonth(-1) 
                        : null,
                    icon: Icon(Icons.chevron_left, color: textColor),
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(_currentMonth),
                    style: GoogleFonts.poppins(
                      fontSize: headerSize,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    iconSize: iconSize,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _currentMonth.isBefore(DateTime(widget.lastDate.year, widget.lastDate.month)) 
                        ? () => _changeMonth(1) 
                        : null,
                    icon: Icon(Icons.chevron_right, color: textColor),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Weekdays
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'].map((day) => 
                  Flexible(
                    child: SizedBox(
                      width: widget.isLarge ? 40 : 28, // Reduced from 32
                      child: Center(
                      child: Text(
                        day,
                        style: GoogleFonts.poppins(
                          fontSize: dayLabelSize,
                          fontWeight: FontWeight.w500,
                          color: textColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  )
                  )
                ).toList(),
              ),
              const SizedBox(height: 8),
              
              // Days Grid
              _buildCalendarGrid(textColor, accentColor, gridSize, dayNumSize, aspectRatio),

              SizedBox(height: widget.isLarge ? 24 : 16),
              
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(fontSize: dayNumSize, color: textColor.withValues(alpha: 0.7)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {
                      widget.onDateSelected(_selectedDate);
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: Text(
                      'Set Date',
                      style: GoogleFonts.poppins(
                        fontSize: dayNumSize,
                        color: accentColor, 
                        fontWeight: FontWeight.w600
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(Color textColor, Color accentColor, double spacing, double fontSize, double ratio) {
    final daysInMonth = DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    final firstDayOffset = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7;
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: ratio,
      ),
      itemCount: daysInMonth + firstDayOffset,
      itemBuilder: (context, index) {
        if (index < firstDayOffset) return const SizedBox();
        
        final day = index - firstDayOffset + 1;
        final date = DateTime(_currentMonth.year, _currentMonth.month, day);
        final isSelected = DateUtils.isSameDay(date, _selectedDate);
        final isToday = DateUtils.isSameDay(date, DateTime.now());
        final isDisabled = date.isBefore(widget.firstDate) || date.isAfter(widget.lastDate);

        return GestureDetector(
          onTap: isDisabled ? null : () {
            setState(() => _selectedDate = date);
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? accentColor : (isToday ? accentColor.withValues(alpha: 0.2) : Colors.transparent),
              shape: BoxShape.circle,
              border: isToday && !isSelected ? Border.all(color: accentColor, width: 1) : null,
            ),
            child: Center(
              child: Text(
                '$day',
                style: GoogleFonts.poppins(
                  fontSize: fontSize,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.white : (isDisabled ? textColor.withValues(alpha: 0.2) : textColor),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
