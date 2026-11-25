import 'package:flutter/widgets.dart';

/// A number that tweens to new values (subtle, 600 ms).
class AnimNum extends StatelessWidget {
  const AnimNum(this.value, {super.key, required this.style, this.decimals = 0, this.suffix = '', this.prefix = ''});
  final double value;
  final TextStyle style;
  final int decimals;
  final String suffix, prefix;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: value),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
        builder: (context, v, _) => Text('$prefix${v.toStringAsFixed(decimals)}$suffix', style: style),
      );
}

/// Big number + small unit in one line, baseline-aligned ("38%", "17 ms").
class NumUnit extends StatelessWidget {
  const NumUnit(this.value, this.unit,
      {super.key, required this.style, required this.unitStyle, this.decimals = 0, this.gap = 2, this.animate = true});
  final double value;
  final String unit;
  final TextStyle style, unitStyle;
  final int decimals;
  final double gap;
  final bool animate;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          animate
              ? AnimNum(value, style: style, decimals: decimals)
              : Text(value.toStringAsFixed(decimals), style: style),
          SizedBox(width: gap),
          Text(unit, style: unitStyle),
        ],
      );
}
