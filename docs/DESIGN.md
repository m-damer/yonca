# YONCA — Design Specification

Version 0.1 · 2026-10-26 · Designer: Mahmoud Damer · Audience: the AI coding assistant that builds the app.

**Status:** design draft. Mahmoud will confirm the screen designs first. Coding starts only after he confirms them.

**How to read this file.** Everything marked "decided" was decided by Mahmoud during the design interview. Do not change a decided item without asking him. Where this file says "recommended" it is a build suggestion that Mahmoud has not seen in detail. Sizes are in dp (layout) or sp (text) unless stated. "Start" and "end" mean left and right in English and right and left in Arabic.

---

## 0. Visual language v2 (current, decided 26 Oct 2026)

This section replaces the warm Material look described later in this file. Where it conflicts with anything below, this section wins.

- **Style ("Four Leaves", chosen 26 Oct 2026):** flat and solid, no glass or blur. A forest-green header band holds the title, search and top actions; content sits on solid white cards (radius 16, hairline border) on a pale green page. Fields and icon buttons have radius 14. Mint is the accent (floating Add button, active chip, Save on the header, nav pill).
- **Colour:** the four logo greens by role: forest `#226B36`/header `#17562B`, jade `#2F8A7A`, teal `#0D8A78`, mint `#8DE5C0`. Avatars rotate through the four; the pipeline bar uses them as four steps. Primary (buttons, active chips) is forest `#17562B` in light and mint `#A8F0D0` in dark; page `#F1F7F2` / `#0C1713`. Hot, warm and cold stay red, amber and blue so green is never a status colour. Text sits on dark ink or light tints; white appears only on large avatar initials. Values are in `lib/theme/palette.dart`; the explorations are in the YONCA Visual Directions canvas (row E).
- **Navigation:** Bento-style bottom bar (Home, Contacts, Calendar, Deals, More) with a pill behind the active item, and an extended "Add" button above it.
- **Modes:** light and dark, both fully drawn. Dark is a token swap, not a redesign: same layout, same icons, same copy. Pastel tags keep dark text; in dark mode the three darker logo petals are brightened (splash and app-icon boards keep the original colours).
- **RTL:** every screen exists in English (left to right) and Arabic (right to left, mirrored, with Arabic copy). Direction arrows and chevrons flip; numbers, phone numbers and codes stay left to right.
- **Canvases:** the design lives in four canvases: Light Part 1, Light Part 2, Dark Part 1, Dark Part 2. A frame has the same position in the light and dark canvas.
- **Wording:** all copy follows the G-tables in this file. Empty states use the G6 strings exactly.
- **Calendar conventions (checked 26 Oct 2026):** the week starts on Saturday in Arabic and Sunday in English (a setting). Dots differ by type: task round, meeting square, event diamond. A temporary-note contact shows a small orange dot on the avatar corner. Type chips (Tasks, Meetings, Events, Done) fit on one line at 390 px in both languages; the Arabic week view also starts on Saturday.
- **Dialogs:** a dialog with three actions puts the primary action full width on top and the two secondary actions side by side below it (the crash report dialog).
- **Dark checks:** every dark frame passes an automated contrast scan (text at least 3:1, disabled controls exempt). Document previews stay white with dark text in both modes.
- **Frame IDs:** each frame has a unique ID per flow (OA onboarding Arabic, HA home Arabic, AB About, CD contact details). English and Arabic twins share a number only when one is the mirror of the other, and the Arabic title ends with "(Arabic)".

## A. Design brief

### A1. Purpose
YONCA is a personal CRM for one salesperson. It keeps every client, lead and supplier in one place with their full history (calls, visits, messages, notes, tasks, meetings, deals, files), reminds the user of what is due, and produces a client report for the user's manager. It works fully offline on the phone.

"YONCA" (Arabic: يونجا) means clover. The logo is a four-leaf green mark (see E, `color.logo`).

### A2. User
- One user, a salesperson. Not a team. The manager sees only exported reports (PDF or CSV).
- Contacts: unlimited. Mostly leads and clients, some suppliers.
- Contact channels: WhatsApp first, then phone calls and visits in person.
- Languages: English and Arabic. Arabic (RTL) is a first-class language.
- Location: Syria. Google Play is not available there. Google Drive works.

### A3. Success
After one month of use: the user is always in control and never misses anything about a client or supplier. A client is found in under 5 seconds.

### A4. Principles
1. **Never miss anything.** Reminders, overdue blocks, alarms and the bell are core, not extras.
2. **Fast lookup, fast entry.** Quick add has three fields. Search finds everything.
3. **Complete history.** Every client has one timeline with everything that happened and everything coming.
4. **Offline first.** All data lives on the phone. Only backup and updates use the internet.
5. **Arabic first-class.** Layouts mirror, search and sorting understand Arabic, plurals are correct.
6. **Colour is never the only signal.** Pair colour with an icon or a word.
7. **No hidden gestures.** Every swipe has a button alternative.
8. **Read-only sheets, edit on the item's own screen.** A bottom sheet shows details and one link button that opens the item's own screen, where Edit and Delete live.
9. **One token file.** Colours, type, shape, spacing and elevation live in one place so the look can change later.
10. **Plain words.** Short, clear sentences in both languages.

### A5. Scope of v1 (decided)
All features below ship in v1. Build order is in section B.

- Contacts: photo with crop, first and last name, nickname, company, job title, several phones, emails, addresses (with labels and a map link), websites, events, roles (Lead, Client, Supplier, several allowed), rating (Hot, Warm, Cold), tags with colours, requirements, current status (automatic with manual override), custom fields, temporary note.
- Buttons per contact: WhatsApp, Call, Email, Map, plus Share (QR or vCard).
- Activities: Call, Visit, Message (WhatsApp or Email), Note (title, text, voice). Outcome = fixed editable title + free description. Files and photos on any activity.
- Tasks (priority, repeat, reminder, alarm), Meetings (several contacts, repeat, type, alarm), Events (title, date, yearly repeat, alert), Calendar (month, week, agenda).
- Deals and pipeline with editable stages (Won and Lost fixed), stage colours, documents (invoice or proposal records), custom deal fields, several currencies (never converted).
- Home with sections, quick actions, recent contacts, needs attention, pipeline snapshot, customize Home.
- Global timeline, global search, notification bell with six tabs.
- Reports (PDF, CSV), Stats, Targets with history.
- QR generator (three sources), QR scanner, My profile with share.
- Import from phone book, duplicate detection and merge, multi-select with bulk share and bulk edit.
- Backup (Google Drive and file), restore, export, delete everything.
- Themes: follow phone (dynamic colour), choose my colour, light/dark/follow phone, high contrast. Arabic font choice. Arabic month names choice. Digit choice.
- Update system through GitHub Releases. Crash report by email (user's choice to send).
- Android shortcuts, notification buttons, "Log this call?" bar, home-screen widgets (last milestone).

### A6. Not doing (decided)
Invoice or proposal creation (they are made outside the app and only recorded) · app PIN lock · email inbox sync · phone dialer · web forms · workflow automation · third-party integrations · team roles and team workspace (maybe much later) · currency conversion · analytics · Hijri calendar · subtasks · two-way phone-book sync · custom snooze length · illustrations (icons only) · compact density mode · 200% text scaling (design and test up to about 130%) · writing meetings to the phone's calendar · GPS check-in · flash or visual cue on the alarm · long-term merge undo · export history · login and Firebase sync (later) · iPhone (later).

### A7. Technical direction (decided unless marked)
- Flutter, Android first. Material 3. Token-based theme.
- Local database on the phone (recommended: SQLite through a Flutter package such as `drift`). Photos, voice notes and files stored on the phone.
- English and Arabic through ICU message files. Arabic plural rules for every counted message.
- Fonts bundled in the app: Roboto; Noto Sans Arabic (default), Cairo, IBM Plex Sans Arabic.
- Notifications, exact alarms and full-screen alerts through native Android APIs.
- Backup to a private app folder in Google Drive, plus a backup file.
- Distribution: signed APK on GitHub Releases (see section D, flow 17).
- Minimum Android version: recommended Android 8.0 (API 26). Dynamic colour needs Android 12.

---

## B. Feature list, priorities and build order

All features are v1. "Order" is the build order. Each milestone must produce something Mahmoud can install and test.

| # | Milestone | Contains |
|---|-----------|----------|
| M0 | Foundations | Project, tokens and theme (fallback palette, light/dark), localization with Arabic and RTL, local database, navigation shell (5 tabs), shared states (empty, loading, error, offline, permission), release signing key created and backed up, an early test of exact alarms and full-screen alerts on a real phone |
| M1 | Contacts core | Quick add, full form, contacts list (rating tabs, sort, alphabet scroller, filters), contact details (header, action row, tabs shell, Details tab), tags, roles, rating, duplicate-phone warning, search on the Contacts tab |
| M2 | Activities and history | Log activity (Call, Visit, Message, Note with voice), outcome list, files and previews, activity cards and detail sheet, contact Timeline and Files tabs, global Timeline, follow-up prompt |
| M3 | Tasks, meetings, events | Task, Meeting (several contacts), Event, Schedule tab, Calendar, reminders, full-screen alarm, quiet hours, temporary-note reminder, Bell (six tabs), upcoming block |
| M4 | Deals | Deal form, stages (colour, edit), pipeline pages, documents, Won and Lost flows, currencies and custom currencies |
| M5 | Home and search | Home sections, quick actions, recent contacts, needs attention, pipeline snapshot, customize Home, global search |
| M6 | Reports and fields | Custom fields (contact and deal) with filters, Reports flow (PDF and CSV, presets), Outcome list screen |
| M7 | Stats and targets | Stats screen, targets, target history, Home summary card |
| M8 | Import, QR, merge | Import from phone book, duplicates and merge, multi-select with bulk share and bulk edit, Share sheet (QR and vCard), QR generator, QR scanner, My profile |
| M9 | Data | Backup and data screen, Google Drive backup, backup file, restore, CSV and vCard export, delete everything, storage use |
| M10 | Look and first run | Onboarding, theme colour picker, high contrast, Arabic font and month-name choice, digits, Settings (all groups and search), About, About the developer, crash report prompt |
| M11 | Updates | In-app update check, Updates screen, release workflow on GitHub |
| M12 | Shortcuts | App icon shortcuts, notification buttons (Done, Snooze), "Log this call?" bar |
| M13 | Widgets | Home-screen widgets (Today list, Quick add, Search). Native Android code. Last. |

**M2 build notes (27 Oct 2026):** built — Log activity (Call, Visit, Message, Note with voice recorder and player, files and photos), outcome chips with the four default outcomes, an Outcome list screen (More tab; pulled forward from M6 because the chips need it), activity cards, the read-only detail sheet (its Open button goes to the edit screen with Delete), the contact Timeline and Files tabs, and the global Timeline (More tab, type filters). **Not in M2:** the "Set a follow-up task?" prompt (needs tasks, arrives with M3), the pinned Upcoming block on the global Timeline (M3), the filter sheet with contact picker and date range, "Jump to date", the single-line entries for task done / stage changed / rating changed, and deleting a voice file when a whole contact is deleted.

**Dependencies and cautions**
- The alarm test in M0 matters. Some phone brands block background alarms and full-screen alerts. Find out early.
- Milestones M1 to M4 should keep the database schema flexible: custom fields, stages, outcomes and currencies are user-defined data, not code.
- A task, meeting or event is stored once and can appear in several places (Calendar, Timeline, Schedule tab, Bell). Never copy it.

### Feature priorities (all v1; order of risk and value)
- **Core (M1 to M5):** contacts, activities, tasks, meetings, events, calendar, deals, Home, search, bell, alarms.
- **Manager output (M6, M7):** reports, stats, targets.
- **Safety and sharing (M8, M9):** import, merge, QR, backup, restore.
- **Polish and delivery (M10 to M13):** onboarding, themes, About, updates, shortcuts, widgets.


---

## C. Screen inventory

**Navigation (decided).** Bottom bar with 5 tabs: **Home, Contacts, Calendar, Deals, More**. The app always opens on Home. The Add button on contact screens is an extended FAB at the bottom end (right in English, left in Arabic).

**Shared states.** Every screen below uses these where they apply. One pattern: an icon, one sentence, one button.
- **Empty (first time):** says what belongs here and offers the main action.
- **Empty (filtered):** "No results" with "Clear filters".
- **Loading:** skeleton placeholders for lists. A progress bar with text only for Reports, Import, Backup and Restore.
- **Error:** plain words, "Try again", and a "Copy details" link. No error codes shown.
- **Offline:** only Drive backup, restore from Drive and Google sign-in. Banner: "No internet. Your data is safe on this phone." Nothing else shows an offline message.
- **Permission denied:** which permission, why, and "Open phone settings". The feature stays usable without it where possible.

Format below: **ID name** — what it contains. *States:* special states for that screen.

### C1. First run

**S01 Onboarding** — at most 5 short screens, each skippable, with a Back button. Order: (1) Language, (2) Digits and Arabic month names (shown only in Arabic; one screen called "Numbers and dates"), (3) Default currency, (4) Theme, (5) optional My profile (name, company, phone), then optional "Import contacts now?" (default "Later"), and a final "Allow reminders" step. Other permissions are asked the first time a feature needs them, with one plain sentence. No feature tour. *States:* permission denied on reminders (explain, continue anyway).

### C2. Home tab

**S02 Home** — top to bottom:
1. Top bar: search icon (opens S03), notification bell with unread count (opens S04).
2. Greeting with a one-line summary, for example "2 overdue, 3 today".
3. Quick actions row: New contact, Log activity, Scan QR, Task.
4. Overdue (red block with a warning icon and the word "Overdue"; one-tap Done and Snooze on each task).
5. Today (tasks and meetings).
6. Upcoming (next 7 days, tasks and meetings, soonest first, "View all" opens the Calendar).
7. To complete (contacts with a filled temporary note).
8. Needs attention (top 3 contacts past their inactivity limit, "View all").
9. Recent contacts strip (last 6 opened, tap to open, long-press for WhatsApp and Call).
10. Pipeline snapshot card (deal count per stage, USD and SYP totals separately, opens Deals).
11. Targets summary card (top 3 targets with progress, opens Stats). Optional.
12. Recent activity (last 8 activities as cards, "View more" opens the Timeline).
13. Global Add button (extended FAB): New contact, Log activity, Deal, Meeting, Task.

Sections with no items are hidden. Sections can be switched on or off and reordered in Settings (S33, Home). *States:* all-caught-up (when nothing is due: a friendly block with shortcuts to add a contact, a task or a note), empty app (no contacts yet: "Add your first contact" and "Import from your phone book").

**S03 Search (global)** — search field, results grouped under Contacts, Notes, Tasks, Meetings, Deals. Custom field values are searched too. Arabic-aware matching (see Arabic rules in E). Tap a result opens its screen. *States:* no results, empty query (recent searches).

**S04 Bell (notification inbox)** — scrollable tabs: **All** (default), **Tasks**, **Meetings**, **Contacts**, **Deals**, **System**, each with an unread count. Row: icon, one line of text, contact name if any, time. Unread = dot and bold text. Swipe or "x" to dismiss (Undo in a snackbar). Top bar: "Mark all as read", "Clear all" (with confirmation), gear icon (opens Settings, Notifications and alarms). Items are removed after 30 days or when the thing is done. Repeating alerts update one item. A missed alarm shows under its own tab with a "Missed" label. Update available shows under System. Tapping an item opens the screen it belongs to. *States:* empty ("You're all caught up", shorter line per tab).

### C3. Contacts tab

**S05 Contacts list** — search bar, scrollable rating tabs (**All, Hot, Warm, Cold, Unrated**, each with a count), filter chips under the search bar (role, tag, deal stage, no activity for X days, plus a "More filters" chip for custom contact fields), result count and "Clear all" when filters are active. Sort icon: Name, Recently added, Recent activity (default, remembered), Needs attention first. Alphabet scroller on the side, shown only when sorting by Name (English first in English, Arabic first in Arabic; أ إ آ ا count as one letter; the article "ال" is ignored; digits and symbols under "#"; a company-only contact sorts by company). Top bar menu: Scan QR, Import from phone. Floating "New contact" button.
Row (2 lines, 72dp): photo or initials at the start; line 1 name then nickname in lighter text; line 2 company; one role badge at the end, centered (first role plus "+1" if more). A small rating icon on the photo corner, only on the All tab. A small dot on the opposite corner if the temporary note is filled. Long-press opens multi-select (S37). Swipe: Call and WhatsApp (with the same actions in the long-press menu). *States:* empty, filtered empty, loading, permission denied (contacts, for import only).

**S06 Quick add (bottom sheet)** — 3 fields: **Name** (one field, with a chevron that expands to first and last name), **Phone** (country code picker, default Syria +963, label default Mobile), **Temporary note** (free text, as long as needed). Buttons: Save, "More details" (opens S07 with typed data carried over). Only a name is required (it may hold a company name). If the phone already exists: warning with the existing contact as a tappable card, "Open existing contact" and "Save anyway". *States:* duplicate warning, validation error.

**S07 Contact form (full)** — copies the Google Contacts pattern. Top to bottom: photo (add, crop), Name (expands to first name and last name), Company, Phone rows (country code, label, remove, "Add phone"), Roles (visible row, multi-select: Lead, Client, Supplier), Rating (visible row: Hot, Warm, Cold, none), Temporary note, then "Add more info" with one chip per extra field: **Email, Address, Job title, Website, Nickname, Events, Tags, Requirements, Custom fields**. Tapping a chip adds that field to the form. **Typed fields (phone, email, website, address) work like Google Contacts:** while a field is not being edited its type shows in the label, for example "Phone (Mobile)" or "Email (Work)"; while it is being edited the label is plain and a separate **Label** field (Work, Home, Other; for phones also Mobile and WhatsApp only) appears below it. **Email, website and address can be added several times**: each has its own ⊖ remove button and an "Add email / Add website / Add address" button below the group; the chip returns only when no row is left. An **address row also has a "Map link" field** (optional, for example a Google Maps share link): the Map action opens that link, or searches the address text when the link is empty. At least one of first name, last name or company is required. Top bar: close, Save. Leaving with changes asks "Discard changes?". Same form for new and edit. *States:* validation errors next to the field (text and icon), duplicate-phone warning, unsaved changes.

**S08 Contact details (the core screen)** — collapsing header that shrinks while scrolling to photo, name and action buttons.
- **Header:** photo, name then nickname (after the name), company, job title, role badges, rating (icon and word).
- **Action row:** WhatsApp, Call, Email, Map. Buttons for missing data are hidden. With several phones or addresses, Call and Map open a small list; WhatsApp uses the number marked for it.
- **3-dot menu:** Share (S09), Edit (S07), Delete (with a warning that the history goes with it).
- **Current status:** one line under the action row (automatic from the latest deal stage and last activity, for example "Offer sent, last visit 12 Oct"). If the user edited it: an "Edited" label, a "Reset to automatic" action, and the automatic text in smaller type underneath.
- **Requirements block:** short text with "Show more".
- **Banner "Complete this contact":** shown if the temporary note is filled; opens S07.
- **Upcoming block:** shown only when needed. Red with a warning icon and the word "Due" or "Overdue" for due and overdue items. Neutral for upcoming items. One item shows directly in the block. Several show a label with a count on the opposite side, and tapping opens a bottom sheet with the details. If both kinds exist, the red block wins and shows only due and overdue items.
- **Pinned scrollable tabs (order, mirrored in Arabic):** **Timeline** (default), **Schedule**, **Deals**, **Files**, **Details**. Each tab shows a count badge; Schedule shows a red badge when something is overdue.
  - *Timeline:* this contact's cards (same cards as the global Timeline).
  - *Schedule:* tasks, meetings and events with sections Overdue, Upcoming, Done.
  - *Deals:* this contact's deals with amount and stage.
  - *Files:* one list with filter chips (All, Files, Notes, Voice). Contains files attached directly to the contact (mandatory title, optional description), notes and voice notes (with preview and audio player), and files from deals and activities. Each item shows a source label ("Deal: Offer 112", "Note: Visit 12 Oct"). Images and PDFs preview in the app with zoom in and out. Notes show title and a few lines; tapping a note opens a read-only bottom sheet with the title and full text. Word, Excel and other types show an icon and file name and open in another app. A small "Add" action offers Attach file, Note, Voice note.
  - *Details:* phones, emails, addresses (each with a map link), websites, events, tags, custom fields, requirements.
- **Add button (extended FAB):** one sheet with four items: Log activity, Deal, Meeting, Task. Same on every tab.
*States:* empty tabs, contact with no phone/email/address (hidden buttons), loading, deleted contact.

**S09 Share sheet (for a contact)** — two formats. **QR code:** live preview, field picker (key fields ticked by default: name, phone, email, company, job title; the rest below, unticked, with a short note that more fields make the code harder to scan), a scan-quality indicator and warning when too full, Share image or Save image. Never includes notes, requirements, custom fields, events, roles, rating or tags. **Contact file (vCard):** all contact fields, optional "Include photo" switch, shared through the phone's share sheet. With several contacts selected only the vCard option is shown.

**S10 Scan QR** — camera view, then a review screen showing the fields found, editable, then Save (same duplicate warning as quick add). If the code is not a contact: "This QR code is not a contact" with "Open link" or "Copy text". *States:* camera permission denied, nothing found.

**S11 Import contacts** — permission explanation, pick list of phone contacts with checkboxes, search, "Select all" and a count; contacts already in the app are marked "Already added" and unticked. A flagged list of matches with Skip, Import as new or Merge. One role choice for the whole import (Lead, Client, Supplier, None). Option: phone-book labels become tags (off by default). Phone birthday becomes an event titled "Birthday" repeating yearly; phone notes become a regular note titled "Imported note". Progress bar, keeps running if the user leaves, summary "Imported 120, skipped 8, merged 3". No two-way sync. *States:* permission denied, empty phone book, progress, summary.

**S12 Duplicates and merge** — (a) List of pairs: two contacts side by side (photo, name, company, phone), reason in words ("Same phone", "Same email", "Similar name and company"), buttons Review, Not a duplicate, Skip. "Hidden pairs" list to undo "Not a duplicate". (b) Merge screen: two columns, field by field; single-value fields (name, company, job title, rating, photo) the user taps the value to keep; multi-value fields (phones, emails, addresses, websites, tags, roles, events) are combined with exact repeats removed. All history moves to the merged contact. The older record survives; the user can swap before confirming. A meeting with both contacts keeps one. Snackbar Undo for a few seconds, then a "Merged with X" line in the Timeline. The app suggests saving a backup file before the first merge. Three or more contacts merge as repeated pairs. *States:* no duplicates found, scanning.

**S37 Multi-select mode** — long-press a row to start. Top bar shows the count and actions: Share (vCard only), Bulk edit (change tag, role, rating), Merge (when exactly 2), Select all. Exit with back. Bulk edit shows a summary and a confirmation. *States:* bulk edit confirmation, nothing selected.

### C4. Add and edit forms

All forms: close button, Save, "Discard changes?" on exit with changes, visible labels, errors as text with an icon.

**S13 Log activity** — one screen. Type selector at the top: **Call, Visit, Message, Note**. Contact picker is the first field when started from Home (recent contacts first, search, "New contact" at the bottom); pre-filled and locked when started from a contact. Note may have no contact ("General note"); the other types always need one. Date and time default to now.
- *Call:* direction (incoming or outgoing), duration (optional), outcome, description.
- *Visit:* place, map link, outcome, description.
- *Message:* channel (WhatsApp or Email), direction (sent or received), outcome (optional), description.
- *Note:* mandatory title, text, voice recorder (record, pause, resume, play, no time limit), description optional.
- *Outcome:* chips from the editable outcome list plus a description field. Required for Call and Visit, optional for Message and Note.
- Attachments: files and photos on any type.
After saving: a prompt "Set a follow-up task?" with tomorrow, in 3 days, next week, pick a date, or dismiss. *States:* recording permission denied, recording in progress.

**S14 Activity detail sheet (read-only)** — bottom sheet from any card: all details, full voice player, attached files, a link button that opens the item's own screen. No Edit or Delete buttons. Same pattern for Timeline entries, Files items and the Upcoming block.

**S15 Note screen** — the note in its own screen with Edit and Delete (title, text, voice, files).

**S16 Task form and detail** — Quick create: one line (title, date). Full: title, contact (optional), due date, optional time, priority (High, Normal, Low; default Normal), reminder (default 1 hour before, custom allowed; date-only tasks remind at 9:00 a.m., changeable), alarm or notification (default alarm for High and Normal, notification for Low), repeat (none, daily, weekly, monthly), description, attachments. Marking a repeating task Done creates the next one. Done and Snooze (1 hour, tomorrow, pick a date).

**S17 Meeting form and detail** — Quick create: title, date, time. Full: title, contacts (multi-select, up to 10, first is main; cards show main name plus "+2"), date, start time, duration chips (15 min, 30 min, 1 hour default, 2 hours, custom), type (In person, Phone, Video; icon and word), place with map link (Video has a link field instead), description, reminder (default 1 hour before), alarm or notification (default alarm), repeat (daily, weekly, monthly), attachments. Overlap warning (saving still allowed). After the meeting time passes: "Did it happen?" with one tap that creates one shared Visit (or Call for phone meetings) linked to all contacts, with date, place and notes pre-filled.

**S18 Event form** — title (free text, last-used titles as chips), contact (required, one), date (past dates allowed; year may be unknown for yearly events), repeat (none or every year), alert type (notification or full-screen alarm), alert time (default from Settings), "Also remind me" (same day only default, 1 day before, 1 week before), description. No fixed birthday field.

**S19 Deal form and detail** — Quick create: title, contact, amount. Full: title, contact (required, one), amount (optional; no amount shows "No amount" and adds nothing to totals), currency (default from Settings, only enabled currencies), stage, expected close date, description (requirements), custom deal fields, attachments. "Add document" section with several records per deal (reference number, amount, date, attached file) for invoices and proposals. Stage history log with dates (automatic). Moving to Won asks for the final amount and date; moving to Lost asks for a reason (editable list) plus a note. A Won or Lost deal can be reopened with a confirmation.

### C5. Calendar tab

**S20 Calendar** — views Month (default), Week, Agenda (switch in the top bar). Month: dots per day with a distinct shape per type (task, meeting, event), a count when more than three, a panel below the grid for the selected day. Type toggles as chips (Tasks, Meetings, Events, Done) and a contact filter. Overdue tasks stay on their original day marked "Overdue" and also appear in a red block above the calendar. Today button. "+" with a selected day opens Task, Meeting or Event with that date pre-filled (Event asks for a contact first). Items open the read-only sheet. First day of the week from Settings (default Saturday in Arabic, Sunday in English). Gregorian only. *States:* empty day, loading.

### C6. Deals tab

**S21 Deals pipeline** — one full-width page per stage; swipe right to left to go to the next stage (mirrors in Arabic). **Stage header** (instead of tabs): stage name, deal count, USD and SYP totals as separate lines (only currencies that have deals), dot indicator, previous and next arrows, a peek of the next page's edge, and tap to open a jump list of stages. Stage header uses the stage tint. Deal card: title, contact name, amount with currency, expected close date, days in stage, stage chip; a text label with an icon "Past close date" when late. Sort inside a stage comes from Settings (default expected close date, soonest first). Tap a deal opens S19; "Move to stage" is a one-tap action. Won and Lost are the last two pages and have a month filter. Filter icon in the header: currency, contact role, deal custom fields; search by deal title or contact. Floating button adds a deal (contact picked first; stage pre-selected if started from a stage). *States:* empty stage with "Add deal", filtered empty.

### C7. More tab

**S22 More** — grouped list. Top: My profile card (photo, name, Share). **Work:** Timeline, Stats, Reports. **Organize:** Tags, Outcome list, Custom fields, Deal stages. **Tools:** QR generator, Scan QR, Import contacts, Duplicates and merge (shows a count badge). **Data:** Backup and data. **Settings** (last item).

**S23 Timeline (global)** — pinned **Upcoming** section on top (next 3 items, "Show all", collapsible, remembered), then history newest first under Today, Yesterday, This week, then month names. Two levels: full cards for things the user creates or does (contact, note, call, visit, message, task, meeting, deal, event); single-line entries (icon, one line, time) for task completed, deal stage changed, rating changed, role changed. Small field edits are not logged. Card contents: note shows title, 2 lines of description and an inline voice player (play, pause, resume, progress, duration); visit shows title, contact name and 2 lines; other types show their key details. Only one voice player plays at a time. Tap a card opens S14. Filter icon opens a sheet (type chips, contact picker, date range, "no contact" switch); active filters appear as chips with a result count and "Clear all". "Jump to date" in the top bar. Items load in pages. A deleted item disappears. No search field (Home search covers it). *States:* empty ("Nothing here yet"), filtered empty, loading.

**S24 Stats** — period segmented control (Week, Month, Custom) with previous and next arrows. One scrolling page of cards in this order: Targets, Activity (calls, visits, meetings, messages), Deals (won, lost, win rate shown as "2 of 3" for small samples, value won per currency, average days Lead to Won), Pipeline (open value per stage), Lost reasons, Follow-up discipline (tasks done on time versus overdue), Contacts (new, past inactivity limit). Numbers with a small bar beside each, compared with the previous period. Tap a number opens the list behind it in a sheet. USD and SYP are always separate rows. Empty period shows "No data for this period". **Targets card:** each target shows "12 of 20", progress bar, days left, text status (On track, Behind, Done), neutral tone, never red. "Set targets" and "History" links. **Set targets screen:** one row per metric (calls, visits, meetings, messages, new contacts, deals won count, sales value won in USD, sales value won in SYP); weekly or monthly per target; empty = no target. **Target history:** past periods ("March: 18 of 20"). Target alerts are off by default.

**S25 Reports** — stepper on one screen: (1) Choose clients (filters role, rating, tag, deal stage, date range, custom fields; or pick by hand; "Select all" with count; a warning on contacts with a filled temporary note), (2) Choose content (switches, all on by default: performance page with date range, requirements, current status, history summary, open deals, targets next to results), (3) Preview and export (scrollable preview of the first page and one client card; title field default "Client report, date"; header with name and company from My profile; language choice; PDF with one card per client, CSV with one row per client). Saved presets ("Weekly report for my manager"). Shared through the phone's share sheet with a one-line privacy reminder. No export history. *States:* progress, error, empty selection.

**S26 Tags** — list (colour swatch, tag name, contact count; tap opens the contacts with that tag). Create and edit: name and one of 12 fixed colours (no custom hex). Rename updates everywhere. Merge combines contacts. Delete asks "Remove this tag from N contacts?" and never deletes contacts. Alphabetical order only. Contact tag picker: chips with search and "Create tag". *States:* empty ("No tags yet" with "New tag").

**S27 Outcome list** — rows with a drag handle (order = chip order in forms), "New outcome" (name up to 30 characters, no translation for custom ones). Defaults: Interested, Needs time, Not interested, No answer (translated). One shared list for Call, Visit and Message. Rename updates everywhere. Used outcomes are archived, not deleted; unused ones can be deleted. Max 8 active. "Restore default outcomes" adds back missing defaults.

**S28 Custom fields** — two sections, **Contact fields** and **Deal fields**, each with "New field" and drag order. Field: name (up to 30 characters), type (Text, Number with optional unit label, Date, Yes/No, Choice with up to 20 single-select options), required or optional, "Show in reports". Type cannot change once the field holds data. A new required field does not block old items (shown as "Missing"). Max 15 fields per section. Archive (keeps values and reports) or delete (with values, after confirmation). Never included in QR or vCard. Searchable in Home search. Usable as filters in the Contacts list, Deals and Reports (filters combine with "and").

**S29 Deal stages** — rows with drag handle, deal count, stage tint swatch; Won and Lost at the bottom, locked, with a lock icon and the word "Fixed". New stage: name (up to 30 characters) and a tint from a fixed palette of about 10 very light colours (no custom hex). Max 8 open stages. Deleting a stage with deals asks where to move them. Rename updates everywhere including history. "Restore default stages" adds missing defaults. Reachable from More and from the stage header.

**S30 QR generator** — three sources: app contact, phone-book contact (picked directly, not imported; needs the Contacts permission), manual entry (fields as in the contact form). Same field picker and preview as S09. After manual entry an optional "Save as contact". Share image or Save image.

**S31 My profile** — photo, name, title, company, phones, email, website, address (same fields as a new contact minus CRM-only fields). Your own QR code. Share button: QR image or contact file (vCard) through the share sheet. Photo is stored on the phone.

**S32 Backup and data** — four sections. **Backup:** Google Drive (private app folder, "Back up only on Wi-Fi" on by default, automatic schedule Off, Daily or Weekly with weekly suggested after sign-in) and "Save backup file" (everything, works offline, optional password with a clear warning that it cannot be recovered); a reminder if no backup for 14 days (on by default). **Restore:** from a file or Drive; replaces all data after a confirmation showing the backup date and contact count; the app saves a safety copy first. **Export:** all contacts as CSV (UTF-8 with BOM) or vCard. **Delete everything:** two steps (type a word, then confirm), offers a backup first. Also: storage use split into photos, voice notes and files with "Clear cache", and a short privacy statement. *States:* offline (Drive only), progress, sign-in failed, wrong password, corrupt file.

### C8. Settings and About

**S33 Settings** — search field at the top. Groups, each opens its own screen:
1. **Appearance:** theme colour ("Follow my phone" default, or "Choose my colour" with about 12 swatches, then Custom with hue slider and hex field and a live preview showing a contact card, a button and a stage chip; too pale or too bright colours are adjusted to keep 4.5:1 with a one-line notice), light, dark or follow phone, high contrast switch (also follows the phone), Arabic font (Noto Sans Arabic default, Cairo, IBM Plex Sans Arabic; live preview line). The text says clearly that phones without dynamic colours (Android 11 and older, iPhone) get the warm cream palette.
2. **Language and region:** English or Arabic, digits (Western or Arabic-Indic), Arabic month names (Syrian or common Gulf and Egyptian), first day of the week, display name order (First Last or Last First), default currency.
3. **Notifications and alarms:** quiet hours (default 10 p.m. to 8 a.m.), alarms during quiet hours (default ring; switch "Silence alarms during quiet hours"), temporary-note reminder frequency (Off, 30 min, 1 hour default, 3 hours, daily; one grouped notification), default time for date-only tasks (9:00 a.m.), event alert time, alarm sound, "Hide details on the lock screen" (off by default), Test alarm, permissions check (notifications, exact alarms, full-screen alerts, install unknown apps), target alerts (off).
4. **Inactivity alerts:** days for Hot (7), Warm (14), Cold (30) and unrated (30), plus Off.
5. **Deals:** currencies (list with on/off; built-in world list bundled offline; "Add custom currency" with code, name, symbol, decimals 0 to 2, symbol before or after; a used currency can be hidden, not deleted; no conversion), sort inside a stage (expected close date, creation date, amount, days in stage, title; ascending or descending), link to Deal stages.
6. **Home:** switch sections on or off and reorder.
7. **Targets and stats:** target alerts switch, default period.
8. **Data and privacy:** opens S32.
9. **About:** opens S34.
Bottom: "Reset all settings to default" (never touches data).

**S34 About** — app name and logo, version, "Check for updates" (Updates screen), "Tell me about new versions" switch (weekly check, on by default), privacy statement (no data collected; the connection is used only to check for and download updates and for Drive backup if turned on; GitHub sees the phone's IP like any download), "Send feedback" (opens the email app with the app version filled in; notice that the developer sees the sender's email address and can reply), "About the developer", footer line: English "Designed and developed with ♥ by Mahmoud Damer"; Arabic "صمّمه وطوّره محمود دامر لكم بكل حب ♥". The heart is an icon with a screen-reader label.

**S35 Updates** — current version, "Check for updates"; when a newer version exists: "Version X is available", what's new, **Download and install** with a plain explanation screen about "Install unknown apps" first, a progress bar, SHA-256 check, then Android's own install prompt. Offers "Save a backup first?" before installing (one tap to skip). *States:* up to date, checking, offline, download failed, checksum mismatch, permission denied.

**S36 About the developer** — large round photo (about 160dp, outline ring in dark theme, text description for screen readers), name (English "Mahmoud Damer", Arabic "محمود دامر"), title and short bio (written by Mahmoud in English and Arabic; placeholders until then), contact buttons (email, WhatsApp, website, LinkedIn; placeholders until Mahmoud provides them). The photo file is bundled in the app.

### C9. System screens

**S38 Full-screen alarm** — shows over the lock screen. Large time, item type with icon and word (Task, Meeting, Event), title, contact name, place with map link for meetings. Three stacked full-width buttons, at least 56dp tall: **Snooze 15 min**, **Open**, **Dismiss** (least prominent). No swipe gestures. No Done button: Dismiss never completes a task; Open lets the user complete it. Phone's alarm sound with vibration, volume follows the phone's alarm volume. If ignored: rings for 1 minute, then a persistent notification and a "Missed" item in the Bell, repeats once after 5 minutes. Several alarms at once: one screen with "+2 more", dismissing moves to the next. Lock-screen detail hiding when the setting is on ("Task reminder" and the time only). No animation. Follows theme with high contrast and large time.

**S39 Crash report prompt** — after a crash: a prompt with the error code asking whether to send it. The notice says the report opens the email app, so the developer can see the sender's email address and can reply. Shows exactly what will be sent: error code, app version, phone model, Android version. Never client data. Buttons: Send, Don't send. If no email app: "Copy details".

**S40 Permission explanation screens** — one plain sentence each for Contacts, Camera, Microphone, Notifications, Exact alarms, Full-screen alerts, Install unknown apps, with "Open phone settings" when denied.

**S41 Splash and app icon** — system splash shows the mark (Android 12 and newer cannot show text); the app's own first screen shows the mark with the word YONCA for a moment. App icon: light cream background version and dark green version (see E, `color.logo`); mark covers about 60% of the icon so masks never cut it. A one-colour version of the mark is needed for notifications and the status bar. Themed icon: off (the logo always looks the same).


---

## D. Flows

Each flow lists the steps, the screens used (IDs from section C), and what happens when something goes wrong. All flows work offline unless marked.

### D1. Add a contact fast (decided)
1. Contacts tab → floating **New contact** (or Home quick action).
2. S06 quick add opens as a bottom sheet: Name, Phone, Temporary note.
3. Save. If the phone number already exists, the duplicate warning shows the existing contact as a tappable card: **Open existing contact** or **Save anyway**.
4. The contact is saved with a filled temporary note. A dot shows on its row, and the "Complete this contact" banner shows on its details.
5. Reminder rule for the temporary note: while the note is filled, the app sends one grouped notification at the frequency set in Settings (default every hour, only outside quiet hours). The notification text counts the contacts ("3 contacts need completing"). Tapping it opens the list of those contacts. The note is cleared when the user taps **Complete this contact**, saves the full form and empties the note, or clears it by hand.
- *Error:* name empty → "Add a name or a company". Sheet stays open.

### D2. Add a contact in full
1. S07 from "More details", from the FAB menu, or from Edit.
2. Fill the form; "Add more info" chips add fields on demand.
3. Save → S08 opens on the Timeline tab.
- *Leaving with changes:* "Discard changes?" with Keep editing and Discard.
- *Error:* none of first name, last name, company → message under the name field.

### D3. Find a contact
1. **From Contacts:** type in the search bar (name, nickname, company, phone, email, tag, custom field). Results filter as the user types. Arabic normalisation applies.
2. **From Home:** tap the search icon → S03. Type. Results grouped by Contacts, Notes, Tasks, Meetings, Deals. Tap a result.
3. **By browsing:** rating tabs, filter chips, alphabet scroller.
- Target: under 5 seconds from opening the app.
- *No results:* "No results" and, in S03, a "Create contact" shortcut with the typed text.

### D4. Contact a client
1. Open S08 (or swipe the row, or long-press a Recent contacts item).
2. Tap WhatsApp / Call / Email / Map. The app hands over to the matching app.
3. When the user returns after a Call (a phone call detected, recommended on Android with the call-log permission **only if** the user allows it; otherwise skip this step) a **"Log this call?"** bar appears at the bottom for 10 seconds with Log and Dismiss. Log opens S13 with type Call and the contact pre-filled. (Built in milestone M12.)
- *No app for the action:* "No app found to open this" with a Copy option.

### D5. Log an activity
1. Start from the FAB (**Log activity**) on a contact, or from Home (contact picker first).
2. S13: pick type, fill the fields, choose an outcome, add files or a voice recording.
3. Save. The activity appears at the top of the contact's Timeline and in the global Timeline. The contact's "last activity" and current status update. Inactivity alerts reset for the contact.
4. Follow-up prompt: "Set a follow-up task?" → quick choices (tomorrow, in 3 days, next week, pick a date) or dismiss. A choice creates a task with the default reminder and the activity's contact.
- *Voice note:* record → pause/resume → stop → play. Leaving the screen while recording asks "Keep this recording?".
- *Microphone denied:* the recorder button explains and offers Open phone settings. Typing still works.
- *No outcome on a Call or Visit:* Save is disabled with the hint "Choose an outcome".

### D6. Create a task
1. FAB → Task (on a contact), or Home quick action, or Calendar "+".
2. S16. Title and date are enough. Everything else has defaults.
3. Save. The task shows in the Schedule tab, Calendar, Home (Today or Upcoming) and the Timeline's Upcoming section.
4. At reminder time: alarm (full screen, S38) or notification, depending on the choice, respecting quiet hours.
5. Done: from the task, the Home block, the notification button or the alarm's Open. A repeating task creates the next one. A completed task becomes a single-line Timeline entry.
- *Overdue:* the task moves into Home's red Overdue block, the contact's red upcoming block and the Calendar's red block. Overdue tasks never disappear until done or deleted.
- *Snooze (1 hour, tomorrow, pick date)* changes the reminder, not the due date, unless the user picks a later due date.

### D7. Create a meeting
1. FAB → Meeting.
2. S17: title, contacts (one or several), date and time, duration, type (In person, Phone, Video), place or link, reminder, alarm or notification, repeat.
3. Overlap check: if the new time overlaps another meeting, show "This overlaps with X" with Save anyway and Change time.
4. Save. It appears in the Schedule tab of every attached contact, in the Calendar, Home and the Timeline.
5. After the meeting end time, a notification and a Home card ask **"Did it happen?"**: Yes creates one Visit (or Call, for a Phone meeting) with all the meeting's contacts, the place and the notes; Reschedule opens the form; Cancel marks it cancelled (kept in history).
- *Deleting a contact attached to a meeting:* the contact is removed from the meeting; if no contacts remain the meeting stays with the title only, after a warning.

### D8. Create an event
1. Contact details → Add (Schedule tab or FAB) → Event, or from the contact form (the Events chip).
2. S18: title, date, repeat every year, alert type, alert time, extra reminders.
3. At the alert time on the day: notification or alarm. "Also remind me" adds earlier alerts.
- Events never become tasks. The Calendar shows them with their own mark.

### D9. Calendar use
1. Calendar tab → Month by default.
2. Tap a day → panel with its items. Tap an item → read-only sheet with a link button.
3. Switch Week or Agenda from the top bar. Toggle types with chips.
4. "+" adds an item on the selected day.
- *Overdue items:* a red block above the calendar, and a marker on the original day.

### D10. Deal lifecycle (decided)
1. FAB → Deal (contact pre-selected), or the Deals tab floating button (contact picked first).
2. S19 quick create: title, contact, amount. Stage defaults to the first stage; it can be changed.
3. Move through stages: on the Deals page tap **Move to stage** on the card, or edit the deal. Each move writes a single-line Timeline entry and a stage-history row with the date.
4. **Won:** asks final amount and date → stage becomes Won, the contact's role Lead becomes Client automatically if it was Lead, Timeline entry added. The deal stays in the Won page with a month filter.
5. **Lost:** asks reason (editable list) and optional note → stage Lost.
6. Reopen: from a Won or Lost deal, "Reopen" asks which open stage to return to.
7. Documents: in the deal detail, **Add document** creates a record (reference, amount, date, file). Several per deal. Documents appear in the contact's Files tab with the source label.
- *Deleting a stage that holds deals:* asks where to move them.
- *Past expected close date:* the card shows an icon and "Past close date".

### D11. Contact status (automatic and manual) (decided)
- Automatic: the app builds a one-line status from the latest open deal stage and the last activity, for example "Offer sent, last visit 12 Oct".
- Manual: tapping the status line lets the user type their own text. The "Edited" label appears and the automatic text shows in smaller type underneath.
- "Reset to automatic" clears the manual text.
- Supplier role: the automatic status says "Supplier" with the last activity.
- Suppliers can have deals (they can also buy). A contact can have several roles at once.

### D12. Build and export a report (decided)
1. More → Reports → S25.
2. Step 1: choose clients with filters, or pick by hand ("Select all" shows the count). Warning for any contact with a filled temporary note: "3 contacts are incomplete".
3. Step 2: choose what goes in (all on by default).
4. Step 3: preview, title, language, then **Create PDF** or **Create CSV**.
5. The phone's share sheet opens. A one-line reminder: "This file contains client data."
- Presets: "Save as preset" stores the filters and switches for next time.
- *Zero clients selected:* Next is disabled.
- *Large report:* progress bar with cancel.
- *PDF details:* Arabic shaping and right-to-left tables in Arabic. Fonts follow the Arabic font choice. Header shows name and company from My profile.

### D13. QR: generate, share, scan (decided)
**Generate**
1. From a contact (Share in the 3-dot menu), My profile, or More → QR generator (app contact, phone-book contact, or manual entry).
2. Pick fields (key fields ticked). Watch the scan-quality indicator.
3. Share image / Save image, or for contacts also Share contact file.
**Scan**
1. Contacts top-bar menu, Home quick action or More → Scan QR.
2. The camera finds a code → review screen → Save (duplicate warning applies).
- A manual QR (typed fields) offers **Save as contact** after generation.
- *Not a contact code:* "This QR code is not a contact" with Open link / Copy text.
- *Camera denied:* explanation and Open phone settings.

### D14. Import contacts (decided)
1. Contacts menu or More → Import contacts.
2. Permission screen (one plain sentence) → the Contacts permission prompt.
3. Pick contacts (all, some, search). Choose one role for the batch. Optional: labels become tags.
4. Matches with existing contacts are shown in a flagged list: Skip, Import as new, or Merge.
5. Import runs with a progress bar. The user may leave the screen; a notification shows the result.
6. Summary: imported, skipped, merged.
- *Permission denied:* explain; the user can still add contacts manually.
- *Phone birthday:* becomes an event "Birthday" repeating yearly.

### D15. Find and merge duplicates (decided)
1. More → Duplicates and merge shows pairs found (same phone, same email, similar name and company).
2. Review a pair → S12 merge screen. Single-value fields: tap the value to keep. Multi-value fields: combined, repeats removed.
3. Confirm. All history moves to the merged contact. A snackbar offers Undo for a few seconds. A "Merged with X" line is added to the Timeline.
4. "Not a duplicate" hides the pair; a "Hidden pairs" list lets the user undo.
- Before the first merge, the app suggests saving a backup file.
- Merge never touches the other contact until the user confirms.

### D16. Backup and restore (decided)
**Back up to Google Drive**
1. More → Backup and data → Drive → sign in with Google (internet needed).
2. The app stores one backup in its private Drive folder. Automatic schedule: Off, Daily or Weekly (weekly suggested after sign-in); Wi-Fi only on by default.
3. A "Last backup" line shows date and size. A reminder appears if 14 days pass without a backup (on by default).
**Save a backup file**
1. Choose "Save backup file". Optional password (with a clear warning that a lost password cannot be recovered).
2. The phone's save or share sheet opens.
**Restore**
1. From file or from Drive.
2. A confirmation shows the backup date and the contact count and says this will replace all current data.
3. The app first saves a safety copy of the current data, then restores. Progress bar. The app restarts on Home.
- *Errors:* wrong password, damaged file, not a YONCA backup, sign-in failed, no internet (Drive only). Each has a plain message and a next step.
**Delete everything**
1. Two steps: type a confirmation word, then a final Delete button. Offers "Save a backup first".

### D17. First run (onboarding) (decided)
1. Language (English or Arabic). The app switches immediately.
2. If Arabic: digits (Western or Arabic-Indic) and month names (Syrian or common).
3. Default currency.
4. Theme: Follow my phone, or choose a colour; light, dark or follow phone.
5. Optional: My profile (name, company, phone) and "Import contacts now?".
6. Allow reminders (notification permission; exact alarms and full-screen alerts are explained and checked later in Settings with a Test alarm).
7. The app opens on Home (empty state).
- Every step has Skip. Nothing is required. All choices can be changed in Settings.

### D18. Alarm (decided)
1. At the reminder time for a task or meeting alarm (or event alarm): if the phone is locked the full-screen alarm (S38) shows; otherwise a heads-up notification with the same buttons.
2. **Snooze 15 min** → rings again in 15 minutes. **Open** → opens the item. **Dismiss** → stops the alarm; the task stays open.
3. Ignored for 1 minute → sound stops, a persistent notification stays, a "Missed" item appears in the Bell (System or the item's category), and it rings once more after 5 minutes.
4. Several alarms together: shown one after another with "+2 more".
5. Quiet hours (default 10 p.m. to 8 a.m.): alarms still ring unless the user turned on "Silence alarms during quiet hours"; notifications are silent during quiet hours and wait.
- *Android settings blocking alarms:* Settings → Notifications and alarms shows a check list with a link to each phone setting and a **Test alarm** button.

### D19. Notification bell (decided)
1. The bell icon on Home shows an unread count.
2. S04 opens on the All tab. Tap a tab to filter.
3. Tap an item to open its source (task, meeting, contact, deal, or Updates).
4. Swipe or tap x to dismiss; Undo in a snackbar. "Mark all as read" and "Clear all" in the top bar.
- Repeating alerts update one item rather than adding more.

### D20. Install, update, release (decided; copied from Mahmoud's Pill Box method)
**Release (developer side)**
1. Push to GitHub. One workflow file `android.yml` has a manual input `release_version`. Enter a version such as `1.0.0`.
2. The workflow builds a signed APK, names it `YONCA-x.y.z.apk` and also `YONCA.apk` (a fixed name), creates a `.sha256` file, and publishes a GitHub Release.
3. `versionCode` must increase on every release or Android refuses the update.
4. The same release key is used forever. Back it up before the first release. Register its SHA-1 in Google Cloud so Drive sign-in keeps working.
5. The landing page Download button points to the fixed-name `YONCA.apk` in the latest release.
**User side**
1. First install: download the APK from the landing page, allow "Install unknown apps" for the browser, install.
2. Updates: once a week the app checks the GitHub Releases API (internet needed). If a newer version exists, one quiet notification per version is sent and an item appears in the Bell (System tab).
3. About → **Check for updates** (S35) shows the version and what's new. **Download and install** explains the "Install unknown apps" permission (first time only), downloads with progress, verifies SHA-256, then opens Android's install prompt. "Save a backup first?" is offered before installing.
4. The switch **Tell me about new versions** in About turns the weekly check off.
- *Errors:* offline, download failed, checksum mismatch (the file is deleted, nothing is installed), permission denied (explain, Open phone settings).

### D21. Crash report (decided)
1. After a crash, the next start shows S39.
2. Send opens the email app with the error code, app version, phone model and Android version in the body. Nothing else.
3. Don't send closes it. The app never sends anything by itself.
4. No email app: Copy details.

### D22. Theme change (decided)
1. Settings → Appearance. Pick Follow my phone, or Choose my colour.
2. A live preview updates at once. If a chosen colour fails the 4.5:1 rule the app adjusts its tone and shows a one-line notice.
3. Switching light, dark or high contrast applies immediately. The choice survives restarts.
- Android 11 and older: "Follow my phone" uses the fallback palette; the Settings text says so.

### D23. Change language, digits or month names
1. Settings → Language and region.
2. Switching language restarts the visible screens at once; layouts mirror. No data changes.
3. Digits and month names affect every screen and exports (PDF, CSV). Phone numbers always use Western digits left to right.

### D24. Targets and stats
1. More → Stats shows the current period. Set targets from the Targets card.
2. Activity entries update progress as the user works. Progress is neutral in tone ("Behind" is a word, not red).
3. At the end of a period the result is stored in Target history ("March: 18 of 20"). Edited targets apply from the next period.
4. Target alerts are off by default; if on, one gentle notification at the middle and end of the period.

### D25. Custom fields
1. More → Custom fields → New field, in the Contact or Deal section.
2. Name, type, required or optional (and a unit for Number, choices for Choice).
3. The field appears in the matching form (under "Add more info"), the Details tab, reports (if "Show in reports") and filters.
4. Archive keeps values; delete removes them after confirmation.

### D26. Delete a contact
1. S08 → 3-dot menu → Delete.
2. Confirmation names what will go: "This also deletes 14 activities, 2 deals and 3 files." Buttons: Cancel, Delete.
3. Done. A snackbar offers Undo for a few seconds. After that it cannot be recovered (use backup).
- Related meetings keep the other contacts. Tasks for that contact are deleted.


---

## E. Design tokens

**Rule:** no screen may hard-code a colour, font size, radius, spacing, elevation or duration. Everything comes from the token file below, through one theme object. Changing a token changes the whole app.

### E1. How the palette is chosen (decided)
1. **Follow my phone (default):** on Android 12 and newer, use the phone's Material You dynamic colour (light and dark). On Android 11 and older, and later on iPhone, use `color.fallback` (warm brown and cream). The Settings text says this.
2. **Choose my colour:** the user picks one of about 12 swatches, or a custom colour (hue slider, hex field). The app builds a full Material 3 tonal palette from that single seed colour (Material colour utilities, `ColorScheme.fromSeed` or the `dynamic_color`/`material_color_utilities` packages) for light, dark and high contrast.
3. **Contrast guard:** every text-on-background pair of a built palette must reach 4.5:1 (7:1 in high contrast); icons, borders and focus rings 3:1. If a user-chosen seed would fail, the app shifts the tone of the failing role until it passes and shows a one-line notice: "We adjusted this colour so text stays easy to read."
4. **High contrast** (Settings switch, also on when the phone's high-contrast text is on): text 7:1, tints removed, container colours replaced by surface with a stronger outline (see `highContrastLight`, `highContrastDark`). Works with any palette: build the high-contrast scheme from the same seed at stronger tones.
5. **Light, dark, follow phone** is independent of the palette choice.

### E2. Colours that do not follow the theme (decided)
- **Semantic colours** (`color.semantic`): success, warning, danger, each with light/dark and container variants. Always paired with an icon and a word.
- **Tag colours** (`color.tags`): 12 fixed hues, each with a light and a dark background/text pair. The user picks from these only (no custom hex).
- **Stage tints** (`color.stageTints`): 10 very light tints for deal stages, light and dark. The user picks from these only. Stage names are always text; the tint is decoration.
- **Logo** (`color.logo`): fixed in light and dark, never themed. Used for app icon, splash and About.
- Colour is never the only signal. Overdue = red + warning icon + the word "Overdue". Rating = icon + word. Stage = name.

### E3. Typography rules
- English: Roboto. Arabic: Noto Sans Arabic by default; Cairo or IBM Plex Sans Arabic by user choice. All bundled in the app (works offline, also used in PDF reports).
- Type scale is Material 3 Expressive (see `typography.scale` and `typography.emphasized`). Headlines, titles, labels and selected states use the **emphasised** (bold) weight; body text stays regular. **Arabic line height = English line height × 1.2**; letter spacing is 0 in Arabic.
- Design and test up to about **130%** text size. Layouts must grow vertically, never clip. (200% is not supported.)
- Numbers: Western digits by default; Arabic-Indic digits if the user chose them. Phone numbers, amounts' currency codes and technical codes always Western and left to right. Mixed text uses Unicode bidi isolation so a phone number inside Arabic text does not reorder.
- Money: amount first, then the currency code, in a fixed order, for example "1,500 USD". Group separators follow the digit choice.

### E4. Shape, spacing, elevation, motion
- Shape (Expressive): bigger, rounder, and shapes **change** with state. Cards 24, list items are separate tiles (outer corners 22, inner 6, 2 apart), bottom sheet and dialog 32, extended FAB 22, text fields 16, avatars 16 (large 36), icon holders 14. Buttons are pills and become a rounded square (16) while pressed. A selected chip or segment changes from 12 to a pill (22). See `shape.component`.
- Spacing scale in `spacing`. Screen gutter 16. Touch targets at least 48×48 with at least 8 between neighbours. One density only ("comfortable").
- Elevation: levels 0–5. Cards use level 0 with a tonal surface (no shadow) in dark theme.
- Motion: Expressive springs for position, size and shape changes (`motion.spring`); colour and opacity do not bounce. Flutter has no built-in spring tokens, so build them with `SpringDescription` and use the 150 / 300 / 500 ms durations as the fallback. Keep it short and calm. If the phone's "Remove animations" is on, all motion is removed. The full-screen alarm never animates.

### E5. Icons
Material Symbols, rounded style, weight 400 (500 in selected states), size 24 (20 in dense chips). Icons that show direction (back arrow, "next" chevrons, send) mirror in Arabic. Icons that show real-world objects (phone, camera, play, microphone) do not mirror. Media controls (play, pause, seek bar) stay left to right in both languages.

### E6. Right-to-left rules (decided)
- Arabic mirrors everything: bottom tabs order, FAB position (bottom-left), swipe directions, pipeline page order, back arrow, list rows (photo at the right edge), alphabet scroller (left edge).
- Do not mirror: media controls, charts' time axis is mirrored (earliest at the right), phone numbers, code, e-mail addresses and URLs (left-to-right, isolated).
- Use "start/end" in all layout code, never "left/right".
- Arabic search and sort normalisation (also used by filters and duplicate matching): treat أ إ آ ا as one letter; ى and ي as one; ة and ه as one; remove diacritics and tatweel; ignore the leading article "ال" for sorting and the alphabet scroller; compare case-insensitively for Latin text. English and Arabic names sort in separate groups (Arabic first in the Arabic version, English first in the English version).
- CSV: UTF-8 with BOM. PDF: Arabic shaping and right-to-left tables.

### E7. Dates and calendar
- Gregorian only. Arabic month names: Syrian (كانون الثاني، شباط، آذار، نيسان، أيار، حزيران، تموز، آب، أيلول، تشرين الأول، تشرين الثاني، كانون الأول) or Gulf/Egyptian (يناير، فبراير، مارس، أبريل، مايو، يونيو، يوليو، أغسطس، سبتمبر، أكتوبر، نوفمبر، ديسمبر). The user chooses (default Syrian when the language is Arabic).
- Time format (12 or 24 hour) follows the phone. First day of the week is a setting (default Saturday in Arabic, Sunday in English).

### E8. Material 3 Expressive (decided, updates every screen)
The screens follow **Material 3 Expressive**, the style Android 16 introduced in 2025. Compared with the first version of Material 3 it has: bigger and more varied shapes that change with state, bolder type, stronger container colours, a taller floating button and flexible navigation bar, segmented lists, connected button groups, wavy progress and spring motion.
- **Colour:** unchanged (dynamic colour from the phone, warm brown fallback, section E1). Expressive only asks for stronger use of container colours: selected states, the FAB, icon holders and avatars use primary or secondary container; cards and list tiles use surface container.
- **Flutter support (check before building):** Flutter's stock Material 3 widgets follow the earlier M3. Some Expressive pieces are arriving in newer Flutter versions, and community packages cover others. Before the build starts, the developer must confirm for the chosen Flutter version which of these exist: new button sizes and shapes, connected button groups, wavy progress, the flexible navigation bar, the new FAB sizes, spring motion. Anything missing is built as a small custom widget from the tokens above. None of this changes the layout of any screen.
- **Fonts:** Roboto (Roboto Flex if the developer prefers) with bold weight for emphasis. Noto Sans Arabic needs a bold file (700) bundled too.
- **Icons:** rounded Material Symbols; the mockups use a stand-in set, the app uses the real one.

### E9. Token file

Save this as `lib/theme/tokens.json` (or generate Dart constants from it). All colour pairs were checked by script: text 4.5:1 (7:1 in high contrast), icons and borders 3:1.

```json
{
  "meta": {
    "name": "YONCA design tokens",
    "version": "0.2.0",
    "units": "dp unless stated",
    "style": "Material 3 Expressive"
  },
  "color": {
    "fallback": {
      "light": {
        "primary": "#7B5733",
        "onPrimary": "#FFFFFF",
        "primaryContainer": "#F6DDBF",
        "onPrimaryContainer": "#2B1700",
        "secondary": "#6F5B46",
        "onSecondary": "#FFFFFF",
        "secondaryContainer": "#F5E0C8",
        "onSecondaryContainer": "#261A0A",
        "tertiary": "#56633A",
        "onTertiary": "#FFFFFF",
        "tertiaryContainer": "#D9E8B5",
        "onTertiaryContainer": "#141F00",
        "error": "#BA1A1A",
        "onError": "#FFFFFF",
        "errorContainer": "#FFDAD6",
        "onErrorContainer": "#410002",
        "background": "#FFF8F2",
        "onBackground": "#201B15",
        "surface": "#FFF8F2",
        "onSurface": "#201B15",
        "surfaceVariant": "#F0E0D0",
        "onSurfaceVariant": "#4F4538",
        "outline": "#7A6E60",
        "outlineVariant": "#D3C4B4",
        "surfaceContainerLowest": "#FFFFFF",
        "surfaceContainerLow": "#FBF2E8",
        "surfaceContainer": "#F5EDE2",
        "surfaceContainerHigh": "#EFE7DC",
        "surfaceContainerHighest": "#E9E1D6",
        "inverseSurface": "#362F28",
        "inverseOnSurface": "#FAEFE4",
        "inversePrimary": "#EBBF8F",
        "scrim": "#000000"
      },
      "dark": {
        "primary": "#EBBF8F",
        "onPrimary": "#452B08",
        "primaryContainer": "#5F4120",
        "onPrimaryContainer": "#FFDDB8",
        "secondary": "#DAC3A9",
        "onSecondary": "#3E2D1A",
        "secondaryContainer": "#564330",
        "onSecondaryContainer": "#F5E0C8",
        "tertiary": "#BDCC9B",
        "onTertiary": "#2A3510",
        "tertiaryContainer": "#404B25",
        "onTertiaryContainer": "#D9E8B5",
        "error": "#FFB4AB",
        "onError": "#690005",
        "errorContainer": "#93000A",
        "onErrorContainer": "#FFDAD6",
        "background": "#17130E",
        "onBackground": "#EBE1D8",
        "surface": "#17130E",
        "onSurface": "#EBE1D8",
        "surfaceVariant": "#4F4538",
        "onSurfaceVariant": "#D3C4B4",
        "outline": "#9C8F80",
        "outlineVariant": "#4F4538",
        "surfaceContainerLowest": "#120E09",
        "surfaceContainerLow": "#1F1B16",
        "surfaceContainer": "#231F1A",
        "surfaceContainerHigh": "#2E2924",
        "surfaceContainerHighest": "#39342E",
        "inverseSurface": "#EBE1D8",
        "inverseOnSurface": "#362F28",
        "inversePrimary": "#7B5733",
        "scrim": "#000000"
      },
      "highContrastLight": {
        "primary": "#4A2F0C",
        "onPrimary": "#FFFFFF",
        "primaryContainer": "#F0D2AE",
        "onPrimaryContainer": "#1A0E00",
        "secondary": "#43321F",
        "onSecondary": "#FFFFFF",
        "secondaryContainer": "#EBD3B6",
        "onSecondaryContainer": "#1A1005",
        "tertiary": "#2F3A18",
        "onTertiary": "#FFFFFF",
        "tertiaryContainer": "#CBDCA3",
        "onTertiaryContainer": "#0C1300",
        "error": "#8C0009",
        "onError": "#FFFFFF",
        "errorContainer": "#FFC9C2",
        "onErrorContainer": "#2E0001",
        "background": "#FFF8F2",
        "onBackground": "#000000",
        "surface": "#FFF8F2",
        "onSurface": "#000000",
        "surfaceVariant": "#F0E0D0",
        "onSurfaceVariant": "#2A2218",
        "outline": "#3A3329",
        "outlineVariant": "#6B5F50",
        "surfaceContainerLowest": "#FFFFFF",
        "surfaceContainerLow": "#FBF2E8",
        "surfaceContainer": "#F5EDE2",
        "surfaceContainerHigh": "#EFE7DC",
        "surfaceContainerHighest": "#E9E1D6",
        "inverseSurface": "#362F28",
        "inverseOnSurface": "#FAEFE4",
        "inversePrimary": "#EBBF8F",
        "scrim": "#000000"
      },
      "highContrastDark": {
        "primary": "#FFD9AE",
        "onPrimary": "#2B1700",
        "primaryContainer": "#5A3D1C",
        "onPrimaryContainer": "#FFFFFF",
        "secondary": "#EBD3B6",
        "onSecondary": "#261A0A",
        "secondaryContainer": "#6A5540",
        "onSecondaryContainer": "#FFFFFF",
        "tertiary": "#D2E2AE",
        "onTertiary": "#2A3510",
        "tertiaryContainer": "#3B4824",
        "onTertiaryContainer": "#FFFFFF",
        "error": "#FFD2CC",
        "onError": "#410002",
        "errorContainer": "#8A1812",
        "onErrorContainer": "#FFFFFF",
        "background": "#0E0B07",
        "onBackground": "#FFFFFF",
        "surface": "#0E0B07",
        "onSurface": "#FFFFFF",
        "surfaceVariant": "#4F4538",
        "onSurfaceVariant": "#EBDDCC",
        "outline": "#D3C4B4",
        "outlineVariant": "#9C8F80",
        "surfaceContainerLowest": "#120E09",
        "surfaceContainerLow": "#1F1B16",
        "surfaceContainer": "#231F1A",
        "surfaceContainerHigh": "#2E2924",
        "surfaceContainerHighest": "#39342E",
        "inverseSurface": "#EBE1D8",
        "inverseOnSurface": "#362F28",
        "inversePrimary": "#7B5733",
        "scrim": "#000000"
      }
    },
    "semantic": {
      "light": {
        "success": "#1F6B3A",
        "onSuccess": "#FFFFFF",
        "successContainer": "#D6F0DC",
        "onSuccessContainer": "#062B14",
        "warning": "#7A4F00",
        "onWarning": "#FFFFFF",
        "warningContainer": "#FFE7B3",
        "onWarningContainer": "#2B1B00",
        "danger": "#BA1A1A",
        "onDanger": "#FFFFFF",
        "dangerContainer": "#FFDAD6",
        "onDangerContainer": "#410002"
      },
      "dark": {
        "success": "#8FD6A0",
        "onSuccess": "#00391A",
        "successContainer": "#0F4A27",
        "onSuccessContainer": "#D6F0DC",
        "warning": "#F5C26B",
        "onWarning": "#432C00",
        "warningContainer": "#5E4200",
        "onWarningContainer": "#FFE7B3",
        "danger": "#FFB4AB",
        "onDanger": "#690005",
        "dangerContainer": "#93000A",
        "onDangerContainer": "#FFDAD6"
      }
    },
    "tags": {
      "red": {
        "light": {
          "bg": "#F7CDC9",
          "text": "#490E08"
        },
        "dark": {
          "bg": "#532B28",
          "text": "#F9CCC8"
        }
      },
      "orange": {
        "light": {
          "bg": "#F7DDC9",
          "text": "#492308"
        },
        "dark": {
          "bg": "#533A28",
          "text": "#F9DCC8"
        }
      },
      "amber": {
        "light": {
          "bg": "#F7EAC9",
          "text": "#493608"
        },
        "dark": {
          "bg": "#534628",
          "text": "#F9EAC8"
        }
      },
      "yellow": {
        "light": {
          "bg": "#F7F1C9",
          "text": "#494108"
        },
        "dark": {
          "bg": "#534D28",
          "text": "#F9F2C8"
        }
      },
      "lime": {
        "light": {
          "bg": "#E8F7C9",
          "text": "#344908"
        },
        "dark": {
          "bg": "#445328",
          "text": "#E9F9C8"
        }
      },
      "green": {
        "light": {
          "bg": "#C9F7D5",
          "text": "#084918"
        },
        "dark": {
          "bg": "#285332",
          "text": "#C8F9D4"
        }
      },
      "teal": {
        "light": {
          "bg": "#C9F7F1",
          "text": "#084941"
        },
        "dark": {
          "bg": "#28534D",
          "text": "#C8F9F2"
        }
      },
      "cyan": {
        "light": {
          "bg": "#C9F0F7",
          "text": "#083F49"
        },
        "dark": {
          "bg": "#284B53",
          "text": "#C8F1F9"
        }
      },
      "blue": {
        "light": {
          "bg": "#C9DDF7",
          "text": "#082349"
        },
        "dark": {
          "bg": "#283A53",
          "text": "#C8DCF9"
        }
      },
      "indigo": {
        "light": {
          "bg": "#C9C9F7",
          "text": "#080849"
        },
        "dark": {
          "bg": "#282853",
          "text": "#C8C8F9"
        }
      },
      "purple": {
        "light": {
          "bg": "#E4C9F7",
          "text": "#2E0849"
        },
        "dark": {
          "bg": "#412853",
          "text": "#E4C8F9"
        }
      },
      "pink": {
        "light": {
          "bg": "#F7C9E0",
          "text": "#490829"
        },
        "dark": {
          "bg": "#53283D",
          "text": "#F9C8E0"
        }
      }
    },
    "stageTints": {
      "sand": {
        "light": "#F5EADB",
        "dark": "#3B3226"
      },
      "rose": {
        "light": "#F5DBE0",
        "dark": "#3B2629"
      },
      "peach": {
        "light": "#F5E4DB",
        "dark": "#3B2D26"
      },
      "honey": {
        "light": "#F5EEDB",
        "dark": "#3B3626"
      },
      "moss": {
        "light": "#E8F5DB",
        "dark": "#303B26"
      },
      "mint": {
        "light": "#DBF5E8",
        "dark": "#263B30"
      },
      "sky": {
        "light": "#DBECF5",
        "dark": "#26343B"
      },
      "lake": {
        "light": "#DBE4F5",
        "dark": "#262D3B"
      },
      "lavender": {
        "light": "#E4DBF5",
        "dark": "#2D263B"
      },
      "orchid": {
        "light": "#F5DBF3",
        "dark": "#3B2639"
      }
    },
    "logo": {
      "light": {
        "iconBackground": "#F4EFE6",
        "tl": [
          "#226B36",
          "#17562B",
          "#2E7845",
          "#3A8A55"
        ],
        "tr": [
          "#2F8A7A",
          "#2A7F78",
          "#4AA68E",
          "#3F9C8A"
        ],
        "bl": [
          "#0D8A78",
          "#1A7E7A",
          "#2BAA80",
          "#1FA07C"
        ],
        "br": [
          "#8DE5C0",
          "#7FDDB8",
          "#6FCB9C",
          "#78D4A6"
        ]
      },
      "dark": {
        "iconBackground": "#0F2A1E",
        "tl": [
          "#2E8A4B",
          "#256F3D",
          "#43A862",
          "#4FB86E"
        ],
        "tr": [
          "#3FB09A",
          "#35978A",
          "#5BC7AC",
          "#4DBBA0"
        ],
        "bl": [
          "#1FB09A",
          "#17938A",
          "#3CCB9A",
          "#2FBF93"
        ],
        "br": [
          "#A8F0D0",
          "#95E8C4",
          "#84DDB0",
          "#8EE4B9"
        ]
      },
      "note": "Each leaf: [baseStart, baseEnd, halfStart, halfEnd]. Base is the full leaf, half is the diagonal half drawn on top. Gradient runs top-left to bottom-right of the leaf's bounding box, in the leaf's own orientation, so mirrored leaves mirror the gradient."
    }
  },
  "typography": {
    "fonts": {
      "latin": "Roboto",
      "arabicDefault": "Noto Sans Arabic",
      "arabicOptions": [
        "Noto Sans Arabic",
        "Cairo",
        "IBM Plex Sans Arabic"
      ],
      "arabicLineHeightMultiplier": 1.2
    },
    "scale": {
      "displayLarge": [
        57,
        64,
        400
      ],
      "displayMedium": [
        45,
        52,
        400
      ],
      "displaySmall": [
        36,
        44,
        400
      ],
      "headlineLarge": [
        32,
        40,
        400
      ],
      "headlineMedium": [
        28,
        36,
        400
      ],
      "headlineSmall": [
        24,
        32,
        400
      ],
      "titleLarge": [
        22,
        28,
        400
      ],
      "titleMedium": [
        16,
        24,
        500
      ],
      "titleSmall": [
        14,
        20,
        500
      ],
      "labelLarge": [
        14,
        20,
        500
      ],
      "labelMedium": [
        12,
        16,
        500
      ],
      "labelSmall": [
        11,
        16,
        500
      ],
      "bodyLarge": [
        16,
        24,
        400
      ],
      "bodyMedium": [
        14,
        20,
        400
      ],
      "bodySmall": [
        12,
        16,
        400
      ]
    },
    "scaleFormat": "[fontSize sp, lineHeight sp, weight]",
    "emphasized": {
      "note": "Expressive uses an emphasised (heavier) weight for titles, labels and selected states. Roboto Flex if available, otherwise Roboto 700.",
      "headlineLarge": [
        32,
        40,
        700
      ],
      "headlineMedium": [
        28,
        36,
        700
      ],
      "headlineSmall": [
        24,
        32,
        700
      ],
      "titleLarge": [
        22,
        28,
        700
      ],
      "titleMedium": [
        16,
        24,
        700
      ],
      "titleSmall": [
        14,
        20,
        700
      ],
      "labelLarge": [
        14,
        20,
        700
      ],
      "labelMedium": [
        12,
        16,
        700
      ]
    }
  },
  "shape": {
    "none": 0,
    "extraSmall": 4,
    "small": 8,
    "medium": 12,
    "large": 16,
    "largeIncreased": 20,
    "extraLarge": 28,
    "extraLargeIncreased": 32,
    "extraExtraLarge": 48,
    "full": 999,
    "component": {
      "card": 24,
      "listItemOuter": 22,
      "listItemInner": 6,
      "listItemGap": 2,
      "button": 999,
      "buttonPressed": 16,
      "fab": 22,
      "textField": 16,
      "sheetTop": 32,
      "dialog": 32,
      "chip": 12,
      "chipSelected": 22,
      "connectedButtonInner": 8,
      "avatar": 16,
      "avatarLarge": 36,
      "iconHolder": 14,
      "banner": 20,
      "appIcon": 34
    },
    "note": "Shapes morph: a selected chip or pressed button changes shape (chip 12 to 22, button full to 16). With 'Remove animations' on, the shape changes instantly."
  },
  "spacing": {
    "0": 0,
    "1": 2,
    "2": 4,
    "3": 8,
    "4": 12,
    "5": 16,
    "6": 20,
    "7": 24,
    "8": 32,
    "9": 40,
    "10": 48,
    "11": 64,
    "screenGutter": 16,
    "minTouchTarget": 48,
    "gapBetweenTargets": 8
  },
  "elevation": {
    "level0": 0,
    "level1": 1,
    "level2": 3,
    "level3": 6,
    "level4": 8,
    "level5": 12
  },
  "motion": {
    "duration": {
      "short": 150,
      "medium": 300,
      "long": 500
    },
    "easing": {
      "standard": [
        0.2,
        0,
        0,
        1
      ],
      "emphasizedDecelerate": [
        0.05,
        0.7,
        0.1,
        1
      ],
      "emphasizedAccelerate": [
        0.3,
        0,
        0.8,
        0.15
      ]
    },
    "respectRemoveAnimations": true,
    "alarmScreenAnimation": "none",
    "spring": {
      "note": "Expressive motion uses springs. Spatial (position, size, shape) is bouncy; effects (colour, opacity) are not.",
      "spatialFast": {
        "stiffness": 1400,
        "damping": 0.6
      },
      "spatialDefault": {
        "stiffness": 700,
        "damping": 0.8
      },
      "spatialSlow": {
        "stiffness": 300,
        "damping": 0.8
      },
      "effects": {
        "stiffness": 1600,
        "damping": 1.0
      },
      "fallbackDurationMs": {
        "short": 150,
        "medium": 300,
        "long": 500
      }
    }
  },
  "opacity": {
    "disabled": 0.38,
    "disabledContainer": 0.12,
    "hover": 0.08,
    "pressed": 0.12,
    "scrim": 0.32
  },
  "contrast": {
    "textMin": 4.5,
    "iconAndBorderMin": 3.0,
    "highContrastTextMin": 7.0
  },
  "layout": {
    "listRowTwoLine": 72,
    "listRowThreeLine": 88,
    "bottomNavHeight": 80,
    "topAppBar": 64,
    "fabSize": 64,
    "extendedFabHeight": 64,
    "alarmButtonHeight": 56,
    "avatarList": 40,
    "avatarHeader": 96,
    "avatarDeveloper": 160,
    "buttonHeightDefault": 56,
    "buttonHeightSmall": 40,
    "progressWavyHeight": 12,
    "progressTrack": 4
  }
}
```


---

## F. Component rules

Material 3 components from Flutter are the base. Rules below add YONCA decisions. Every component reads colours, type, shape and spacing from the tokens (section E).

### F1. General rules
- Touch targets ≥ 48×48dp, gaps ≥ 8dp. Visible focus ring (3:1) for keyboard and switch access.
- Every icon-only button has a text label for screen readers. Every image has a description or is marked decorative.
- Every swipe has a button alternative.
- Layout uses start/end, never left/right. Test every screen in English and Arabic.
- Text never truncates silently: long names wrap to two lines, then ellipsis; the full text is available on the details screen.

### F2. Buttons
- **Filled** = main action of the screen (one per screen). **Tonal** = secondary. **Outlined** = alternative. **Text** = low priority (Cancel, Skip).
- Pill shape. Default height **56** (Expressive medium), small 40 (48 touch area). Bold label. While pressed the shape changes to a rounded square (16). Labels are verbs: "Save", "Add task".
- Several related choices (Hot / Warm / Cold, QR code / Contact file) use a **connected button group**: 2 apart, outer corners round, the selected button becomes a full pill.
- Destructive actions use the danger colour plus the word (Delete) and always ask first.
- Disabled buttons show a reason nearby ("Choose an outcome").
- Alarm buttons: 56dp tall, full width, stacked, no icons only.

### F3. Floating buttons
- **Contacts list:** floating "New contact" (extended on scroll up, small on scroll down).
- **Contact details:** extended "Add" FAB opening a sheet with Log activity, Deal, Meeting, Task.
- **Home:** extended "Add" FAB: New contact, Log activity, Deal, Meeting, Task.
- **Deals:** floating "New deal".
- Look: 64 high, corner 22, bold label, primary container colour, level-3 shadow. Position: bottom end (mirrors). It never covers the last list item: lists have bottom padding of FAB height + 16.

### F4. Bottom navigation
5 destinations: Home, Contacts, Calendar, Deals, More. Icon + label always visible. The active item has the indicator pill. Badges: Home (no number; the bell has the count), More (small dot when duplicates or an update need attention), Calendar (red dot for overdue). Flexible navigation bar: height 80, no divider line, surface container colour, wide (64 × 32) indicator pill, bold label for the active item. Tapping the active tab scrolls to top; tapping a tab keeps its own back stack.

### F5. Top app bars
- Home: greeting area, search icon, bell. Others: title, optional actions (max 2 icons + overflow).
- Contact details: collapsing large bar (photo, name, actions).
- Forms: close (x) on the start, Save on the end.
- Back arrow mirrors in Arabic.

### F6. Lists and rows
- **Segmented list:** every row is its own tile in a surface container colour, 2dp apart. The first and last tile of a group have big outer corners (22), the ones between are nearly square (6). A group ends with 10dp space. Rows inside cards and sheets have no tile.
- Two-line row 64dp minimum, three-line 88dp. Start: avatar 40 (photo or initials on a tinted circle). Middle: primary text then secondary. End: badge or time.
- Contact row details in C (S05). No divider lines between tiles (the gap does the job).
- Swipe actions have a coloured background with an icon and word, and the same actions exist in the long-press menu.
- Alphabet scroller: shows the current letter as a bubble while dragging; Arabic letters first in the Arabic version.
- Selection mode: leading checkbox replaces the avatar; top bar shows the count.

### F7. Cards
- **Timeline card** (full level): type icon in a tonal circle, title, 2 lines of description, contact name (if not on a contact screen), time. Note cards show an inline voice player.
- **Timeline entry** (single line): small icon, one line, time. No card border.
- **Deal card:** title, contact, amount + currency, expected close, days in stage, stage chip. "Past close date" has icon + text.
- **Stat card:** title, big number, small bar, comparison with the previous period.
- **Target row:** "12 of 20", progress bar, days left, status word. Neutral colours only.
- **Upcoming block:** one item shows directly; several show a label and a count at the opposite side; red + warning icon + word for due/overdue.
- Cards: radius 24, tonal surface, padding 16 to 18, 10 between cards. Whole card is one tap target.

### F8. Chips
- **Filter chips:** outlined, radius 12; selected = tonal and a full pill (the shape changes), bold label, with a check icon. Show the active filter's name and, for filters with a value, the value. A "Clear all" text button appears when any filter is active, with the result count.
- **Tag chips:** tag colour pair from `color.tags`, text label, optional x when editable.
- **Role badge:** small tonal pill (Lead, Client, Supplier). First role + "+1" if more.
- **Stage chip:** stage tint with stage name.
- **Rating:** icon + word (Hot, Warm, Cold). Never colour alone.
- Chips height 32 (48 touch area through padding).

### F9. Text fields and forms
- Outlined fields, radius 16, 2dp border, label always visible above or floating. Helper text under the field. Errors replace helper text, with an icon and a sentence; they never rely on colour.
- Phone field: country-code picker (default +963), number always left to right.
- Name field: one field with a chevron that expands to first and last name; the same pattern as Google Contacts.
- Date and time pickers: Material pickers, Gregorian, month names per the user's setting.
- Multi-line fields grow up to 6 lines, then scroll.
- Required fields marked with the word "required" in the helper text, not only an asterisk.
- "Add more info" chips: one chip per missing field; when used, the chip disappears and the field appears in a sensible order.

### F10. Bottom sheets
- Modal sheet, top radius 32, surface container colour, drag handle, max height 90%.
- Read-only detail sheets show details and **one** link button ("Open note", "Open task"). No Edit/Delete inside.
- Action sheets list actions with icon + label (≥ 56dp rows).
- Closing: swipe down, tap outside, or Back.

### F11. Dialogs
- Only for confirmations that block something destructive or irreversible (Delete, Restore, Clear all, Delete everything). Title states the action; body states the effect with numbers; buttons: Cancel (text) and the action (filled or danger). Everything else uses snackbars or inline messages.

### F12. Snackbars and banners
- Snackbar: 4 seconds, one line, one optional action (Undo, View). Sits above the bottom bar and FAB. Screen readers announce it.
- Banners (inline, persistent): offline notice, "Complete this contact", missed alarms, permission problems. They have an icon, one sentence, and one action.

### F13. Progress and loading
- Skeleton placeholders for lists; circular indicator inside buttons while saving; **wavy** linear indicator (12dp high, flat 4dp track) with text for Reports, Import, Backup, Restore and Update download. Flutter's stock indicator is flat: build the wave with a custom painter, or use the flat one if the wave is not worth the work (decision for the developer).
- Long jobs (import, backup, restore) keep running if the user leaves and finish with a notification or a Bell item.

### F14. Voice note player and recorder
- Recorder: record, pause, resume, stop, play, delete. Large time counter. A level meter is optional. No time limit.
- Player: play/pause, a seek bar, current/total time. Controls stay left to right in Arabic. Only one player plays at a time; starting another stops the first. Playing continues when the card scrolls off screen only on its own screen (stops on leaving).
- Accessible: play/pause has a label with the note title.

### F15. File items and previews
- Image: thumbnail → full-screen viewer with pinch-zoom and double-tap zoom, share button.
- PDF: first-page thumbnail → in-app viewer with zoom.
- Word, Excel and others: icon, file name, size → opens in another app via the system.
- Every file has a mandatory title and an optional description; list shows the source label (Deal, Activity, Note, Contact).

### F16. Avatars
- 40dp in lists, 96dp in the contact header, 160dp in About the developer. Photo cropped to a circle; without a photo show initials (first letter of first and last name, or the first two letters of the company) on a tonal circle. Arabic initials use the first Arabic letter.

### F17. Empty, error and offline states
- Icon (48dp) + one sentence + one button. No illustrations. Error states add "Try again" and "Copy details". The offline banner appears only where the internet is needed.

### F18. Pipeline page header
- Stage name, deal count, totals per currency (separate lines), the dots indicator, previous/next arrows, and the edge of the next page. Tap the name to open the jump list. Tint from `stageTints`.

### F19. Calendar components
- Month grid: day numbers in the user's digit style; dots shaped by type (task = circle, meeting = square, event = diamond); a "+N" when more than three. Today has a filled circle; the selected day an outline.
- Week view: time column + day columns, items as blocks with title.
- Agenda: list by day with sticky date headers.

### F20. Alarm screen components
- Time (display size), item type (icon + word), title, contact, place; three stacked 56dp buttons: Snooze 15 min, Open, Dismiss. No gestures. No animation. Follows theme and high contrast.

### F21. Accessibility checklist (applies to every screen)
- Contrast ≥ 4.5:1 text, 3:1 icons/borders (7:1 in high contrast).
- Works at 130% text size without clipping.
- TalkBack order follows the visual order (mirrored in Arabic); each interactive element has a label.
- Not colour alone.
- Motion off when the phone asks for it.
- No time-limited actions without an alternative (snackbar Undo is also available in the item's own screen where possible).


---

## G. Message inventory

**Status of the Arabic text: a first draft written by Claude. Mahmoud must review every Arabic line before release.** Short, plain sentences. The app speaks to the user in the second person.

**How to use this section.**
- Each row is one message key for the ICU message files (`app_en.arb`, `app_ar.arb`). Use the key name as given.
- `{name}`, `{count}`, `{date}` are placeholders. Never join sentences from pieces; each full sentence is one message.
- Counted messages use ICU `plural`. English needs `one` and `other`. **Arabic needs all six forms: `zero`, `one`, `two`, `few` (3–10), `many` (11–99), `other` (100+ and decimals).** Where a table shows an Arabic plural, all six forms are written out.
- Arabic numbers inside messages follow the user's digit choice (Western or Arabic-Indic) through the number formatter, not typed by hand.
- Toasts are snackbars (4 seconds). Errors are inline text or banners. Confirmations are dialogs (F11).

### G1. Counted messages (plural forms)

| Key | English | Arabic (all six forms) |
|---|---|---|
| `contactsCount` | `{count, plural, =0{No contacts} one{1 contact} other{{count} contacts}}` | `{count, plural, zero{لا جهات اتصال} one{جهة اتصال واحدة} two{جهتا اتصال} few{{count} جهات اتصال} many{{count} جهة اتصال} other{{count} جهة اتصال}}` |
| `homeSummaryOverdue` | `{count, plural, one{1 overdue} other{{count} overdue}}` | `{count, plural, zero{لا شيء متأخر} one{واحد متأخر} two{اثنان متأخران} few{{count} متأخرة} many{{count} متأخرًا} other{{count} متأخر}}` |
| `homeSummaryToday` | `{count, plural, =0{nothing today} one{1 today} other{{count} today}}` | `{count, plural, zero{لا شيء اليوم} one{واحد اليوم} two{اثنان اليوم} few{{count} اليوم} many{{count} اليوم} other{{count} اليوم}}` |
| `tempNoteReminder` | `{count, plural, one{1 contact needs completing} other{{count} contacts need completing}}` | `{count, plural, zero{لا جهات تحتاج إلى استكمال} one{جهة اتصال واحدة تحتاج إلى استكمال} two{جهتا اتصال تحتاجان إلى استكمال} few{{count} جهات اتصال تحتاج إلى استكمال} many{{count} جهة اتصال تحتاج إلى استكمال} other{{count} جهة اتصال تحتاج إلى استكمال}}` |
| `daysSince` | `{count, plural, one{1 day} other{{count} days}}` | `{count, plural, zero{أقل من يوم} one{يوم واحد} two{يومان} few{{count} أيام} many{{count} يومًا} other{{count} يوم}}` |
| `daysInStage` | `{count, plural, one{1 day in this stage} other{{count} days in this stage}}` | `{count, plural, zero{اليوم الأول في هذه المرحلة} one{يوم واحد في هذه المرحلة} two{يومان في هذه المرحلة} few{{count} أيام في هذه المرحلة} many{{count} يومًا في هذه المرحلة} other{{count} يوم في هذه المرحلة}}` |
| `daysLeft` | `{count, plural, =0{Last day} one{1 day left} other{{count} days left}}` | `{count, plural, zero{اليوم الأخير} one{بقي يوم واحد} two{بقي يومان} few{بقيت {count} أيام} many{بقي {count} يومًا} other{بقي {count} يوم}}` |
| `inactiveDays` | `{count, plural, one{No contact for 1 day} other{No contact for {count} days}}` | `{count, plural, zero{تواصلت اليوم} one{لا تواصل منذ يوم} two{لا تواصل منذ يومين} few{لا تواصل منذ {count} أيام} many{لا تواصل منذ {count} يومًا} other{لا تواصل منذ {count} يوم}}` |
| `moreItems` | `{count, plural, one{+1 more} other{+{count} more}}` | `{count, plural, zero{} one{+١ آخر} two{+٢ آخران} few{+{count} أخرى} many{+{count} آخر} other{+{count} آخر}}` (digits via formatter) |
| `upcomingCount` | `{count, plural, one{1 upcoming item} other{{count} upcoming items}}` | `{count, plural, zero{لا عناصر قادمة} one{عنصر قادم واحد} two{عنصران قادمان} few{{count} عناصر قادمة} many{{count} عنصرًا قادمًا} other{{count} عنصر قادم}}` |
| `dueCount` | `{count, plural, one{1 item due} other{{count} items due}}` | `{count, plural, zero{لا عناصر مستحقة} one{عنصر مستحق واحد} two{عنصران مستحقان} few{{count} عناصر مستحقة} many{{count} عنصرًا مستحقًا} other{{count} عنصر مستحق}}` |
| `overdueCount` | `{count, plural, one{1 overdue item} other{{count} overdue items}}` | `{count, plural, zero{لا عناصر متأخرة} one{عنصر متأخر واحد} two{عنصران متأخران} few{{count} عناصر متأخرة} many{{count} عنصرًا متأخرًا} other{{count} عنصر متأخر}}` |
| `importResult` | `Imported {imported}, skipped {skipped}, merged {merged}.` | `تم استيراد {imported}، وتخطي {skipped}، ودمج {merged}.` |
| `deleteContactConfirmBody` | `This also deletes {activities, plural, one{1 activity} other{{activities} activities}}, {deals, plural, one{1 deal} other{{deals} deals}} and {files, plural, one{1 file} other{{files} files}}.` | `سيؤدي هذا أيضًا إلى حذف {activities, plural, zero{لا أنشطة} one{نشاط واحد} two{نشاطين} few{{activities} أنشطة} many{{activities} نشاطًا} other{{activities} نشاط}} و{deals, plural, zero{لا صفقات} one{صفقة واحدة} two{صفقتين} few{{deals} صفقات} many{{deals} صفقة} other{{deals} صفقة}} و{files, plural, zero{لا ملفات} one{ملف واحد} two{ملفين} few{{files} ملفات} many{{files} ملفًا} other{{files} ملف}}.` |
| `removeTagConfirm` | `Remove this tag from {count, plural, one{1 contact} other{{count} contacts}}? The contacts are not deleted.` | `هل تريد إزالة هذه الوسمة من {count, plural, zero{أي جهة اتصال} one{جهة اتصال واحدة} two{جهتي اتصال} few{{count} جهات اتصال} many{{count} جهة اتصال} other{{count} جهة اتصال}}؟ لن تُحذف جهات الاتصال.` |
| `mergedContacts` | `{count, plural, one{1 contact merged} other{{count} contacts merged}}` | `{count, plural, zero{} one{تم دمج جهة اتصال واحدة} two{تم دمج جهتي اتصال} few{تم دمج {count} جهات اتصال} many{تم دمج {count} جهة اتصال} other{تم دمج {count} جهة اتصال}}` |
| `selectedCount` | `{count, plural, one{1 selected} other{{count} selected}}` | `{count, plural, zero{لم تحدد شيئًا} one{محدد واحد} two{محددان} few{{count} محددة} many{{count} محددًا} other{{count} محدد}}` |
| `meetingWithOthers` | `{name} and {count, plural, one{1 other} other{{count} others}}` | `{name} و{count, plural, zero{} one{شخص آخر} two{شخصين آخرين} few{{count} أشخاص آخرين} many{{count} شخصًا آخر} other{{count} شخص آخر}}` |
| `reportClients` | `{count, plural, one{1 client in this report} other{{count} clients in this report}}` | `{count, plural, zero{لا عملاء في هذا التقرير} one{عميل واحد في هذا التقرير} two{عميلان في هذا التقرير} few{{count} عملاء في هذا التقرير} many{{count} عميلًا في هذا التقرير} other{{count} عميل في هذا التقرير}}` |
| `incompleteContactsWarn` | `{count, plural, one{1 contact is incomplete.} other{{count} contacts are incomplete.}}` | `{count, plural, zero{} one{جهة اتصال واحدة غير مكتملة.} two{جهتا اتصال غير مكتملتين.} few{{count} جهات اتصال غير مكتملة.} many{{count} جهة اتصال غير مكتملة.} other{{count} جهة اتصال غير مكتملة.}}` |
| `targetProgress` | `{done} of {goal}` | `{done} من {goal}` |
| `storageUsed` | `Using {size} on this phone` | `يستخدم {size} من مساحة هذا الهاتف` |

### G2. Confirmations (dialogs)

| Key | Title (EN / AR) | Body (EN / AR) | Buttons (EN / AR) |
|---|---|---|---|
| `dlgDiscardChanges` | Discard changes? / هل تريد تجاهل التغييرات؟ | Your changes have not been saved. / لم تُحفظ تغييراتك. | Keep editing, Discard / متابعة التعديل، تجاهل |
| `dlgDeleteContact` | Delete this contact? / هل تريد حذف جهة الاتصال هذه؟ | (see `deleteContactConfirmBody`) | Cancel, Delete / إلغاء، حذف |
| `dlgDeleteItem` | Delete this item? / هل تريد حذف هذا العنصر؟ | This cannot be undone. / لا يمكن التراجع عن هذا. | Cancel, Delete / إلغاء، حذف |
| `dlgDeleteTag` | Delete this tag? / هل تريد حذف هذه الوسمة؟ | (see `removeTagConfirm`) | Cancel, Delete / إلغاء، حذف |
| `dlgDeleteStage` | Delete this stage? / هل تريد حذف هذه المرحلة؟ | Choose where to move its deals. / اختر المرحلة التي ستنتقل إليها صفقاتها. | Cancel, Delete stage / إلغاء، حذف المرحلة |
| `dlgDeleteField` | Delete this field? / هل تريد حذف هذا الحقل؟ | The values saved in it will be deleted too. You can archive it instead. / ستُحذف القيم المحفوظة فيه أيضًا. يمكنك أرشفته بدلًا من ذلك. | Cancel, Archive, Delete / إلغاء، أرشفة، حذف |
| `dlgClearBell` | Clear all notifications? / هل تريد مسح كل الإشعارات؟ | / | Cancel, Clear all / إلغاء، مسح الكل |
| `dlgRestore` | Restore this backup? / هل تريد استعادة هذه النسخة الاحتياطية؟ | This backup is from {date} and has {count} contacts. It will replace everything on this phone. We save a safety copy first. / هذه النسخة بتاريخ {date} وفيها {count} جهة اتصال. ستحل محل كل ما على هذا الهاتف. سنحفظ نسخة أمان أولًا. | Cancel, Restore / إلغاء، استعادة |
| `dlgDeleteAllStep1` | Delete everything? / هل تريد حذف كل شيء؟ | This deletes all contacts, history and files from this phone. Type DELETE to continue. / سيحذف هذا كل جهات الاتصال والسجل والملفات من هذا الهاتف. اكتب DELETE للمتابعة. | Cancel, Continue / إلغاء، متابعة |
| `dlgDeleteAllStep2` | This cannot be undone / لا يمكن التراجع عن هذا | Save a backup first if you may need your data. / احفظ نسخة احتياطية أولًا إذا كنت قد تحتاج إلى بياناتك. | Save a backup, Delete everything / حفظ نسخة احتياطية، حذف كل شيء |
| `dlgReopenDeal` | Reopen this deal? / هل تريد إعادة فتح هذه الصفقة؟ | Choose a stage to return it to. / اختر المرحلة التي ستعود إليها. | Cancel, Reopen / إلغاء، إعادة فتح |
| `dlgResetSettings` | Reset all settings? / هل تريد إعادة ضبط كل الإعدادات؟ | Your contacts and history are not touched. / لن تتأثر جهات الاتصال والسجل. | Cancel, Reset / إلغاء، إعادة ضبط |
| `dlgBulkEdit` | Change {count} contacts? / هل تريد تغيير {count} جهة اتصال؟ | (summary of the change) | Cancel, Apply / إلغاء، تطبيق |
| `dlgMergeConfirm` | Merge these contacts? / هل تريد دمج جهتي الاتصال؟ | All history moves to the merged contact. / سينتقل كل السجل إلى جهة الاتصال المدمجة. | Cancel, Merge / إلغاء، دمج |
| `dlgSaveBackupFirst` | Save a backup first? / هل تريد حفظ نسخة احتياطية أولًا؟ | Recommended before installing an update. / يُنصح بذلك قبل تثبيت تحديث. | Skip, Save backup / تخطي، حفظ نسخة |
| `dlgKeepRecording` | Keep this recording? / هل تريد الاحتفاظ بهذا التسجيل؟ | / | Discard, Keep / تجاهل، احتفاظ |
| `dlgCancelMeeting` | Cancel this meeting? / هل تريد إلغاء هذا الاجتماع؟ | It stays in the history as cancelled. / سيبقى في السجل على أنه ملغى. | Back, Cancel meeting / رجوع، إلغاء الاجتماع |
| `dlgOverlap` | This overlaps with {name} / يتعارض هذا مع {name} | / | Change time, Save anyway / تغيير الوقت، حفظ على أي حال |

### G3. Toasts (snackbars)

| Key | English | Arabic |
|---|---|---|
| `toastContactSaved` | Contact saved | تم حفظ جهة الاتصال |
| `toastContactDeleted` | Contact deleted | تم حذف جهة الاتصال (action: Undo / تراجع) |
| `toastActivitySaved` | Activity saved | تم حفظ النشاط |
| `toastTaskSaved` | Task saved | تم حفظ المهمة |
| `toastTaskDone` | Task done | تم إنجاز المهمة (Undo / تراجع) |
| `toastTaskSnoozed` | Reminder moved to {time} | تم تأجيل التذكير إلى {time} |
| `toastMeetingSaved` | Meeting saved | تم حفظ الاجتماع |
| `toastEventSaved` | Event saved | تم حفظ المناسبة |
| `toastDealSaved` | Deal saved | تم حفظ الصفقة |
| `toastDealWon` | Deal won | تم ربح الصفقة |
| `toastDealLost` | Deal marked as lost | تم تسجيل الصفقة على أنها خاسرة |
| `toastDealMoved` | Moved to {stage} | تم النقل إلى {stage} |
| `toastNoteSaved` | Note saved | تم حفظ الملاحظة |
| `toastFileAdded` | File added | تمت إضافة الملف |
| `toastTagSaved` | Tag saved | تم حفظ الوسمة |
| `toastCopied` | Copied | تم النسخ |
| `toastDismissed` | Dismissed | تم الإغلاق (Undo / تراجع) |
| `toastMergeDone` | Contacts merged | تم دمج جهتي الاتصال (Undo / تراجع) |
| `toastBackupDone` | Backup saved | تم حفظ النسخة الاحتياطية |
| `toastRestoreDone` | Data restored | تمت استعادة البيانات |
| `toastExportDone` | Export ready | التصدير جاهز |
| `toastSettingsReset` | Settings reset | تمت إعادة ضبط الإعدادات |
| `toastTonedColour` | We adjusted this colour so text stays easy to read. | عدّلنا هذا اللون ليبقى النص سهل القراءة. |
| `toastMarkedRead` | All marked as read | تم تحديد الكل كمقروء |
| `toastSavedToPhone` | Saved to this phone | تم الحفظ على هذا الهاتف |

### G4. Errors and warnings (inline or banner)

| Key | English | Arabic |
|---|---|---|
| `errNameRequired` | Add a name or a company. | أضف اسمًا أو اسم شركة. |
| `errPhoneInvalid` | This phone number looks wrong. Check the digits. | يبدو رقم الهاتف غير صحيح. تحقق من الأرقام. |
| `errEmailInvalid` | This email address looks wrong. | يبدو عنوان البريد الإلكتروني غير صحيح. |
| `errTitleRequired` | Add a title. | أضف عنوانًا. |
| `errOutcomeRequired` | Choose an outcome. | اختر نتيجة. |
| `errContactRequired` | Choose a contact. | اختر جهة اتصال. |
| `errDateRequired` | Choose a date. | اختر تاريخًا. |
| `errAmountInvalid` | Enter a number. | أدخل رقمًا. |
| `errFieldRequired` | This field is required. | هذا الحقل مطلوب. |
| `errDuplicatePhone` | A contact with this number already exists. | توجد جهة اتصال بهذا الرقم بالفعل. |
| `errNoResults` | No results. | لا نتائج. |
| `errGeneric` | Something went wrong. Try again. | حدث خطأ ما. حاول مرة أخرى. |
| `errNoApp` | No app found to open this. | لم يتم العثور على تطبيق لفتح هذا. |
| `errOffline` | No internet. Your data is safe on this phone. | لا يوجد اتصال بالإنترنت. بياناتك آمنة على هذا الهاتف. |
| `errSignInFailed` | We could not sign in to Google. Try again. | تعذر تسجيل الدخول إلى Google. حاول مرة أخرى. |
| `errBackupFailed` | The backup did not finish. Try again. | لم تكتمل النسخة الاحتياطية. حاول مرة أخرى. |
| `errWrongPassword` | That password is not correct. | كلمة المرور غير صحيحة. |
| `errBackupDamaged` | This file is damaged or is not a YONCA backup. | هذا الملف تالف أو ليس نسخة احتياطية من يونجا. |
| `errNoSpace` | There is not enough space on this phone. | لا توجد مساحة كافية على هذا الهاتف. |
| `errImportNothing` | No contacts were found on this phone. | لم يتم العثور على جهات اتصال في هذا الهاتف. |
| `errQrNotContact` | This QR code is not a contact. | رمز QR هذا ليس جهة اتصال. |
| `errQrNothing` | No QR code found. Hold the camera steady. | لم يُعثر على رمز QR. ثبّت الكاميرا. |
| `errQrTooFull` | Too much information: the code may be hard to scan. Remove some fields. | معلومات كثيرة: قد يصعب مسح الرمز. أزل بعض الحقول. |
| `errRecordingFailed` | The recording stopped. Try again. | توقف التسجيل. حاول مرة أخرى. |
| `errFileTooLarge` | This file cannot be opened here. | لا يمكن فتح هذا الملف هنا. |
| `errUpdateDownload` | The download did not finish. Try again. | لم يكتمل التنزيل. حاول مرة أخرى. |
| `errUpdateChecksum` | The downloaded file did not match. We deleted it. Nothing was installed. | لم يتطابق الملف الذي تم تنزيله. حذفناه ولم يُثبَّت شيء. |
| `warnOverlap` | This overlaps with {name}. | يتعارض هذا مع {name}. |
| `warnPastCloseDate` | Past close date | تجاوز تاريخ الإغلاق |
| `warnOverdue` | Overdue | متأخر |
| `warnDue` | Due | مستحق |
| `warnNoAmount` | No amount | بلا مبلغ |
| `warnMissing` | Missing | غير مُدخل |
| `warnBackupOld` | No backup for 14 days. Back up now? | لا توجد نسخة احتياطية منذ ١٤ يومًا. هل تريد النسخ الآن؟ |
| `warnPasswordLost` | If you lose this password, the backup cannot be opened. | إذا فقدت كلمة المرور فلن يمكن فتح النسخة الاحتياطية. |
| `warnReportShare` | This file contains client data. | يحتوي هذا الملف على بيانات العملاء. |

### G5. Permissions (explanations)

| Key | English | Arabic |
|---|---|---|
| `permContacts` | YONCA reads your phone contacts only to import them. Nothing is uploaded. | يقرأ يونجا جهات الاتصال في هاتفك لاستيرادها فقط. لا يُرفع شيء. |
| `permCamera` | The camera is used only to scan QR codes and take photos. | تُستخدم الكاميرا لمسح رموز QR والتقاط الصور فقط. |
| `permMic` | The microphone is used only to record voice notes. | يُستخدم الميكروفون لتسجيل الملاحظات الصوتية فقط. |
| `permNotifications` | Allow notifications so YONCA can remind you. | اسمح بالإشعارات ليتمكن يونجا من تذكيرك. |
| `permExactAlarms` | Allow exact alarms so reminders ring on time. | اسمح بالمنبهات الدقيقة لتُنبّهك التذكيرات في وقتها. |
| `permFullScreen` | Allow full-screen alerts so alarms show on a locked phone. | اسمح بالتنبيهات بملء الشاشة لتظهر المنبهات على الهاتف المقفل. |
| `permInstall` | To install updates, Android asks you to allow "Install unknown apps" for YONCA. YONCA only installs files from its own release page and checks them first. | لتثبيت التحديثات يطلب منك أندرويد السماح بـ«تثبيت التطبيقات غير المعروفة» لتطبيق يونجا. يثبّت يونجا ملفات صفحة إصداراته فقط ويتحقق منها أولًا. |
| `permDenied` | This permission is off. You can turn it on in phone settings. | هذا الإذن متوقف. يمكنك تشغيله من إعدادات الهاتف. |
| `permOpenSettings` | Open phone settings | فتح إعدادات الهاتف |

### G6. Empty states

| Key | English | Arabic | Button |
|---|---|---|---|
| `emptyContacts` | No contacts yet. | لا توجد جهات اتصال بعد. | New contact / جهة اتصال جديدة |
| `emptyHome` | You're all caught up. | أنجزت كل شيء. | (shortcuts: Add contact, Add task, Add note / إضافة جهة اتصال، إضافة مهمة، إضافة ملاحظة) |
| `emptyTimeline` | Nothing here yet. | لا شيء هنا بعد. | Log activity / تسجيل نشاط |
| `emptySchedule` | Nothing scheduled. | لا شيء مجدول. | Add task / إضافة مهمة |
| `emptyDeals` | No deals yet. | لا توجد صفقات بعد. | New deal / صفقة جديدة |
| `emptyStage` | No deals in this stage. | لا توجد صفقات في هذه المرحلة. | Add deal / إضافة صفقة |
| `emptyFiles` | No files yet. | لا توجد ملفات بعد. | Add file / إضافة ملف |
| `emptyBell` | You're all caught up. | لا إشعارات جديدة. | |
| `emptyTags` | No tags yet. | لا توجد وسوم بعد. | New tag / وسمة جديدة |
| `emptyDuplicates` | No duplicates found. | لم يُعثر على مكررات. | |
| `emptyFiltered` | No results for these filters. | لا نتائج لهذه المرشحات. | Clear filters / مسح المرشحات |
| `emptyStats` | No data for this period. | لا بيانات لهذه الفترة. | |
| `emptySearch` | No results. | لا نتائج. | Create contact / إنشاء جهة اتصال |
| `emptyDay` | Nothing on this day. | لا شيء في هذا اليوم. | |

### G7. Notifications and alarms

| Key | English | Arabic |
|---|---|---|
| `notifTaskDue` | Task: {title} | مهمة: {title} |
| `notifMeetingSoon` | Meeting at {time}: {title} | اجتماع في {time}: {title} |
| `notifEventToday` | {title} — {name} | {title} — {name} |
| `notifTaskDone` (button) | Done | تم |
| `notifSnooze` (button) | Snooze | تأجيل |
| `notifMeetingHappened` | Did your meeting with {name} happen? | هل تم اجتماعك مع {name}؟ |
| `notifTempNote` | (see `tempNoteReminder`) | (see `tempNoteReminder`) |
| `notifInactivity` | {name}: {count} days without contact | {name}: لا تواصل منذ {count} يومًا (use `inactiveDays` plural) |
| `notifMissedAlarm` | Missed: {title} | فاتك: {title} |
| `notifUpdate` | YONCA {version} is available | الإصدار {version} من يونجا متاح |
| `notifBackupReminder` | (see `warnBackupOld`) | (see `warnBackupOld`) |
| `notifLockHidden` | Task reminder | تذكير بمهمة |
| `alarmSnooze` | Snooze 15 min | تأجيل ١٥ دقيقة |
| `alarmOpen` | Open | فتح |
| `alarmDismiss` | Dismiss | إغلاق |
| `alarmMore` | (see `moreItems`) | (see `moreItems`) |
| `callLogBar` | Log this call? | هل تريد تسجيل هذه المكالمة؟ |
| `callLogBarYes` / `No` | Log / Dismiss | تسجيل / إغلاق |

### G8. Prompts

| Key | English | Arabic |
|---|---|---|
| `promptFollowUp` | Set a follow-up task? | هل تريد إضافة مهمة متابعة؟ |
| `promptFollowUpChoices` | Tomorrow · In 3 days · Next week · Pick a date · No | غدًا · بعد ٣ أيام · الأسبوع القادم · اختيار تاريخ · لا |
| `promptMeetingHappened` | Did it happen? | هل تم الاجتماع؟ |
| `promptMeetingYes` / `Reschedule` / `Cancel` | Yes / Reschedule / Cancel | نعم / إعادة جدولة / إلغاء |
| `promptComplete` | Complete this contact | استكمل بيانات جهة الاتصال هذه |
| `promptCrashTitle` | YONCA closed unexpectedly | أُغلق يونجا بشكل غير متوقع |
| `promptCrashBody` | You can send an error report by email. It contains only the error code, app version, phone model and Android version. It never contains client data. The developer will see your email address and can reply to you. | يمكنك إرسال تقرير الخطأ بالبريد الإلكتروني. يحتوي فقط على رمز الخطأ وإصدار التطبيق وطراز الهاتف وإصدار أندرويد، ولا يحتوي أبدًا على بيانات العملاء. سيرى المطوّر عنوان بريدك ويمكنه الرد عليك. |
| `promptCrashSend` / `Dont` / `Copy` | Send report / Don't send / Copy details | إرسال التقرير / عدم الإرسال / نسخ التفاصيل |
| `promptFeedbackNote` | Sending feedback opens your email app. The developer will see your email address and can reply. | يفتح إرسال الملاحظات تطبيق البريد لديك. سيرى المطوّر عنوان بريدك ويمكنه الرد عليك. |
| `promptUnsaved` | (see `dlgDiscardChanges`) | |
| `promptFirstMerge` | Save a backup file before your first merge? | هل تريد حفظ ملف نسخة احتياطية قبل أول عملية دمج؟ |
| `promptStatusReset` | Reset to automatic | العودة إلى التلقائي |
| `promptStatusEdited` | Edited | معدّل |

### G9. Settings, About and updates

| Key | English | Arabic |
|---|---|---|
| `setFollowPhone` | Follow my phone | حسب هاتفي |
| `setChooseColour` | Choose my colour | اختيار لوني |
| `setDynamicNote` | Phones with Android 11 or older (and iPhone) use YONCA's warm cream colours. | تستخدم الهواتف ذات أندرويد ١١ أو أقدم (وآيفون) ألوان يونجا الكريمية الدافئة. |
| `setHighContrast` | High contrast | تباين عالٍ |
| `setArabicFont` | Arabic font | الخط العربي |
| `setDigits` | Digits | الأرقام |
| `setDigitsWestern` / `Arabic` | 0 1 2 3 / ٠ ١ ٢ ٣ | 0 1 2 3 / ٠ ١ ٢ ٣ |
| `setMonthNames` | Arabic month names | أسماء الأشهر العربية |
| `setMonthSyrian` / `Gulf` | تشرين الأول (Syrian) / أكتوبر (Gulf, Egyptian) | تشرين الأول (سوري) / أكتوبر (خليجي ومصري) |
| `setWeekStart` | First day of the week | أول يوم في الأسبوع |
| `setQuietHours` | Quiet hours | ساعات الهدوء |
| `setQuietAlarms` | Silence alarms during quiet hours | كتم المنبهات خلال ساعات الهدوء |
| `setTestAlarm` | Test alarm | تجربة المنبه |
| `setHideLock` | Hide details on the lock screen | إخفاء التفاصيل على شاشة القفل |
| `setInactivity` | Inactivity alerts | تنبيهات الانقطاع عن التواصل |
| `setReset` | Reset all settings | إعادة ضبط كل الإعدادات |
| `setSearchHint` | Search settings | البحث في الإعدادات |
| `aboutVersion` | Version {version} | الإصدار {version} |
| `aboutCheckUpdates` | Check for updates | التحقق من التحديثات |
| `aboutUpToDate` | You have the latest version. | لديك أحدث إصدار. |
| `aboutNewVersion` | Version {version} is available. | الإصدار {version} متاح. |
| `aboutInstall` | Download and install | تنزيل وتثبيت |
| `aboutTellMe` | Tell me about new versions | أخبرني بالإصدارات الجديدة |
| `aboutPrivacy` | Privacy | الخصوصية |
| `aboutPrivacyText` | Your data stays on this phone. YONCA collects nothing and has no analytics. The internet is used only to check for updates, to download them, and to back up to your own Google Drive if you turn that on. | تبقى بياناتك على هذا الهاتف. لا يجمع يونجا أي شيء ولا يستخدم أي تحليلات. يُستخدم الإنترنت فقط للتحقق من التحديثات وتنزيلها وللنسخ الاحتياطي إلى حساب Google Drive الخاص بك إذا فعّلت ذلك. |
| `aboutDeveloper` | About the developer | عن المطوّر |
| `aboutSendFeedback` | Send feedback | إرسال ملاحظات |
| `aboutFooter` | Designed and developed with ♥ by Mahmoud Damer | صمّمه وطوّره محمود دامر لكم بكل حب ♥ |
| `aboutDevName` | Mahmoud Damer | محمود دامر |
| `aboutDevBio` | (bio written by Mahmoud) | (نبذة يكتبها محمود) |
| `updDownloading` | Downloading… {percent}% | جارٍ التنزيل… {percent}% |
| `updVerifying` | Checking the file… | جارٍ التحقق من الملف… |
| `updReady` | Ready to install | جاهز للتثبيت |
| `updWhatsNew` | What's new | الجديد |
| `bkSignIn` | Sign in with Google | تسجيل الدخول باستخدام Google |
| `bkWifiOnly` | Back up only on Wi-Fi | النسخ الاحتياطي عبر Wi-Fi فقط |
| `bkSaveFile` | Save a backup file | حفظ ملف نسخة احتياطية |
| `bkLast` | Last backup: {date} | آخر نسخة احتياطية: {date} |
| `bkNever` | No backup yet | لا توجد نسخة احتياطية بعد |

### G10. Onboarding

| Key | English | Arabic |
|---|---|---|
| `obWelcome` | Welcome to YONCA | أهلًا بك في يونجا |
| `obLanguage` | Choose your language | اختر لغتك |
| `obNumbersDates` | Numbers and dates | الأرقام والتواريخ |
| `obCurrency` | Choose your main currency | اختر عملتك الأساسية |
| `obTheme` | Choose how YONCA looks | اختر شكل يونجا |
| `obProfile` | Tell us about you (optional) | عرّفنا بنفسك (اختياري) |
| `obImport` | Import contacts from your phone now? | هل تريد استيراد جهات الاتصال من هاتفك الآن؟ |
| `obReminders` | Allow reminders | السماح بالتذكيرات |
| `obSkip` / `Next` / `Back` / `Done` | Skip / Next / Back / Done | تخطي / التالي / رجوع / تم |
| `obChangeLater` | You can change this later in Settings. | يمكنك تغيير هذا لاحقًا من الإعدادات. |

### G11. Common labels

| Key | English | Arabic |
|---|---|---|
| `tabHome` / `Contacts` / `Calendar` / `Deals` / `More` | Home / Contacts / Calendar / Deals / More | الرئيسية / جهات الاتصال / التقويم / الصفقات / المزيد |
| `ratingHot` / `Warm` / `Cold` / `Unrated` | Hot / Warm / Cold / Unrated | ساخن / دافئ / بارد / بلا تقييم |
| `roleLead` / `Client` / `Supplier` | Lead / Client / Supplier | عميل محتمل / عميل / مورّد |
| `actLog` | Log activity | تسجيل نشاط |
| `actCall` / `Visit` / `Message` / `Note` | Call / Visit / Message / Note | مكالمة / زيارة / رسالة / ملاحظة |
| `outInterested` / `NeedsTime` / `NotInterested` / `NoAnswer` | Interested / Needs time / Not interested / No answer | مهتم / يحتاج وقتًا / غير مهتم / لا إجابة |
| `stageNew` etc. | (default stages set by Mahmoud, editable) | (المراحل الافتراضية يحددها محمود) |
| `stageWon` / `Lost` | Won / Lost | رابحة / خاسرة |
| `prioHigh` / `Normal` / `Low` | High / Normal / Low | عالية / عادية / منخفضة |
| `meetInPerson` / `Phone` / `Video` | In person / Phone / Video | حضوري / هاتفي / عبر الفيديو |
| `repeatNone` / `Daily` / `Weekly` / `Monthly` / `Yearly` | Never / Daily / Weekly / Monthly / Every year | بلا تكرار / يوميًا / أسبوعيًا / شهريًا / كل سنة |
| `lblToday` / `Yesterday` / `Tomorrow` | Today / Yesterday / Tomorrow | اليوم / أمس / غدًا |
| `lblOverdue` / `Upcoming` / `ToComplete` / `NeedsAttention` | Overdue / Upcoming / To complete / Needs attention | متأخر / قادم / للاستكمال / يحتاج انتباهًا |
| `lblRecentActivity` / `ViewMore` | Recent activity / View more | آخر الأنشطة / عرض المزيد |
| `lblSave` / `Cancel` / `Delete` / `Edit` / `Share` / `Done` | Save / Cancel / Delete / Edit / Share / Done | حفظ / إلغاء / حذف / تعديل / مشاركة / تم |
| `lblWhatsApp` / `Call` / `Email` / `Map` | WhatsApp / Call / Email / Map | واتساب / اتصال / بريد / خريطة |
| `lblTemporaryNote` | Temporary note | ملاحظة مؤقتة |
| `lblRequirements` | Requirements | المتطلبات |
| `lblSearch` | Search | بحث |
| `greetMorning` / `Afternoon` / `Evening` | Good morning / Good afternoon / Good evening | صباح الخير / مساء الخير / مساء الخير |


---

## H. Open questions and risks

### H1. Open questions for Mahmoud
Q1, Q2, Q5, Q6, Q7 were answered on 2026-10-26: Mahmoud accepted the recommended defaults (Q7: he asked Claude to choose; Android 8.0 chosen because it covers almost all phones in use and gives the notification and adaptive-icon features the app needs). Q4 is accepted as a draft; Mahmoud will review the Arabic later, and it does not block the screen design. Q3 (bio and links) is still open and uses placeholders. The rest keep their defaults.

| # | Question | Default until answered |
|---|---|---|
| Q1 | Default deal stages (names and order, between the fixed Won and Lost) | **Decided:** New, Contacted, Offer sent, Negotiation |
| Q2 | Default list of lost reasons | **Decided:** Price, Chose a competitor, No budget, No response, Other |
| Q3 | Short bio, contact links (email, WhatsApp, website, LinkedIn) and his photo placement for About the developer, in English and Arabic | Placeholder text; photo `me.jpg` bundled |
| Q4 | Review of every Arabic message in section G (all Arabic is a first draft) | Draft text used |
| Q5 | Default inactivity days per rating (Hot, Warm, Cold, Unrated) | **Decided:** Hot 7, Warm 14, Cold 30, Unrated 30 (changeable in Settings) |
| Q6 | Should the app ask for the call-log permission to offer "Log this call?" — it needs sensitive access that Google Play would restrict, but sideloaded APKs are not restricted | **Decided:** offer it as an optional switch in Settings, off by default |
| Q7 | Minimum Android version | **Decided: Android 8.0 (API 26)** |
| Q8 | Which 12 theme swatch colours to show | Chosen from the logo greens, the fallback brown and 10 spread hues |
| Q9 | The exact outcome names in Arabic | See G11; Mahmoud to confirm |
| Q10 | The GitHub repository name and landing page address | Not needed until M11 |
| Q11 | Whether the temporary-note reminder stops during meetings or only in quiet hours | Quiet hours only |
| Q12 | App display name in Arabic | **Decided: يونجا** (Arabic UI and launcher name in Arabic; "يونجا" in English) |

### H2. Risks

| # | Risk | What could go wrong | What we do |
|---|---|---|---|
| R1 | **Alarms blocked by phone makers** | Some brands (Xiaomi, Huawei, Oppo, Samsung power saving) stop background alarms and full-screen alerts. The user misses a meeting. The main promise ("never miss anything") breaks. | Test on a real phone in M0. Settings has a check list and a Test alarm. Add a setup guide per brand later. Missed alarms always leave a persistent notification and a Bell item. |
| R2 | **Android 14+ permissions** | Full-screen alerts and exact alarms need user permissions that can be turned off. | Ask clearly in onboarding and Settings; show a banner when off. |
| R3 | **Signing key loss** | If the release key is lost, nobody can update the app; users must uninstall and lose data. | Back up the key in two places before the first release. Never change it. |
| R4 | **versionCode not increased** | Android refuses the update. | The release workflow checks that versionCode is higher and stops otherwise. |
| R5 | **Drive sign-in breaks** | If the key's SHA-1 is not registered in Google Cloud, sign-in fails. | Register SHA-1 once; keep the same key. File backup is always available. |
| R6 | **Data loss** | Everything is only on the phone. A lost phone loses the business. | Default weekly backup after sign-in; reminder at 14 days; backup before updates and merges; restore makes a safety copy. |
| R7 | **Scope size** | The v1 list is very large. Risk of a long build and bugs. | Fixed milestones M0–M13, each installable. Review after each. Do not add features during a milestone. |
| R8 | **Arabic quality** | Wrong plural forms, broken mixed text, wrong shaping in PDF. | ICU plurals with all six forms; bidi isolation; a test checklist in Arabic for every screen; Mahmoud reviews Arabic text. |
| R9 | **Large data** | Unlimited contacts, files and voice notes can fill the phone. | Storage line in Backup and data; lists load in pages; files are compressed (photos); search uses an index. |
| R10 | **Backup size and time** | Backups with many files may be big. | Backup includes files; show size; Wi-Fi only; progress and resume. |
| R11 | **Imported or QR data** | A QR from someone else could contain unexpected text. | Always show the review screen before saving; treat text as plain text; never open links automatically. |
| R12 | **Privacy of exported files** | Reports and CSV hold client data and travel through other apps. | Reminder line before sharing; password option for backup files. |
| R13 | **Install unknown apps** | The update system needs a risky-sounding permission. | Explain it plainly; verify SHA-256; only download from the app's own release page. |
| R14 | **Dynamic colour contrast** | The phone's colours or a chosen colour may give weak contrast. | Contrast guard (E1); high-contrast mode; test in light, dark and high contrast. |
| R15 | **Widgets** | Native Android widgets are extra work and hard in Flutter. | Last milestone (M13); can be dropped without hurting the rest. |
| R16 | **Phone-book import duplicates** | Many duplicates after import. | Duplicate flag before import and the Duplicates and merge screen. |
| R17 | **Small-screen layouts** | Dense screens (contact details, forms) may overflow at 130% text. | Test at 130% and on a 360dp-wide phone. |
| R18 | **No play-store review** | No outside check of the app; crashes are only reported if the user sends them. | Crash prompt; keep an error-code list. |
| R19 | **Single developer** | Only Mahmoud tests. | Clear test checklists per milestone are part of each milestone. |

### H3. Decisions that must not be reopened without a strong reason
Navigation (Home, Contacts, Calendar, Deals, More); quick add = name, phone, temporary note; contact tabs order (Timeline, Schedule, Deals, Files, Details); one Add FAB with Log activity, Deal, Meeting, Task; read-only sheets; Note is an activity type; outcomes = fixed title + description; offline-first with Drive backup; no currency conversion; Won and Lost fixed; no custom hex for tags or stages; colour never the only signal; Arabic first-class; Gregorian only; 130% text size limit; install and update method copied from Pill Box.

### H4. Next steps
1. Mahmoud reads this file and answers H1.
2. Screen designs: start from section C. Mahmoud confirms each group of screens.
3. After confirmation, the AI coding assistant starts at M0, one milestone at a time. After each milestone Mahmoud installs and tests the APK.

---

## I. Build notes (M3–M10)

What each milestone built, and what was left out on purpose. Items marked **not built** are still open.

| Milestone | Built | Not built |
|---|---|---|
| M3 Calendar | Tasks, meetings, repeat, reminders (notifications), Agenda / Month / Tasks views, schedule tab on a contact | Full-screen alarm screen, quiet hours, Bell inbox, Week view |
| M4 Deals | Stages (add, rename, tint, reorder, remove, restore), deals, move, win (Lead becomes Client), lose with reason, documents, deals tab on a contact | Month filter on Won/Lost pages, stage-change entries on the Timeline |
| M5 Home and search | Home (greeting, quick actions, targets, overdue/today/soon, needs attention, recent, pipeline, activity), global search | Follow-up task prompt after logging an activity, Upcoming block on global Timeline |
| M6 Reports and fields | Custom fields (types, required, archive), values on contacts, Reports to PDF and CSV, presets | Custom-field filters in the Contacts list |
| M7 Stats and targets | Stats page (week/month), targets and progress | — |
| M8 Import / QR / merge | Phone-book import, duplicates and merge, multi-select with share and bulk edit, vCard share, QR show and scan, My profile | — |
| M9 Data | Storage use, backup zip (share to Drive or anywhere), restore (applied on next start, after a safety check), CSV and vCard export, delete everything | Direct Google Drive sign-in and weekly auto-backup (needs Google Cloud credentials), password for backup files |
| M10 Look and first run | Onboarding (3 pages, language), Settings with groups and search, colour choice (5), high contrast, About and developer line, grouped More tab | Arabic font and month-name choice, digit choice, crash report prompt, About links and full bio (Mahmoud writes these) |

Restore flow: the backup is unpacked into `restore_pending/` and swapped in the next time the app opens, before the database is opened.
