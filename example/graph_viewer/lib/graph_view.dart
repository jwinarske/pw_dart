// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pw_dart/pw_dart.dart';

import 'inspector.dart';
import 'layout.dart';
import 'theme.dart';

const double _kPortHit = 16;

/// Top-level graph viewer: pan/zoom canvas + inspector side panel.
class GraphView extends StatefulWidget {
  const GraphView({super.key, required this.client, this.filter = ''});

  final PwClient client;
  final String filter;

  @override
  State<GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends State<GraphView> {
  static const Duration _kInspectorTimeout = Duration(seconds: 5);

  final TransformationController _xform = TransformationController();
  PwNode? _selected;
  Timer? _inspectorTimer;
  bool _hasFitToView = false;
  int _lastFitNodeCount = 0;

  void _fitToView(Size viewport, Size canvas) {
    if (canvas.width <= 0 || canvas.height <= 0) return;
    final sx = viewport.width / canvas.width;
    final sy = viewport.height / canvas.height;
    final scale = (sx < sy ? sx : sy).clamp(0.25, 1.0);
    final dx = (viewport.width - canvas.width * scale) / 2;
    final dy = (viewport.height - canvas.height * scale) / 2;
    _xform.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _selectNode(PwNode? node) {
    setState(() => _selected = node);
    _inspectorTimer?.cancel();
    if (node != null) {
      _inspectorTimer = Timer(_kInspectorTimeout, () {
        if (mounted) setState(() => _selected = null);
      });
    }
  }

  @override
  void dispose() {
    _inspectorTimer?.cancel();
    super.dispose();
  }

  // Live link-drag state, in *graph* (canvas) coordinates.
  Offset? _dragFrom;
  Offset? _dragTo;
  PwPort? _dragPort;
  bool _dragFromOutput = false;

  @override
  Widget build(BuildContext context) {
    final layout =
        GraphLayout.compute(widget.client.graph, filter: widget.filter);
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: AppTheme.background,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final n = layout.boxes.length;
                final shouldFit = !_hasFitToView
                    ? n > 0
                    : n >= _lastFitNodeCount * 2 && n > _lastFitNodeCount + 2;
                if (shouldFit) {
                  _hasFitToView = true;
                  _lastFitNodeCount = n;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _fitToView(
                        Size(constraints.maxWidth, constraints.maxHeight),
                        layout.canvasSize,
                      );
                    }
                  });
                }
                return InteractiveViewer(
                  transformationController: _xform,
                  constrained: false,
                  minScale: 0.25,
                  maxScale: 3.0,
                  boundaryMargin: const EdgeInsets.all(2000),
                  child: SizedBox(
                    width: layout.canvasSize.width,
                    height: layout.canvasSize.height,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Base layer: grid + links + nodes painter.
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _GraphPainter(
                              layout: layout,
                              links: widget.client.graph.links.values.toList(),
                              selected: _selected?.id,
                              dragFrom: _dragFrom,
                              dragTo: _dragTo,
                            ),
                          ),
                        ),
                        // Per-node tap targets (for selection).
                        for (final box in layout.boxes.values)
                          Positioned.fromRect(
                            rect: box.rect,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () => _selectNode(box.node),
                            ),
                          ),
                        // Per-link delete targets (secondary tap on midpoint).
                        ..._buildLinkTargets(layout),
                        // Per-port drag targets — must be last so they win.
                        ..._buildPortTargets(layout),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Positioned(
          left: 12,
          bottom: 12,
          child: FloatingActionButton.small(
            tooltip: 'Fit to view',
            backgroundColor: AppTheme.surfaceHigh,
            foregroundColor: AppTheme.fg,
            onPressed: () {
              final ctx = context;
              final size = ctx.size ?? const Size(800, 600);
              _fitToView(size, layout.canvasSize);
            },
            child: const Icon(Icons.fit_screen, size: 18),
          ),
        ),
        if (_selected != null)
          Positioned(
            top: 12,
            right: 12,
            bottom: 12,
            child: MouseRegion(
              onEnter: (_) => _inspectorTimer?.cancel(),
              onExit: (_) => _selectNode(_selected),
              child: Material(
                elevation: 8,
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: NodeInspector(
                    client: widget.client,
                    node: _selected!,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Iterable<Widget> _buildPortTargets(GraphLayout layout) sync* {
    for (final box in layout.boxes.values) {
      for (final port in box.inputs) {
        final c = box.portCenter(port.id);
        if (c != null) yield _portTarget(box, port, c, isOutput: false);
      }
      for (final port in box.outputs) {
        final c = box.portCenter(port.id);
        if (c != null) yield _portTarget(box, port, c, isOutput: true);
      }
    }
  }

  Widget _portTarget(NodeBox box, PwPort port, Offset center,
      {required bool isOutput}) {
    return Positioned(
      left: center.dx - _kPortHit / 2,
      top: center.dy - _kPortHit / 2,
      width: _kPortHit,
      height: _kPortHit,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) {
          setState(() {
            _dragPort = port;
            _dragFromOutput = isOutput;
            _dragFrom = center;
            _dragTo = center;
          });
        },
        onPanUpdate: (d) {
          if (_dragPort == null) return;
          // d.delta is in *local* (untransformed) coordinates which equal
          // canvas coordinates because the gesture detector lives inside
          // the InteractiveViewer's child.
          setState(() => _dragTo = (_dragTo ?? center) + d.delta);
        },
        onPanEnd: (_) async {
          final from = _dragPort;
          final dropAt = _dragTo;
          final fromOut = _dragFromOutput;
          setState(() {
            _dragPort = null;
            _dragFrom = null;
            _dragTo = null;
          });
          if (from == null || dropAt == null) return;
          final hit = _findLayout().portAt(dropAt);
          if (hit == null || hit.port.id == from.id) return;

          final reason =
              _checkCompatible(from, fromOut, hit.port, hit.isOutput);
          if (reason != null) {
            _toast(reason);
            return;
          }

          final outId = fromOut ? from.id : hit.port.id;
          final inId = fromOut ? hit.port.id : from.id;
          try {
            await widget.client.createLink(outId, inId);
          } on TimeoutException {
            _toast('PipeWire refused the link (no confirmation in 5s)');
          } catch (e) {
            _toast('Link failed: $e');
          }
        },
        child: const MouseRegion(
          cursor: SystemMouseCursors.precise,
          child: SizedBox.expand(),
        ),
      ),
    );
  }

  // Recompute layout once on drop so port positions are accurate even if
  // the graph mutated mid-drag.
  GraphLayout _findLayout() =>
      GraphLayout.compute(widget.client.graph, filter: widget.filter);

  /// Returns null if [from]→[to] is a legal new link, otherwise a
  /// human-readable reason it should be rejected.
  String? _checkCompatible(
    PwPort from,
    bool fromOutput,
    PwPort to,
    bool toOutput,
  ) {
    if (fromOutput == toOutput) {
      return fromOutput ? 'Both ports are outputs' : 'Both ports are inputs';
    }
    if (from.nodeId == to.nodeId) {
      return 'Cannot link a node to itself';
    }
    final a = from.mediaType.toLowerCase();
    final b = to.mediaType.toLowerCase();
    if (a.isNotEmpty && b.isNotEmpty && a != b) {
      return 'Incompatible media types: $a ↔ $b';
    }
    final outId = fromOutput ? from.id : to.id;
    final inId = fromOutput ? to.id : from.id;
    final exists = widget.client.graph.links.values.any(
      (l) => l.outputPortId == outId && l.inputPortId == inId,
    );
    if (exists) return 'Link already exists';
    return null;
  }

  void _toast(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Iterable<Widget> _buildLinkTargets(GraphLayout layout) sync* {
    for (final link in widget.client.graph.links.values) {
      final outBox = layout.boxes[link.outputNodeId];
      final inBox = layout.boxes[link.inputNodeId];
      if (outBox == null || inBox == null) continue;
      final a = outBox.portCenter(link.outputPortId);
      final b = inBox.portCenter(link.inputPortId);
      if (a == null || b == null) continue;
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      yield Positioned(
        left: mid.dx - 10,
        top: mid.dy - 10,
        width: 20,
        height: 20,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onSecondaryTap: () => widget.client.destroyLink(link.id),
          onDoubleTap: () => widget.client.destroyLink(link.id),
          child: const MouseRegion(
            cursor: SystemMouseCursors.click,
            child: SizedBox.expand(),
          ),
        ),
      );
    }
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.layout,
    required this.links,
    required this.selected,
    required this.dragFrom,
    required this.dragTo,
  });

  final GraphLayout layout;
  final List<PwLink> links;
  final int? selected;
  final Offset? dragFrom;
  final Offset? dragTo;

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    _drawLinks(canvas);
    for (final box in layout.boxes.values) {
      _drawNode(canvas, box, selected: box.node.id == selected);
    }
    if (dragFrom != null && dragTo != null) {
      _drawBezier(
        canvas,
        dragFrom!,
        dragTo!,
        Paint()
          ..color = AppTheme.accent.withValues(alpha: 0.8)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.border.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawNode(Canvas canvas, NodeBox box, {required bool selected}) {
    final r = RRect.fromRectAndRadius(box.rect, const Radius.circular(8));
    canvas.drawRRect(r, Paint()..color = AppTheme.surface);
    canvas.drawRRect(
      r,
      Paint()
        ..color = selected ? AppTheme.accent : AppTheme.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2 : 1,
    );

    final header = Rect.fromLTWH(
      box.rect.left,
      box.rect.top,
      box.rect.width,
      NodeMetrics.headerH,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        header,
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(8),
      ),
      Paint()..color = AppTheme.surfaceHigh,
    );
    _drawText(
      canvas,
      box.node.name,
      Offset(box.rect.left + 10, box.rect.top + 7),
      AppTheme.fg,
      bold: true,
      maxWidth: box.rect.width - 20,
    );

    for (final port in box.inputs) {
      final c = box.portCenter(port.id)!;
      final color = AppTheme.portColor(port.mediaType, isOutput: false);
      canvas.drawCircle(c, 5, Paint()..color = color);
      _drawText(canvas, port.name, c + const Offset(10, -7), AppTheme.fgDim,
          maxWidth: box.size.width / 2 - 18);
    }
    for (final port in box.outputs) {
      final c = box.portCenter(port.id)!;
      final color = AppTheme.portColor(port.mediaType, isOutput: true);
      canvas.drawCircle(c, 5, Paint()..color = color);
      _drawText(
        canvas,
        port.name,
        c + const Offset(-10, -7),
        AppTheme.fgDim,
        maxWidth: box.size.width / 2 - 18,
        rightAlign: true,
      );
    }
  }

  void _drawLinks(Canvas canvas) {
    for (final link in links) {
      final outBox = layout.boxes[link.outputNodeId];
      final inBox = layout.boxes[link.inputNodeId];
      if (outBox == null || inBox == null) continue;
      final a = outBox.portCenter(link.outputPortId);
      final b = inBox.portCenter(link.inputPortId);
      if (a == null || b == null) continue;
      final color = link.state == PwLinkState.active
          ? AppTheme.linkActive
          : AppTheme.linkIdle;
      _drawBezier(
        canvas,
        a,
        b,
        Paint()
          ..color = color.withValues(alpha: 0.9)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawBezier(Canvas canvas, Offset a, Offset b, Paint paint) {
    final dx = (b.dx - a.dx).abs() * 0.5 + 20;
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(a.dx + dx, a.dy, b.dx - dx, b.dy, b.dx, b.dy);
    canvas.drawPath(path, paint);
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset at,
    Color color, {
    bool bold = false,
    double maxWidth = 200,
    bool rightAlign = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    final origin = rightAlign ? at.translate(-tp.width, 0) : at;
    tp.paint(canvas, origin);
  }

  @override
  bool shouldRepaint(covariant _GraphPainter old) =>
      old.layout != layout ||
      old.links != links ||
      old.selected != selected ||
      old.dragFrom != dragFrom ||
      old.dragTo != dragTo;
}
