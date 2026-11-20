/// Text-to-speech boundary.
///
/// The app depends on this instead of `flutter_tts` so widget tests can use a
/// recording fake and a build without audio support can leave the provider null.
abstract interface class TtsService {
  /// Starts speaking [text]; returns when playback has been requested.
  Future<void> speak(String text);

  /// Stops any current utterance.
  Future<void> stop();
}
