enum PageId {
  home('Home', 'home', {}),
  system('System', 'system', {'system', 'network'}),
  claude('Claude', 'claude', {'claude'}),
  calendar('Calendar', 'calendar', {'calendar'}),
  weather('Weather', 'weather', {}),
  music('Music', 'music', {'media'}),
  hotspot('Hotspot', 'hotspot', {'hotspot'}),
  timer('Timer', 'timer', {}),
  slack('Slack', 'slack', {'slack'}),
  github('GitHub', 'github', {'github', 'gitlab'}),
  shortcuts('Shortcuts', 'shortcuts', {'shortcuts'});

  const PageId(this.label, this.icon, this.topics);
  final String label;

  /// Key into the icon set (lib/ui/icons.dart).
  final String icon;

  /// Agent topics this page needs in addition to [homeTopics].
  final Set<String> topics;
}

/// Always subscribed so Home stays current. github is included because some themes' Home
/// pages use it (Diorama's plant); slack because a new message opens the Slack page from
/// anywhere. Both are cheap (GitHub is cached for 15 min; Slack only sends on new messages).
const homeTopics = {'system', 'claude', 'media', 'calendar', 'github', 'slack'};

Set<String> topicsFor(PageId p) => {...homeTopics, ...p.topics};
