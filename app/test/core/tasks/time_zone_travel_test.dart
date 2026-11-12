import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/db/database.dart';
import 'package:sheettick/core/reminders/reminder_planner.dart';
import 'package:sheettick/core/tasks/recurrence.dart';
import 'package:sheettick/core/tasks/smart_lists.dart';
import 'package:sheettick/core/tasks/task_completion.dart';
import 'package:sheettick/core/tasks/task_dates.dart';
import 'package:sheettick/core/tasks/task_status.dart';

import '../../support/fake_sheets_backend.dart';
import '../../support/test_device.dart';

/// The device travels: the zone it reads dates in changes between a write and a read, and a second device sits in
/// another zone. All-day dates are calendar days, so they must not move; "today" is wherever the device is.
void main() {
  const seoul = 'Asia/Seoul'; // +09:00, no daylight saving
  const lisbon = 'Europe/Lisbon'; // +00:00 / +01:00
  const kampala = 'Africa/Kampala'; // +03:00
  const honolulu = 'Pacific/Honolulu'; // -10:00, the far west
  const kiritimati = 'Pacific/Kiritimati'; // +14:00, the far east
  const newYork =
      'America/New_York'; // -05:00 / -04:00, changes on other days than Lisbon
  const zones = [seoul, lisbon, kampala, honolulu, kiritimati, newYork];

  /// The instant the wall clock in [zone] reads this moment.
  DateTime at(String zone, int y, int mo, int d, [int h = 0, int mi = 0]) =>
      wallToInstant(DateTime.utc(y, mo, d, h, mi), locationOf(zone));

  late FakeSheetsBackend backend;
  late TestDevice device;

  setUp(() async {
    backend = FakeSheetsBackend();
    device = await TestDevice.create(backend);
  });

  tearDown(() => device.close());

  Future<Task> taskRow(TestDevice d, String id) =>
      (d.db.select(d.db.tasks)..where((t) => t.id.equals(id))).getSingle();

  /// A task with these dates written on [zone], the way the app writes them.
  Future<String> add(
    TaskDates dates, {
    Map<String, Object?> extra = const {},
  }) => device.addTask('Task', extra: {...dates.toFields(), ...extra});

  TaskDates read(Task t, String zone) => TaskDates.fromRow(
    startAt: t.startAt,
    dueAt: t.dueAt,
    allDay: t.allDay,
    tz: t.tz,
    deviceZone: zone,
  );

  Set<SmartList> dateListsOf(Task t, DateTime now, String zone) => {
    for (final l in [SmartList.today, SmartList.tomorrow, SmartList.next7Days])
      if (smartListHas(l, t, now: now, zone: zone)) l,
  };

  test(
    'every zone name a task or a phone can carry is known, link names included',
    () {
      // The TickTick data carries Africa/Kampala, a link to Africa/Nairobi; Android can report Asia/Calcutta. A name that
      // is not found reads as the platform's zone, which would shift every time in it without any error.
      for (final name in [
        ...zones,
        'Africa/Nairobi',
        'Asia/Calcutta',
        'Asia/Kolkata',
        'Europe/Kiev',
        'Europe/Kyiv',
        'UTC',
      ]) {
        expect(locationOf(name), isNotNull, reason: name);
      }
      expect(
        locationOf('Africa/Kampala')!.currentTimeZone.offset,
        const Duration(hours: 3),
      );
      expect(locationOf('Not/AZone'), isNull);
    },
  );

  group('an all-day task keeps its calendar day', () {
    test('whatever zone the device reads it on', () async {
      final id = await add(
        TaskDates(due: DateTime.utc(2026, 11, 12), allDay: true, zone: seoul),
      );
      final row = await taskRow(device, id);
      expect(row.dueAt, '2026-11-12');
      expect(row.tz, isNull);
      for (final zone in zones) {
        final dates = read(row, zone);
        expect(dates.allDay, isTrue, reason: zone);
        expect(dates.due, DateTime.utc(2026, 11, 12), reason: zone);
        // Writing it back from there changes nothing in the cells.
        expect(dates.toFields()['due_at'], '2026-11-12', reason: zone);
        expect(dates.toFields()['tz'], isNull, reason: zone);
      }
    });

    test('through the Sheet, on a second device in another zone', () async {
      final id = await add(
        TaskDates(
          start: DateTime.utc(2026, 12, 31),
          due: DateTime.utc(2027, 1, 1),
          allDay: true,
          zone: kiritimati,
        ),
      );
      await device.sync();
      final other = await TestDevice.create(backend, id: 'and-0002');
      addTearDown(other.close);
      await other.sync();

      final row = await taskRow(other, id);
      expect(row.startAt, '2026-12-31');
      expect(row.dueAt, '2027-01-01');
      for (final zone in zones) {
        final dates = read(row, zone);
        expect(dates.start, DateTime.utc(2026, 12, 31), reason: zone);
        expect(dates.due, DateTime.utc(2027, 1, 1), reason: zone);
      }

      // The second device edits another field from yet another zone; the dates are not rewritten.
      other.tick();
      await other.edit(id, {'title': 'Renamed'});
      await other.sync();
      await device.sync();
      final back = await taskRow(device, id);
      expect(back.title, 'Renamed');
      expect(back.dueAt, '2027-01-01');
      expect(back.allDay, isTrue);
    });

    test('editing it from another zone writes the same day', () async {
      final id = await add(
        TaskDates(due: DateTime.utc(2026, 11, 12), allDay: true, zone: seoul),
      );
      // Seen on Honolulu and moved by one day there: the day is the day shown, not an instant converted.
      final moved = read(
        await taskRow(device, id),
        honolulu,
      ).withDue(DateTime.utc(2026, 11, 13));
      expect(moved.toFields(), {
        'start_at': null,
        'due_at': '2026-11-13',
        'all_day': true,
        'tz': null,
      });
    });

    test('a timed task keeps its instant, and shows on the wall clock of the zone the device is in', () async {
      final id = await add(
        TaskDates(due: DateTime.utc(2026, 11, 12, 9), zone: seoul),
      );
      final row = await taskRow(device, id);
      expect(row.dueAt, '2026-11-12T09:00:00+09:00');
      expect(row.tz, seoul);
      expect(read(row, seoul).due, DateTime.utc(2026, 11, 12, 9));
      expect(read(row, lisbon).due, DateTime.utc(2026, 11, 12, 0)); // 00:00Z
      expect(read(row, kampala).due, DateTime.utc(2026, 11, 12, 3));
      expect(
        read(row, honolulu).due,
        DateTime.utc(2026, 11, 11, 14),
      ); // the day before
      expect(read(row, kiritimati).due, DateTime.utc(2026, 11, 12, 14));
    });
  });

  group(
    'Today, Tomorrow and Next 7 Days roll over at the midnight of the device',
    () {
      for (final zone in zones) {
        test(zone, () async {
          final allDay = await taskRow(
            device,
            await add(TaskDates(due: DateTime.utc(2026, 11, 12), allDay: true)),
          );

          // The evening before: tomorrow.
          expect(dateListsOf(allDay, at(zone, 2026, 11, 11, 23, 59), zone), {
            SmartList.tomorrow,
            SmartList.next7Days,
          });
          // The minute the day starts: today.
          expect(dateListsOf(allDay, at(zone, 2026, 11, 12), zone), {
            SmartList.today,
            SmartList.next7Days,
          });
          expect(dateListsOf(allDay, at(zone, 2026, 11, 12, 23, 59), zone), {
            SmartList.today,
            SmartList.next7Days,
          });
          // The next minute it is overdue: still in Today, no longer in Next 7 Days.
          expect(dateListsOf(allDay, at(zone, 2026, 11, 13), zone), {
            SmartList.today,
          });
          // Seven days ahead is out of Next 7 Days; six is in.
          expect(
            dateListsOf(allDay, at(zone, 2026, 11, 5, 23, 59), zone),
            isEmpty,
          );
          expect(dateListsOf(allDay, at(zone, 2026, 11, 6), zone), {
            SmartList.next7Days,
          });
        });
      }

      test(
        'the same instant is a different day on different devices',
        () async {
          final allDay = await taskRow(
            device,
            await add(TaskDates(due: DateTime.utc(2026, 11, 12), allDay: true)),
          );
          final instant = DateTime.utc(
            2026,
            11,
            12,
            1,
          ); // 10:00 on the 12th in Seoul, 15:00 on the 11th in Honolulu
          expect(dateListsOf(allDay, instant, seoul), {
            SmartList.today,
            SmartList.next7Days,
          });
          expect(dateListsOf(allDay, instant, honolulu), {
            SmartList.tomorrow,
            SmartList.next7Days,
          });
        },
      );

      test(
        'across a daylight-saving change the day still starts at midnight',
        () async {
          final allDay = await taskRow(
            device,
            await add(TaskDates(due: DateTime.utc(2026, 10, 26), allDay: true)),
          );
          // Lisbon puts the clocks back at 02:00 on Sunday 25 October: that day is 25 hours long.
          expect(
            dateListsOf(allDay, at(lisbon, 2026, 10, 25, 23, 59), lisbon),
            {SmartList.tomorrow, SmartList.next7Days},
          );
          expect(dateListsOf(allDay, at(lisbon, 2026, 10, 26), lisbon), {
            SmartList.today,
            SmartList.next7Days,
          });
          // New York puts them forward on 8 March 2026: that day is 23 hours long.
          final march = await taskRow(
            device,
            await add(TaskDates(due: DateTime.utc(2026, 3, 9), allDay: true)),
          );
          expect(dateListsOf(march, at(newYork, 2026, 3, 8, 23, 59), newYork), {
            SmartList.tomorrow,
            SmartList.next7Days,
          });
          expect(dateListsOf(march, at(newYork, 2026, 3, 9), newYork), {
            SmartList.today,
            SmartList.next7Days,
          });
        },
      );

      test(
        'a timed task moves between lists with the zone the device is in',
        () async {
          // 08:00 on 12 November in Seoul is 23:00 on the 11th in Lisbon.
          final timed = await taskRow(
            device,
            await add(
              TaskDates(due: DateTime.utc(2026, 11, 12, 8), zone: seoul),
            ),
          );
          final now = at(lisbon, 2026, 11, 11, 12);
          expect(dateListsOf(timed, now, lisbon), {
            SmartList.today,
            SmartList.next7Days,
          });
          expect(dateListsOf(timed, now, seoul), {
            SmartList.tomorrow,
            SmartList.next7Days,
          });
        },
      );
    },
  );

  group('repeats', () {
    /// Completes the task [id] on a device that is in [zone] and reads [now] as local time, and returns the new
    /// task's `due_at`, or null when nothing was created.
    Future<String?> completeIn(String id, String zone, DateTime now) async {
      final task = await taskRow(device, id);
      final newId = await setTaskStatus(
        device.writer,
        task,
        TaskStatus.completed,
        now: now,
        zone: zone,
      );
      return newId == null ? null : (await taskRow(device, newId)).dueAt;
    }

    for (final zone in zones) {
      test(
        'monthly on the 25th gives the 25th of the next month in $zone, across the daylight-saving change',
        () async {
          for (final hour in [0, 12, 23]) {
            final id = await add(
              TaskDates(due: DateTime.utc(2026, 10, 25), allDay: true),
              extra: {'rrule': 'FREQ=MONTHLY;BYMONTHDAY=25'},
            );
            expect(
              await completeIn(id, zone, at(zone, 2026, 10, 25, hour, 30)),
              '2026-11-25',
              reason: '$zone $hour:30',
            );
          }
        },
      );

      test(
        'monthly on the 31st skips the months that have no 31st in $zone',
        () async {
          final id = await add(
            TaskDates(due: DateTime.utc(2026, 10, 31), allDay: true),
            extra: {'rrule': 'FREQ=MONTHLY;BYMONTHDAY=31'},
          );
          expect(
            await completeIn(id, zone, at(zone, 2026, 10, 31, 12)),
            '2026-12-31',
          );
        },
      );

      test(
        'every 3 days from completion counts from the local day it was finished in $zone',
        () async {
          // Finished on the evening before the clocks change in Lisbon (25 Oct) and in New York (1 Nov).
          for (final (y, m, d, expected) in [
            (2026, 10, 24, '2026-10-27'),
            (2026, 10, 31, '2026-11-03'),
          ]) {
            for (final hour in [0, 12, 23]) {
              final id = await add(
                TaskDates(due: DateTime.utc(2026, 10, 20), allDay: true),
                extra: {
                  'rrule': 'FREQ=DAILY;INTERVAL=3',
                  'repeat_from': 'COMPLETION',
                },
              );
              expect(
                await completeIn(id, zone, at(zone, y, m, d, hour, 30)),
                expected,
                reason: '$zone $d $hour:30',
              );
            }
          }
        },
      );
    }

    test('finished late the same local day, whichever zone: the next one is not already overdue', () async {
      for (final zone in zones) {
        final id = await add(
          TaskDates(due: DateTime.utc(2026, 11, 10), allDay: true),
          extra: {'rrule': 'FREQ=DAILY'},
        );
        // Three days late: the next one is the day after the day it was finished, whatever the zone.
        expect(
          await completeIn(id, zone, at(zone, 2026, 11, 13, 8)),
          '2026-11-14',
          reason: zone,
        );
      }
    });

    test('a timed daily task keeps its clock time across the daylight-saving change, and its offset follows', () async {
      final id = await add(
        TaskDates(due: DateTime.utc(2026, 10, 24, 9), zone: lisbon),
        extra: {'rrule': 'FREQ=DAILY'},
      );
      expect((await taskRow(device, id)).dueAt, '2026-10-24T09:00:00+01:00');
      expect(
        await completeIn(id, lisbon, at(lisbon, 2026, 10, 24, 10)),
        '2026-10-25T09:00:00+00:00',
      );
    });

    test('a timed weekly task in New York keeps 09:00 over the change of 1 November', () async {
      final id = await add(
        TaskDates(due: DateTime.utc(2026, 10, 30, 9), zone: newYork),
        extra: {'rrule': 'FREQ=WEEKLY;BYDAY=FR'},
      );
      expect((await taskRow(device, id)).dueAt, '2026-10-30T09:00:00-04:00');
      expect(
        await completeIn(id, newYork, at(newYork, 2026, 10, 30, 10)),
        '2026-11-06T09:00:00-05:00',
      );
    });

    test('nextOccurrence gives the same days whatever zone the wall clock came from', () {
      // The function works on wall clocks, so a zone cannot change its answer: the same wall clock, the same next day.
      for (final zone in zones) {
        final dates = TaskDates(
          due: DateTime.utc(2026, 10, 25),
          allDay: true,
          zone: zone,
        );
        final next = nextOccurrence(
          rrule: 'FREQ=MONTHLY;BYMONTHDAY=25',
          repeatFrom: RepeatFrom.due,
          dates: dates,
          completedWall: DateTime.utc(2026, 10, 25, 12),
        );
        expect(next!.dates.due, DateTime.utc(2026, 11, 25), reason: zone);
        expect(next.dates.zone, zone);
      }
    });
  });

  group('reminders for an all-day task fire at the clock time on the zone the device is in', () {
    // `PT9H` is 9:00 that day; `-PT15H` is 9:00 the day before (see allDayReminderPresets).
    const onTheDay = '["TRIGGER:PT9H"]';
    const dayBefore = '["TRIGGER:-PT15H"]';

    Future<DateTime> firstReminder(
      String reminders,
      DateTime day,
      String zone,
    ) async {
      final task = await taskRow(
        device,
        await add(
          TaskDates(due: day, allDay: true),
          extra: {'reminders': reminders},
        ),
      );
      final planned = planReminders(
        [task],
        after: DateTime.utc(2000),
        deviceZone: zone,
      );
      expect(planned, hasLength(1), reason: zone);
      return planned.single.at;
    }

    for (final zone in zones) {
      test('on an ordinary day in $zone', () async {
        expect(
          await firstReminder(onTheDay, DateTime.utc(2026, 11, 12), zone),
          at(zone, 2026, 11, 12, 9),
        );
        expect(
          await firstReminder(dayBefore, DateTime.utc(2026, 11, 12), zone),
          at(zone, 2026, 11, 11, 9),
        );
      });
    }

    test(
      'the same task reminds at 09:00 on each zone the device visits',
      () async {
        final task = await taskRow(
          device,
          await add(
            TaskDates(due: DateTime.utc(2026, 11, 12), allDay: true),
            extra: {'reminders': onTheDay},
          ),
        );
        List<DateTime> plan(String zone) => [
          for (final r in planReminders(
            [task],
            after: DateTime.utc(2000),
            deviceZone: zone,
          ))
            r.at,
        ];
        expect(plan(seoul), [DateTime.utc(2026, 11, 12, 0)]);
        expect(plan(lisbon), [DateTime.utc(2026, 11, 12, 9)]);
        expect(plan(kampala), [DateTime.utc(2026, 11, 12, 6)]);
        expect(plan(honolulu), [DateTime.utc(2026, 11, 12, 19)]);
      },
    );

    // A day that is 25 or 23 hours long: "9:00" has to mean the clock on the wall, not nine hours after midnight.
    for (final (label, zone, y, m, d) in [
      ('Lisbon, the day the clocks go back (25 hours)', lisbon, 2026, 10, 25),
      ('Lisbon, the day the clocks go forward (23 hours)', lisbon, 2026, 3, 29),
      ('New York, the day the clocks go back', newYork, 2026, 11, 1),
      ('New York, the day the clocks go forward', newYork, 2026, 3, 8),
    ]) {
      test('on the day itself: $label', () async {
        expect(
          await firstReminder(onTheDay, DateTime.utc(y, m, d), zone),
          at(zone, y, m, d, 9),
        );
      });

      test('9:00 the day before, for a task due on that day: $label', () async {
        expect(
          await firstReminder(dayBefore, DateTime.utc(y, m, d), zone),
          at(zone, y, m, d - 1, 9),
        );
      });

      test(
        '9:00 the day before, for a task due the day after: $label',
        () async {
          expect(
            await firstReminder(dayBefore, DateTime.utc(y, m, d + 1), zone),
            at(zone, y, m, d, 9),
          );
        },
      );
    }
  });
}
