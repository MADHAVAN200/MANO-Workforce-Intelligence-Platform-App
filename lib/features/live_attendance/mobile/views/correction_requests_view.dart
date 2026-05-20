import 'package:flutter/material.dart';
import '../../../attendance/admin/views/admin_correction_requests.dart';

class MobileCorrectionRequestsView extends StatelessWidget {
  const MobileCorrectionRequestsView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: AdminCorrectionRequests(),
    );
  }
}
