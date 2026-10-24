import 'dart:io';

import 'package:cove/features/today/letter/compose_day_letter.dart';
import 'package:flutter_test/flutter_test.dart';

String _joinText(List<LetterSpan> spans) => spans.map((s) => s.text).join();

void main() {
  // Wednesday, 21 October 2026 at 09:41
  final wednesdayClock = DateTime(2026, 10, 21, 9, 41);
  final todayDate = DateTime(2026, 10, 21);
  final tomorrowDate = DateTime(2026, 10, 22);

  group('composeDayLetter — pure unit tests (design/specs/11-day-letter.md)', () {
    test('1. Empty first-run day renders italic tertiary prompt', () {
      final input = DayLetterInput.firstRun(
        clock: wednesdayClock,
        currencySymbol: '₹',
      );
      final spans = composeDayLetter(input);

      expect(spans, hasLength(1));
      expect(
        spans.single.text,
        equals('The letter writes itself once there is a day to read.'),
      );
      expect(spans.single.style, equals(LetterSpanStyle.italic));
      expect(spans.single.isTertiary, isTrue);
    });

    test('2. Clear day (0 things)', () {
      final input = DayLetterInput(
        clock: wednesdayClock,
        currencySymbol: '₹',
      );
      final spans = composeDayLetter(input);

      expect(
        _joinText(spans),
        equals('A clear Wednesday. Nothing on the calendar.'),
      );
      expect(spans, hasLength(1));
      expect(spans.single.style, equals(LetterSpanStyle.plain));
    });

    test('3. Quiet day matching the spec sentences (1–2 things)', () {
      final input = DayLetterInput(
        clock: wednesdayClock,
        currencySymbol: '₹',
        events: [
          DayLetterEvent(
            id: 'ev-amma',
            title: 'Call with Amma',
            startTime: DateTime(2026, 10, 21, 19, 0),
          ),
        ],
        habits: const [
          DayLetterHabit(
            id: 'hab-walk',
            title: 'Morning walk',
            doneByYou: true,
            doneByPartner: true,
          ),
          DayLetterHabit(
            id: 'hab-read',
            title: 'Read twenty pages',
            doneByYou: false,
            doneByPartner: false,
          ),
        ],
        commitmentsDue: [
          DayLetterCommitment(
            id: 'com-ac',
            title: 'AC — the instalment',
            amount: 3974,
            dueDate: tomorrowDate,
          ),
          DayLetterCommitment(
            id: 'com-car',
            title: 'Car insurance',
            amount: 4900,
            dueDate: tomorrowDate,
          ),
        ],
        openLists: const [
          DayLetterList(
            id: 'list-grocery',
            name: 'grocery',
            openCount: 2,
          ),
        ],
      );

      final spans = composeDayLetter(input);
      expect(
        _joinText(spans),
        equals(
          'A quiet Wednesday. '
          'One thing on the calendar — Call with Amma at seven this evening. '
          'Morning walk done; Read twenty pages still waiting. '
          '₹8,874 of commitments goes out tomorrow. '
          'Two lines are still on the grocery list.',
        ),
      );
      expect(spans.last.style, equals(LetterSpanStyle.italic));
      expect(
        spans.last.text,
        equals('Two lines are still on the grocery list.'),
      );
    });

    test('4. Busy day (7+ things, multiple events with non-hour time)', () {
      final input = DayLetterInput(
        clock: wednesdayClock,
        currencySymbol: '₹',
        events: [
          DayLetterEvent(
            id: 'ev-1',
            title: 'Dentist — Dr. Nair',
            startTime: DateTime(2026, 10, 21, 7, 30),
          ),
          DayLetterEvent(
            id: 'ev-2',
            title: 'Architect review',
            startTime: DateTime(2026, 10, 21, 11, 0),
          ),
          DayLetterEvent(
            id: 'ev-3',
            title: 'Call with Amma',
            startTime: DateTime(2026, 10, 21, 19, 0),
          ),
        ],
        habits: const [
          DayLetterHabit(
            id: 'hab-1',
            title: 'Morning walk',
            doneByYou: true,
            doneByPartner: true,
          ),
          DayLetterHabit(
            id: 'hab-2',
            title: 'Stretch',
            doneByYou: true,
            doneByPartner: true,
          ),
        ],
        expenses: const [
          DayLetterExpense(id: 'exp-1', title: 'Filter coffee', amount: 180),
          DayLetterExpense(id: 'exp-2', title: 'Metro top-up', amount: 200),
          DayLetterExpense(id: 'exp-3', title: 'Flowers', amount: 220),
        ],
        tickedTaskCount: 2,
      );

      final spans = composeDayLetter(input);
      // 3 events + 3 expenses + 2 ticked tasks + 2 habit check-ins = 10 things -> busy
      expect(
        _joinText(spans),
        equals(
          'A busy Wednesday. '
          'Three things on the calendar, the first at 7:30 this morning. '
          'Morning walk and Stretch are done for both of you. '
          '₹600 went out today.',
        ),
      );
    });

    test('5. Money with one dominant item (>= 50% of total)', () {
      final input = DayLetterInput(
        clock: wednesdayClock,
        currencySymbol: '₹',
        expenses: const [
          DayLetterExpense(
            id: 'exp-1',
            title: 'Namdhari’s — the big run',
            amount: 3200,
          ),
          DayLetterExpense(
            id: 'exp-2',
            title: 'Auto to the market',
            amount: 400,
          ),
        ],
      );

      final spans = composeDayLetter(input);
      expect(
        _joinText(spans),
        equals(
          'A quiet Wednesday. '
          'Nothing on the calendar. '
          '₹3,600 went out today, most of it Namdhari’s — the big run.',
        ),
      );
    });

    test('6. Money with two items over 75% (clean titles join with "and")', () {
      final input = DayLetterInput(
        clock: wednesdayClock,
        currencySymbol: '₹',
        expenses: const [
          DayLetterExpense(
            id: 'exp-gifts',
            title: 'Diwali gifts',
            amount: 2491,
          ),
          DayLetterExpense(
            id: 'exp-groceries',
            title: 'Fresh groceries',
            amount: 2640,
          ),
          DayLetterExpense(
            id: 'exp-auto',
            title: 'Auto to the market',
            amount: 500,
          ),
        ],
      );

      final spans = composeDayLetter(input);
      expect(
        _joinText(spans),
        equals(
          'A full Wednesday. '
          'Nothing on the calendar. '
          '₹5,631 went out today, most of it Fresh groceries and Diwali gifts.',
        ),
      );
    });

    test('7. Habits all done by both (single and multiple)', () {
      final singleDone = DayLetterInput(
        clock: wednesdayClock,
        currencySymbol: '₹',
        habits: const [
          DayLetterHabit(
            id: 'h-walk',
            title: 'Morning walk',
            doneByYou: true,
            doneByPartner: true,
          ),
        ],
      );
      expect(
        _joinText(composeDayLetter(singleDone)),
        equals(
          'A quiet Wednesday. '
          'Nothing on the calendar. '
          'Morning walk is done for both of you.',
        ),
      );

      final threeDone = DayLetterInput(
        clock: wednesdayClock,
        currencySymbol: '₹',
        habits: const [
          DayLetterHabit(
            id: 'h-1',
            title: 'Morning walk',
            doneByYou: true,
            doneByPartner: true,
          ),
          DayLetterHabit(
            id: 'h-2',
            title: 'Meditation',
            doneByYou: true,
            doneByPartner: true,
          ),
          DayLetterHabit(
            id: 'h-3',
            title: 'Vitamins',
            doneByYou: true,
            doneByPartner: true,
          ),
        ],
      );
      expect(
        _joinText(composeDayLetter(threeDone)),
        equals(
          'A full Wednesday. '
          'Nothing on the calendar. '
          'Morning walk, Meditation and one more are done for both of you.',
        ),
      );
    });

    test('8. Habits mixed (names at most two, then "and {N} more")', () {
      final input = DayLetterInput(
        clock: wednesdayClock,
        currencySymbol: '₹',
        habits: const [
          DayLetterHabit(
            id: 'h-1',
            title: 'Morning walk',
            doneByYou: true,
            doneByPartner: true,
          ),
          DayLetterHabit(
            id: 'h-2',
            title: 'Meditation',
            doneByYou: true,
            doneByPartner: true,
          ),
          DayLetterHabit(
            id: 'h-3',
            title: 'Vitamins',
            doneByYou: true,
            doneByPartner: true,
          ),
          DayLetterHabit(
            id: 'h-4',
            title: 'Read twenty pages',
            doneByYou: false,
            doneByPartner: false,
          ),
          DayLetterHabit(
            id: 'h-5',
            title: 'Journal',
            doneByYou: false,
            doneByPartner: true,
          ),
          DayLetterHabit(
            id: 'h-6',
            title: 'No screens after ten',
            doneByYou: false,
            doneByPartner: false,
          ),
        ],
      );

      final spans = composeDayLetter(input);
      expect(
        _joinText(spans),
        equals(
          'A full Wednesday. '
          'Nothing on the calendar. '
          'Morning walk, Meditation and one more done; '
          'Read twenty pages, Journal and one more still waiting.',
        ),
      );
    });

    test('9. Commitments due tomorrow', () {
      final input = DayLetterInput(
        clock: wednesdayClock,
        currencySymbol: '₹',
        commitmentsDue: [
          DayLetterCommitment(
            id: 'com-1',
            title: 'AC — the instalment',
            amount: 3974,
            dueDate: tomorrowDate,
          ),
          DayLetterCommitment(
            id: 'com-2',
            title: 'Car loan — HDFC',
            amount: 4900,
            dueDate: tomorrowDate,
          ),
        ],
      );

      final spans = composeDayLetter(input);
      expect(
        _joinText(spans),
        equals(
          'A clear Wednesday. '
          'Nothing on the calendar. '
          '₹8,874 of commitments goes out tomorrow.',
        ),
      );
    });

    test('10. Several lists ("…still on your lists." in italic)', () {
      final input = DayLetterInput(
        clock: wednesdayClock,
        currencySymbol: '₹',
        openLists: const [
          DayLetterList(id: 'l-1', name: 'grocery', openCount: 2),
          DayLetterList(id: 'l-2', name: 'hardware', openCount: 3),
        ],
      );

      final spans = composeDayLetter(input);
      expect(
        _joinText(spans),
        equals(
          'A clear Wednesday. '
          'Nothing on the calendar. '
          'Five lines are still on your lists.',
        ),
      );
      expect(spans.last.style, equals(LetterSpanStyle.italic));
      expect(spans.last.text, equals('Five lines are still on your lists.'));
    });

    test('11. Determinism: composing twice yields identical spans', () {
      final input = DayLetterInput(
        clock: wednesdayClock,
        currencySymbol: '₹',
        events: [
          DayLetterEvent(
            id: 'ev-1',
            title: 'Call with Amma',
            startTime: DateTime(2026, 10, 21, 19, 0),
          ),
        ],
        habits: const [
          DayLetterHabit(
            id: 'h-1',
            title: 'Morning walk',
            doneByYou: true,
            doneByPartner: true,
          ),
        ],
        expenses: const [
          DayLetterExpense(
            id: 'e-1',
            title: 'Namdhari’s — the big run',
            amount: 2640,
          ),
        ],
        commitmentsDue: [
          DayLetterCommitment(
            id: 'c-1',
            title: 'AC — the instalment',
            amount: 3974,
            dueDate: tomorrowDate,
          ),
        ],
        openLists: const [
          DayLetterList(id: 'l-1', name: 'grocery', openCount: 2),
        ],
      );

      final firstRun = composeDayLetter(input);
      final secondRun = composeDayLetter(input);
      expect(firstRun, equals(secondRun));
    });

    test('12. Every link span has a non-null target', () {
      final fixtures = <DayLetterInput>[
        DayLetterInput.firstRun(clock: wednesdayClock, currencySymbol: '₹'),
        DayLetterInput(clock: wednesdayClock, currencySymbol: '₹'),
        DayLetterInput(
          clock: wednesdayClock,
          currencySymbol: '₹',
          events: [
            DayLetterEvent(
              id: 'ev-1',
              title: 'Call with Amma',
              startTime: DateTime(2026, 10, 21, 19, 0),
            ),
          ],
          habits: const [
            DayLetterHabit(
              id: 'h-1',
              title: 'Morning walk',
              doneByYou: true,
              doneByPartner: true,
            ),
            DayLetterHabit(
              id: 'h-2',
              title: 'Read twenty pages',
              doneByYou: false,
              doneByPartner: false,
            ),
          ],
          expenses: const [
            DayLetterExpense(
              id: 'e-1',
              title: 'Diwali gifts',
              amount: 2491,
            ),
            DayLetterExpense(
              id: 'e-2',
              title: 'Fresh groceries',
              amount: 2640,
            ),
          ],
          commitmentsDue: [
            DayLetterCommitment(
              id: 'c-1',
              title: 'AC — the instalment',
              amount: 3974,
              dueDate: todayDate,
            ),
            DayLetterCommitment(
              id: 'c-2',
              title: 'Car loan',
              amount: 4900,
              dueDate: tomorrowDate,
            ),
          ],
          openLists: const [
            DayLetterList(id: 'l-1', name: 'grocery', openCount: 1),
          ],
        ),
        DayLetterInput(
          clock: wednesdayClock,
          currencySymbol: '₹',
          events: [
            DayLetterEvent(
              id: 'ev-1',
              title: 'Dentist',
              startTime: DateTime(2026, 10, 21, 10, 0),
            ),
            DayLetterEvent(
              id: 'ev-2',
              title: 'Architect',
              startTime: DateTime(2026, 10, 21, 14, 30),
            ),
          ],
        ),
      ];

      for (final fixture in fixtures) {
        final spans = composeDayLetter(fixture);
        final linkSpans = spans
            .where((s) => s.style == LetterSpanStyle.link)
            .toList();
        for (final link in linkSpans) {
          expect(
            link.target,
            isNotNull,
            reason: 'Link span "${link.text}" must carry a target.',
          );
        }
      }
    });

    test('13. Indian grouping on a lakh figure via formatCoveCurrency()', () {
      final input = DayLetterInput(
        clock: wednesdayClock,
        currencySymbol: '₹',
        expenses: const [
          DayLetterExpense(
            id: 'exp-jewellery',
            title: 'Tanishq gold coin',
            amount: 125000,
          ),
        ],
        commitmentsDue: [
          DayLetterCommitment(
            id: 'com-home',
            title: 'Home loan EMI',
            amount: 142500,
            dueDate: tomorrowDate,
          ),
        ],
      );

      final spans = composeDayLetter(input);
      final text = _joinText(spans);
      expect(text, contains('₹1,25,000 went out today'));
      expect(text, contains('₹1,42,500 of commitments goes out tomorrow.'));
    });

    test('14. Names are VERBATIM — odd casing and punctuation pass through unchanged', () {
      const oddEventTitle = 'Call with Amma — [URGENT?!] #2 (don\'t reschedule!)';
      const oddHabitTitle = 'mOrNiNg   wAlK :: 5km / Cubbon-Park!!';
      const oddExpenseTitle = 'Namdhari\'s — "THE BIG RUN" & Co. (₹₹)';
      const oddListName = 'Amma\'s   Diwali_Prep #1!!';

      final input = DayLetterInput(
        clock: wednesdayClock,
        currencySymbol: '₹',
        events: [
          DayLetterEvent(
            id: 'ev-odd',
            title: oddEventTitle,
            startTime: DateTime(2026, 10, 21, 19, 0),
          ),
        ],
        habits: const [
          DayLetterHabit(
            id: 'hab-odd',
            title: oddHabitTitle,
            doneByYou: true,
            doneByPartner: true,
          ),
        ],
        expenses: const [
          DayLetterExpense(
            id: 'exp-odd',
            title: oddExpenseTitle,
            amount: 1500,
          ),
        ],
        openLists: const [
          DayLetterList(
            id: 'list-odd',
            name: oddListName,
            openCount: 1,
          ),
        ],
      );

      final spans = composeDayLetter(input);
      final fullText = _joinText(spans);

      expect(fullText, contains(oddEventTitle));
      expect(fullText, contains(oddHabitTitle));
      expect(fullText, contains(oddExpenseTitle));
      expect(fullText, contains('One line is still on the $oddListName list.'));
      expect(
        spans.any(
          (s) => s.style == LetterSpanStyle.link && s.text == oddEventTitle,
        ),
        isTrue,
      );
      expect(
        spans.any(
          (s) => s.style == LetterSpanStyle.link && s.text == oddHabitTitle,
        ),
        isTrue,
      );
      expect(
        spans.any(
          (s) => s.style == LetterSpanStyle.link && s.text == oddExpenseTitle,
        ),
        isTrue,
      );
    });

    test('15. No DateTime.now() anywhere in lib/features/today/letter/', () {
      final letterDir = Directory('lib/features/today/letter');
      expect(letterDir.existsSync(), isTrue);

      final dartFiles = letterDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      expect(dartFiles, isNotEmpty);

      final forbiddenPattern = RegExp(r'DateTime\s*\.\s*now\s*\(');
      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        expect(
          forbiddenPattern.hasMatch(content),
          isFalse,
          reason: '${file.path} must not call or reference DateTime.now()',
        );
      }
    });

    test(
      '16. Correction 1 — Times include part of day ("this morning", "this afternoon", "this evening", "tonight")',
      () {
        final morning7 = composeDayLetter(
          DayLetterInput(
            clock: wednesdayClock,
            currencySymbol: '₹',
            events: [
              DayLetterEvent(
                id: 'ev-am',
                title: 'Yoga in the park',
                startTime: DateTime(2026, 10, 21, 7, 0),
              ),
            ],
          ),
        );
        expect(
          _joinText(morning7),
          equals(
            'A quiet Wednesday. '
            'One thing on the calendar — Yoga in the park at seven this morning.',
          ),
        );

        final afternoon = composeDayLetter(
          DayLetterInput(
            clock: wednesdayClock,
            currencySymbol: '₹',
            events: [
              DayLetterEvent(
                id: 'ev-pm',
                title: 'CA tax filing check-in',
                startTime: DateTime(2026, 10, 21, 14, 15),
              ),
            ],
          ),
        );
        expect(
          _joinText(afternoon),
          equals(
            'A quiet Wednesday. '
            'One thing on the calendar — CA tax filing check-in at 2:15 this afternoon.',
          ),
        );

        final evening = composeDayLetter(
          DayLetterInput(
            clock: wednesdayClock,
            currencySymbol: '₹',
            events: [
              DayLetterEvent(
                id: 'ev-eve',
                title: 'Call with Amma',
                startTime: DateTime(2026, 10, 21, 19, 0),
              ),
            ],
          ),
        );
        expect(
          _joinText(evening),
          equals(
            'A quiet Wednesday. '
            'One thing on the calendar — Call with Amma at seven this evening.',
          ),
        );

        final tonight = composeDayLetter(
          DayLetterInput(
            clock: wednesdayClock,
            currencySymbol: '₹',
            events: [
              DayLetterEvent(
                id: 'ev-night',
                title: 'Airport pickup',
                startTime: DateTime(2026, 10, 21, 21, 30),
              ),
            ],
          ),
        );
        expect(
          _joinText(tonight),
          equals(
            'A quiet Wednesday. '
            'One thing on the calendar — Airport pickup at 9:30 tonight.',
          ),
        );
      },
    );

    test(
      '17. Correction 2 — Commitments decide today vs tomorrow from clock, ignore other days, and combine when both exist',
      () {
        // Only today (plus an ignored commitment two days later)
        final onlyToday = composeDayLetter(
          DayLetterInput(
            clock: wednesdayClock,
            currencySymbol: '₹',
            commitmentsDue: [
              DayLetterCommitment(
                id: 'c-today',
                title: 'Broadband bill',
                amount: 1499,
                dueDate: todayDate,
              ),
              DayLetterCommitment(
                id: 'c-later',
                title: 'Rent',
                amount: 45000,
                dueDate: DateTime(2026, 10, 25),
              ),
            ],
          ),
        );
        expect(
          _joinText(onlyToday),
          equals(
            'A clear Wednesday. '
            'Nothing on the calendar. '
            '₹1,499 of commitments goes out today.',
          ),
        );

        // Both today and tomorrow (plus an ignored commitment from yesterday)
        final bothTodayAndTomorrow = composeDayLetter(
          DayLetterInput(
            clock: wednesdayClock,
            currencySymbol: '₹',
            commitmentsDue: [
              DayLetterCommitment(
                id: 'c-yesterday',
                title: 'Old bill',
                amount: 999,
                dueDate: DateTime(2026, 10, 20),
              ),
              DayLetterCommitment(
                id: 'c-today',
                title: 'Broadband bill',
                amount: 1499,
                dueDate: todayDate,
              ),
              DayLetterCommitment(
                id: 'c-tomorrow-1',
                title: 'AC — the instalment',
                amount: 3974,
                dueDate: tomorrowDate,
              ),
              DayLetterCommitment(
                id: 'c-tomorrow-2',
                title: 'Car insurance',
                amount: 4900,
                dueDate: tomorrowDate,
              ),
            ],
          ),
        );
        expect(
          _joinText(bothTodayAndTomorrow),
          equals(
            'A clear Wednesday. '
            'Nothing on the calendar. '
            '₹1,499 goes out today and ₹8,874 tomorrow.',
          ),
        );
      },
    );

    test(
      '18. Correction 3 — Required currencySymbol formats with the home currency (no silent ₹ fallback)',
      () {
        final usdLetter = composeDayLetter(
          DayLetterInput(
            clock: wednesdayClock,
            currencySymbol: '\$',
            expenses: const [
              DayLetterExpense(
                id: 'e-1',
                title: 'Trader Joe’s',
                amount: 185,
              ),
            ],
            commitmentsDue: [
              DayLetterCommitment(
                id: 'c-1',
                title: 'PG&E utility',
                amount: 240,
                dueDate: tomorrowDate,
              ),
            ],
          ),
        );

        expect(
          _joinText(usdLetter),
          equals(
            'A quiet Wednesday. '
            'Nothing on the calendar. '
            '\$185 went out today, most of it Trader Joe’s. '
            '\$240 of commitments goes out tomorrow.',
          ),
        );
      },
    );

    test(
      '19. Correction 4 — Money with two items >= 75% names only the larger one when either contains —, –, comma, or semicolon',
      () {
        final withPunctuation = composeDayLetter(
          DayLetterInput(
            clock: wednesdayClock,
            currencySymbol: '₹',
            expenses: const [
              DayLetterExpense(
                id: 'exp-gifts',
                title: 'Diwali gifts — Amma, Appa',
                amount: 2491,
              ),
              DayLetterExpense(
                id: 'exp-groceries',
                title: 'Namdhari’s — the big run',
                amount: 2640,
              ),
              DayLetterExpense(
                id: 'exp-auto',
                title: 'Auto to the market',
                amount: 500,
              ),
            ],
          ),
        );

        expect(
          _joinText(withPunctuation),
          equals(
            'A full Wednesday. '
            'Nothing on the calendar. '
            '₹5,631 went out today, most of it Namdhari’s — the big run.',
          ),
        );
      },
    );
  });
}
