import 'dart:io';
import 'dart:ui' as ui;

import 'package:pdfx/pdfx.dart';

import 'crash_log.dart';
import 'timeline_builder.dart';

/// Width the pictures are drawn at, in pixels (twice what the report shows, so they stay sharp on paper).
const int timelinePictureWidth = 640;

/// At most this many pictures go into one report; the rest are listed by name.
const int timelineMaxPictures = 100;

/// Draws every photo and the first page of every PDF in the timelines into [TlFile.png].
Future<void> loadTimelinePreviews(List<ContactTimeline> timelines, {int max = timelineMaxPictures}) async {
  var n = 0;
  for (final t in timelines) {
    for (final e in t.entries) {
      for (final f in e.files) {
        if (n >= max) return;
        if (!f.isImage && !f.isPdf) continue;
        try {
          if (!File(f.path).existsSync()) continue;
          if (f.isPdf) {
            await _pdfFirstPage(f);
          } else {
            await _photo(f);
          }
          if (f.png != null) n++;
        } catch (err, st) {
          CrashLog.instance?.record('Timeline preview failed for ${f.name}: $err', st);
        }
      }
    }
  }
}

Future<void> _photo(TlFile f) async {
  final bytes = await File(f.path).readAsBytes();
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final desc = await ui.ImageDescriptor.encoded(buffer);
  final codec = await desc.instantiateCodec(targetWidth: desc.width > timelinePictureWidth ? timelinePictureWidth : null);
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  frame.image.dispose();
  codec.dispose();
  desc.dispose();
  buffer.dispose();
  if (data != null) f.png = data.buffer.asUint8List();
}

Future<void> _pdfFirstPage(TlFile f) async {
  final doc = await PdfDocument.openFile(f.path);
  try {
    f.pages = doc.pagesCount;
    final page = await doc.getPage(1);
    try {
      final w = timelinePictureWidth.toDouble();
      final img = await page.render(width: w, height: w * page.height / page.width, format: PdfPageImageFormat.png, backgroundColor: '#FFFFFF');
      f.png = img?.bytes;
    } finally {
      await page.close();
    }
  } finally {
    await doc.close();
  }
}
