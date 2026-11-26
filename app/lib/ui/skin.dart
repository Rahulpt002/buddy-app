import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/conn/controller.dart';
import '../core/conn/loop.dart';
import '../core/pages.dart';
import '../core/settings.dart';
import 'skins/ink.dart';
import 'skins/mosaic.dart';
import 'skins/cockpit.dart';
import 'skins/blueprint.dart';
import 'skins/terminal.dart';
import 'skins/departures.dart';
import 'skins/expressive.dart';
import 'skins/sketch.dart';
import 'skins/diorama.dart';
import 'skins/liquid.dart';
import 'skins/glow.dart';
import 'skins/panel.dart';
import 'skins/slate.dart';

/// Colour/type tokens every skin provides. Shared screens (settings, pairing, empty
/// states) are drawn only from these so they look native in all three themes.
class SkinTokens {
  const SkinTokens({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.text,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.onAccent,
    required this.ok,
    required this.warn,
    required this.bad,
    required this.claude,
    required this.green,
    required this.cpu,
    required this.gpu,
    required this.ram,
    required this.vram,
    required this.sky,
    required this.cloud,
    required this.body,
    required this.display,
    required this.radius,
    this.dark = true,
  });

  final Color bg, surface, surface2, line, text, muted, faint, accent, onAccent;
  final Color ok, warn, bad, claude, green, cpu, gpu, ram, vram, sky, cloud;

  /// Font families: body copy and big display numbers.
  final String body, display;
  final double radius;
  final bool dark;

  TextStyle t(double size, {FontWeight w = FontWeight.w500, Color? c, double? ls, double? h}) =>
      TextStyle(
          fontFamily: body,
          fontSize: size,
          fontWeight: w,
          color: c ?? text,
          letterSpacing: ls ?? 0, // CSS 'normal'; never inherit Material's 0.25
          height: h,
          fontFeatures: const [FontFeature.tabularFigures()]);

  TextStyle d(double size, {FontWeight w = FontWeight.w600, Color? c, double? ls, double? h}) =>
      TextStyle(
          fontFamily: display,
          fontSize: size,
          fontWeight: w,
          color: c ?? text,
          letterSpacing: ls ?? 0, // CSS 'normal'; never inherit Material's 0.25
          height: h ?? 1,
          fontFeatures: const [FontFeature.tabularFigures()]);

  /// Small uppercase section label ("LAST 7 DAYS").
  TextStyle get label =>
      t(10.5, w: FontWeight.w600, c: muted, ls: 1.05);
}

class ShellArgs {
  const ShellArgs({
    required this.pages,
    required this.current,
    required this.onSelect,
    required this.conn,
    required this.onStatusTap,
    required this.child,
    required this.settings,
  });
  final List<PageId> pages;
  final PageId current;
  final ValueChanged<PageId> onSelect;
  final ConnState conn;
  final VoidCallback onStatusTap;
  final Widget child;
  final AppSettings settings;
}

/// How [toast] renders in a skin.
class ToastStyle {
  const ToastStyle(
      {required this.bg, required this.fg, required this.font, this.radius = 99, this.size = 13, this.bottom = 18});
  final Color bg, fg;
  final String font;

  /// [bottom] = distance from the bottom edge (clear of bottom navs).
  final double radius, size, bottom;
}

abstract class Skin {
  const Skin();

  /// Cross-fade between pages. Zero = instant swap (e-ink).
  Duration get pageTransition => const Duration(milliseconds: 220);

  /// Override for a skin-specific toast; default is an inverted pill.
  ToastStyle get toastStyle => ToastStyle(bg: tokens.text, fg: tokens.bg, font: tokens.body);
  SkinId get id;
  SkinTokens get tokens;

  /// The colour actually behind the shell right now (fills the strip the burn-in shift
  /// uncovers). Skins with their own light/dark variants override this.
  Color backdrop(BuildContext context, WidgetRef ref) => tokens.bg;

  /// Navigation chrome around [ShellArgs.child].
  Widget shell(ShellArgs a);

  /// The designed page for [id] (`lib/ui/skins/<skin>_pages.dart`).
  Widget page(PageId id);

  /// A content container in this skin's idiom (card / bare / LCD window).
  Widget card({required Widget child, EdgeInsets? padding, VoidCallback? onTap, String? label});

  static Skin of(SkinId id) => switch (id) {
        SkinId.slate => const SlateSkin(),
        SkinId.glow => const GlowSkin(),
        SkinId.panel => const PanelSkin(),
        SkinId.ink => const InkSkin(),
        SkinId.mosaic => const MosaicSkin(),
        SkinId.cockpit => const CockpitSkin(),
        SkinId.blueprint => const BlueprintSkin(),
        SkinId.terminal => const TerminalSkin(),
        SkinId.departures => const DeparturesSkin(),
        SkinId.expressive => const ExpressiveSkin(),
        SkinId.sketch => const SketchSkin(),
        SkinId.diorama => const DioramaSkin(),
        SkinId.liquid => const LiquidSkin(),
      };
}

/// Connection summary used by every shell's status widget.
({String text, bool ok, String icon}) connSummary(ConnState c) => switch (c.status) {
      LinkStatus.connected => (
          text: c.transport == Transport.usb ? 'Laptop on USB' : 'Laptop on Wi-Fi',
          ok: true,
          icon: c.transport == Transport.usb ? 'usb' : 'wifi'
        ),
      LinkStatus.demo => (text: 'Demo mode', ok: true, icon: 'wifi'),
      LinkStatus.connecting || LinkStatus.loading => (text: 'Connecting…', ok: false, icon: 'off'),
      LinkStatus.unpaired => (text: 'Not paired', ok: false, icon: 'off'),
      LinkStatus.authFailed => (text: 'Re-pair needed', ok: false, icon: 'off'),
      LinkStatus.protoMismatch => (text: 'Update needed', ok: false, icon: 'off'),
      LinkStatus.offline => (text: 'Laptop offline', ok: false, icon: 'off'),
    };

class SkinScope extends InheritedWidget {
  const SkinScope({super.key, required this.skin, required super.child});
  final Skin skin;
  static Skin of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<SkinScope>()!.skin;
  @override
  bool updateShouldNotify(SkinScope old) => old.skin.id != skin.id;
}

extension SkinCtx on BuildContext {
  Skin get skin => SkinScope.of(this);
  SkinTokens get tk => SkinScope.of(this).tokens;
}
