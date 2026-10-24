import 'package:flutter/foundation.dart';

import '../../../core/utils/cove_currency_formatter.dart';

/// Visual & semantic role of a span inside the Day Letter (`design/specs/11-day-letter.md`).
enum LetterSpanStyle {
  plain,
  link,
  italic,
}

/// Destination kind for a tappable link (or section reference) in the Day Letter.
enum LetterTargetKind {
  calendarSection,
  event,
  habitsSection,
  habit,
  expensesSection,
  expense,
  commitmentsSection,
  commitment,
  listsSection,
  list,
  person,
}

/// Navigation target attached to a [LetterSpan].
@immutable
class LetterTarget {
  final LetterTargetKind kind;
  final String? id;

  const LetterTarget({
    required this.kind,
    this.id,
  });

  const LetterTarget.calendarSection()
    : kind = LetterTargetKind.calendarSection,
      id = null;

  const LetterTarget.event(String this.id) : kind = LetterTargetKind.event;

  const LetterTarget.habitsSection()
    : kind = LetterTargetKind.habitsSection,
      id = null;

  const LetterTarget.habit(String this.id) : kind = LetterTargetKind.habit;

  const LetterTarget.expensesSection()
    : kind = LetterTargetKind.expensesSection,
      id = null;

  const LetterTarget.expense(String this.id) : kind = LetterTargetKind.expense;

  const LetterTarget.commitmentsSection()
    : kind = LetterTargetKind.commitmentsSection,
      id = null;

  const LetterTarget.commitment(String this.id)
    : kind = LetterTargetKind.commitment;

  const LetterTarget.listsSection()
    : kind = LetterTargetKind.listsSection,
      id = null;

  const LetterTarget.list(String this.id) : kind = LetterTargetKind.list;

  const LetterTarget.person(String this.id) : kind = LetterTargetKind.person;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LetterTarget && other.kind == kind && other.id == id;
  }

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() =>
      id == null ? 'LetterTarget(${kind.name})' : 'LetterTarget(${kind.name}, $id)';
}

/// A single styled span of the Day Letter (`{text, style: plain | link | italic, target?}`).
@immutable
class LetterSpan {
  final String text;
  final LetterSpanStyle style;
  final LetterTarget? target;

  /// True for the first-run empty-home prompt, which renders in italic `text.tertiary`.
  final bool isTertiary;

  const LetterSpan({
    required this.text,
    this.style = LetterSpanStyle.plain,
    this.target,
    this.isTertiary = false,
  }) : assert(
         style != LetterSpanStyle.link || target != null,
         'Every link span in the Letter must carry a non-null target.',
       );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LetterSpan &&
        other.text == text &&
        other.style == style &&
        other.target == target &&
        other.isTertiary == isTertiary;
  }

  @override
  int get hashCode => Object.hash(text, style, target, isTertiary);

  @override
  String toString() =>
      'LetterSpan("$text", ${style.name}${target != null ? ', $target' : ''}${isTertiary ? ', tertiary' : ''})';
}

/// A calendar event occurring on the day described by the Letter.
@immutable
class DayLetterEvent {
  final String id;
  final String title;
  final DateTime startTime;
  final bool isAllDay;

  const DayLetterEvent({
    required this.id,
    required this.title,
    required this.startTime,
    this.isAllDay = false,
  });
}

/// A habit scheduled on the day described by the Letter.
@immutable
class DayLetterHabit {
  final String id;
  final String title;
  final bool doneByYou;
  final bool doneByPartner;
  final bool isShared;

  const DayLetterHabit({
    required this.id,
    required this.title,
    this.doneByYou = false,
    this.doneByPartner = false,
    this.isShared = true,
  });

  /// True when a shared habit has been completed by both partners today.
  bool get isDoneByBoth => isShared && doneByYou && doneByPartner;

  /// True when the habit is completed for today.
  bool get isDone => isShared ? (doneByYou && doneByPartner) : doneByYou;

  /// True when at least one check-in was recorded today.
  bool get hasAnyCheckIn => doneByYou || doneByPartner;
}

/// An expense recorded on the day described by the Letter.
@immutable
class DayLetterExpense {
  final String id;
  final String title;
  final double amount;

  const DayLetterExpense({
    required this.id,
    required this.title,
    required this.amount,
  });
}

/// A commitment surfaced in the Letter, with its explicit [dueDate].
@immutable
class DayLetterCommitment {
  final String id;
  final String title;
  final double amount;
  final DateTime dueDate;

  const DayLetterCommitment({
    required this.id,
    required this.title,
    required this.amount,
    required this.dueDate,
  });
}

/// A list with open items surfaced at the end of the Letter.
@immutable
class DayLetterList {
  final String id;
  final String name;
  final int openCount;

  const DayLetterList({
    required this.id,
    required this.name,
    required this.openCount,
  });
}

/// Complete, clock-explicit input for [composeDayLetter].
@immutable
class DayLetterInput {
  final DateTime clock;
  final String currencySymbol;
  final bool isFirstRun;
  final String? partnerName;
  final List<DayLetterEvent> events;
  final List<DayLetterHabit> habits;
  final List<DayLetterExpense> expenses;
  final int tickedTaskCount;
  final List<DayLetterCommitment> commitmentsDue;
  final List<DayLetterList> openLists;

  const DayLetterInput({
    required this.clock,
    required this.currencySymbol,
    this.isFirstRun = false,
    this.partnerName,
    this.events = const <DayLetterEvent>[],
    this.habits = const <DayLetterHabit>[],
    this.expenses = const <DayLetterExpense>[],
    this.tickedTaskCount = 0,
    this.commitmentsDue = const <DayLetterCommitment>[],
    this.openLists = const <DayLetterList>[],
  });

  const DayLetterInput.firstRun({
    required this.clock,
    required this.currencySymbol,
    this.partnerName,
  }) : isFirstRun = true,
       events = const <DayLetterEvent>[],
       habits = const <DayLetterHabit>[],
       expenses = const <DayLetterExpense>[],
       tickedTaskCount = 0,
       commitmentsDue = const <DayLetterCommitment>[],
       openLists = const <DayLetterList>[];
}

const List<String> _kWeekdayNames = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const List<String> _kSmallNumberWordsLower = <String>[
  'zero',
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
];

const List<String> _kSmallNumberWordsUpper = <String>[
  'Zero',
  'One',
  'Two',
  'Three',
  'Four',
  'Five',
  'Six',
  'Seven',
  'Eight',
  'Nine',
];

const List<String> _kHourWords = <String>[
  'twelve',
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
  'ten',
  'eleven',
  'twelve',
];

final RegExp _kCompoundTitlePunctuation = RegExp(r'[—–,;]');

/// Formats numbers 1–9 as words and 10+ as digits per `design/specs/11-day-letter.md`.
String formatLetterNumber(int value, {bool capitalize = false}) {
  if (value >= 1 && value <= 9) {
    return capitalize
        ? _kSmallNumberWordsUpper[value]
        : _kSmallNumberWordsLower[value];
  }
  return '$value';
}

/// Returns the part of the day relative to today:
/// - `< 12:00` → `"this morning"`
/// - `12:00–16:59` → `"this afternoon"`
/// - `17:00–20:59` → `"this evening"`
/// - `21:00+` → `"tonight"`
String formatLetterDayPart(DateTime time) {
  final hour = time.hour;
  if (hour < 12) return 'this morning';
  if (hour < 17) return 'this afternoon';
  if (hour < 21) return 'this evening';
  return 'tonight';
}

/// Formats a time on the hour as words ("at seven this evening") and otherwise
/// as digits ("at 7:30 this morning").
String formatLetterTime(DateTime time) {
  final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final dayPart = formatLetterDayPart(time);
  if (time.minute == 0) {
    return 'at ${_kHourWords[hour12]} $dayPart';
  }
  final minutePadded = time.minute.toString().padLeft(2, '0');
  return 'at $hour12:$minutePadded $dayPart';
}

/// Pure, deterministic composer for the Day Letter (`design/specs/11-day-letter.md`).
///
/// Produces up to six sentences in fixed order:
/// 1. The day ("A clear/quiet/full/busy {Weekday}.")
/// 2. The calendar ("Nothing on the calendar." / "One thing..." / "{N} things...")
/// 3. Habits ("{habit} is done for both of you." / "{done} done; {waiting} still waiting.")
/// 4. Money ("{total} went out today[, most of it ...].")
/// 5. Commitments ("{sum} of commitments goes out today/tomorrow." / "₹X goes out today and ₹Y tomorrow.")
/// 6. Lists in italic ("{N} line(s) is/are still on the {list} list." / "...still on your lists.")
List<LetterSpan> composeDayLetter(DayLetterInput input) {
  if (input.isFirstRun) {
    return const <LetterSpan>[
      LetterSpan(
        text: 'The letter writes itself once there is a day to read.',
        style: LetterSpanStyle.italic,
        isTertiary: true,
      ),
    ];
  }

  final sentences = <List<LetterSpan>>[];

  // 1. The day
  sentences.add(_composeDaySentence(input));

  // 2. The calendar
  sentences.add(_composeCalendarSentence(input.events));

  // 3. Habits (omitted when no habits are scheduled today)
  final habitsSentence = _composeHabitsSentence(input.habits);
  if (habitsSentence.isNotEmpty) {
    sentences.add(habitsSentence);
  }

  // 4. Money (omitted at 0)
  final moneySentence = _composeMoneySentence(
    input.expenses,
    input.currencySymbol,
  );
  if (moneySentence.isNotEmpty) {
    sentences.add(moneySentence);
  }

  // 5. Commitments (filtered against input.clock for today vs tomorrow)
  final commitmentsSentence = _composeCommitmentsSentence(
    input.commitmentsDue,
    input.clock,
    input.currencySymbol,
  );
  if (commitmentsSentence.isNotEmpty) {
    sentences.add(commitmentsSentence);
  }

  // 6. Lists (italic, omitted when no open items)
  final listsSentence = _composeListsSentence(input.openLists);
  if (listsSentence.isNotEmpty) {
    sentences.add(listsSentence);
  }

  final rawSpans = <LetterSpan>[];
  for (var i = 0; i < sentences.length; i++) {
    if (i > 0) {
      rawSpans.add(const LetterSpan(text: ' '));
    }
    rawSpans.addAll(sentences[i]);
  }

  return _coalescePlainSpans(rawSpans);
}

List<LetterSpan> _composeDaySentence(DayLetterInput input) {
  final weekday = _kWeekdayNames[(input.clock.weekday - 1).clamp(0, 6)];
  final positiveExpensesCount = input.expenses
      .where((e) => e.amount > 0)
      .length;
  final habitCheckInsCount = input.habits.where((h) => h.hasAnyCheckIn).length;
  final things =
      input.events.length +
      positiveExpensesCount +
      input.tickedTaskCount +
      habitCheckInsCount;

  final String adjective;
  if (things <= 0) {
    adjective = 'clear';
  } else if (things <= 2) {
    adjective = 'quiet';
  } else if (things <= 6) {
    adjective = 'full';
  } else {
    adjective = 'busy';
  }

  return <LetterSpan>[
    LetterSpan(text: 'A $adjective $weekday.'),
  ];
}

List<LetterSpan> _composeCalendarSentence(List<DayLetterEvent> events) {
  if (events.isEmpty) {
    return const <LetterSpan>[
      LetterSpan(text: 'Nothing on the calendar.'),
    ];
  }

  final sorted = List<DayLetterEvent>.of(events)
    ..sort((a, b) => a.startTime.compareTo(b.startTime));

  if (sorted.length == 1) {
    final event = sorted.first;
    final timeClause = event.isAllDay
        ? 'all day'
        : formatLetterTime(event.startTime);
    return <LetterSpan>[
      const LetterSpan(text: 'One thing on the calendar — '),
      LetterSpan(
        text: event.title,
        style: LetterSpanStyle.link,
        target: LetterTarget.event(event.id),
      ),
      LetterSpan(text: ' $timeClause.'),
    ];
  }

  final first = sorted.first;
  final countText = formatLetterNumber(sorted.length, capitalize: true);
  final timeClause = first.isAllDay
      ? 'all day'
      : formatLetterTime(first.startTime);
  return <LetterSpan>[
    LetterSpan(
      text: '$countText things on the calendar',
      style: LetterSpanStyle.link,
      target: const LetterTarget.calendarSection(),
    ),
    LetterSpan(text: ', the first $timeClause.'),
  ];
}

List<LetterSpan> _composeHabitsSentence(List<DayLetterHabit> habits) {
  if (habits.isEmpty) {
    return const <LetterSpan>[];
  }

  final allDoneByBoth = habits.every((h) => h.isDoneByBoth);
  if (allDoneByBoth) {
    if (habits.length == 1) {
      final only = habits.first;
      return <LetterSpan>[
        LetterSpan(
          text: only.title,
          style: LetterSpanStyle.link,
          target: LetterTarget.habit(only.id),
        ),
        const LetterSpan(text: ' is done for both of you.'),
      ];
    }
    return <LetterSpan>[
      ..._buildHabitGroupSpans(habits),
      const LetterSpan(text: ' are done for both of you.'),
    ];
  }

  final done = habits.where((h) => h.isDone).toList();
  final waiting = habits.where((h) => !h.isDone).toList();

  if (done.isNotEmpty && waiting.isNotEmpty) {
    return <LetterSpan>[
      ..._buildHabitGroupSpans(done),
      const LetterSpan(text: ' done; '),
      ..._buildHabitGroupSpans(waiting),
      const LetterSpan(text: ' still waiting.'),
    ];
  }

  if (done.isNotEmpty) {
    return <LetterSpan>[
      ..._buildHabitGroupSpans(done),
      const LetterSpan(text: ' done.'),
    ];
  }

  return <LetterSpan>[
    ..._buildHabitGroupSpans(waiting),
    const LetterSpan(text: ' still waiting.'),
  ];
}

/// Names at most two habits verbatim as links, then "and {N} more".
List<LetterSpan> _buildHabitGroupSpans(List<DayLetterHabit> group) {
  if (group.isEmpty) return const <LetterSpan>[];
  if (group.length == 1) {
    return <LetterSpan>[
      LetterSpan(
        text: group.first.title,
        style: LetterSpanStyle.link,
        target: LetterTarget.habit(group.first.id),
      ),
    ];
  }
  if (group.length == 2) {
    return <LetterSpan>[
      LetterSpan(
        text: group[0].title,
        style: LetterSpanStyle.link,
        target: LetterTarget.habit(group[0].id),
      ),
      const LetterSpan(text: ' and '),
      LetterSpan(
        text: group[1].title,
        style: LetterSpanStyle.link,
        target: LetterTarget.habit(group[1].id),
      ),
    ];
  }

  final extra = formatLetterNumber(group.length - 2);
  return <LetterSpan>[
    LetterSpan(
      text: group[0].title,
      style: LetterSpanStyle.link,
      target: LetterTarget.habit(group[0].id),
    ),
    const LetterSpan(text: ', '),
    LetterSpan(
      text: group[1].title,
      style: LetterSpanStyle.link,
      target: LetterTarget.habit(group[1].id),
    ),
    LetterSpan(text: ' and $extra more'),
  ];
}

bool _hasCompoundPunctuation(String title) =>
    _kCompoundTitlePunctuation.hasMatch(title);

List<LetterSpan> _composeMoneySentence(
  List<DayLetterExpense> expenses,
  String currencySymbol,
) {
  final positive = expenses.where((e) => e.amount > 0).toList();
  if (positive.isEmpty) {
    return const <LetterSpan>[];
  }

  final total = positive.fold<double>(0.0, (sum, e) => sum + e.amount);
  if (total <= 0) {
    return const <LetterSpan>[];
  }

  // Stable descending sort by amount so ties preserve input order deterministically.
  final indexed = positive.asMap().entries.toList()
    ..sort((a, b) {
      final cmp = b.value.amount.compareTo(a.value.amount);
      return cmp != 0 ? cmp : a.key.compareTo(b.key);
    });
  final sorted = indexed.map((e) => e.value).toList();

  final totalText = formatCoveCurrency(total, currencySymbol);
  final spans = <LetterSpan>[
    LetterSpan(
      text: totalText,
      style: LetterSpanStyle.link,
      target: const LetterTarget.expensesSection(),
    ),
    const LetterSpan(text: ' went out today'),
  ];

  final top1 = sorted.first;
  if (top1.amount * 100.0 >= total * 50.0) {
    spans.addAll(<LetterSpan>[
      const LetterSpan(text: ', most of it '),
      LetterSpan(
        text: top1.title,
        style: LetterSpanStyle.link,
        target: LetterTarget.expense(top1.id),
      ),
    ]);
  } else if (sorted.length >= 2 &&
      (sorted[0].amount + sorted[1].amount) * 100.0 >= total * 75.0) {
    final first = sorted[0];
    final second = sorted[1];
    final canJoinBoth =
        !_hasCompoundPunctuation(first.title) &&
        !_hasCompoundPunctuation(second.title);

    if (canJoinBoth) {
      spans.addAll(<LetterSpan>[
        const LetterSpan(text: ', most of it '),
        LetterSpan(
          text: first.title,
          style: LetterSpanStyle.link,
          target: LetterTarget.expense(first.id),
        ),
        const LetterSpan(text: ' and '),
        LetterSpan(
          text: second.title,
          style: LetterSpanStyle.link,
          target: LetterTarget.expense(second.id),
        ),
      ]);
    } else {
      spans.addAll(<LetterSpan>[
        const LetterSpan(text: ', most of it '),
        LetterSpan(
          text: first.title,
          style: LetterSpanStyle.link,
          target: LetterTarget.expense(first.id),
        ),
      ]);
    }
  }

  spans.add(const LetterSpan(text: '.'));
  return spans;
}

bool _isSameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

List<LetterSpan> _composeCommitmentsSentence(
  List<DayLetterCommitment> commitmentsDue,
  DateTime clock,
  String currencySymbol,
) {
  final todayDate = DateTime(clock.year, clock.month, clock.day);
  final tomorrowDate = DateTime(clock.year, clock.month, clock.day + 1);

  final dueToday = commitmentsDue
      .where((c) => c.amount > 0 && _isSameCalendarDay(c.dueDate, todayDate))
      .toList();
  final dueTomorrow = commitmentsDue
      .where((c) => c.amount > 0 && _isSameCalendarDay(c.dueDate, tomorrowDate))
      .toList();

  final sumToday = dueToday.fold<double>(0.0, (acc, c) => acc + c.amount);
  final sumTomorrow = dueTomorrow.fold<double>(0.0, (acc, c) => acc + c.amount);

  if (sumToday <= 0 && sumTomorrow <= 0) {
    return const <LetterSpan>[];
  }

  LetterTarget targetFor(List<DayLetterCommitment> items) => items.length == 1
      ? LetterTarget.commitment(items.first.id)
      : const LetterTarget.commitmentsSection();

  if (sumToday > 0 && sumTomorrow > 0) {
    return <LetterSpan>[
      LetterSpan(
        text: formatCoveCurrency(sumToday, currencySymbol),
        style: LetterSpanStyle.link,
        target: targetFor(dueToday),
      ),
      const LetterSpan(text: ' goes out today and '),
      LetterSpan(
        text: formatCoveCurrency(sumTomorrow, currencySymbol),
        style: LetterSpanStyle.link,
        target: targetFor(dueTomorrow),
      ),
      const LetterSpan(text: ' tomorrow.'),
    ];
  }

  if (sumToday > 0) {
    return <LetterSpan>[
      LetterSpan(
        text: formatCoveCurrency(sumToday, currencySymbol),
        style: LetterSpanStyle.link,
        target: targetFor(dueToday),
      ),
      const LetterSpan(text: ' of commitments goes out today.'),
    ];
  }

  return <LetterSpan>[
    LetterSpan(
      text: formatCoveCurrency(sumTomorrow, currencySymbol),
      style: LetterSpanStyle.link,
      target: targetFor(dueTomorrow),
    ),
    const LetterSpan(text: ' of commitments goes out tomorrow.'),
  ];
}

List<LetterSpan> _composeListsSentence(List<DayLetterList> openLists) {
  final active = openLists.where((l) => l.openCount > 0).toList();
  if (active.isEmpty) {
    return const <LetterSpan>[];
  }

  final totalOpen = active.fold<int>(0, (sum, l) => sum + l.openCount);
  final countWord = formatLetterNumber(totalOpen, capitalize: true);
  final nounAndVerb = totalOpen == 1 ? 'line is' : 'lines are';

  if (active.length == 1) {
    final list = active.first;
    return <LetterSpan>[
      LetterSpan(
        text: '$countWord $nounAndVerb still on the ${list.name} list.',
        style: LetterSpanStyle.italic,
        target: LetterTarget.list(list.id),
      ),
    ];
  }

  return <LetterSpan>[
    LetterSpan(
      text: '$countWord $nounAndVerb still on your lists.',
      style: LetterSpanStyle.italic,
      target: const LetterTarget.listsSection(),
    ),
  ];
}

List<LetterSpan> _coalescePlainSpans(List<LetterSpan> spans) {
  if (spans.isEmpty) return const <LetterSpan>[];
  final merged = <LetterSpan>[];
  for (final span in spans) {
    if (span.text.isEmpty) continue;
    if (merged.isNotEmpty &&
        merged.last.style == LetterSpanStyle.plain &&
        span.style == LetterSpanStyle.plain &&
        merged.last.target == null &&
        span.target == null &&
        !merged.last.isTertiary &&
        !span.isTertiary) {
      merged[merged.length - 1] = LetterSpan(
        text: '${merged.last.text}${span.text}',
      );
    } else {
      merged.add(span);
    }
  }
  return List<LetterSpan>.unmodifiable(merged);
}
