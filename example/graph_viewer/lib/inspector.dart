// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0

import 'package:flutter/material.dart';
import 'package:pw_dart/pw_dart.dart';

import 'theme.dart';

/// Side panel showing details for the selected node.
class NodeInspector extends StatefulWidget {
  const NodeInspector({super.key, required this.client, required this.node});

  final PwClient client;
  final PwNode node;

  @override
  State<NodeInspector> createState() => _NodeInspectorState();
}

class _NodeInspectorState extends State<NodeInspector> {
  Map<String, PwParam>? _params;
  Object? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant NodeInspector old) {
    super.didUpdateWidget(old);
    if (old.node.id != widget.node.id) _load();
  }

  Future<void> _load() async {
    try {
      final p = await widget.client.getNodeParams(widget.node.id);
      if (mounted) setState(() => _params = p);
    } catch (e) {
      if (mounted) setState(() => _err = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    return Container(
      width: 300,
      color: AppTheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(n.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('id ${n.id} · ${n.mediaClass}',
              style: const TextStyle(color: AppTheme.fgDim, fontSize: 12)),
          const SizedBox(height: 4),
          Text('state: ${n.state.name}',
              style: const TextStyle(color: AppTheme.fgDim, fontSize: 12)),
          const Divider(height: 24),
          const Text('Properties',
              style: TextStyle(color: AppTheme.fgDim, fontSize: 11)),
          const SizedBox(height: 8),
          ...n.properties.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 12, color: AppTheme.fg),
                  children: [
                    TextSpan(
                      text: '${e.key}: ',
                      style: const TextStyle(color: AppTheme.fgDim),
                    ),
                    TextSpan(text: e.value),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 24),
          const Text('Params',
              style: TextStyle(color: AppTheme.fgDim, fontSize: 11)),
          const SizedBox(height: 8),
          if (_err != null)
            Text('error: $_err',
                style: const TextStyle(color: AppTheme.video, fontSize: 12))
          else if (_params == null)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_params!.isEmpty)
            const Text('(none)',
                style: TextStyle(color: AppTheme.fgDim, fontSize: 12))
          else
            ..._params!.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${e.key}: ${e.value}',
                    style: const TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}
