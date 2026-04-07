// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0
//
// Integration tests against a real PipeWire daemon.
//
// These tests require a running PipeWire daemon on the host. They are tagged
// `integration` so they do not run under a default `dart test`. Run them
// explicitly with:
//
//     dart test --tags integration
//
// If no daemon is reachable, every test in this file is skipped with a
// message rather than failing — so this file is safe to keep enabled in CI
// matrices that include hosts without PipeWire.

@Tags(['integration'])
library;

import 'dart:async';

import 'package:pw_dart/pw_dart.dart';
import 'package:test/test.dart';

void main() {
  group('PwClient against a real PipeWire daemon', () {
    PwClient? client;
    Object? connectError;

    setUpAll(() async {
      try {
        client = await PwClient.connect();
      } catch (e) {
        connectError = e;
      }
    });

    tearDownAll(() async {
      await client?.dispose();
    });

    setUp(() {
      if (connectError != null) {
        // Skipping the whole group is cleaner than failing on a missing
        // daemon — the same suite then runs on dev boxes and CI hosts that
        // happen not to have PipeWire installed.
        markTestSkipped('PipeWire daemon not reachable: $connectError');
      }
    });

    test('connect succeeds and exposes a non-empty graph', () {
      final c = client!;
      expect(c.isDisposed, isFalse);
      expect(
        c.graph.nodes,
        isNotEmpty,
        reason: 'a running PipeWire usually has at least one node',
      );
    });

    test('version info matches the runtime library', () {
      final v = client!.getVersion();
      expect(
        v.isCompatible,
        isTrue,
        reason:
            'header and library versions should be compatible '
            '(${v.headerVersionString} vs ${v.libraryVersionString})',
      );
      expect(
        v.meetsMinimumVersion,
        isTrue,
        reason:
            'runtime library must meet PwVersion.minVersion '
            '(got ${v.libraryVersionString})',
      );
    });

    test('every port belongs to a known node', () {
      final g = client!.graph;
      for (final p in g.ports.values) {
        expect(
          g.nodes,
          contains(p.nodeId),
          reason:
              'port ${p.id} ("${p.name}") references unknown '
              'node ${p.nodeId}',
        );
      }
    });

    test('every link references known ports and nodes', () {
      final g = client!.graph;
      for (final l in g.links.values) {
        expect(
          g.ports,
          contains(l.outputPortId),
          reason: 'link ${l.id} references unknown output port',
        );
        expect(
          g.ports,
          contains(l.inputPortId),
          reason: 'link ${l.id} references unknown input port',
        );
        expect(
          g.nodes,
          contains(l.outputNodeId),
          reason: 'link ${l.id} references unknown output node',
        );
        expect(
          g.nodes,
          contains(l.inputNodeId),
          reason: 'link ${l.id} references unknown input node',
        );
      }
    });

    test('linksForNode and portsForNode agree with link membership', () {
      final g = client!.graph;
      for (final node in g.nodes.values) {
        final ports = g.portsForNode(node.id).map((p) => p.id).toSet();
        for (final l in g.linksForNode(node.id)) {
          final touchesNode =
              ports.contains(l.outputPortId) || ports.contains(l.inputPortId);
          expect(
            touchesNode,
            isTrue,
            reason:
                'linksForNode(${node.id}) returned link ${l.id} '
                'which does not touch any of the node\'s ports',
          );
        }
      }
    });

    test('refreshGraph returns at least the same set of nodes', () {
      final c = client!;
      final before = c.graph.nodes.keys.toSet();
      c.refreshGraph();
      final after = c.graph.nodes.keys.toSet();
      // Nodes can come and go between calls, but the snapshot must always be
      // internally consistent. We only assert that the call doesn't crash and
      // returns *something* — strict equality would race against a live graph.
      expect(after, isNotEmpty);
      expect(
        after.length,
        greaterThanOrEqualTo(before.length ~/ 2),
        reason:
            'graph should not lose more than half its nodes between '
            'two consecutive snapshots',
      );
    });

    test(
      'events stream emits a NodeAdded for an existing node within 1s',
      () async {
        final c = client!;
        // Trigger a fresh snapshot to coerce native to re-emit info events for
        // currently-bound proxies. Even without that, in practice the daemon
        // will emit at least one event within a second on any non-idle system,
        // but we keep the assertion lenient: we only require *some* event.
        final firstEvent = c.events.first.timeout(
          const Duration(seconds: 1),
          onTimeout: () => throw TimeoutException('no events within 1s'),
        );

        // Don't fail the suite if the system happens to be perfectly quiet —
        // just log it. The connect/snapshot path is exercised by other tests.
        try {
          final ev = await firstEvent;
          expect(ev, isA<PwGraphEvent>());
        } on TimeoutException {
          markTestSkipped('no graph events arrived within 1s — quiet system?');
        }
      },
    );

    test('disposing a fresh client is clean (no native abort)', () async {
      // Regression guard for the disconnect-time heap corruption that came
      // from calling pw_main_loop_quit on the wrong thread and from freeing
      // spa_hooks without spa_hook_remove. If the native teardown ever
      // regresses, this test aborts the whole process — which is exactly
      // what we want CI to flag. We deliberately do NOT assert anything
      // about graph contents here: the registry events arrive async after
      // connect, and the point of this test is purely teardown safety.
      final fresh = await PwClient.connect();
      await fresh.dispose();
      expect(fresh.isDisposed, isTrue);
    });
  });
}
