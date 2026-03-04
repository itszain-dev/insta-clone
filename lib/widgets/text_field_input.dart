import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter/utils/colors.dart';

class TextFieldInput extends StatefulWidget {
  final TextEditingController textEditingController;
  final bool isPass;
  final String hintText;
  final TextInputType textInputType;
  final IconData? prefixIcon;
  final String? labelText;
  final String? Function(String?)? validator;
  const TextFieldInput({
    Key? key,
    required this.textEditingController,
    this.isPass = false,
    required this.hintText,
    required this.textInputType,
    this.prefixIcon,
    this.labelText,
    this.validator,
  }) : super(key: key);

  @override
  State<TextFieldInput> createState() => _TextFieldInputState();
}

class _TextFieldInputState extends State<TextFieldInput> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.isPass;
  }

  @override
  Widget build(BuildContext context) {
    final radius = const BorderRadius.all(Radius.circular(12));
    final inputBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: mobileSearchColor, width: 1),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: blueColor, width: 1.2),
    );

    return TextFormField(
      controller: widget.textEditingController,
      keyboardType: widget.textInputType,
      obscureText: _obscure,
      cursorColor: primaryColor,
      validator: widget.validator,
      style: const TextStyle(color: primaryColor, fontSize: 14),
      autofillHints: _autofillHintsFor(widget.textInputType, widget.isPass),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: const TextStyle(color: secondaryColor),
        labelText: widget.labelText,
        labelStyle: const TextStyle(color: secondaryColor),
        filled: true,
        fillColor: mobileSearchColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: focusedBorder,
        prefixIcon: widget.prefixIcon == null
            ? null
            : Icon(widget.prefixIcon, color: secondaryColor),
        suffixIcon: widget.isPass
            ? IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: secondaryColor,
                ),
                onPressed: () {
                  setState(() {
                    _obscure = !_obscure;
                  });
                },
              )
            : null,
      ),
    );
  }

  Iterable<String>? _autofillHintsFor(TextInputType type, bool isPass) {
    if (isPass) return const [AutofillHints.password];
    if (type == TextInputType.emailAddress) {
      return const [AutofillHints.email, AutofillHints.username];
    }
    return null;
  }
}
