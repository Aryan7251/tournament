import 'package:flutter/foundation.dart';
import 'audio_web_js.dart';

class AviatorAudioService {
  static bool _muted = false;
  static bool get isMuted => _muted;

  static void setMuted(bool muted) {
    _muted = muted;
    if (kIsWeb) {
      try {
        evalAudioJs('if (window.aviatorAudio) window.aviatorAudio.setMuted($muted);');
      } catch (_) {}
    }
  }

  static void toggleMute() {
    setMuted(!_muted);
  }

  static void startEngine() {
    if (_muted) return;
    if (kIsWeb) {
      try {
        evalAudioJs('if (window.aviatorAudio) window.aviatorAudio.startEngine();');
      } catch (_) {}
    }
  }

  static void updateEnginePitch(double multiplier) {
    if (_muted) return;
    if (kIsWeb) {
      try {
        evalAudioJs('if (window.aviatorAudio) window.aviatorAudio.updateEnginePitch($multiplier);');
      } catch (_) {}
    }
  }

  static void stopEngine() {
    if (kIsWeb) {
      try {
        evalAudioJs('if (window.aviatorAudio) window.aviatorAudio.stopEngine();');
      } catch (_) {}
    }
  }

  static void playCashout() {
    if (_muted) return;
    if (kIsWeb) {
      try {
        evalAudioJs('if (window.aviatorAudio) window.aviatorAudio.playCashout();');
      } catch (_) {}
    }
  }

  static void playCrash() {
    if (_muted) return;
    if (kIsWeb) {
      try {
        evalAudioJs('if (window.aviatorAudio) window.aviatorAudio.playCrash();');
      } catch (_) {}
    }
  }

  static void playTick() {
    if (_muted) return;
    if (kIsWeb) {
      try {
        evalAudioJs('if (window.aviatorAudio) window.aviatorAudio.playTick();');
      } catch (_) {}
    }
  }

  static void playBet() {
    if (_muted) return;
    if (kIsWeb) {
      try {
        evalAudioJs('if (window.aviatorAudio) window.aviatorAudio.playBet();');
      } catch (_) {}
    }
  }
}
