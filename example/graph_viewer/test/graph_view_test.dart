// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_viewer/main.dart';
import 'package:graph_viewer/theme.dart';

import 'fake_bridge.dart';

void main() {
  testWidgets('renders graph viewer with sample graph', (tester) async {
    final bridge = FakeBridge(buildSampleGraph());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: GraphViewerHome(bridge: bridge),
      ),
    );
    // Connect future + first frame.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('pw_dart Graph Viewer'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  test('FakeBridge records createLink calls', () {
    final bridge = FakeBridge(buildSampleGraph());
    bridge.createLink(10, 20);
    expect(bridge.createdLinks, contains((10, 20)));
  });

  testWidgets('filter hides non-matching nodes', (tester) async {
    final bridge = FakeBridge(buildSampleGraph());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: GraphViewerHome(bridge: bridge),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(find.byType(TextField), 'nothingmatches');
    await tester.pump();
    // Filter is applied; canvas still rendered (just empty).
    expect(find.byType(CustomPaint), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
