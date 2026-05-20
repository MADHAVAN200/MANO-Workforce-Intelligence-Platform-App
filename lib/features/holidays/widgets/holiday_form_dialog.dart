import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_date_picker.dart';
import '../models/holiday_model.dart';

class HolidayFormDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;
  final Holiday? initialData;

  const HolidayFormDialog({super.key, required this.onSubmit, this.initialData});

  @override
  HolidayFormDialogState createState() => HolidayFormDialogState();
}

class HolidayFormDialogState extends State<HolidayFormDialog> {
  late TextEditingController _nameCtrl;
  late DateTime _selectedDate;
  late String _type;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialData?.name ?? '');
    _selectedDate = widget.initialData != null 
        ? DateTime.parse(widget.initialData!.date) 
        : DateTime.now();
    _type = widget.initialData?.type ?? "Public";
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _pickDate() async {
    // Show Custom GlassDatePicker
    showDialog(
      context: context,
      builder: (context) => GlassDatePicker(
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        onDateSelected: (date) {
           setState(() => _selectedDate = date);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white54 : Colors.black54;

    return Dialog(
       backgroundColor: Colors.transparent,
       surfaceTintColor: Colors.transparent,
       child: GlassContainer(
         width: 400,
         padding: const EdgeInsets.all(24),
         borderRadius: 24,
         child: Form(
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
                     widget.initialData == null ? "Add Holiday" : "Edit Holiday",
                     style: GoogleFonts.poppins(
                       fontSize: 20, 
                       fontWeight: FontWeight.bold, 
                       color: textColor
                     ),
                   ),
                   IconButton(
                     onPressed: () => Navigator.pop(context),
                     icon: Icon(Icons.close, color: textColor),
                   ),
                 ],
               ),
               const SizedBox(height: 24),
               
               // Name Field
               Text("Holiday Name", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: hintColor)),
               const SizedBox(height: 8),
               TextFormField(
                 controller: _nameCtrl,
                 style: GoogleFonts.poppins(color: textColor),
                 validator: (value) => value == null || value.isEmpty ? 'Please enter a name' : null,
                 decoration: InputDecoration(
                   filled: true,
                   fillColor: isDark ? const Color(0xFF0D1117).withValues(alpha: 0.5) : Colors.grey[100],
                   hintText: "e.g. New Year's Day",
                   hintStyle: GoogleFonts.poppins(color: Colors.grey),
                   contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                   enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
                   focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366F1))),
                 ),
               ),
               const SizedBox(height: 16),
               
               // Date Picker Field
               Text("Date", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: hintColor)),
               const SizedBox(height: 8),
               InkWell(
                 onTap: _pickDate,
                 child: Container(
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                   decoration: BoxDecoration(
                     color: isDark ? const Color(0xFF0D1117).withValues(alpha: 0.5) : Colors.grey[100],
                     borderRadius: BorderRadius.circular(12),
                     border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                   ),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Text(
                         DateFormat('MMMM dd, yyyy').format(_selectedDate),
                         style: GoogleFonts.poppins(color: textColor),
                       ),
                       Icon(Icons.calendar_today, size: 18, color: hintColor),
                     ],
                   ),
                 ),
               ),

               const SizedBox(height: 16),
               
               // Type Dropdown
               Text("Type", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: hintColor)),
               const SizedBox(height: 8),
               DropdownButtonFormField<String>(
                 value: _type,
                 dropdownColor: isDark ? const Color(0xFF161B22) : Colors.white,
                 style: GoogleFonts.poppins(color: textColor),
                 items: ["Public", "Optional", "Observance"].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                 onChanged: (val) => setState(() => _type = val!),
                 decoration: InputDecoration(
                   filled: true,
                   fillColor: isDark ? const Color(0xFF0D1117).withValues(alpha: 0.5) : Colors.grey[100],
                   contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                   enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
                   focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366F1))),
                 ),
               ),
               
               const SizedBox(height: 32),
               
               // Action Buttons
               Row(
                 mainAxisAlignment: MainAxisAlignment.end,
                 children: [
                   TextButton(
                     onPressed: () => Navigator.pop(context), 
                     style: TextButton.styleFrom(
                       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                       foregroundColor: hintColor,
                     ),
                     child: Text("Cancel", style: GoogleFonts.poppins(fontWeight: FontWeight.w500))
                   ),
                   const SizedBox(width: 8),
                   ElevatedButton(
                     style: ElevatedButton.styleFrom(
                       backgroundColor: const Color(0xFF6366F1),
                       foregroundColor: Colors.white,
                       elevation: 0,
                       padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                     ),
                     onPressed: () {
                       if (!_formKey.currentState!.validate()) return;
                       widget.onSubmit({
                         "holiday_name": _nameCtrl.text,
                         "holiday_date": DateFormat('yyyy-MM-dd').format(_selectedDate),
                         "holiday_type": _type,
                       });
                     },
                     child: Text(
                       widget.initialData == null ? "Add Holiday" : "Update", 
                       style: GoogleFonts.poppins(fontWeight: FontWeight.w600)
                     ),
                   )
                 ],
               )
             ],
           ),
         ),
       ),
    );
  }
}
