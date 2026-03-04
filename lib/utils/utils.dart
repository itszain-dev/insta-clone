import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone_flutter/utils/colors.dart';

// for picking up image from gallery
pickImage(ImageSource source) async {
  final ImagePicker imagePicker = ImagePicker();
  XFile? file = await imagePicker.pickImage(source: source);
  if (file != null) {
    return await file.readAsBytes();
  }
}

pickVideo(ImageSource source) async {
  final ImagePicker imagePicker = ImagePicker();
  XFile? file = await imagePicker.pickVideo(source: source);
  if (file != null) {
    return await file.readAsBytes();
  }
}

// for displaying snackbars
enum SnackBarVariant { info, success, error }

String humanizeErrorText(String text) {
  final e = text.toLowerCase();
  if (e.contains('invalid login credentials')) {
    return 'Invalid email or password';
  }
  if (e.contains('already registered') || e.contains('user already') || e.contains('exists')) {
    return 'Email already registered';
  }
  if (e.contains('not authenticated') || e.contains('unauthorized')) {
    return 'You need to sign in';
  }
  if (e.contains('permission denied')) {
    return 'You do not have permission';
  }
  if (e.contains('socket') || e.contains('clientexception') || e.contains('network') ||
      e.contains('failed host lookup') || e.contains('timeout') || e.contains('connection')) {
    return 'Network error. Check your connection.';
  }
  if (e == 'some error occurred' || e == 'some error occurred.') {
    return 'Something went wrong';
  }
  return text;
}

showSnackBar(BuildContext context, String text,
    {SnackBarVariant variant = SnackBarVariant.info}) {
  Color bg;
  IconData icon;
  switch (variant) {
    case SnackBarVariant.success:
      bg = Colors.green.shade600;
      icon = Icons.check_circle;
      break;
    case SnackBarVariant.error:
      bg = Colors.red.shade700;
      icon = Icons.error_outline;
      break;
    case SnackBarVariant.info:
      bg = mobileSearchColor;
      icon = Icons.info_outline;
      break;
  }
  if (variant == SnackBarVariant.error) {
    text = humanizeErrorText(text);
  }
  return ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      duration: const Duration(seconds: 4),
      content: Row(
        children: [
          Icon(icon, color: primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: primaryColor),
            ),
          ),
        ],
      ),
    ),
  );
}
