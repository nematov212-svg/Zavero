import 'dart:js_interop';

@JS('window.playChimeSound')
external void _playChimeSoundJS(JSString type);

@JS('window.announceOrderVoice')
external void _announceOrderVoiceJS(
  JSNumber orderId,
  JSString speechText,
  JSString reminderText,
  JSNumber repeatIntervalSec,
);

@JS('window.stopOrderVoice')
external void _stopOrderVoiceJS(JSNumber orderId);

@JS('window.stopAllOrderVoices')
external void _stopAllOrderVoicesJS();

@JS('window.testVoiceAnnouncement')
external void _testVoiceAnnouncementJS(JSString sampleText);

@JS('window.setVoiceNotificationEnabled')
external void _setVoiceNotificationEnabledJS(JSBoolean enabled);

void playChimeOnWeb(String type) {
  try {
    _playChimeSoundJS(type.toJS);
  } catch (_) {}
}

void announceOrderVoiceOnWeb(
  int orderId,
  String speechText,
  String reminderText,
  int repeatIntervalSec,
) {
  try {
    _announceOrderVoiceJS(
      orderId.toJS,
      speechText.toJS,
      reminderText.toJS,
      repeatIntervalSec.toJS,
    );
  } catch (_) {}
}

void stopOrderVoiceOnWeb(int orderId) {
  try {
    _stopOrderVoiceJS(orderId.toJS);
  } catch (_) {}
}

void stopAllOrderVoicesOnWeb() {
  try {
    _stopAllOrderVoicesJS();
  } catch (_) {}
}

void testVoiceAnnouncementOnWeb(String sampleText) {
  try {
    _testVoiceAnnouncementJS(sampleText.toJS);
  } catch (_) {}
}

void setVoiceNotificationEnabledOnWeb(bool enabled) {
  try {
    _setVoiceNotificationEnabledJS(enabled.toJS);
  } catch (_) {}
}
