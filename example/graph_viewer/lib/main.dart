// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0

import 'package:flutter/material.dart';
import 'package:pw_dart/pw_dart.dart';

import 'graph_view.dart';
import 'theme.dart';

void main() => runApp(const GraphViewerApp());

class GraphViewerApp extends StatelessWidget {
  const GraphViewerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'pw_dart Graph Viewer',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: const GraphViewerHome(),
      );
}

class GraphViewerHome extends StatefulWidget {
  const GraphViewerHome({super.key, this.bridge});

  /// Optional bridge override (used by widget tests with a mock).
  final PwNativeBridge? bridge;

  @override
  State<GraphViewerHome> createState() => _GraphViewerHomeState();
}

class _GraphViewerHomeState extends State<GraphViewerHome> {
  PwClient? _client;
  Object? _error;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      final client = await PwClient.connect(bridge: widget.bridge);
      if (!mounted) return;
      setState(() => _client = client);
      client.events.listen((_) {
        if (mounted) setState(() {});
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _client?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_client == null
            ? 'pw_dart Graph Viewer'
            : 'pw_dart Graph Viewer  ·  ${_client!.graph.summary}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Filter nodes…',
                prefixIcon: Icon(Icons.search, size: 18),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _filter = v.toLowerCase()),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Text(
          'Failed to connect to PipeWire:\n$_error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.fgDim),
        ),
      );
    }
    final client = _client;
    if (client == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return GraphView(client: client, filter: _filter);
  }
}
