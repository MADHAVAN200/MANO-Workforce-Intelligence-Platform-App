import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

extension ToastExtension on BuildContext {
  void showToast(
    String message, {
    bool isError = false,
    bool isSuccess = false,
    bool isWarning = false,
  }) {
    final isDark = Theme.of(this).brightness == Brightness.dark;

    // Determine colors & icons based on status
    Color bgColor;
    IconData icon;

    if (isError) {
      bgColor = const Color(0xFFDA3637); // GitHub error red
      icon = Icons.error_outline;
    } else if (isWarning) {
      bgColor = const Color(0xFFD29922); // GitHub warning yellow/amber
      icon = Icons.warning_amber_outlined;
    } else if (isSuccess) {
      bgColor = const Color(0xFF2EA043); // GitHub success green
      icon = Icons.check_circle_outline;
    } else {
      bgColor = isDark ? const Color(0xFF21262D) : const Color(0xFF24292F);
      icon = Icons.info_outline;
    }

    ScaffoldMessenger.of(this).clearSnackBars();
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bgColor,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
