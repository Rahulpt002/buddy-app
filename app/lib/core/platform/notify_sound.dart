// The phone's own default notification sound (Settings → Sound → Default notification
// sound), played through the notification stream so it follows the phone's notification
// volume, silent mode and Do Not Disturb.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('deskpanel/sound');

Future<void> playNotificationSound() async {
  try {
    await _channel.invokeMethod<void>('notify');
  } on MissingPluginException {
    // tests / non-Android
  } on PlatformException catch (e) {
    debugPrint('DeskPanel sound: ${e.message}');
  }
}
