import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'icon_paths.dart';

/// Agent tile icon names -> concept icon keys.
const _aliases = {
  'vol_down': 'volDown',
  'vol_up': 'volUp',
  'screenshot': 'shot',
  'mic_off': 'micOff',
  'speaker_off': 'speakerOff',
};

class DpIcon extends StatelessWidget {
  const DpIcon(this.name, {super.key, this.size = 20, this.color, this.stroke = 1.8});
  final String name;
  final double size;
  final Color? color;
  final double stroke;

  static bool has(String name) => iconPaths.containsKey(_aliases[name] ?? name);

  @override
  Widget build(BuildContext context) {
    final body = iconPaths[_aliases[name] ?? name] ?? iconPaths['shortcuts']!;
    final c = color ?? DefaultTextStyle.of(context).style.color ?? const Color(0xFFFFFFFF);
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
        'stroke="currentColor" stroke-width="$stroke" stroke-linecap="round" '
        'stroke-linejoin="round">$body</svg>';
    return SvgPicture.string(
      svg,
      width: size,
      height: size,
      theme: SvgTheme(currentColor: c),
    );
  }
}
