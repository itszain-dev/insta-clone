import 'package:video_player/video_player.dart';

VideoPlayerController createVideoControllerImpl({String? filePath, required String url}) {
  return VideoPlayerController.networkUrl(Uri.parse(url));
}
