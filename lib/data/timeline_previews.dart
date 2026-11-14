import 'dart:io';
import 'dart:ui' as ui;

import 'package:pdfx/pdfx.dart';

import 'crash_log.dart';
import 'timeline_builder.dart';

/// Width the pictures are drawn at, in pixels: an A4 page at about 170 dpi, so small print stays readable.
const int timelinePictureWidth = 1400;

/// Photos are saved as PNG (the phone cannot make JPEG), which is big, so they are drawn a little smaller.
const int timelinePhotoWidth = 1100;

/// At most this many pictures and PDF pages go into one report; the rest are counted and left out.
const int timelineMaxPictures = 150;

/// Draws every photo, and every page of every PDF, in the timelines into [TlFile.pictures].
Future<void> loadTimelinePictures(List<ContactTimeline> timelines, {int max = timelineMaxPictures}) async {
  var n = 0;
  for (final t in timelines) {
    for (final e in t.entries) {
      for (final f in e.files) {
        if (!f.isPicture && !f.isPdf) continue;
        try {
          if (!File(f.path).existsSync()) continue;
          if (f.isPdf) {
            n += await _pdfPages(f, max - n);
          } else if (n < max) {
            await _photo(f);
            n += f.pictures.length;
          }
        } catch (err, st) {
          CrashLog.instance?.record('Timeline picture failed for ${f.name}: $err', st);
        }
      }
    }
  }
}

Future<void> _photo(TlFile f) async {
  final bytes = await File(f.path).readAsBytes();
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final desc = await ui.ImageDescriptor.encoded(buffer);
  final codec = await desc.instantiateCodec(targetWidth: desc.width > timelinePhotoWidth ? timelinePhotoWidth : null);
  final frame = await codec.getNextFrame();
  final img = frame.image;
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  final w = img.width;
  final h = img.height;
  img.dispose();
  codec.dispose();
  desc.dispose();
  buffer.dispose();
  if (data != null) f.pictures.add(TlPicture(data.buffer.asUint8List(), w, h));
}

/// Every page as a JPEG; returns how many pages were added (pages past [room] are counted in [TlFile.skipped]).
Future<int> _pdfPages(TlFile f, int room) async {
  final doc = await PdfDocument.openFile(f.path);
  try {
    f.pages = doc.pagesCount;
    var added = 0;
    for (var i = 1; i <= doc.pagesCount; i++) {
      if (added >= room) {
        f.skipped = doc.pagesCount - added;
        break;
      }
      final page = await doc.getPage(i);
      try {
        final w = timelinePictureWidth.toDouble();
        final h = (w * page.height / page.width).roundToDouble();
        final img = await page.render(width: w, height: h, format: PdfPageImageFormat.jpeg, quality: 80, backgroundColor: '#FFFFFF');
        if (img != null) {
          f.pictures.add(TlPicture(img.bytes, w.round(), h.round()));
          added++;
        }
      } finally {
        await page.close();
      }
    }
    return added;
  } finally {
    await doc.close();
  }
}
