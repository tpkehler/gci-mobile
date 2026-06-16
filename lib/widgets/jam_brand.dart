import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// The Jam signature — the live belief field. Seven voices interact, influence
/// each other, and converge; an amber bloom marks the moment of coherence.
///
/// This is a faithful Flutter re-implementation of the brand sheet's animated
/// SVG (which uses SMIL animation that Flutter cannot render directly).
class LiveBeliefField extends StatefulWidget {
  const LiveBeliefField({
    super.key,
    this.duration = const Duration(seconds: 7),
    this.background,
  });

  final Duration duration;

  /// Optional field background (defaults to transparent so it can sit on Ink).
  final Color? background;

  @override
  State<LiveBeliefField> createState() => _LiveBeliefFieldState();
}

class _LiveBeliefFieldState extends State<LiveBeliefField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!_started && !reduceMotion) {
      _started = true;
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return ClipRect(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _BeliefFieldPainter(
              reduceMotion ? 1.0 : _c.value,
              widget.background,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _Node {
  const _Node(this.cx, this.cy, this.r, this.light);
  final List<double> cx;
  final List<double> cy;
  final double r;
  final bool light;
}

class _BeliefFieldPainter extends CustomPainter {
  _BeliefFieldPainter(this.t, this.background);

  final double t;
  final Color? background;

  static const _keyTimes = [0.0, 0.28, 0.52, 0.7, 1.0];
  static const _ease = Cubic(0.4, 0.0, 0.2, 1.0);

  // Seven voices: cx/cy keyframes (model space, centered near the bright core).
  static const _nodes = <_Node>[
    _Node([-150, -128, -156, -150, -150], [-70, 58, -22, 0, 0], 8, false),
    _Node([-44, -92, -58, -70, -70], [86, -40, 36, 0, 0], 8, true),
    _Node([34, -12, 40, 10, 10], [-88, 48, -30, 0, 0], 9, false),
    _Node([118, 70, 104, 90, 90], [92, -34, 40, 0, 0], 8, true),
    _Node([172, 150, 180, 170, 170], [-78, 52, -18, 0, 0], 10, true),
    _Node([-26, -58, -18, -30, -30], [-96, -30, -58, -46, -46], 7, false),
    _Node([58, 26, 66, 50, 50], [100, 36, 64, 46, 46], 7, false),
  ];

  // Resting field geometry (the lines fade in as the field converges).
  static const _lines = <List<double>>[
    [-150, 0, -70, 0],
    [-70, 0, 10, 0],
    [10, 0, 90, 0],
    [90, 0, 170, 0],
    [-70, 0, -30, -46],
    [90, 0, 50, 46],
  ];

  double _kf(List<double> vals) {
    if (t <= 0) return vals.first;
    if (t >= 1) return vals.last;
    for (var i = 0; i < _keyTimes.length - 1; i++) {
      final a = _keyTimes[i];
      final b = _keyTimes[i + 1];
      if (t >= a && t <= b) {
        final lt = ((t - a) / (b - a)).clamp(0.0, 1.0);
        final e = _ease.transform(lt);
        return vals[i] + (vals[i + 1] - vals[i]) * e;
      }
    }
    return vals.last;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background!);
    }

    final scale = math.min(
      (size.width / 2 - 6) / 160,
      (size.height / 2 - 6) / 100,
    );
    if (scale <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    Offset map(double x, double y) =>
        center + Offset((x - 10) * scale, y * scale);

    // Field lines fade in as convergence happens.
    final lineOpacity = (((t - 0.55) / 0.30).clamp(0.0, 1.0)) * 0.8;
    if (lineOpacity > 0.01) {
      final lp = Paint()
        ..color = GciTheme.brandTeal.withValues(alpha: lineOpacity)
        ..strokeWidth = math.max(1.0, 1.6 * scale)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (final l in _lines) {
        canvas.drawLine(map(l[0], l[1]), map(l[2], l[3]), lp);
      }
    }

    // The seven voices.
    for (final n in _nodes) {
      final p = map(_kf(n.cx), _kf(n.cy));
      final color = n.light ? GciTheme.brandTealLight : GciTheme.brandTeal;
      canvas.drawCircle(p, n.r * scale, Paint()..color = color);
    }

    // Amber coherence bloom — earned, only at the moment of resolution.
    if (t > 0.72) {
      final c = map(10, 0);
      final bp = ((t - 0.72) / 0.23).clamp(0.0, 1.0); // 0..1 across the bloom
      final ringR = 120.0 * bp;
      final ringOpacity = (0.9 * (1 - bp)).clamp(0.0, 0.9);
      if (ringOpacity > 0.01) {
        canvas.drawCircle(
          c,
          ringR * scale,
          Paint()
            ..color = GciTheme.brandAmber.withValues(alpha: ringOpacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.0, 2.6 * scale),
        );
      }
      // Brief bright amber flash at the core (triangular peak early in bloom).
      final flash = (1 - (bp / 0.4 - 1).abs()).clamp(0.0, 1.0);
      if (flash > 0.01) {
        canvas.drawCircle(
          c,
          5.5 * scale,
          Paint()..color = GciTheme.brandAmber.withValues(alpha: 0.85 * flash),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BeliefFieldPainter old) =>
      old.t != t || old.background != background;
}

/// The "Jam" wordmark with its single teal resonance underline, plus the
/// "by CrowdSmart" endorsement (always smaller, present on primary use).
class JamWordmark extends StatelessWidget {
  const JamWordmark({
    super.key,
    this.onDark = true,
    this.fontSize = 44,
    this.showEndorsement = true,
  });

  final bool onDark;
  final double fontSize;
  final bool showEndorsement;

  @override
  Widget build(BuildContext context) {
    final wordColor = onDark ? Colors.white : GciTheme.brandCharcoal;
    final underline = onDark ? GciTheme.brandTeal : GciTheme.brandTealDeep;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.only(bottom: fontSize * 0.08),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: underline,
                width: math.max(2.5, fontSize * 0.075),
              ),
            ),
          ),
          child: Text(
            'Jam',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: wordColor,
              letterSpacing: -fontSize * 0.03,
              height: 1,
            ),
          ),
        ),
        if (showEndorsement) ...[
          SizedBox(height: fontSize * 0.18),
          Text(
            'BY CROWDSMART',
            style: TextStyle(
              fontSize: math.max(9, fontSize * 0.2),
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              color: onDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ],
    );
  }
}

/// The static belief-field glyph: rim voices resolving inward to a bright
/// coherent center. Use at small sizes (login, About, intro).
class JamGlyph extends StatelessWidget {
  const JamGlyph({super.key, this.size = 80, this.withBackground = true});

  final double size;
  final bool withBackground;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GlyphPainter(withBackground)),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.withBackground);

  final bool withBackground;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 116; // brand glyph is authored in a 116pt box
    Offset p(double x, double y) => Offset(x * s, y * s);

    if (withBackground) {
      final r = RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(26 * s),
      );
      canvas.drawRRect(r, Paint()..color = GciTheme.brandInk);
    }

    void ring(double radius, Color color, double w, [double opacity = 1]) {
      canvas.drawCircle(
        p(58, 58),
        radius * s,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * s,
      );
    }

    ring(42, const Color(0xFF3F5D58), 1.4, 0.7);
    ring(29, GciTheme.brandTealDeep, 1.6);
    ring(16, GciTheme.brandTeal, 2);

    void dot(double x, double y, double radius, Color color) {
      canvas.drawCircle(p(x, y), radius * s, Paint()..color = color);
    }

    // Rim voices (deep teal).
    for (final c in const [
      [58.0, 16.0],
      [96.0, 46.0],
      [82.0, 92.0],
      [28.0, 88.0],
      [20.0, 44.0],
    ]) {
      dot(c[0], c[1], 3.4, GciTheme.brandTealDeep);
    }
    // Inner voices (teal).
    for (final c in const [
      [58.0, 29.0],
      [83.0, 58.0],
      [58.0, 87.0],
      [33.0, 58.0],
    ]) {
      dot(c[0], c[1], 3.8, GciTheme.brandTeal);
    }
    // Bright coherent center.
    dot(58, 58, 8, GciTheme.brandTealLight);
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) =>
      old.withBackground != withBackground;
}
