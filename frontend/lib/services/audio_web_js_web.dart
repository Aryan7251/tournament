import 'dart:js_interop' as js;

@js.JS('eval')
external void _evalJs(String code);

void evalAudioJs(String code) {
  _evalJs(code);
}
