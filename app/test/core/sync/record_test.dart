import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/sheets/sheet_schema.dart';
import 'package:sheettick/core/sync/record.dart';

void main() {
  group('decodeCell', () {
    test('empty cells are null for every type', () {
      for (final t in ColumnType.values) {
        expect(decodeCell(t, null), isNull, reason: '$t');
        expect(decodeCell(t, ''), isNull, reason: '$t');
      }
    });

    test('booleans: native, text and numeric spellings', () {
      expect(decodeCell(ColumnType.boolean, true), true);
      expect(decodeCell(ColumnType.boolean, 'TRUE'), true);
      expect(decodeCell(ColumnType.boolean, ' false '), false);
      expect(decodeCell(ColumnType.boolean, 1), true);
      expect(decodeCell(ColumnType.boolean, 0), false);
      expect(decodeCell(ColumnType.boolean, 'maybe'), isNull);
    });

    test('numbers: a human can type anything, and it never throws', () {
      expect(decodeCell(ColumnType.integer, 3), 3);
      expect(decodeCell(ColumnType.integer, 3.0), 3);
      expect(decodeCell(ColumnType.integer, '5'), 5);
      expect(decodeCell(ColumnType.integer, 'five'), isNull);
      expect(decodeCell(ColumnType.number, 2), 2.0);
      expect(decodeCell(ColumnType.number, '2.5'), 2.5);
      expect(decodeCell(ColumnType.number, 'x'), isNull);
    });

    test('text columns keep strings, and render a typed number without ".0"', () {
      expect(decodeCell(ColumnType.text, 'hello'), 'hello');
      expect(decodeCell(ColumnType.text, 42), '42');
      expect(decodeCell(ColumnType.text, 42.0), '42');
      expect(decodeCell(ColumnType.text, 4.5), '4.5');
      expect(decodeCell(ColumnType.timestamp, '2026-10-19T13:05:00Z'), '2026-10-19T13:05:00Z');
    });
  });

  group('encodeCell', () {
    test('null clears the cell (empty string), the rest is written as is', () {
      expect(encodeCell(null), '');
      expect(encodeCell('x'), 'x');
      expect(encodeCell(true), true);
      expect(encodeCell(7), 7);
      expect(encodeCell(2.5), 2.5);
      expect(encodeCell(3.0), 3);
    });
  });

  group('sameValue and rowHash', () {
    test('null and empty string are the same, numbers compare by value', () {
      expect(sameValue(null, ''), isTrue);
      expect(sameValue('', null), isTrue);
      expect(sameValue(1, 1.0), isTrue);
      expect(sameValue('a', 'b'), isFalse);
      expect(sameValue(0, null), isFalse);
      expect(sameValue(false, null), isFalse);
    });

    final spec = tabSpec('lists');
    final base = <String, Object?>{
      'id': 'l1',
      'name': 'Inbox',
      'sort_order': 0.0,
      'is_inbox': true,
      'version': 1,
      'deleted': false,
    };

    test('the hash does not depend on how an empty value or a whole number is represented', () {
      final h = rowHash(spec, base);
      expect(rowHash(spec, {...base, 'color': ''}), h);
      expect(rowHash(spec, {...base, 'color': null}), h);
      expect(rowHash(spec, {...base, 'sort_order': 0}), h);
    });

    test('the hash changes when any column does', () {
      final h = rowHash(spec, base);
      expect(rowHash(spec, {...base, 'name': 'Inbox2'}), isNot(h));
      expect(rowHash(spec, {...base, 'version': 2}), isNot(h));
      expect(rowHash(spec, {...base, 'deleted': true}), isNot(h));
    });

    test('values outside the schema columns do not affect the hash', () {
      expect(rowHash(spec, {...base, 'extra': 'x'}), rowHash(spec, base));
    });
  });

  group('mergeFields', () {
    final base = {'title': 'milk', 'priority': 0, 'content': null};
    final cols = ['title', 'priority', 'content'];
    Fields row(Object? title, Object? priority, Object? content, String updatedAt, String device) => {
      'title': title,
      'priority': priority,
      'content': content,
      'updated_at': updatedAt,
      'device': device,
    };

    test('fields changed on different sides are both kept', () {
      final out = mergeFields(
        base: base,
        local: row('milk', 5, 'blue', '2026-10-19T10:00:00Z', 'win-1'),
        remote: row('oat milk', 0, null, '2026-10-19T11:00:00Z', 'and-2'),
        columns: cols,
      );
      expect(out, {'title': 'oat milk', 'priority': 5, 'content': 'blue'});
    });

    test('the same field on both sides: the newer updated_at wins', () {
      final newerLocal = mergeFields(
        base: base,
        local: row('L', 0, null, '2026-10-19T12:00:00Z', 'win-1'),
        remote: row('R', 0, null, '2026-10-19T11:00:00Z', 'and-2'),
        columns: cols,
      );
      final newerRemote = mergeFields(
        base: base,
        local: row('L', 0, null, '2026-10-19T10:00:00Z', 'win-1'),
        remote: row('R', 0, null, '2026-10-19T11:00:00Z', 'and-2'),
        columns: cols,
      );
      expect(newerLocal['title'], 'L');
      expect(newerRemote['title'], 'R');
    });

    test('a tie is broken the same way on both devices', () {
      const t = '2026-10-19T10:00:00Z';
      final a = row('from win', 0, null, t, 'win-1');
      final b = row('from and', 0, null, t, 'and-2');
      final onWin = mergeFields(base: base, local: a, remote: b, columns: cols);
      final onAnd = mergeFields(base: base, local: b, remote: a, columns: cols);
      expect(onWin['title'], onAnd['title']);
    });

    test('both sides making the same change is not a conflict', () {
      final out = mergeFields(
        base: base,
        local: row('same', 0, null, '2026-10-19T10:00:00Z', 'win-1'),
        remote: row('same', 0, null, '2026-10-19T09:00:00Z', 'and-2'),
        columns: cols,
      );
      expect(out['title'], 'same');
    });

    test('without a base, differing fields are conflicts and equal ones stay', () {
      final out = mergeFields(
        base: const {},
        local: row('L', 3, 'x', '2026-10-19T12:00:00Z', 'win-1'),
        remote: row('R', 3, null, '2026-10-19T11:00:00Z', 'and-2'),
        columns: cols,
      );
      expect(out['title'], 'L'); // newer
      expect(out['priority'], 3);
      expect(out['content'], 'x'); // remote has nothing to say
    });

    test('unparsable timestamps fall back to the device id, never throw', () {
      expect(localWinsConflict({'updated_at': 'garbage', 'device': 'win-1'}, {'updated_at': null, 'device': 'and-2'}), isTrue);
      expect(localWinsConflict({'updated_at': null, 'device': 'a'}, {'updated_at': null, 'device': 'a'}), isFalse);
    });
  });

  test('snapshots round-trip through JSON', () {
    final f = {'a': 'x', 'b': 1, 'c': 2.5, 'd': true, 'e': null};
    expect(decodeSnapshot(encodeSnapshot(f)), f);
  });
}
