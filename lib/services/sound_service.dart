import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import 'uzbek_speech_helper.dart';

import 'sound_service_stub.dart'
    if (dart.library.js_interop) 'sound_service_web.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  bool _isVoiceEnabled = true;
  bool get isVoiceEnabled => _isVoiceEnabled;
  AudioPlayer? _audioPlayer;

  AudioPlayer get _player => _audioPlayer ??= AudioPlayer();

  Future<void> _playVoiceNative() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('audio/voicelab-speech.wav'));
    } catch (e) {
      debugPrint('Native audio play error: $e');
    }
  }

  /// Enable or disable voice notifications
  void setVoiceEnabled(bool enabled) {
    _isVoiceEnabled = enabled;
    if (kIsWeb) {
      try {
        setVoiceNotificationEnabledOnWeb(enabled);
      } catch (e) {
        debugPrint('setVoiceNotificationEnabledOnWeb error: $e');
      }
    }
  }

  /// Play a crisp "Ting!" bell chime for general in-app messages/SMS
  void playTing([String type = 'sms']) {
    try {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}

    if (kIsWeb) {
      try {
        playChimeOnWeb(type);
      } catch (e) {
        debugPrint('playChimeOnWeb error: $e');
      }
    }
  }

  /// Play basic chime sound when a QR customer orders
  void playNewOrderSound() {
    playTing('qr_order');
  }

  /// Start professional voice announcement loop for a new QR order
  /// Plays voicelab-speech.wav audio and repeats until accepted/dismissed
  void announceNewOrder({
    required CustomerOrder order,
    int repeatIntervalSec = 6,
  }) {
    if (!_isVoiceEnabled) return;

    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    final fullSpeechText = UzbekSpeechHelper.buildOrderAnnouncement(order);
    final reminderText = UzbekSpeechHelper.buildReminderAnnouncement(order);

    if (kIsWeb) {
      try {
        announceOrderVoiceOnWeb(
          order.id,
          fullSpeechText,
          reminderText,
          repeatIntervalSec,
        );
      } catch (e) {
        debugPrint('announceOrderVoiceOnWeb error: $e');
      }
    } else {
      _playVoiceNative();
    }
  }

  /// Stop the repeating voice loop when staff accepts or dismisses the order
  void stopOrderVoice(int orderId) {
    if (kIsWeb) {
      try {
        stopOrderVoiceOnWeb(orderId);
      } catch (e) {
        debugPrint('stopOrderVoiceOnWeb error: $e');
      }
    } else {
      try {
        _audioPlayer?.stop();
      } catch (_) {}
    }
  }

  /// Stop all active voices and repeating loops
  void stopAllVoices() {
    if (kIsWeb) {
      try {
        stopAllOrderVoicesOnWeb();
      } catch (e) {
        debugPrint('stopAllOrderVoicesOnWeb error: $e');
      }
    } else {
      try {
        _audioPlayer?.stop();
      } catch (_) {}
    }
  }

  /// Test speech announcement (for Settings screen)
  void testVoiceAnnouncement([String? sampleText]) {
    final text = sampleText ??
        'Diqqat! Yangi buyurtma keldi. Ali ismli mijozdan yangi buyurtma qabul qilindi.';

    if (kIsWeb) {
      try {
        testVoiceAnnouncementOnWeb(text);
      } catch (e) {
        debugPrint('testVoiceAnnouncementOnWeb error: $e');
      }
    } else {
      _playVoiceNative();
    }
  }

  /// Play support SMS sound ("Ting!")
  void playSupportSmsSound() {
    playTing('sms');
  }
}
