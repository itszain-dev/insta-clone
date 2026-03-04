import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter/models/user.dart' as model;
import 'package:instagram_clone_flutter/providers/user_provider.dart';
import 'package:instagram_clone_flutter/resources/supabase_methods.dart';
import 'package:instagram_clone_flutter/utils/colors.dart';
import 'package:instagram_clone_flutter/utils/utils.dart';
import 'package:instagram_clone_flutter/widgets/comment_card.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommentsScreen extends StatefulWidget {
  final postId;
  const CommentsScreen({Key? key, required this.postId}) : super(key: key);

  @override
  _CommentsScreenState createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController commentEditingController =
      TextEditingController();

  void postComment(String uid, String name, String profilePic) async {
    try {
      String res = await FireStoreMethods().postComment(
        widget.postId,
        commentEditingController.text,
        uid,
        name,
        profilePic,
      );

      if (res != 'success') {
        if (context.mounted) {
          showSnackBar(context, res, variant: SnackBarVariant.error);
        }
      }
      setState(() {
        commentEditingController.text = "";
      });
    } catch (err) {
      showSnackBar(
        context,
        err.toString(),
        variant: SnackBarVariant.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final model.User? user = Provider.of<UserProvider>(context).user;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        title: const Text(
          'Comments',
        ),
        centerTitle: false,
      ),
      body: StreamBuilder(
        stream: Supabase.instance.client
            .from('comments')
            .stream(primaryKey: ['comment_id'])
            .eq('post_id', widget.postId)
            .order('date_published'),
        builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final items = snapshot.data ?? const [];
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load comments. Check your internet.'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (ctx, index) => CommentCard(
              snap: items[index],
            ),
          );
        },
      ),
      // text input
      bottomNavigationBar: user == null
          ? const SafeArea(
              child: SizedBox(
                height: kToolbarHeight,
                child: Center(child: Text('Sign in to comment')),
              ),
            )
          : SafeArea(
              child: Container(
                height: kToolbarHeight,
                margin: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      child: (() {
                        final url = user.photoUrl;
                        if (url.isEmpty) {
                          return const Icon(Icons.person);
                        }
                        return null;
                      })(),
                      backgroundImage:
                          user.photoUrl.isEmpty ? null : NetworkImage(user.photoUrl),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 8),
                        child: TextField(
                          controller: commentEditingController,
                          decoration: InputDecoration(
                            hintText: 'Comment as ${user.username}',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => postComment(
                        user.uid,
                        user.username,
                        user.photoUrl,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 8),
                        child: const Text(
                          'Post',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}
