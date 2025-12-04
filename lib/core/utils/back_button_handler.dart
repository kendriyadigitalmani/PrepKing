// lib/core/utils/back_button_handler.dart
import 'package:flutter/material.dart';

mixin BackButtonHandlerMixin<T extends StatefulWidget> on State<T> {
  bool _isHandlingBack = false;

  /// Override this method to handle back button press
  Future<bool> onWillPop() async {
    return true; // Default behavior - allow back
  }

  /// Wrap your scaffold with back button handling
  Widget buildWithBackHandler(Widget child) {
    return WillPopScope(
      onWillPop: () async {
        if (_isHandlingBack) return false;
        _isHandlingBack = true;

        final shouldPop = await onWillPop();

        if (mounted) {
          _isHandlingBack = false;
        }

        return shouldPop;
      },
      child: child,
    );
  }

  /// Show exit confirmation dialog
  Future<bool> showExitConfirmation() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Exit PrepKing?", style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to exit the app?", style: TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Stay", style: TextStyle(fontFamily: 'Poppins', color: Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7)),
            onPressed: () => Navigator.pop(context, true),
            child: Text("Exit", style: TextStyle(fontFamily: 'Poppins', color: Colors.white)),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  /// Show quit quiz confirmation dialog
  Future<bool> showQuitQuizConfirmation() async {
    final shouldQuit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Quit Quiz?", style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to quit without completing the quiz?", style: TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel", style: TextStyle(fontFamily: 'Poppins', color: Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text("Quit", style: TextStyle(fontFamily: 'Poppins', color: Colors.white)),
          ),
        ],
      ),
    );
    return shouldQuit ?? false;
  }
}