import 'package:flutter/material.dart';

class Validators {
  static final _emailRegex = RegExp(r'^[\w\.\-\+]+@[\w\-]+\.[\w\-\.]+$');

  static String? username(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Username is required';
    if (v.length < 3) return 'Username must be at least 3 characters';
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? Function(String?) confirmPassword(TextEditingController passwordController) {
    return (value) {
      final v = value ?? '';
      if (v.isEmpty) return 'Please confirm your password';
      if (v != passwordController.text) return 'Passwords do not match';
      return null;
    };
  }
}