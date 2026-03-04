import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:instagram_clone_flutter/resources/story_methods.dart';
import 'package:instagram_clone_flutter/utils/utils.dart';
import 'package:instagram_clone_flutter/utils/colors.dart';

class StoryAddSheet extends StatefulWidget {
  final Uint8List file;
  final String mediaType;
  const StoryAddSheet({super.key, required this.file, required this.mediaType});

  @override
  State<StoryAddSheet> createState() => _StoryAddSheetState();
}

class _StoryAddSheetState extends State<StoryAddSheet> {
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final me = client.auth.currentUser;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: (() {
                if (widget.mediaType == 'video') {
                  return Container(
                    height: 240,
                    color: Colors.black12,
                    alignment: Alignment.center,
                    child: const Icon(Icons.play_circle_fill, size: 64, color: primaryColor),
                  );
                }
                return Image.memory(widget.file, height: 240, fit: BoxFit.cover);
              })(),
            ),
            const SizedBox(height: 12),
            if (_isUploading)
              const LinearProgressIndicator(
                minHeight: 3,
                color: blueColor,
                backgroundColor: Colors.white24,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: const BorderSide(color: secondaryColor),
                    ),
                    onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blueColor,
                      foregroundColor: primaryColor,
                    ),
                    onPressed: _isUploading
                        ? null
                        : () async {
                            if (me == null) return;
                            setState(() { _isUploading = true; });
                            try {
                              final row = await client.from('users').select('username').eq('uid', me.id).single();
                              final res = await StoryMethods().uploadStory(
                                file: widget.file,
                                uid: me.id,
                                username: (row['username'] ?? '').toString(),
                                mediaType: widget.mediaType,
                              );
                              if (!mounted) return;
                              if (res == 'success') {
                                showSnackBar(context, 'Story added', variant: SnackBarVariant.success);
                                Navigator.of(context).pop(true);
                              } else {
                                showSnackBar(context, res, variant: SnackBarVariant.error);
                              }
                            } catch (e) {
                              if (!mounted) return;
                              showSnackBar(context, e.toString(), variant: SnackBarVariant.error);
                            } finally {
                              if (mounted) setState(() { _isUploading = false; });
                            }
                          },
                    child: const Text('Add Story'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
