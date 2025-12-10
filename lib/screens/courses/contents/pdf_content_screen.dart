// lib/screens/course/contents/pdf_content_screen.dart
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfContentScreen extends StatelessWidget {
  final Map<String, dynamic> content;

  const PdfContentScreen({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final url = content['pdf_url']?.toString() ?? content['file_url']?.toString() ?? '';

    if (url.isEmpty) {
      return const Center(
        child: Text("No PDF file found.", style: TextStyle(fontSize: 18)),
      );
    }

    return SfPdfViewer.network(
      url,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      pageLayoutMode: PdfPageLayoutMode.continuous,
    );
  }
}