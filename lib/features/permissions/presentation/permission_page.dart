import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_color.dart';
import '../../../core/theme/bevel.dart';
import '../../emergency_profile/presentation/emergency_profile_page.dart';

class PermissionPage extends StatefulWidget {
  const PermissionPage({super.key});

  @override
  State<PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage> {
  bool _requesting = false;

  Future<void> _requestPermissions() async {
    setState(() => _requesting = true);

    // Statuses aren't branched on here -- matches original behavior,
    // which proceeds to the next screen regardless of grant/deny per
    // permission.
    await [
      Permission.locationWhenInUse,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.camera,
      Permission.microphone,
    ].request();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const EmergencyProfilePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Document-style header, not a SaaS onboarding stepper --
              // reads as a manifest of what the device needs to grant.
              Bevel(
                inset: true,
                fill: AppColors.panel,
                radius: 8,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: const Text(
                  "MESHRESQ // ACCESS MANIFEST",
                  style: TextStyle(
                    color: AppColors.amber,
                    fontSize: 10.5,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                "Required for emergency dispatch",
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "MeshResQ works without an account. To find nearby "
                    "peer nodes and send SOS signals offline, it needs "
                    "the local access listed below.",
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Bevel(
                  radius: 10,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    children: const [
                      _ManifestRow(
                        index: "01",
                        icon: Icons.location_on_outlined,
                        accent: AppColors.amber,
                        title: "High-precision GPS",
                        subtitle: "Embeds exact coordinates into offline SOS packets.",
                      ),
                      _ManifestRow(
                        index: "02",
                        icon: Icons.bluetooth_searching_rounded,
                        accent: AppColors.olive,
                        title: "Nearby mesh discovery",
                        subtitle: "Relays messages via BLE & Wi-Fi Direct to nearby phones.",
                      ),
                      _ManifestRow(
                        index: "03",
                        icon: Icons.mic_none_rounded,
                        accent: AppColors.olive,
                        title: "Audio & photo evidence",
                        subtitle: "Attaches short voice notes and photos to alerts for responders.",
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "You can change any of these later in Settings.",
                style: TextStyle(
                  color: AppColors.textMuted.withValues(alpha: 0.7),
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 16),
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
                  onPressed: _requesting ? null : _requestPermissions,
                  child: _requesting
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation(Colors.black87),
                    ),
                  )
                      : const Text(
                    "GRANT ACCESS & CONTINUE",
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
    );
  }
}

/// One line item in the access manifest: a numbered row with a hairline
/// divider below it, and a "REQUIRED" tag styled as a small stamped
/// plate rather than a soft rounded pill.
class _ManifestRow extends StatelessWidget {
  final String index;
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final bool isLast;

  const _ManifestRow({
    required this.index,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  index,
                  style: TextStyle(
                    color: accent.withValues(alpha: 0.8),
                    fontFamily: 'Courier',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(icon, color: accent, size: 19),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Bevel(
                inset: true,
                fill: AppColors.panel,
                radius: 4,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                child: const Text(
                  "REQUIRED",
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, thickness: 1, color: AppColors.hairline, indent: 12, endIndent: 12),
      ],
    );
  }
}