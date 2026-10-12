import 'dart:js_interop';

@JS('zaveroBiometrics.isAvailable')
external JSPromise<JSBoolean> _jsIsAvailable();

@JS('zaveroBiometrics.registerTouchID')
external JSPromise<JSString> _jsRegisterTouchID(JSString username);

@JS('zaveroBiometrics.verifyTouchID')
external JSPromise<JSString> _jsVerifyTouchID();

Future<bool> jsIsAvailable() async {
  try {
    final res = await _jsIsAvailable().toDart;
    return res.toDart;
  } catch (e) {
    return false;
  }
}

Future<String?> jsRegisterTouchID(String username) async {
  try {
    final jsStr = await _jsRegisterTouchID(username.toJS).toDart;
    return jsStr.toDart;
  } catch (e) {
    return null;
  }
}

Future<String?> jsVerifyTouchID() async {
  try {
    final jsStr = await _jsVerifyTouchID().toDart;
    return jsStr.toDart;
  } catch (e) {
    return null;
  }
}
