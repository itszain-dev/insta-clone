import 'package:flutter/material.dart';

class OfflineNotice extends StatelessWidget {
  const OfflineNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Connection issue. Check your internet.'),
      ),
    );
  }
}
