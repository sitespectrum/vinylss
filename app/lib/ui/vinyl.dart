import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// A vinyl record: grooved black disc with a centre label.
///
/// The label shows [labelUrl] (usually the album cover), else a plain accent label with
/// optional [labelText] or [labelIcon]. [spin] rotates the disc; the light sheen stays put.
class VinylDisc extends StatelessWidget {
  const VinylDisc({
    super.key,
    required this.size,
    this.labelUrl,
    this.labelText,
    this.labelIcon,
    this.spin,
  });

  final double size;
  final String? labelUrl;
  final String? labelText;
  final IconData? labelIcon;
  final Animation<double>? spin;

  @override
  Widget build(BuildContext context) {
    final labelSize = size * 0.36;
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(colors: [Palette.accent, Color(0xFFD9822B)]),
      ),
      child: Align(
        // Text sits above the spindle hole; icons are centred.
        alignment: labelIcon != null ? Alignment.center : const Alignment(0, -0.42),
        child: labelIcon != null
            ? Icon(labelIcon, size: labelSize * 0.42, color: Palette.onAccent)
            : labelText != null
                ? Text(
                    labelText!,
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontWeight: FontWeight.w800,
                      fontSize: labelSize * 0.13,
                      letterSpacing: labelSize * 0.02,
                      color: Palette.onAccent,
                    ),
                  )
                : null,
      ),
    );
    final label = labelUrl == null ? fallback : artwork(labelUrl!, fallback);

    final record = Stack(alignment: Alignment.center, children: [
      CustomPaint(size: Size.square(size), painter: const _GroovePainter()),
      Container(
        width: labelSize,
        height: labelSize,
        foregroundDecoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withValues(alpha: 0.35), width: size * 0.006),
        ),
        child: ClipOval(child: label),
      ),
    ]);

    return SizedBox.square(
      dimension: size,
      child: Stack(alignment: Alignment.center, children: [
        RotationTransition(turns: spin ?? const AlwaysStoppedAnimation(0), child: record),
        IgnorePointer(child: CustomPaint(size: Size.square(size), painter: const _SheenPainter())),
        // Spindle hole.
        Container(
          width: math.max(3, size * 0.035),
          height: math.max(3, size * 0.035),
          decoration: const BoxDecoration(color: Palette.background, shape: BoxShape.circle),
        ),
      ]),
    );
  }
}

class _GroovePainter extends CustomPainter {
  const _GroovePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = Palette.vinyl);

    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, r * 0.006);
    var i = 0;
    for (var g = r * 0.2; g < r * 0.95; g += math.max(1.6, r * 0.024), i++) {
      if (g < r * 0.21) continue;
      // Gaps between "tracks" are slightly wider and darker.
      final isGap = (g / r - 0.55).abs() < 0.012 || (g / r - 0.76).abs() < 0.012;
      groove.color = isGap
          ? Colors.black
          : i.isEven
              ? Palette.groove
              : const Color(0xFF151515);
      canvas.drawCircle(c, g, groove);
    }
    canvas.drawCircle(
      c,
      r - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF444444),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Static light reflection over the grooves.
class _SheenPainter extends CustomPainter {
  const _SheenPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    const clear = Color(0x00FFFFFF);
    const shine = Color(0x24FFFFFF);
    final paint = Paint()
      ..shader = const SweepGradient(
        colors: [clear, shine, clear, clear, shine, clear, clear],
        stops: [0.0, 0.10, 0.2, 0.5, 0.6, 0.7, 1.0],
        transform: GradientRotation(-math.pi / 5),
      ).createShader(rect);
    // Only over the grooved band, not the label.
    final band = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: c, radius: r * 0.97))
      ..addOval(Rect.fromCircle(center: c, radius: r * 0.19));
    canvas.drawPath(band, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Album cover in its sleeve, with the record peeking out on the right.
///
/// Fills the given width; the sleeve is 88% of it. When [pulled] the record slides
/// further out and turns, like pulling it from the sleeve.
class SleeveCover extends StatelessWidget {
  const SleeveCover({
    super.key,
    required this.url,
    this.pulled = false,
    this.overlay,
    this.radius = 6,
  });

  static const sleeveFraction = 0.88;

  final String? url;
  final bool pulled;

  /// Widgets stacked on the sleeve (stickers, menus), positioned relative to it.
  final List<Widget>? overlay;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final sleeve = width * sleeveFraction;
      final disc = sleeve * 0.96;
      final restLeft = sleeve + width * 0.065 - disc;
      final pulledLeft = width - disc;
      const duration = Duration(milliseconds: 320);
      const curve = Curves.easeOutCubic;

      return SizedBox(
        width: width,
        height: sleeve,
        child: Stack(clipBehavior: Clip.none, children: [
          AnimatedPositioned(
            duration: duration,
            curve: curve,
            left: pulled ? pulledLeft : restLeft,
            top: (sleeve - disc) / 2,
            child: AnimatedRotation(
              duration: duration,
              curve: curve,
              turns: pulled ? 0.12 : 0,
              child: VinylDisc(size: disc, labelUrl: url),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            width: sleeve,
            height: sleeve,
            child: AnimatedContainer(
              duration: duration,
              curve: curve,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: pulled ? 0.6 : 0.45),
                    blurRadius: pulled ? 18 : 10,
                    offset: Offset(pulled ? 4 : 2, pulled ? 8 : 4),
                  ),
                ],
              ),
              child: Stack(fit: StackFit.expand, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: CoverImage(url: url),
                ),
                // Subtle sleeve edge: light top-left, worn opening on the right.
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.06),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.25),
                        ],
                        stops: const [0, 0.08, 0.94, 1],
                      ),
                    ),
                  ),
                ),
                ...?overlay,
              ]),
            ),
          ),
        ]),
      );
    });
  }
}

/// Square album art. Without art it shows a plain paper sleeve with a die-cut hole
/// revealing the record label.
class CoverImage extends StatelessWidget {
  const CoverImage({super.key, required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final placeholder = LayoutBuilder(builder: (context, c) {
      final side = c.biggest.shortestSide;
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2C2925), Color(0xFF1E1C1A)],
          ),
        ),
        child: Center(
          child: Container(
            width: side * 0.38,
            height: side * 0.38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Palette.vinyl,
              boxShadow: [
                // Inner edge of the cut-out.
                BoxShadow(color: Colors.white.withValues(alpha: 0.05), spreadRadius: 1),
              ],
            ),
            alignment: Alignment.center,
            child: Container(
              width: side * 0.3,
              height: side * 0.3,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Palette.accent, Color(0xFFD9822B)]),
              ),
              alignment: Alignment.center,
              child: Container(
                width: math.max(2, side * 0.03),
                height: math.max(2, side * 0.03),
                decoration: const BoxDecoration(color: Palette.vinyl, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
      );
    });
    if (url == null) return placeholder;
    return artwork(url!, placeholder);
  }
}

/// Replaces network artwork, e.g. with generated covers in screenshot tests.
@visibleForTesting
Widget Function(String url)? debugArtworkBuilder;

/// Cached album art for [url], showing [fallback] while loading or on error.
Widget artwork(String url, Widget fallback) =>
    debugArtworkBuilder?.call(url) ??
    CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );

/// A round record-shop price sticker.
class PriceSticker extends StatelessWidget {
  const PriceSticker({super.key, required this.price, this.size = 46}) : available = true;

  /// A greyed-out sticker for albums without a known vinyl pressing.
  const PriceSticker.noVinyl({super.key, this.size = 46})
      : price = null,
        available = false;

  /// Short price such as "$18.50"; null shows just "VINYL".
  final String? price;
  final double size;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: fontFamily,
      color: available ? const Color(0xFF2A1A00) : Palette.subtext,
      height: 1.0,
    );
    final small = style.copyWith(fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 1);
    return Transform.rotate(
      angle: -0.2,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.08),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: available
                ? const [Color(0xFFFFE27A), Palette.sticker]
                : const [Color(0xFF4A4A4A), Color(0xFF333333)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 4,
              offset: const Offset(1, 2),
            ),
          ],
        ),
        child: FittedBox(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (!available) ...[
              Text('NO', style: small),
              const SizedBox(height: 2),
            ],
            Text('VINYL', style: small),
            if (price != null) ...[
              const SizedBox(height: 2),
              Text(price!, style: style.copyWith(fontSize: 13, fontWeight: FontWeight.w800)),
            ],
          ]),
        ),
      ),
    );
  }
}

/// A record turning at 33⅓ rpm with the tonearm swung onto it. Used as the loading indicator.
class SpinningRecord extends StatefulWidget {
  const SpinningRecord({
    super.key,
    this.size = 96,
    this.labelUrl,
    this.labelText,
    this.tonearm = true,
    this.secondsPerTurn = 1.8,
  });

  final double size;
  final String? labelUrl;
  final String? labelText;
  final bool tonearm;
  final double secondsPerTurn;

  @override
  State<SpinningRecord> createState() => _SpinningRecordState();
}

class _SpinningRecordState extends State<SpinningRecord> with TickerProviderStateMixin {
  late final _spin = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.secondsPerTurn * 1000).round()),
  );
  late final _arm = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _spin.stop();
      _arm.value = 1;
    } else {
      if (!_spin.isAnimating) _spin.repeat();
      if (_arm.value == 0) _arm.forward();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _arm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disc = VinylDisc(
      size: widget.size,
      labelUrl: widget.labelUrl,
      labelText: widget.labelText,
      spin: _spin,
    );
    if (!widget.tonearm) return disc;
    final arm = CurvedAnimation(parent: _arm, curve: Curves.easeInOutCubic);
    return SizedBox(
      width: widget.size * 1.25,
      height: widget.size,
      child: Stack(children: [
        disc,
        Positioned.fill(
          child: AnimatedBuilder(
            animation: arm,
            builder: (_, _) => CustomPaint(painter: _TonearmPainter(arm.value, widget.size)),
          ),
        ),
      ]),
    );
  }
}

class _TonearmPainter extends CustomPainter {
  _TonearmPainter(this.progress, this.disc);

  /// 0 = resting beside the record, 1 = stylus in the groove.
  final double progress;
  final double disc;

  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(disc * 1.12, disc * 0.1);
    final length = disc * 0.78;
    final angle = (90 + 25 * progress) * math.pi / 180;
    final end = pivot + Offset(math.cos(angle), math.sin(angle)) * length;

    final arm = Paint()
      ..color = const Color(0xFFCFCFCF)
      ..strokeWidth = math.max(1.5, disc * 0.022)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(pivot, end, arm);

    // Headshell.
    canvas.save();
    canvas.translate(end.dx, end.dy);
    canvas.rotate(angle - math.pi / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: disc * 0.07, height: disc * 0.11),
        Radius.circular(disc * 0.012),
      ),
      Paint()..color = const Color(0xFF9A9A9A),
    );
    canvas.restore();

    // Pivot base and counterweight.
    canvas.drawCircle(pivot, disc * 0.075, Paint()..color = const Color(0xFF2E2E2E));
    canvas.drawCircle(pivot, disc * 0.045, Paint()..color = const Color(0xFFB8B8B8));
  }

  @override
  bool shouldRepaint(_TonearmPainter old) => old.progress != progress || old.disc != disc;
}

/// Centered empty/error state with a record illustration.
class VinylMessage extends StatelessWidget {
  const VinylMessage({
    super.key,
    required this.icon,
    required this.text,
    this.detail,
    this.action,
    this.spinning = false,
  });

  final IconData icon;
  final String text;
  final String? detail;
  final Widget? action;

  /// Shows the turning record with its tonearm instead of the still disc, for work in progress.
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (spinning)
              const SpinningRecord(size: 120)
            else
              VinylDisc(size: 120, labelIcon: icon),
            const SizedBox(height: 24),
            Text(text, textAlign: TextAlign.center, style: theme.titleMedium),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(detail!, textAlign: TextAlign.center, style: theme.bodyMedium),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ]),
        ),
      ),
    );
  }
}

/// Large page heading shared by the top-level screens, with an optional line below it.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 8, 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: theme.headlineMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: theme.bodyMedium),
            ],
          ]),
        ),
        ?trailing,
      ]),
    );
  }
}

/// Full-area loading state.
class LoadingRecord extends StatelessWidget {
  const LoadingRecord({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: SpinningRecord());
}
