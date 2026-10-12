void playChimeOnWeb(String type) {
  // No-op for non-web platforms (mobile, desktop)
}

void announceOrderVoiceOnWeb(
  int orderId,
  String speechText,
  String reminderText,
  int repeatIntervalSec,
) {
  // No-op for non-web platforms
}

void stopOrderVoiceOnWeb(int orderId) {
  // No-op for non-web platforms
}

void stopAllOrderVoicesOnWeb() {
  // No-op for non-web platforms
}

void testVoiceAnnouncementOnWeb(String sampleText) {
  // No-op for non-web platforms
}

void setVoiceNotificationEnabledOnWeb(bool enabled) {
  // No-op for non-web platforms
}
