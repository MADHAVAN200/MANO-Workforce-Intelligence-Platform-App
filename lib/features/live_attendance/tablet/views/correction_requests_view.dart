import 'package:flutter/material.dart';
import '../../../attendance/admin/views/admin_correction_requests.dart';

class CorrectionRequestsView extends StatelessWidget {
  const CorrectionRequestsView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: AdminCorrectionRequests(),
    );
  }
}
