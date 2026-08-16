import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/services/device_identity_service.dart';
import '../../../core/services/mesh_api_service.dart';
import '../../../core/theme/app_color.dart';
import '../../../core/theme/bevel.dart';
import '../../profile/presentation/profile_page.dart';

class _EmergencyCategory {
  final String label;
  final IconData icon;
  const _EmergencyCategory(this.label, this.icon);
}

const List<_EmergencyCategory> _categories = [
  _EmergencyCategory("Medical", Icons.medical_services_outlined),
  _EmergencyCategory("Trapped / Lost", Icons.terrain_outlined),
  _EmergencyCategory("Fire / Disaster", Icons.local_fire_department_outlined),
  _EmergencyCategory("Wildlife Threat", Icons.warning_amber_rounded),
];

class _Channel {
  final String label;
  final IconData icon;
  final bool isActive;
  const _Channel(this.label, this.icon, this.isActive);
}

const List<_Channel> _channels = [
  _Channel("SAT-LINK", Icons.public, false),
  _Channel("MESH-NET", Icons.hub, true),
  _Channel("LORA-RF", Icons.settings_input_antenna, true),
  _Channel("DTN-NODE", Icons.layers, true),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late final AnimationController _ledBlink;
  late final AnimationController _holdProgress;

  String _deviceUuid = "\u2014";
  String _victimName = "User Profile";
  bool _isBroadcasting = false;
  String _selectedCategory = "Medical";
  bool _profileLoadFailed = false;

  late final TextEditingController _sitrepTextController;
  bool _isRecordingVoice = false;
  bool _hasVoiceRecording = false;
  int _voiceDurationSeconds = 0;

  static const Map<String, String> _defaultVoiceNotes = {
    "Medical": "காலில் பலத்த எலும்பு முறிவு மற்றும் ரத்தம் கசிகிறது, எங்களால் நடக்க முடியவில்லை!",
    "Trapped / Lost": "அடர்ந்த காட்டில் பாதை தெரியவில்லை, நீர் ஆதாரம் குறைவு, உடனடியாக ஜிபிஎஸ் உதவி தேவை!",
    "Fire / Disaster": "காட்டுத் தீ வேகமாக பரவுகிறது, கடுமையான புகை சூழ்கிறது, உடனடி மீட்பு தேவை!",
    "Wildlife Threat": "கண்ணாடி விரியன் பாம்பு கடித்துவிட்டது, விஷம் பரவி கை வீங்கியுள்ளது, அவசர உதவி!",
  };

  void _toggleVoiceRecording() {
    HapticFeedback.selectionClick();
    if (_isRecordingVoice) {
      setState(() {
        _isRecordingVoice = false;
        _hasVoiceRecording = true;
        _voiceDurationSeconds = 4;
      });
    } else {
      setState(() {
        _isRecordingVoice = true;
        _hasVoiceRecording = false;
      });
      // Simulate voice capture completion after 3.5 seconds
      Future.delayed(const Duration(milliseconds: 3500), () {
        if (mounted && _isRecordingVoice) {
          setState(() {
            _isRecordingVoice = false;
            _hasVoiceRecording = true;
            _voiceDurationSeconds = 4;
          });
          HapticFeedback.lightImpact();
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _sitrepTextController = TextEditingController(
      text: _defaultVoiceNotes[_selectedCategory],
    );

    _ledBlink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _holdProgress = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _confirmBroadcast();
      }
    });

    _loadLocalData();
  }

  @override
  void dispose() {
    _sitrepTextController.dispose();
    _ledBlink.dispose();
    _holdProgress.dispose();
    super.dispose();
  }

  Future<void> _loadLocalData() async {
    try {
      final uuid = DeviceIdentityService.getOrCreateDeviceUUID();
      final profileBox = await Hive.openBox('emergency_profile_box');
      final name = profileBox.get('full_name', defaultValue: 'Anonymous Victim');
      if (!mounted) return;
      setState(() {
        _deviceUuid = uuid;
        _victimName = name;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _profileLoadFailed = true);
    }
  }

  void _onHoldStart(LongPressStartDetails _) {
    if (_isBroadcasting) return;
    HapticFeedback.lightImpact();
    _holdProgress.forward(from: 0);
  }

  void _onHoldCancel() {
    if (_isBroadcasting) return;
    if (_holdProgress.value < 1.0) {
      _holdProgress.reverse();
    }
  }

  Future<void> _confirmBroadcast() async {
    HapticFeedback.heavyImpact();
    setState(() => _isBroadcasting = true);
    _ledBlink.repeat(reverse: true);

    double? lat;
    double? lng;
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 3),
      );
      lat = position.latitude;
      lng = position.longitude;
    } catch (_) {}

    final voicePayload = _sitrepTextController.text.trim().isNotEmpty
        ? _sitrepTextController.text.trim()
        : (_defaultVoiceNotes[_selectedCategory] ?? "அவசர உதவி தேவைப்படுகிறது!");

    final res = await MeshApiService.sendEmergencyBeacon(
      category: _selectedCategory,
      channel: "MESH-NET",
      latitude: lat,
      longitude: lng,
      voiceText: voicePayload,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.panel,
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.olive, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                res['offline'] == true
                    ? "SOS PACKET STORED IN OFFLINE MESH QUEUE"
                    : "🚨 SOS TRANSMITTED LIVE TO COMMAND CENTER!",
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _abortBroadcast() {
    HapticFeedback.mediumImpact();
    setState(() => _isBroadcasting = false);
    _holdProgress.value = 0;
    _ledBlink.stop();
    _ledBlink.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    child: Column(
                      children: [
                        _buildChannelsCard(),
                        const SizedBox(height: 18),
                        _buildCategorySection(),
                        const SizedBox(height: 16),
                        _buildSitrepSection(),
                        const SizedBox(height: 24),
                        _buildSosTrigger(),
                        const SizedBox(height: 32),
                        _buildProfileRow(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isBroadcasting) _buildMissionBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Bevel(
              inset: true,
              fill: AppColors.panel,
              radius: 8,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "MESHRESQ // CONSOLE",
                    style: TextStyle(
                      color: AppColors.amber,
                      fontSize: 10.5,
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(color: AppColors.ledOn, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "NODE ID: ${_deviceUuid.toUpperCase()}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontFamily: 'Courier',
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
              _loadLocalData();
            },
            child: Bevel(
              radius: 8,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              child: const Column(
                children: [
                  Icon(Icons.person_outline, color: AppColors.olive, size: 16),
                  SizedBox(height: 3),
                  Text(
                    "PROFILE",
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelsCard() {
    return Bevel(
      radius: 10,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "COMMUNICATION CHANNELS",
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _channels.map((c) => _ChannelIndicator(channel: c)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            "SELECT EMERGENCY VECTOR",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              fontSize: 9.5,
              letterSpacing: 1.1,
            ),
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: _categories.map((cat) {
            final isSelected = _selectedCategory == cat.label;
            return Semantics(
              button: true,
              selected: isSelected,
              label: "${cat.label} emergency category",
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedCategory = cat.label;
                    _sitrepTextController.text = _defaultVoiceNotes[cat.label] ?? "";
                  });
                },
                child: Bevel(
                  inset: isSelected,
                  fill: isSelected ? AppColors.oliveDim : AppColors.panel,
                  radius: 9,
                  padding: EdgeInsets.zero,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          cat.icon,
                          color: isSelected ? AppColors.textPrimary : AppColors.olive,
                          size: 18,
                        ),
                        const SizedBox(width: 9),
                        Text(
                          cat.label.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSitrepSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Voice Note Recording Area
        Bevel(
          inset: true,
          fill: AppColors.panel,
          radius: 8,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: _toggleVoiceRecording,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _isRecordingVoice
                        ? AppColors.distress.withValues(alpha: 0.2)
                        : (_hasVoiceRecording
                            ? AppColors.olive.withValues(alpha: 0.2)
                            : AppColors.panelRaised),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isRecordingVoice
                          ? AppColors.distress
                          : (_hasVoiceRecording ? AppColors.olive : AppColors.hairline),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    _isRecordingVoice
                        ? Icons.stop
                        : (_hasVoiceRecording ? Icons.play_arrow : Icons.mic),
                    color: _isRecordingVoice
                        ? AppColors.distress
                        : (_hasVoiceRecording ? AppColors.olive : AppColors.amber),
                    size: 17,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (_isRecordingVoice) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.distress,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            "RECORDING VOICE SOS...",
                            style: TextStyle(
                              color: AppColors.distress,
                              fontSize: 10,
                              fontFamily: 'Courier',
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ] else if (_hasVoiceRecording) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.olive,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "VOICE MEMO ATTACHED (0:0${_voiceDurationSeconds}s)",
                            style: const TextStyle(
                              color: AppColors.olive,
                              fontSize: 10,
                              fontFamily: 'Courier',
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ] else ...[
                          const Text(
                            "RECORD EMERGENCY VOICE NOTE",
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isRecordingVoice
                          ? "Sampling Tamil/English speech buffer..."
                          : (_hasVoiceRecording
                              ? "Attached to LoRa mesh packet"
                              : "Tap microphone to record ambient SOS"),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasVoiceRecording && !_isRecordingVoice)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _hasVoiceRecording = false;
                      _voiceDurationSeconds = 0;
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.close, color: AppColors.textMuted, size: 15),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // 2. Direct Inline Text Area
        Bevel(
          inset: true,
          fill: AppColors.panel,
          radius: 8,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "EMERGENCY SITUATION TEXT",
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 8.5,
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _sitrepTextController.text = _defaultVoiceNotes[_selectedCategory] ?? "";
                      });
                    },
                    child: const Text(
                      "RESET",
                      style: TextStyle(
                        color: AppColors.olive,
                        fontSize: 8.5,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _sitrepTextController,
                maxLines: 2,
                minLines: 1,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11.5,
                  height: 1.3,
                ),
                decoration: const InputDecoration(
                  hintText: "Type situation details in Tamil or English...",
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                  border: InputBorder.none,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSosTrigger() {
    return Semantics(
      button: true,
      label: _isBroadcasting
          ? "Broadcasting SOS. Tap to abort."
          : "Hold to broadcast SOS for $_selectedCategory",
      child: GestureDetector(
        onTap: _isBroadcasting ? _abortBroadcast : null,
        onLongPressStart: _onHoldStart,
        onLongPressEnd: (_) => _onHoldCancel(),
        onLongPressCancel: _onHoldCancel,
        child: AnimatedBuilder(
          animation: Listenable.merge([_ledBlink, _holdProgress]),
          builder: (context, child) {
            final pressed = _isBroadcasting;
            return SizedBox(
              height: 214,
              width: 214,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 214,
                    width: 214,
                    decoration: const BoxDecoration(
                      color: AppColors.panelRaised,
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(BorderSide(color: AppColors.bevelDark, width: 1.5)),
                    ),
                  ),
                  if (!pressed && _holdProgress.value > 0)
                    SizedBox(
                      height: 198,
                      width: 198,
                      child: CircularProgressIndicator(
                        value: _holdProgress.value,
                        strokeWidth: 3.5,
                        backgroundColor: AppColors.bevelDark,
                        valueColor: const AlwaysStoppedAnimation(AppColors.amber),
                      ),
                    ),
                  Container(
                    height: 176,
                    width: 176,
                    decoration: BoxDecoration(
                      color: pressed ? AppColors.distress : AppColors.amber,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: pressed ? AppColors.distressDim : AppColors.amberDim,
                        width: pressed ? 4 : 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: pressed
                                ? Colors.black87.withValues(alpha: 0.35 + 0.35 * _ledBlink.value)
                                : Colors.black38,
                          ),
                        ),
                        Icon(
                          pressed ? Icons.sensors : Icons.emergency_outlined,
                          size: 46,
                          color: Colors.black87,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          pressed ? "BROADCASTING" : "HOLD FOR SOS",
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pressed ? "TAP TO ABORT" : _selectedCategory.toUpperCase(),
                          style: TextStyle(
                            color: Colors.black87.withValues(alpha: 0.6),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileRow() {
    return Bevel(
      radius: 10,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Bevel(
            inset: true,
            fill: AppColors.panel,
            radius: 20,
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.person_outline, color: AppColors.olive, size: 17),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _victimName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _profileLoadFailed ? "PROFILE UNAVAILABLE OFFLINE" : "PROFILE ACTIVE & SYNCED",
                  style: TextStyle(
                    color: _profileLoadFailed ? AppColors.textMuted : AppColors.olive,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _profileLoadFailed ? AppColors.ledOff : AppColors.ledOn,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: const BoxDecoration(
          color: AppColors.distressDim,
          border: Border(top: BorderSide(color: AppColors.bevelDark, width: 2)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "MISSION ACTIVE",
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.9,
                    ),
                  ),
                  Text(
                    "Broadcasting $_selectedCategory SOS via mesh & LoRa",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFD8B9B4), fontSize: 9.5),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _abortBroadcast,
              child: Bevel(
                fill: AppColors.panelRaised,
                radius: 8,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: const Text(
                  "ABORT",
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 10.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelIndicator extends StatelessWidget {
  final _Channel channel;
  const _ChannelIndicator({required this.channel});

  @override
  Widget build(BuildContext context) {
    final color = channel.isActive ? AppColors.olive : AppColors.textMuted;
    return Semantics(
      label: "${channel.label} ${channel.isActive ? 'active' : 'offline'}",
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Bevel(
                inset: !channel.isActive,
                fill: AppColors.panel,
                radius: 10,
                padding: const EdgeInsets.all(10),
                child: Icon(channel.icon, color: color, size: 19),
              ),
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: channel.isActive ? AppColors.ledOn : AppColors.ledOff,
                    border: Border.all(color: AppColors.bg, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            channel.label,
            style: TextStyle(
              fontSize: 8,
              fontFamily: 'Courier',
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}