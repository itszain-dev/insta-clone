import 'dart:io';
import 'package:video_player/video_player.dart';

VideoPlayerController createVideoControllerImpl({String? filePath, required String url}) {
  if ((filePath ?? '').isNotEmpty) {
    return VideoPlayerController.file(File(filePath!));
  }
  return VideoPlayerController.networkUrl(Uri.parse(url));
}
