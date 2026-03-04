import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone_flutter/providers/user_provider.dart';
import 'package:instagram_clone_flutter/resources/supabase_methods.dart';
import 'package:instagram_clone_flutter/utils/colors.dart';
import 'package:instagram_clone_flutter/utils/utils.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:instagram_clone_flutter/widgets/video_player_widget.dart';

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({Key? key}) : super(key: key);

  @override
  _AddPostScreenState createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  Uint8List? _file;
  String _mediaType = 'image';
  bool isLoading = false;
  final TextEditingController _descriptionController = TextEditingController();
  String? _tempVideoPath;

  Future<void> _prepareTempVideo(Uint8List bytes) async {
    try {
      final dir = await getTemporaryDirectory();
      final fp = '${dir.path}/picked_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final f = File(fp);
      await f.writeAsBytes(bytes, flush: true);
      if (mounted) setState(() { _tempVideoPath = fp; });
    } catch (_) {}
  }

  _selectImage(BuildContext parentContext) async {
    return showDialog(
      context: parentContext,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Create a Post'),
          children: <Widget>[
            SimpleDialogOption(
                padding: const EdgeInsets.all(20),
                child: const Text('Take a photo'),
                onPressed: () async {
                  Navigator.pop(context);
                  Uint8List file = await pickImage(ImageSource.camera);
                  setState(() {
                    _file = file;
                    _mediaType = 'image';
                  });
                }),
            SimpleDialogOption(
                padding: const EdgeInsets.all(20),
                child: const Text('Choose from Gallery'),
                onPressed: () async {
                  Navigator.of(context).pop();
                  Uint8List file = await pickImage(ImageSource.gallery);
                  setState(() {
                    _file = file;
                    _mediaType = 'image';
                  });
                }),
            SimpleDialogOption(
                padding: const EdgeInsets.all(20),
                child: const Text('Choose video'),
                onPressed: () async {
                  Navigator.of(context).pop();
                  Uint8List file = await pickVideo(ImageSource.gallery);
                  setState(() {
                    _file = file;
                    _mediaType = 'video';
                  });
                  await _prepareTempVideo(file);
                }),
            SimpleDialogOption(
              padding: const EdgeInsets.all(20),
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.pop(context);
              },
            )
          ],
        );
      },
    );
  }

  void postImage(String uid, String username, String profImage) async {
    setState(() {
      isLoading = true;
    });
    // start the loading
    try {
      // upload to storage and db
      String res = await FireStoreMethods().uploadPost(
        _descriptionController.text,
        _file!,
        uid,
        username,
        profImage,
        mediaType: _mediaType,
        
      );
      if (res == "success") {
        setState(() {
          isLoading = false;
        });
        if (context.mounted) {
          showSnackBar(
            context,
            'Posted!',
          );
        }
        clearImage();
      } else {
        if (context.mounted) {
          showSnackBar(context, res, variant: SnackBarVariant.error);
        }
      }
    } catch (err) {
      setState(() {
        isLoading = false;
      });
      showSnackBar(
        context,
        err.toString(),
        variant: SnackBarVariant.error,
      );
    }
  }

  void clearImage() {
    setState(() {
      _file = null;
    });
  }

  @override
  void dispose() {
    super.dispose();
    _descriptionController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UserProvider userProvider = Provider.of<UserProvider>(context);

      return Scaffold(
        appBar: _file == null
            ? AppBar(
              backgroundColor: mobileBackgroundColor,
              title: const Text('Create a Post'),
              centerTitle: false,
            )
            : AppBar(
              backgroundColor: mobileBackgroundColor,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: clearImage,
              ),
              title: const Text('Post to'),
              centerTitle: false,
              actions: <Widget>[
                TextButton(
                  onPressed: userProvider.user == null
                      ? null
                      : () => postImage(
                            userProvider.user!.uid,
                            userProvider.user!.username,
                            userProvider.user!.photoUrl,
                          ),
                  child: const Text(
                    "Post",
                    style: TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16.0),
                  ),
                )
              ],
            ),
        body: _file == null
            ? Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: mobileSearchColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.add_photo_alternate, size: 56),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Share a photo or video',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose from gallery or take a new photo',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final file = await pickImage(ImageSource.gallery);
                          if (file != null) {
                            setState(() { _file = file; _mediaType = 'image'; });
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: const BorderSide(color: secondaryColor),
                        ),
                        icon: const Icon(Icons.photo_library, color: primaryColor),
                        label: const Text('Gallery'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final file = await pickImage(ImageSource.camera);
                          if (file != null) {
                            setState(() { _file = file; _mediaType = 'image'; });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blueColor,
                          foregroundColor: primaryColor,
                        ),
                        icon: const Icon(Icons.photo_camera, color: primaryColor),
                        label: const Text('Camera'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final file = await pickVideo(ImageSource.gallery);
                          if (file != null) {
                            setState(() { _file = file; _mediaType = 'video'; });
                            await _prepareTempVideo(file);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: const BorderSide(color: secondaryColor),
                        ),
                        icon: const Icon(Icons.video_library, color: primaryColor),
                        label: const Text('Video'),
                      ),
                    ],
                  ),
                ],
              ),
            )
            : Column(
              children: <Widget>[
                isLoading
                    ? const LinearProgressIndicator()
                    : const Padding(padding: EdgeInsets.only(top: 0.0)),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      CircleAvatar(
                        child: (() {
                          final u = userProvider.user;
                          if (u == null || u.photoUrl.isEmpty) {
                            return const Icon(Icons.person);
                          }
                          return null;
                        })(),
                        backgroundImage: (userProvider.user?.photoUrl.isEmpty ?? true)
                            ? null
                            : NetworkImage(userProvider.user!.photoUrl),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                              hintText: "Write a caption...",
                              border: InputBorder.none),
                          maxLines: null,
                          minLines: 3,
                        ),
                      ),
                      SizedBox(
                        height: 120,
                        width: 120,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: (() {
                            if (_mediaType == 'video') {
                              final p = _tempVideoPath;
                              if ((p ?? '').isEmpty) {
                                return Container(color: Colors.black12, alignment: Alignment.center, child: const Icon(Icons.play_circle_fill, size: 40));
                              }
                              return VideoPlayerWidget(bucket: 'local', path: 'local', filePath: p, autoplay: false, showControls: false, showCenterPlay: true, muted: false);
                            }
                            return Image.memory(_file!, fit: BoxFit.cover);
                          })(),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _selectImage(context),
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Change media'),
                      ),
                      const SizedBox(width: 12),
                      TextButton.icon(
                        onPressed: clearImage,
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        label: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ],
            ),
      );
  }
}
