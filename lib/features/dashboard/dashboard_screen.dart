import 'package:flutter/material.dart';
import '../../shared/layout/main_layout.dart';
import 'tablet/views/portrait.dart';
import 'mobile/views/landscape.dart';
import 'mobile/views/portrait.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Mobile Breakpoint (Content Width < 600 typically means Portrait Phone)
        // Check for Mobile Landscape: Landscape implementation on Width < 900?
        if (constraints.maxWidth < 600) {
           return const MobilePortrait();
        }

        return OrientationBuilder(
          builder: (context, orientation) {
            if (orientation == Orientation.portrait) {
              return const TabletPortrait();
            } else {
              // LANDSCAPE
              // If width is smaller than typical Tablet Landscape (1024+), use Mobile Landscape
              // Using 900 as breakpoint.
              if (constraints.maxWidth < 900) {
                return const MobileLandscape();
              }
              return const MainLayout(); // Tablet/Desktop Landscape
            }
          },
        );
      },
    );
  }
}
