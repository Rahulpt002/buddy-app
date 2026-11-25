import 'package:deskpanel/core/pages.dart';
import 'package:deskpanel/core/settings.dart';
import 'package:deskpanel/ui/pages/kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SlackData parses messages, unread and display helpers', () {
    final d = SlackData({
      'status': 'ok',
      'team': 'Acme',
      'unread': 1,
      'messages': [
        {
          'id': 'D1:1', 'ts': 1700000000000, 'channel_id': 'D1', 'channel': 'Maya Chen', 'kind': 'dm',
          'sender': 'Maya Chen', 'sender_color': '#E01E5A', 'text': 'hi', 'thread': false, 'unread': true,
        },
        {
          'id': 'C1:2', 'ts': 1699990000000, 'channel_id': 'C1', 'channel': '#deploys', 'kind': 'mention',
          'sender': 'jonas', 'sender_color': '#2EB67D', 'text': '@you ok?', 'thread': true, 'unread': false,
        },
      ],
    });
    expect(d.unread, 1);
    expect(d.unreadMessages.single.sender, 'Maya Chen');
    expect(d.messages.first.initials, 'MC');
    expect(d.messages.last.initials, 'JO');
    expect(d.messages.first.where, 'DM');
    expect(slackWhere(d.messages.last), '#deploys · thread');
    expect(slackSummary(d), '1 unread');
  });

  test('slackTime is compact', () {
    final now = DateTime(2026, 11, 24, 15, 0);
    expect(slackTime(now.subtract(const Duration(seconds: 20)), now), 'now');
    expect(slackTime(now.subtract(const Duration(minutes: 7)), now), '7m');
    expect(slackTime(DateTime(2026, 11, 24, 9, 0), now), '6h');
    expect(slackTime(DateTime(2026, 11, 23, 22, 0), now), 'Yesterday');
    expect(slackTime(DateTime(2026, 11, 20, 9, 0), now), 'Fri');
    expect(slackTime(DateTime(2026, 11, 2, 9, 0), now), 'Nov 2');
  });

  test('saved settings: the old Games page becomes Slack in the same slot', () {
    final s = AppSettings.fromJson({
      'pages': ['home', 'games', 'system', 'printer'],
      'hidden': ['games', 'printer'],
    });
    expect(s.pages.take(4), [PageId.home, PageId.slack, PageId.system, PageId.hotspot]);
    // The hidden Printer page becomes a visible Hotspot page.
    expect(s.hidden, {PageId.slack});
  });

  test('Slack sound is on by default and saved', () {
    expect(AppSettings.fromJson({}).slackSound, isTrue);
    final off = AppSettings.fromJson({}).copyWith(slackSound: false);
    expect(AppSettings.fromJson(off.toJson()).slackSound, isFalse);
  });
}
