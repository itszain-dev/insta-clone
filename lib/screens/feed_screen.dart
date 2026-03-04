import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone_flutter/utils/colors.dart';
import 'package:instagram_clone_flutter/utils/global_variable.dart';
import 'package:instagram_clone_flutter/widgets/post_card.dart';
import 'package:instagram_clone_flutter/feed/feed_notifier.dart';
import 'package:instagram_clone_flutter/models/post.dart';
import 'package:instagram_clone_flutter/widgets/stories_bar.dart';
import 'package:instagram_clone_flutter/resources/story_methods.dart';
import 'package:instagram_clone_flutter/utils/utils.dart';
import 'package:instagram_clone_flutter/widgets/story_add_sheet.dart';
import 'package:instagram_clone_flutter/stories/stories_notifier.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> with AutomaticKeepAliveClientMixin<FeedScreen> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(feedProvider.notifier).init();
    });
    _controller.addListener(() {
      if (_controller.position.pixels >= _controller.position.maxScrollExtent - 200) {
        ref.read(feedProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    try {
      ref.read(currentPlayingPostIdProvider.notifier).state = null;
    } catch (_) {}
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final width = MediaQuery.of(context).size.width;
    final state = ref.watch(feedProvider);

    return Scaffold(
      backgroundColor:
          width > webScreenSize ? webBackgroundColor : mobileBackgroundColor,
      appBar: width > webScreenSize
          ? null
          : AppBar(
              backgroundColor: mobileBackgroundColor,
              centerTitle: false,
              title: SvgPicture.asset(
                'assets/ic_instagram.svg',
                color: primaryColor,
                height: 32,
              ),
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.messenger_outline,
                    color: primaryColor,
                  ),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: primaryColor,
                  ),
                  onPressed: () async {
                    final client = Supabase.instance.client;
                    final me = client.auth.currentUser;
                    if (me == null) return;
                    try {
                      final type = await showDialog<String>(
                        context: context,
                        builder: (ctx) {
                          return SimpleDialog(
                            title: const Text('Add to your story'),
                            children: [
                              SimpleDialogOption(
                                padding: const EdgeInsets.all(20),
                                child: const Text('Photo from gallery'),
                                onPressed: () => Navigator.pop(ctx, 'image'),
                              ),
                              SimpleDialogOption(
                                padding: const EdgeInsets.all(20),
                                child: const Text('Video from gallery'),
                                onPressed: () => Navigator.pop(ctx, 'video'),
                              ),
                            ],
                          );
                        },
                      );
                      if (type == null) return;
                      final file = type == 'video' ? await pickVideo(ImageSource.gallery) : await pickImage(ImageSource.gallery);
                      if (file == null) return;
                      if (!mounted) return;
                      final added = await showModalBottomSheet<bool>(
                        context: context,
                        backgroundColor: mobileBackgroundColor,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                        builder: (_) => StoryAddSheet(file: file, mediaType: type),
                      );
                      if (added == true && mounted) {
                        setState(() {});
                      }
                    } catch (e) {
                      if (!mounted) return;
                      showSnackBar(context, e.toString(), variant: SnackBarVariant.error);
                    }
                  },
                ),
              ],
            ),
      body: RefreshIndicator(
        color: blueColor,
        backgroundColor: width > webScreenSize ? webBackgroundColor : mobileBackgroundColor,
        onRefresh: () async {
          await ref.read(feedProvider.notifier).refresh();
          await ref.read(storiesProvider.notifier).refresh();
        },
        child: Builder(
          builder: (context) {
            if (!state.initialized && state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            final posts = state.posts;
            return ListView.builder(
              key: const PageStorageKey('feedList'),
              controller: _controller,
              physics: const AlwaysScrollableScrollPhysics(),
              cacheExtent: 1200,
              addAutomaticKeepAlives: true,
              itemCount: posts.length + 1 + (state.isLoadingMore ? 1 : 0),
              itemBuilder: (ctx, index) {
                if (index == 0) {
                  return Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: width > webScreenSize ? width * 0.1 : 0,
                    ),
                    child: const StoriesBar(),
                  );
                }
                final postIndex = index - 1;
                if (postIndex >= posts.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final Post p = posts[postIndex];
                return Container(
                  key: ValueKey(p.postId),
                  margin: EdgeInsets.symmetric(
                    horizontal: width > webScreenSize ? width * 0.3 : 0,
                    vertical: width > webScreenSize ? 15 : 0,
                  ),
                  child: PostCard(
                    snap: p.toDbMap(),
                    scrollController: _controller,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
