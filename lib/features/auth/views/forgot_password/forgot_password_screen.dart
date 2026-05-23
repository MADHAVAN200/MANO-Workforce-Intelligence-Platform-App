import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/widgets/toast_helper.dart';
import '../verify_otp/verify_otp_screen.dart';
import 'mobile/forgot_password_mobile_portrait.dart';
import 'tablet/forgot_password_tablet_portrait.dart';
import 'tablet/forgot_password_tablet_landscape.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => ForgotPasswordScreenState();
}

class ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> sendOtp() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      await auth.forgotPassword(emailController.text.trim());

      if (!mounted) return;
      context.showToast(
        'OTP sent successfully. Please check your email.',
        isSuccess: true,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyOtpScreen(email: emailController.text.trim()),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      context.showToast(
        e.toString().replaceAll('Exception: ', ''),
        isError: true,
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
      backgroundColor: const Color(0xFF0D1117),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return ForgotPasswordMobilePortrait(controller: this);
          }
          return OrientationBuilder(
            builder: (_, orientation) {
              return orientation == Orientation.portrait
                  ? ForgotPasswordTabletPortrait(controller: this)
                  : ForgotPasswordTabletLandscape(controller: this);
            },
          );
        },
      ),
    );
  }
}
