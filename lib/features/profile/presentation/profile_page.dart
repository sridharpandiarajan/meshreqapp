import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/services/device_identity_service.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/services/mesh_api_service.dart';
import '../../../core/theme/app_color.dart';
import '../../../core/theme/bevel.dart';
import '../../auth/presentation/auth_gate.dart';
import '../../emergency_profile/presentation/emergency_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _name = 'Operator';
  String _phone = 'Not set';
  String _bloodGroup = 'O+';
  String _medicalNotes = 'None';
  String _iceContact = 'Not set';
  String _email = '';
  String _nodeUuid = '';
  String _serverUrl = '';
  bool _isEmergencyBypass = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  void _loadProfileData() {
    final box = Hive.isBoxOpen('emergency_profile_box')
        ? Hive.box('emergency_profile_box')
        : null;

    final savedName = box?.get('full_name') as String?;
    final savedPhone = box?.get('phone') as String?;
    final savedBlood = box?.get('blood_group') as String?;
    final savedNotes = box?.get('medical_notes') as String?;
    final savedIce = box?.get('ice_contact') as String?;

    setState(() {
      _name = (savedName != null && savedName.isNotEmpty)
          ? savedName
          : (FirebaseAuthService.currentUserDisplayName.isNotEmpty
              ? FirebaseAuthService.currentUserDisplayName
              : 'Citizen / Student');
      _phone = (savedPhone != null && savedPhone.isNotEmpty) ? savedPhone : 'Not configured';
      _bloodGroup = savedBlood ?? 'O+';
      _medicalNotes = (savedNotes != null && savedNotes.isNotEmpty) ? savedNotes : 'No chronic conditions listed';
      _iceContact = (savedIce != null && savedIce.isNotEmpty) ? savedIce : 'No ICE contact specified';
      _email = FirebaseAuthService.currentUserEmail.isNotEmpty
          ? FirebaseAuthService.currentUserEmail
          : 'offline-node@meshresq.local';
      _nodeUuid = DeviceIdentityService.getOrCreateDeviceUUID();
      _serverUrl = MeshApiService.getBaseUrl();
      _isEmergencyBypass = FirebaseAuthService.isEmergencyBypass;
    });
  }

  Future<void> _editServerUrl() async {
    final controller = TextEditingController(text: _serverUrl);
    final newUrl = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          "CONFIGURE COMMAND GATEWAY",
          style: TextStyle(
            color: AppColors.amber,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Set the IP / URL of the MeshResQ FastAPI backend server:",
              style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontFamily: 'Courier'),
              decoration: InputDecoration(
                hintText: "e.g. http://192.168.1.100:8000",
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                filled: true,
                fillColor: AppColors.panelRaised,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppColors.olive, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.olive,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text("SAVE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (newUrl != null && newUrl.isNotEmpty && mounted) {
      await MeshApiService.setBaseUrl(newUrl);
      setState(() => _serverUrl = newUrl);
    }
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          "TERMINATE NODE SESSION?",
          style: TextStyle(
            color: AppColors.amber,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        content: const Text(
          "Signing out will disconnect your verified Firebase credentials from this offline radio node. You will need to re-authenticate when rejoining the network.",
          style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("CANCEL", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.distress,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text("SIGN OUT", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await FirebaseAuthService.signOut();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Navigation Bar
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Bevel(
                      radius: 8,
                      padding: const EdgeInsets.all(10),
                      child: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Bevel(
                      inset: true,
                      fill: AppColors.panel,
                      radius: 8,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: const Text(
                        "OPERATOR PROFILE & MESH IDENTITY",
                        style: TextStyle(
                          color: AppColors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Operator Identity Card
              Bevel(
                radius: 10,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.panelRaised,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.hairline),
                          ),
                          child: const Icon(Icons.person, color: AppColors.olive, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _name,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _email,
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    const Divider(color: AppColors.hairline, height: 1),
                    const SizedBox(height: 12),

                    // Security / Auth Status Badge
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isEmergencyBypass ? AppColors.amber : AppColors.ledOn,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isEmergencyBypass
                              ? "AUTHENTICATION: EMERGENCY BYPASS (OFFLINE)"
                              : "AUTHENTICATION: VERIFIED IDENTITY (FIREBASE)",
                          style: TextStyle(
                            color: _isEmergencyBypass ? AppColors.amber : AppColors.ledOn,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Node UUID with copy button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.panel,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.fingerprint, color: AppColors.textMuted, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "NODE ID: ${_nodeUuid.toUpperCase()}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                                fontFamily: 'Courier',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: _nodeUuid));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Node ID copied to clipboard"),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: const Icon(Icons.copy, color: AppColors.olive, size: 15),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Emergency Medical Dossier Card
              Bevel(
                radius: 10,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "MEDICAL & TRIAGE PROFILE",
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const EmergencyProfilePage()),
                            );
                            _loadProfileData();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.olive.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.olive.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.edit_outlined, color: AppColors.olive, size: 13),
                                SizedBox(width: 4),
                                Text(
                                  "EDIT",
                                  style: TextStyle(
                                    color: AppColors.olive,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Blood Group & Phone Grid
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.panel,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.hairline),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "BLOOD GROUP",
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _bloodGroup,
                                  style: const TextStyle(
                                    color: AppColors.distress,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.panel,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.hairline),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "PHONE CONTACT",
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _phone,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ICE Contact
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.panel,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "IN CASE OF EMERGENCY (ICE) CONTACT",
                            style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _iceContact,
                            style: const TextStyle(color: AppColors.amber, fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Medical Notes & Allergies
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.panel,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "CRITICAL MEDICAL NOTES / ALLERGIES",
                            style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _medicalNotes,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Hardware Telemetry & Mesh Radio Specs
              Bevel(
                inset: true,
                fill: AppColors.panel,
                radius: 10,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "DEVICE HARDWARE & RADIO STATUS",
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text("Bluetooth LE 5.0 Radio", style: TextStyle(color: AppColors.textPrimary, fontSize: 11.5)),
                        Text("ACTIVE (0 dBm)", style: TextStyle(color: AppColors.ledOn, fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text("LoRa 868.1 MHz Gateway Sync", style: TextStyle(color: AppColors.textPrimary, fontSize: 11.5)),
                        Text("READY", style: TextStyle(color: AppColors.olive, fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text("DTN Bundle Storage (Hive)", style: TextStyle(color: AppColors.textPrimary, fontSize: 11.5)),
                        Text("ENCRYPTED LOCAL", style: TextStyle(color: AppColors.amber, fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(color: AppColors.hairline, height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "COMMAND SERVER GATEWAY",
                                style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _serverUrl,
                                style: const TextStyle(
                                  color: AppColors.olive,
                                  fontSize: 11,
                                  fontFamily: 'Courier',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _editServerUrl,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.olive.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.olive.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              "CHANGE IP",
                              style: TextStyle(
                                color: AppColors.olive,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Sign Out Button
              OutlinedButton.icon(
                onPressed: _handleSignOut,
                icon: const Icon(Icons.logout, color: AppColors.distress, size: 18),
                label: const Text(
                  "TERMINATE SESSION / SIGN OUT",
                  style: TextStyle(
                    color: AppColors.distress,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.distress, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  backgroundColor: AppColors.distress.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
