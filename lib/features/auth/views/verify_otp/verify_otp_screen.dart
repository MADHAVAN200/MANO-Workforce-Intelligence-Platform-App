import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/services/auth_service.dart';
import '../reset_password/reset_password_screen.dart';
import 'mobile/verify_otp_mobile_portrait.dart';
import 'tablet/verify_otp_tablet_portrait.dart';
import 'tablet/verify_otp_tablet_landscape.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String email;

  const VerifyOtpScreen({super.key, required this.email});

  @override
  State<VerifyOtpScreen> createState() => VerifyOtpScreenState();
}

class VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final formKey = GlobalKey<FormState>();
  final otpController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  Future<void> verifyOtp() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      // The API should return the reset token
      final response = await auth.verifyOtp(widget.email, otpController.text.trim());

      // Based on typical flows, the response should contain the reset token.
      // Adjust key based on actual API response if needed.
      // Assuming 'resetToken' or 'accessToken' or just parsing from response.
      // If the API returns { "resetToken": "..." }
      
      final token = response['resetToken'] ?? response['accessToken'] ?? response['token'];
      
      if (token == null) {
        throw Exception('Token not found in response');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP Verified Successfully.')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(resetToken: token),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: const Color(0xFF0D1117), // Removed hardcoded color
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return VerifyOtpMobilePortrait(controller: this);
          }
          return OrientationBuilder(
            builder: (_, orientation) {
              return orientation == Orientation.portrait
                  ? VerifyOtpTabletPortrait(controller: this)
                  : VerifyOtpTabletLandscape(controller: this);
            },
          );
        },
      ),
    );
  }
}
