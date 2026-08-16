import 'package:flutter/material.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/theme/app_color.dart';
import '../../../core/theme/bevel.dart';
import '../../permissions/presentation/permission_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isRegistering = false;
  bool _isLoading = false;
  String? _errorMessage;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    Map<String, dynamic> result;
    if (_isRegistering) {
      result = await FirebaseAuthService.registerWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
        displayName: _nameController.text,
      );
    } else {
      result = await FirebaseAuthService.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
    }

    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PermissionPage()),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result['error'] ?? 'Authentication failed';
      });
    }
  }

  Future<void> _handleEmergencyBypass() async {
    setState(() => _isLoading = true);
    await FirebaseAuthService.emergencyBypass();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PermissionPage()),
    );
  }

  InputDecoration _tacticalFieldDecoration({
    required String label,
    required IconData icon,
    required Color accent,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5), fontSize: 12.5),
      floatingLabelStyle: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.bold),
      prefixIcon: Icon(icon, color: accent, size: 20),
      filled: true,
      fillColor: AppColors.panel,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.hairline, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.distress, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.distress, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Tactical Header
              Bevel(
                inset: true,
                fill: AppColors.panel,
                radius: 8,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.olive, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "MESHRESQ // TACTICAL NODE AUTH",
                            style: TextStyle(
                              color: AppColors.amber,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "SECURE RELAY IDENTITY & PROFILE ACCESS",
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10.5,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Segmented Tab Switcher (Login / Register)
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isRegistering = false),
                      child: Bevel(
                        inset: _isRegistering,
                        fill: !_isRegistering ? AppColors.panelRaised : AppColors.panel,
                        radius: 6,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            "SIGN IN",
                            style: TextStyle(
                              color: !_isRegistering ? AppColors.olive : AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isRegistering = true),
                      child: Bevel(
                        inset: !_isRegistering,
                        fill: _isRegistering ? AppColors.panelRaised : AppColors.panel,
                        radius: 6,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            "REGISTER ID",
                            style: TextStyle(
                              color: _isRegistering ? AppColors.olive : AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Form Container
              Bevel(
                inset: false,
                fill: AppColors.panelRaised,
                radius: 8,
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.distress.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.distress.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.distress, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: AppColors.distress, fontSize: 11.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Full Name (Only on Registration)
                      if (_isRegistering) ...[
                        TextFormField(
                          controller: _nameController,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          decoration: _tacticalFieldDecoration(
                            label: "OPERATOR / CITIZEN NAME",
                            icon: Icons.person_outline,
                            accent: AppColors.amber,
                            hint: "e.g. Sridhar P",
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Email / Student ID
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                        decoration: _tacticalFieldDecoration(
                          label: "EMAIL / OPERATOR ID",
                          icon: Icons.alternate_email,
                          accent: AppColors.olive,
                          hint: "e.g. sridhar@college.edu",
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Required";
                          if (!v.contains('@')) return "Enter valid email address";
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                        decoration: _tacticalFieldDecoration(
                          label: "TACTICAL PASSKEY",
                          icon: Icons.lock_outline,
                          accent: AppColors.olive,
                          hint: "Min 6 characters",
                        ),
                        validator: (v) {
                          if (v == null || v.length < 6) return "Min 6 characters required";
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // Submit Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.olive,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : Text(
                                _isRegistering ? "CREATE SECURE NODE ID" : "AUTHORIZE & ENTER NETWORK",
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Emergency Bypass Card (Disaster Protocol)
              Bevel(
                inset: true,
                fill: AppColors.panel,
                radius: 8,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.distress, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          "EMERGENCY PROTOCOL // ZERO CONNECTIVITY",
                          style: TextStyle(
                            color: AppColors.distress,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "In an immediate life-threatening emergency or zero-connectivity disaster, bypass authentication to access the offline SOS transmitter instantly.",
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleEmergencyBypass,
                      icon: const Icon(Icons.flash_on, color: AppColors.distress, size: 18),
                      label: const Text(
                        "🚨 EMERGENCY QUICK ACCESS (SKIP AUTH)",
                        style: TextStyle(
                          color: AppColors.distress,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.8,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.distress, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        backgroundColor: AppColors.distress.withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
