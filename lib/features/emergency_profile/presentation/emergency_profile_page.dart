import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/theme/app_color.dart';
import '../../../core/theme/bevel.dart';
import '../../home/presentation/home_page.dart';

class EmergencyProfilePage extends StatefulWidget {
  const EmergencyProfilePage({super.key});

  @override
  State<EmergencyProfilePage> createState() => _EmergencyProfilePageState();
}

class _EmergencyProfilePageState extends State<EmergencyProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _medicalInfoController = TextEditingController();
  final TextEditingController _iceContactController = TextEditingController();

  String _selectedBloodGroup = 'O+';
  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _medicalInfoController.dispose();
    _iceContactController.dispose();
    super.dispose();
  }

  Future<void> _saveProfileAndContinue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final box = await Hive.openBox('emergency_profile_box');
    await box.put('full_name', _nameController.text);
    await box.put('phone', _phoneController.text);
    await box.put('blood_group', _selectedBloodGroup);
    await box.put('medical_notes', _medicalInfoController.text);
    await box.put('ice_contact', _iceContactController.text);
    await box.put('profile_completed', true);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  // Flat, uniform-bordered fields -- a terminal data-entry look rather
  // than a soft translucent glass fill. (Text fields stay on a regular
  // OutlineInputBorder rather than the bevel treatment: InputDecoration
  // only supports a single uniform BorderSide, and reacting to focus/
  // error state needs that built-in support rather than a static
  // hand-painted bevel.)
  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    required Color accent,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13.5),
      hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5), fontSize: 13),
      floatingLabelStyle: TextStyle(color: accent, fontSize: 13),
      prefixIcon: Icon(icon, color: accent, size: 20),
      filled: true,
      fillColor: AppColors.fieldFill,
      errorStyle: const TextStyle(color: AppColors.error, fontSize: 11.5),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: accent, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.error, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back, color: AppColors.textMuted, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Bevel(
                        inset: true,
                        fill: AppColors.panel,
                        radius: 8,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: const Text(
                          "MESHRESQ // VICTIM IDENTIFICATION",
                          style: TextStyle(
                            color: AppColors.amber,
                            fontSize: 10.5,
                            fontFamily: 'Courier',
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  "Who are we saving?",
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Stored only on this device. This information is embedded "
                      "inside encrypted offline SOS payloads sent to first "
                      "responders \u2014 nowhere else.",
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),

                const _SectionLabel("IDENTITY", accent: AppColors.olive),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _fieldDecoration(
                    label: "Full name",
                    icon: Icons.person_outline,
                    accent: AppColors.olive,
                  ),
                  validator: (value) => value == null || value.isEmpty ? "Enter your name" : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _fieldDecoration(
                    label: "Phone number (optional)",
                    icon: Icons.phone_outlined,
                    accent: AppColors.olive,
                  ),
                ),

                const SizedBox(height: 26),
                const _SectionLabel("CRITICAL MEDICAL DATA", accent: AppColors.amber),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  initialValue: _selectedBloodGroup,
                  dropdownColor: AppColors.panelRaised,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: _fieldDecoration(
                    label: "Blood group",
                    icon: Icons.bloodtype_outlined,
                    accent: AppColors.amber,
                  ),
                  items: _bloodGroups
                      .map((group) => DropdownMenuItem(value: group, child: Text(group)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedBloodGroup = val);
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _iceContactController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _fieldDecoration(
                    label: "In case of emergency (ICE) contact",
                    icon: Icons.contact_phone_outlined,
                    accent: AppColors.amber,
                  ),
                  validator: (value) =>
                  value == null || value.isEmpty ? "Provide an emergency contact number" : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _medicalInfoController,
                  maxLines: 3,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _fieldDecoration(
                    label: "Medical notes / allergies",
                    hint: "e.g. diabetic, severe asthma, penicillin allergy",
                    icon: Icons.medical_services_outlined,
                    accent: AppColors.amber,
                  ),
                ),

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amber,
                      disabledBackgroundColor: AppColors.amber.withValues(alpha: 0.5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: _saving ? null : _saveProfileAndContinue,
                    child: _saving
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(Colors.black87),
                      ),
                    )
                        : const Text(
                      "SAVE PROFILE & CONTINUE",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small section divider label -- signals grouping within the form
/// without resorting to full card containers around each group.
class _SectionLabel extends StatelessWidget {
  final String text;
  final Color accent;
  const _SectionLabel(this.text, {required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(height: 3, width: 3, color: accent),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: accent.withValues(alpha: 0.9),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider(height: 1, thickness: 1, color: AppColors.hairline)),
      ],
    );
  }
}