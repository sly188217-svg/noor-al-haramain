import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';

class QuranAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  QuranAudioHandler() {
    _player.onPlayerComplete.listen((event) {
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.completed,
        playing: false,
      ));
    });
  }

  @override
  Future<void> play() async {
    await _player.resume();
    playbackState.add(playbackState.value.copyWith(playing: true));
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    playbackState.add(playbackState.value.copyWith(playing: false));
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
    return super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> playFromUrl(String url, String title, String artist) async {
    mediaItem.add(MediaItem(
      id: url,
      title: title,
      artist: artist,
      duration: Duration.zero,
    ));
    await _player.play(UrlSource(url));
    playbackState.add(playbackState.value.copyWith(
      controls: [MediaControl.pause, MediaControl.stop],
      processingState: AudioProcessingState.ready,
      playing: true,
    ));
  }
}
