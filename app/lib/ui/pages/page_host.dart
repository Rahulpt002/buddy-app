import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/conn/controller.dart';
import '../../core/data/topics.dart';
import '../../core/pages.dart';
import '../../core/settings.dart';
import '../fmt.dart';
import '../icons.dart';
import '../screens/pair_screen.dart';
import '../skin.dart';
import '../widgets/common.dart';
import 'kit.dart';

/// The agent topic a page can't render without (pages not listed work standalone).
const primaryTopic = {
  PageId.system: 'system',
  PageId.claude: 'claude',
  PageId.music: 'media',
  PageId.hotspot: 'hotspot',
  PageId.slack: 'slack',
  PageId.github: 'github',
  PageId.shortcuts: 'shortcuts',
};

/// Pages that are useful with no laptop at all.
const standalonePages = {PageId.home, PageId.weather, PageId.timer, PageId.calendar};

/// Routes a [PageId] to the active skin's page, or a waiting / setup / pairing state.
class PageHost extends ConsumerWidget {
  const PageHost({super.key, required this.page, required this.onOpen, required this.onSettings});
  final PageId page;
  final ValueChanged<PageId> onOpen;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conn = ref.watch(agentProvider);
    final skin = context.skin;
    final source = page == PageId.github ? ref.watch(codeSourceProvider) : 0;
    final topic = page == PageId.github ? (source == 1 ? 'gitlab' : 'github') : primaryTopic[page];
    final entry = topic == null ? null : ref.watch(topicProvider(topic));

    Widget body;
    final noWeather = page == PageId.weather && ref.watch(weatherProvider) == null;
    if (noWeather) {
      final issue = ref.watch(weatherIssueProvider);
      body = StateMessage(
        icon: 'weather',
        title: issue == null ? 'Finding your location…' : 'Choose a location',
        body: issue ??
            'Allow location access when Android asks (approximate is enough), '
                'or pick a city in Settings → Weather → Location.',
      );
    } else if (conn.status == LinkStatus.unpaired && !standalonePages.contains(page) && entry == null) {
      body = const PairPrompt();
    } else if (topic != null && entry == null) {
      body = StateMessage(
        icon: page.icon,
        action: page == PageId.github
            ? SkinButton(
                label: 'Show ${codeSources[1 - source]}',
                onTap: () => ref.read(codeSourceProvider.notifier).set(1 - source))
            : null,
        title: conn.live ? 'Waiting for ${page.label.toLowerCase()} data…' : 'No ${page.label.toLowerCase()} data yet',
        body: conn.live
            ? 'The laptop is connected; the first update should arrive in a moment.'
            : 'This page fills in once the laptop agent connects.',
      );
    } else if (entry != null && entry.data is StatusOnly) {
      body = StateMessage(
        icon: page.icon,
        title: page == PageId.github ? _setupTitle(page, entry.data.status).replaceFirst('GitHub', codeSources[source])
            : _setupTitle(page, entry.data.status),
        body: entry.data.message ?? _setupHint(page),
        // The switch lives in the page itself, which isn't shown here: offer the other source.
        action: page == PageId.github
            ? SkinButton(
                label: 'Show ${codeSources[1 - source]}',
                onTap: () => ref.read(codeSourceProvider.notifier).set(1 - source))
            : null,
      );
    } else {
      body = skin.page(page);
    }

    final dim = !conn.live && conn.status != LinkStatus.loading && conn.status != LinkStatus.unpaired;
    return PageNav(
      open: onOpen,
      child: AnimatedOpacity(
        opacity: dim ? .55 : 1,
        duration: const Duration(milliseconds: 400),
        child: Stack(fit: StackFit.expand, children: [
          body,
          if (entry != null && entry.data is! StatusOnly) _StaleBadge(topic: topic!, entry: entry, live: conn.live),
        ]),
      ),
    );
  }

  static String _setupTitle(PageId p, TopicStatus s) => switch (s) {
        TopicStatus.unconfigured => 'Set up ${p.label}',
        TopicStatus.unsupported => '${p.label} isn\'t available on this laptop',
        TopicStatus.starting => 'Starting ${p.label.toLowerCase()}…',
        _ => '${p.label} hit a problem',
      };

  static String _setupHint(PageId p) => switch (p) {
        PageId.github => 'Add a GitHub token under [github] in ~/.deskpanel/config.toml on the laptop.',
        PageId.slack => 'Create the DeskPanel Slack app and add its tokens under [slack] in ~/.deskpanel/config.toml (README → Slack).',
        PageId.hotspot => 'On the laptop run  deskpanel-agent hotspot-login  and sign in to your Hotspot Monitor Server (a viewer account is enough).',
        PageId.claude => 'Run  deskpanel-agent install-statusline  on the laptop to share your limits.',
        _ => 'Check the agent log on the laptop for details.',
      };
}

/// Shown when connected but a topic hasn't updated within its expected interval.
class _StaleBadge extends StatelessWidget {
  const _StaleBadge({required this.topic, required this.entry, required this.live});
  final String topic;
  final TopicEntry entry;
  final bool live;

  @override
  Widget build(BuildContext context) => Ticker(
        period: const Duration(seconds: 5),
        builder: (context, now) {
          final age = now.difference(entry.receivedAt);
          final stale = live && (entry.fromCache || age > staleAfter(topic));
          if (!stale) return const SizedBox.shrink();
          final t = context.tk;
          return Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: t.warn.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text('Stale · updated ${ago(age)}', style: t.t(11, w: FontWeight.w600, c: t.warn)),
            ),
          );
        },
      );
}

/// Friendly empty / setup state in the active skin.
class StateMessage extends StatelessWidget {
  const StateMessage({super.key, required this.icon, required this.title, required this.body, this.action});
  final String icon, title, body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final t = skin.tokens;
    final panel = skin.id == SkinId.panel;
    final fg = panel ? const Color(0xFFE7ECE5) : t.text;
    final mu = panel ? const Color(0xFF737B76) : t.muted;
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DpIcon(icon, size: 40, color: mu, stroke: 1.5),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: t.d(24, w: FontWeight.w600, c: fg, h: 1.15)),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center, style: t.t(13.5, c: mu, h: 1.45)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      ),
    );
    return skin.card(child: content);
  }
}

class PairPrompt extends ConsumerWidget {
  const PairPrompt({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => StateMessage(
        icon: 'monitor',
        title: 'Pair with your laptop',
        body: 'On the laptop run  deskpanel-agent pair  and scan the QR code. '
            'For the USB cable to work too, enable USB debugging on this phone.',
        action: Row(mainAxisSize: MainAxisSize.min, children: [
          SkinButton(label: 'Scan QR code', primary: true, onTap: () => Navigator.of(context).push(pairRoute())),
          const SizedBox(width: 12),
          SkinButton(
            label: 'Try demo',
            onTap: () => ref.read(settingsProvider.notifier).update((s) => s.copyWith(demo: true)),
          ),
        ]),
      );
}

class SkinButton extends StatelessWidget {
  const SkinButton({super.key, required this.label, this.onTap, this.primary = false});
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final panel = context.skin.id == SkinId.panel;
    return Press(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? .5 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: primary ? t.accent : const Color(0x00000000),
            borderRadius: BorderRadius.circular(panel ? 8 : 99),
            border: primary ? null : Border.all(color: (panel ? const Color(0xFF737B76) : t.muted).withValues(alpha: .6)),
          ),
          child: Text(label,
              style: t.t(13, w: FontWeight.w700, c: primary ? t.onAccent : (panel ? const Color(0xFFE7ECE5) : t.text))),
        ),
      ),
    );
  }
}
