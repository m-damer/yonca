// Renders the app's screens to PNG files so they can be put next to the design canvases.
// Run in CI by .github/workflows/screenshots.yml; output goes to $SCREENSHOT_DIR (default build/screens).
// A screen that fails to open is written to errors.txt and the run carries on.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/app_controller.dart';
import 'package:yonca/data/app_database.dart';
import 'package:yonca/domain/activity_models.dart';
import 'package:yonca/domain/contact_models.dart';
import 'package:yonca/domain/deal_models.dart';
import 'package:yonca/domain/schedule_models.dart';
import 'package:yonca/features/activities/activity_card.dart';
import 'package:yonca/features/activities/activity_feed.dart';
import 'package:yonca/features/activities/log_activity_page.dart';
import 'package:yonca/features/activities/outcome_list_page.dart';
import 'package:yonca/features/bell/bell_page.dart';
import 'package:yonca/features/contacts/contact_details_page.dart';
import 'package:yonca/shell/bento_nav_bar.dart';
import 'package:yonca/l10n/app_localizations.dart';
import 'package:yonca/features/contacts/contact_form_page.dart';
import 'package:yonca/features/contacts/tags_page.dart';
import 'package:yonca/features/data/data_page.dart';
import 'package:yonca/features/deals/deal_detail_page.dart';
import 'package:yonca/features/deals/deal_form_page.dart';
import 'package:yonca/features/deals/stages_page.dart';
import 'package:yonca/features/fields/fields_page.dart';
import 'package:yonca/features/importing/duplicates_page.dart';
import 'package:yonca/features/importing/profile_page.dart';
import 'package:yonca/features/reports/reports_page.dart';
import 'package:yonca/features/schedule/meeting_form_page.dart';
import 'package:yonca/features/schedule/schedule_view_pages.dart';
import 'package:yonca/features/schedule/task_form_page.dart';
import 'package:yonca/features/search/search_page.dart';
import 'package:yonca/features/settings/about_page.dart';
import 'package:yonca/features/settings/settings_page.dart';
import 'package:yonca/features/settings/settings_pages.dart';
import 'package:yonca/features/settings/updates_page.dart';
import 'package:yonca/features/sharing/qr_generator_page.dart';
import 'package:yonca/features/stats/stats_page.dart';
import 'package:yonca/features/stats/targets_page.dart';
import 'package:yonca/main.dart';

late Directory out;
final errors = StringBuffer();

Future<void> loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final l = FontLoader(family);
    for (final f in files) {
      l.addFont(File(f).readAsBytes().then((b) => ByteData.view(b.buffer)));
    }
    await l.load();
  }

  const weights = ['400Regular', '500Medium', '700Bold'];
  for (final fam in ['Roboto', 'NotoSansArabic', 'Cairo', 'IBMPlexSansArabic', 'YoncaIndicDigits']) {
    await load(fam, [
      for (final w in weights) 'assets/fonts/${fam}_$w.ttf',
      if (fam == 'IBMPlexSansArabic') 'assets/fonts/IBMPlexSansArabic_600SemiBold.ttf',
    ]);
  }
  await load('IBMPlexSans', [for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) 'assets/fonts/IBMPlexSans_$w.ttf']);
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) await load('MaterialIcons', [icons.path]);
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUpAll(() async {
    out = Directory(Platform.environment['SCREENSHOT_DIR'] ?? 'build/screens')..createSync(recursive: true);
    await loadFonts();
  });
  tearDownAll(() => File('${out.path}/errors.txt').writeAsStringSync(errors.toString()));

  final key = GlobalKey();

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 3; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await t.pump(const Duration(milliseconds: 250));
    }
  }


  /// Writes every text and filled box on screen (logical pixels) so the app can be compared with the canvas by numbers.
  void dumpGeometry(WidgetTester t, String name) {
    final root = t.renderObject<RenderRepaintBoundary>(find.byKey(key));
    final texts = <Map<String, Object?>>[];
    final boxes = <Map<String, Object?>>[];
    String hex(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}';
    void visit(RenderObject r) {
      if (r is RenderOffstage && r.offstage) return;
      if (r is RenderIndexedStack) {
        final i = r.index;
        if (i != null) {
          var k = 0;
          r.visitChildren((c) {
            if (k++ == i) visit(c);
          });
        }
        return;
      }
      if (r is RenderParagraph) {
        final o = r.localToGlobal(Offset.zero);
        final span = r.text;
        final st = span.style;
        if (r.size.height > 0 && span.toPlainText().trim().isNotEmpty) {
          texts.add({
            't': span.toPlainText(),
            'x': o.dx, 'y': o.dy, 'w': r.size.width, 'h': r.size.height,
            'fs': st?.fontSize, 'fw': st?.fontWeight?.value, 'c': st?.color == null ? null : hex(st!.color!),
          });
        }
      } else if (r is RenderDecoratedBox) {
        final o = r.localToGlobal(Offset.zero);
        final d = r.decoration;
        if (d is BoxDecoration && r.size.height > 0 && (d.color != null || d.border != null)) {
          final br = d.borderRadius;
          boxes.add({
            'x': o.dx, 'y': o.dy, 'w': r.size.width, 'h': r.size.height,
            'bg': d.color == null ? null : hex(d.color!),
            'r': br is BorderRadius ? br.topLeft.x : null,
            'bw': d.border is Border ? (d.border as Border).top.width : null,
            'bc': d.border is Border ? hex((d.border as Border).top.color) : null,
          });
        }
      }
      r.visitChildren(visit);
    }
    visit(root);
    File('${out.path}/$name.json').writeAsStringSync(jsonEncode({'texts': texts, 'boxes': boxes}));
  }

  Future<void> shot(WidgetTester t, String name) async {
    await settle(t);
    final ex = t.takeException();
    if (ex != null) errors.writeln('OVERFLOW/EXCEPTION on $name: ${ex.toString().split('\n').first}\n');
    try {
      dumpGeometry(t, name);
    } catch (e) {
      errors.writeln('dump $name: $e');
    }
    final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(key));
    await t.runAsync(() async {
      final img = await boundary.toImage(pixelRatio: 2);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      await File('${out.path}/$name.png').writeAsBytes(data!.buffer.asUint8List());
    });
  }

  NavigatorState nav(WidgetTester t) => t.state<NavigatorState>(find.byType(Navigator).first);

  /// Opens [builder] on top of the app, takes the picture, goes back.
  Future<void> page(WidgetTester t, String prefix, String name, WidgetBuilder builder) async {
    // ignore: avoid_print
    print('screen $prefix $name');
    try {
      nav(t).push(MaterialPageRoute<void>(builder: builder));
      await t.pump(const Duration(milliseconds: 400));
      await shot(t, '${prefix}_$name');
    } catch (e, s) {
      errors.writeln('$prefix $name: $e\n$s\n');
    } finally {
      try {
        t.takeException();
        nav(t).pop();
        await t.pump(const Duration(milliseconds: 400));
      } catch (_) {}
    }
  }

  Future<void> step(WidgetTester t, String label, Future<void> Function() body) async {
    // ignore: avoid_print
    print('step $label');
    try {
      await body();
    } catch (e, s) {
      errors.writeln('$label: $e\n$s\n');
    }
    t.takeException();
  }

  Future<AppController> seeded(WidgetTester t, {required bool dark, required bool ar, int accent = 0}) async {
    final db = AppDatabase(NativeDatabase.memory());
    final c = AppController(database: db, onboarded: true);
    await t.runAsync(() async {
      final now = DateTime.now();
      final ids = <int>[];
      Future<int> person(String f, String l, String co, Rating r, List<Role> roles, String phone, {String nick = ''}) => c.contacts!.save(ContactInput(
          firstName: f,
          lastName: l,
          company: co,
          nickname: nick,
          rating: r,
          roles: roles,
          jobTitle: 'Procurement manager',
          phones: [PhoneInput(number: phone, isWhatsApp: true)]));
      // The same people as in the design canvas, so the lists can be compared line by line.
      final specs = <Future<int> Function()>[
        () => person('Ahmad', 'Khoury', 'Al-Noor Trading', Rating.hot, [Role.client], '944123456', nick: 'Abu Omar'),
        () => person('Lina', 'Haddad', 'Haddad Electric', Rating.warm, [Role.lead], '933222111'),
        () => person('Omar', 'Saleh', 'Saleh Contracting', Rating.cold, [Role.client, Role.supplier], '955333444'),
        () => person('', '', '', Rating.none, [Role.lead], '911123456'),
        () => person('Khaled', 'Aziz', 'Aziz Group', Rating.hot, [Role.supplier], '966777888'),
        () => person('Rana', 'Mansour', 'Mansour Pharmacy', Rating.warm, [Role.client], '988111222', nick: 'Um Sami'),
        () => person('Samer', 'Darwish', 'Darwish Solar', Rating.none, [Role.lead], '988333444'),
        () => person('Hala', 'Mounir', 'Mounir Supplies', Rating.none, [Role.supplier], '977444555'),
      ];
      ids.addAll(List.filled(specs.length, 0));
      for (var i = specs.length - 1; i >= 0; i--) {
        ids[i] = await specs[i]();
      }
      await c.database!.putSetting('profile.name', 'Mahmoud');
      final outcome = (await c.activities!.outcomes()).first;
      await c.activities!.save(ActivityInput(
          type: ActivityType.call, contactId: ids[0], occurredAt: now.subtract(const Duration(hours: 5)), direction: 'outgoing', durationMinutes: 6, outcomeId: outcome.id));
      await c.activities!.save(ActivityInput(
          type: ActivityType.visit, contactId: ids[1], occurredAt: now.subtract(const Duration(days: 2)), place: 'Aleppo workshop', outcomeId: outcome.id));
      await c.activities!.save(ActivityInput(
          type: ActivityType.message, contactId: ids[2], occurredAt: now.subtract(const Duration(days: 34)), channel: 'whatsapp'));
      await c.activities!.save(ActivityInput(
          type: ActivityType.message, contactId: ids[4], occurredAt: now.subtract(const Duration(days: 9)), channel: 'whatsapp'));
      await c.activities!.save(ActivityInput(
          type: ActivityType.message, contactId: ids[5], occurredAt: now.subtract(const Duration(days: 16)), channel: 'whatsapp'));
      await c.activities!.save(ActivityInput(
          type: ActivityType.note, contactId: ids[0], occurredAt: now.subtract(const Duration(days: 1)), title: 'Wants a price list', description: 'Send before Thursday.'));
      DateTime at(int days, int h, int m) => DateTime(now.year, now.month, now.day + days, h, m);
      await c.schedule!.saveTask(TaskInput(title: 'Send price offer', contactId: ids[0], dueAt: at(-1, 16, 0), hasTime: true));
      await c.schedule!.saveTask(TaskInput(title: 'Call back about samples', contactId: ids[1], dueAt: at(-3, 11, 0), hasTime: true));
      await c.schedule!.saveTask(TaskInput(title: 'Confirm delivery date', contactId: ids[1], dueAt: at(0, 14, 0), hasTime: true));
      await c.schedule!.saveTask(TaskInput(title: 'Send contract draft', contactId: ids[4], dueAt: at(2, 12, 0), hasTime: true));
      await c.schedule!.saveMeeting(MeetingInput(title: 'Visit Al-Noor Trading', contactIds: [ids[0]], startAt: at(0, 0, 1), place: 'Al-Noor Trading'));
      await c.schedule!.saveTask(TaskInput(title: 'Supplier call', contactId: ids[7], dueAt: at(4, 11, 0), hasTime: true));
      await c.schedule!.saveMeeting(MeetingInput(title: 'Meeting at the warehouse', contactIds: [ids[2], ids[4]], startAt: at(0, 10, 30), place: 'Warehouse'));
      await c.schedule!.saveMeeting(MeetingInput(title: 'Visit Al-Noor Trading', contactIds: [ids[0]], startAt: at(1, 9, 0), place: 'Al-Noor Trading'));
      final stages = await c.deals!.openStages();
      DateTime day(int d) => DateTime(now.year, now.month, d);
      await c.deals!.saveDeal(DealInput(title: 'UPS 20 kVA', contactId: ids[0], amount: 12500, stageId: stages[2].id, expectedClose: DateTime(now.year, now.month + 1, 30)));
      await c.deals!.saveDeal(DealInput(title: 'Solar 5 kW', contactId: ids[6], amount: 4800, stageId: stages[2].id, expectedClose: now.subtract(const Duration(days: 12))));
      await c.deals!.saveDeal(DealInput(title: 'Generator 60 kVA', contactId: ids[2], amount: 85000000, currency: 'SYP', stageId: stages[2].id, expectedClose: DateTime(now.year, now.month + 1, 10)));
      await c.deals!.saveDeal(DealInput(title: 'Battery bank', contactId: ids[4], stageId: stages[2].id));
      await c.deals!.saveDeal(DealInput(title: 'Steel order', contactId: ids[1], amount: 4800, stageId: stages[0].id));
      await c.deals!.saveDeal(DealInput(title: 'UPS 10 kVA', contactId: ids[1], amount: 7200, stageId: stages[3].id, expectedClose: DateTime(now.year, now.month + 1, 5)));
      for (final w in [('UPS 20 kVA', 0, 12000.0, 14), ('Solar 3 kW', 1, 2900.0, 8), ('Battery bank', 4, 1150.0, 2)]) {
        final id = await c.deals!.saveDeal(DealInput(title: w.$1, contactId: ids[w.$2], amount: w.$3, stageId: stages[3].id));
        await c.deals!.winDeal(id, date: day(w.$4));
      }
    });
    await c.setAccent(accent);
    await c.setThemeMode(dark ? ThemeMode.dark : ThemeMode.light);
    await c.setLocale(Locale(ar ? 'ar' : 'en'));
    return c;
  }

  Future<void> start(WidgetTester t, AppController c) async {
    t.view.physicalSize = const Size(780, 1688);
    t.view.devicePixelRatio = 2.0;
    t.view.padding = const FakeViewPadding(top: 88); // 44dp status bar, like the canvas
    t.view.viewPadding = const FakeViewPadding(top: 88);
    addTearDown(t.view.reset);
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
    t.platformDispatcher.alwaysUse24HourFormatTestValue = true;
    addTearDown(t.platformDispatcher.clearAllTestValues);
    await t.pumpWidget(RepaintBoundary(key: key, child: YoncaApp(controller: c)));
    await settle(t);
  }

  Future<void> tab(WidgetTester t, String prefix, String name, int index) async {
    await step(t, '$prefix tab $name', () async {
      // Bento bar buttons are the last five tappable labels at the bottom.
      final bar = find.byType(NavigationBar);
      if (bar.evaluate().isNotEmpty) {
        await t.tap(find.descendant(of: bar, matching: find.byType(InkResponse)).at(index));
      } else {
        final size = t.view.physicalSize / t.view.devicePixelRatio;
        final w = size.width / 5;
        final x = ar(t) ? size.width - w * (index + .5) : w * (index + .5);
        await t.tapAt(Offset(x, size.height - 40));
      }
      await t.pump(const Duration(milliseconds: 400));
      await shot(t, '${prefix}_tab_$name');
    });
  }

  final matrix = <(String, bool, bool, int)>[
    ('light_en', false, false, 0),
    ('light_ar', false, true, 0),
    ('dark_en', true, false, 0),
    ('dark_ar', true, true, 0),
  ];

  for (final m in matrix) {
    final (prefix, dark, isAr, accent) = m;
    AppController? c0;
    testWidgets('screens $prefix', timeout: const Timeout(Duration(minutes: 6)), (t) async {
     try {
      final c = await seeded(t, dark: dark, ar: isAr, accent: accent);
      c0 = c;
      await start(t, c);
      final contacts = c.contacts!;
      final cid = (await t.runAsync(() => contacts.list()))!.firstWhere((x) => x.contact.firstName == 'Ahmad').contact.id;
      final deals = (await t.runAsync(() => c.deals!.listDeals()))!;
      final dealId = deals.isEmpty ? null : deals.first.deal.id;

      await shot(t, '${prefix}_tab_home');
      t.view.physicalSize = const Size(780, 3800);
      await t.pump(const Duration(milliseconds: 400));
      await shot(t, '${prefix}_tab_home_full');
      t.view.physicalSize = const Size(780, 1688);
      await t.pump(const Duration(milliseconds: 400));
      await tab(t, prefix, 'contacts', 1);
      await tab(t, prefix, 'calendar', 2);
      await tab(t, prefix, 'deals', 3);
      await tab(t, prefix, 'more', 4);
      await tab(t, prefix, 'home', 0);

      if (accent != 0) return; // colour runs only need the main tabs
      await step(t, 'quick add', () async {
        await t.tap(find.byType(FloatingActionButton));
        await t.pump(const Duration(milliseconds: 500));
        await shot(t, '${prefix}_sheet_new_contact');
        nav(t).pop();
        await t.pump(const Duration(milliseconds: 400));
      });
      await page(t, prefix, 'contact_details', (_) => ContactDetailsPage(repo: contacts, id: cid, activities: c.activities, schedule: c.schedule, deals: c.deals, fields: c.fields, navBar: (ctx) {
        final l = AppLocalizations.of(ctx);
        return BentoNavBar(destinations: [
          BentoDestination(Icons.home_outlined, Icons.home, l.navHome),
          BentoDestination(Icons.people_outline, Icons.people, l.navContacts),
          BentoDestination(Icons.calendar_month_outlined, Icons.calendar_month, l.navCalendar),
          BentoDestination(Icons.paid_outlined, Icons.paid, l.navDeals),
          BentoDestination(Icons.more_vert, Icons.more_vert, l.navMore),
        ], selectedIndex: 1, onSelected: (_) {});
      }));
      await page(t, prefix, 'contact_form', (_) => ContactFormPage(repo: contacts));
      await page(t, prefix, 'bell', (_) => BellPage(controller: c));
      await page(t, prefix, 'search', (_) => SearchPage(controller: c));
      await page(t, prefix, 'settings', (_) => SettingsPage(controller: c));
      await page(t, prefix, 'set_appearance', (_) => AppearancePage(controller: c));
      await page(t, prefix, 'set_language', (_) => LanguagePage(controller: c));
      await page(t, prefix, 'set_notifications', (_) => NotificationsSettingsPage(controller: c));
      await page(t, prefix, 'set_inactivity', (_) => InactivityPage(controller: c));
      await page(t, prefix, 'set_deals', (_) => DealsSettingsPage(controller: c));
      await page(t, prefix, 'set_home', (_) => HomeSettingsPage(controller: c));
      await page(t, prefix, 'about', (_) => AboutPage(controller: c));
      await page(t, prefix, 'updates', (_) => UpdatesPage(controller: c));
      await page(t, prefix, 'data', (_) => DataPage(controller: c));
      await page(t, prefix, 'stats', (_) => StatsPage(controller: c));
      await page(t, prefix, 'targets', (_) => TargetsPage(stats: c.stats!));
      await page(t, prefix, 'reports', (_) => ReportsPage(controller: c));
      await page(t, prefix, 'stages', (_) => StagesPage(deals: c.deals!));
      await page(t, prefix, 'fields', (_) => FieldsPage(fields: c.fields!));
      await page(t, prefix, 'outcomes', (_) => OutcomeListPage(activities: c.activities!));
      await page(t, prefix, 'duplicates', (_) => DuplicatesPage(repo: contacts));
      await page(t, prefix, 'profile', (_) => ProfilePage(db: c.database!));
      await page(t, prefix, 'timeline', (_) => TimelinePage(activities: c.activities!, contacts: contacts, schedule: c.schedule));
      await page(t, prefix, 'tags', (_) => TagsPage(repo: contacts));
      await page(t, prefix, 'qr_generator', (_) => QrGeneratorPage(repo: contacts));
      await page(t, prefix, 'task_view', (_) => TaskViewPage(schedule: c.schedule!, contacts: contacts, id: 1));
      await page(t, prefix, 'meeting_view', (_) => MeetingViewPage(schedule: c.schedule!, contacts: contacts, id: 1));
      final act = await t.runAsync(() => c.activities!.get(4));
      if (act != null) await page(t, prefix, 'activity_view', (_) => ActivityViewPage(item: act, activities: c.activities!, contacts: contacts));
      await page(t, prefix, 'log_visit', (_) => LogActivityPage(activities: c.activities!, contacts: contacts, contactId: cid, initialType: ActivityType.visit));
      await page(t, prefix, 'log_call', (_) => LogActivityPage(activities: c.activities!, contacts: contacts, contactId: cid, schedule: c.schedule));
      await page(t, prefix, 'log_note', (_) => LogActivityPage(activities: c.activities!, contacts: contacts, initialType: ActivityType.note));
      await page(t, prefix, 'task_form', (_) => TaskFormPage(schedule: c.schedule!, contacts: contacts));
      await page(t, prefix, 'meeting_form', (_) => MeetingFormPage(schedule: c.schedule!, contacts: contacts));
      await page(t, prefix, 'deal_form', (_) => DealFormPage(deals: c.deals!, contacts: contacts));
      if (dealId != null) {
        await page(t, prefix, 'deal_detail', (_) => DealDetailPage(deals: c.deals!, contacts: contacts, id: dealId, fields: c.fields));
      }
     } catch (e, st) {
       errors.writeln('TEST $prefix FAILED: $e\n$st\n');
     } finally {
       // Tear down inside the test: unmount, let timers run out, then close the database for real.
       try {
         await t.pumpWidget(const SizedBox());
         await t.pump(const Duration(seconds: 1));
         await t.runAsync(() => c0?.database?.close() ?? Future<void>.value());
       } catch (_) {}
     }
    });
  }

  for (final m in [('light_en', false, false), ('dark_ar', true, true)]) {
    final (prefix, dark, isAr) = m;
    testWidgets('onboarding $prefix', timeout: const Timeout(Duration(minutes: 2)), (t) async {
      final db = AppDatabase(NativeDatabase.memory());
      final c = AppController(database: db, onboarded: false);
      await c.setAccent(0);
      await c.setThemeMode(dark ? ThemeMode.dark : ThemeMode.light);
      await c.setLocale(Locale(isAr ? 'ar' : 'en'));
      await start(t, c);
      for (var i = 0; i < 6; i++) {
        await step(t, 'onboarding $i', () async {
          await shot(t, '${prefix}_onb_$i');
          final next = find.byType(FilledButton);
          if (next.evaluate().isNotEmpty) {
            await t.tap(next.first);
            await t.pump(const Duration(milliseconds: 400));
          }
        });
      }
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
      await t.runAsync(db.close);
    });
  }
}

bool ar(WidgetTester t) => Directionality.of(t.element(find.byType(Scaffold).first)) == TextDirection.rtl;
