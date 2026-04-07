// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0

import 'dart:math' as math;
import 'dart:ui';

import 'package:pw_dart/pw_dart.dart';

/// Geometry of a laid-out node box.
class NodeBox {
  NodeBox({
    required this.node,
    required this.inputs,
    required this.outputs,
    required this.position,
    required this.size,
  });

  final PwNode node;
  final List<PwPort> inputs;
  final List<PwPort> outputs;
  Offset position;
  final Size size;

  Rect get rect => position & size;

  /// Center of port [portId] in graph coordinates, or null if unknown.
  Offset? portCenter(int portId) {
    final isInput = inputs.any((p) => p.id == portId);
    final list = isInput ? inputs : outputs;
    final idx = list.indexWhere((p) => p.id == portId);
    if (idx < 0) return null;
    final dx = isInput ? 0.0 : size.width;
    final dy = NodeMetrics.headerH +
        NodeMetrics.portRowH * (idx + 0.5) +
        NodeMetrics.padTop;
    return position + Offset(dx, dy);
  }
}

class NodeMetrics {
  static const double width = 200;
  static const double headerH = 28;
  static const double portRowH = 22;
  static const double padTop = 6;
  static const double padBot = 8;
  static const double minHeight = 60;

  static Size sizeFor(int inputs, int outputs) {
    final rows = math.max(inputs, outputs);
    final h = headerH + padTop + padBot + rows * portRowH;
    return Size(width, math.max(minHeight, h));
  }
}

/// Computes a stable column-based layout from a [PwGraph].
///
/// Sources go on the left, sinks on the right, everything else in the
/// middle — same intuition as a typical patchbay. Force-directed
/// refinement is intentionally omitted to keep things readable and
/// deterministic; users can still drag nodes manually.
class GraphLayout {
  final Map<int, NodeBox> boxes;
  final Size canvasSize;

  GraphLayout(this.boxes, this.canvasSize);

  factory GraphLayout.compute(PwGraph graph, {String filter = ''}) {
    const colW = 280.0;
    const rowH = 24.0;
    const topPad = 40.0;

    final visible = graph.nodes.values.where((n) {
      if (filter.isEmpty) return true;
      return n.name.toLowerCase().contains(filter) ||
          n.mediaClass.toLowerCase().contains(filter);
    }).toList();

    // Bucket nodes into columns by media class.
    final cols = <int, List<PwNode>>{0: [], 1: [], 2: []};
    for (final n in visible) {
      final cls = n.mediaClass.toLowerCase();
      // Streams (apps) always go in the middle column so flow reads
      // source → stream → sink.
      int col;
      if (cls.startsWith('stream/')) {
        col = 1;
      } else if (cls.contains('source')) {
        col = 0;
      } else if (cls.contains('sink')) {
        col = 2;
      } else {
        col = 1;
      }
      cols[col]!.add(n);
    }

    final boxes = <int, NodeBox>{};
    cols.forEach((colIdx, list) {
      list.sort((a, b) => a.name.compareTo(b.name));
      double y = topPad;
      for (final node in list) {
        final ports = graph.portsForNode(node.id);
        final inputs =
            ports.where((p) => p.direction == PwDirection.input).toList();
        final outputs =
            ports.where((p) => p.direction == PwDirection.output).toList();
        final size = NodeMetrics.sizeFor(inputs.length, outputs.length);
        boxes[node.id] = NodeBox(
          node: node,
          inputs: inputs,
          outputs: outputs,
          position: Offset(40 + colIdx * colW, y),
          size: size,
        );
        y += size.height + rowH;
      }
    });

    // Compute canvas extents from actual node placements + padding.
    double maxX = 1200, maxY = 800;
    for (final b in boxes.values) {
      if (b.rect.right > maxX) maxX = b.rect.right;
      if (b.rect.bottom > maxY) maxY = b.rect.bottom;
    }
    return GraphLayout(boxes, Size(maxX + 80, maxY + 80));
  }

  NodeBox? nodeAt(Offset graphPoint) {
    for (final box in boxes.values) {
      if (box.rect.contains(graphPoint)) return box;
    }
    return null;
  }

  /// Find the port whose dot contains [graphPoint], if any.
  ({NodeBox box, PwPort port, bool isOutput})? portAt(Offset graphPoint) {
    const r = 8.0;
    for (final box in boxes.values) {
      for (final inp in box.inputs) {
        final c = box.portCenter(inp.id);
        if (c != null && (c - graphPoint).distance <= r) {
          return (box: box, port: inp, isOutput: false);
        }
      }
      for (final out in box.outputs) {
        final c = box.portCenter(out.id);
        if (c != null && (c - graphPoint).distance <= r) {
          return (box: box, port: out, isOutput: true);
        }
      }
    }
    return null;
  }
}
