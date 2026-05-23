import 'package:flutter/material.dart';
import '../forgot_password_screen.dart';

class ForgotPasswordMobilePortrait extends StatelessWidget {
  final ForgotPasswordScreenState controller;

  const ForgotPasswordMobilePortrait({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Form(
          key: controller.formKey,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Forgot Password',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFC9D1D9),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your registered email to receive OTP.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF8B949E),
                      ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: controller.emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Color(0xFFC9D1D9)),
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    labelStyle: const TextStyle(color: Color(0xFF8B949E)),
                    prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF8B949E)),
                    filled: true,
                    fillColor: const Color(0xFF0D1117),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (!v.contains('@')) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: controller.isLoading ? null : controller.sendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2F81F7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: controller.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('SEND OTP', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
