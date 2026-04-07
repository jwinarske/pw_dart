// Copyright 2026 Tonic Contributors
// Licensed under the Apache License, Version 2.0
//
// pw_cli — interactive REPL for inspecting and mutating the PipeWire graph.
//
// Commands:
//   help                            show this help
//   version                         print PipeWire version info
//   summary                         show graph counts
//   nodes                           list nodes
//   ports [node_id]                 list ports (optionally filtered by node)
//   links                           list links
//   devices                         list devices
//   dump                            print full graph as JSON
//   getparams <node_id>             list a node's params
//   setparam <node_id> <key> <val>  set a node parameter
//   link <out_port_id> <in_port_id> create a link
//   unlink <link_id>                destroy a link
//   refresh                         refresh graph snapshot
//   quit                            exit
//
// Usage:
//   dart run example/pw_cli.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pw_dart/pw_dart.dart';

Future<void> main(List<String> args) async {
  final client = await PwClient.connect();
  stdout.writeln('pw_cli — ${client.graph.summary}');
  stdout.writeln('type "help" for commands, "quit" to exit');

  while (true) {
    stdout.write('pw> ');
    final line = stdin.readLineSync();
    if (line == null) break;
    final parts = line.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) continue;

    try {
      final done = await _dispatch(client, parts);
      if (done) break;
    } catch (e) {
      stderr.writeln('error: $e');
    }
  }

  await client.dispose();
}

Future<bool> _dispatch(PwClient client, List<String> parts) async {
  final cmd = parts.first;
  final rest = parts.skip(1).toList();

  switch (cmd) {
    case 'help':
      stdout.writeln(_help);
    case 'quit' || 'exit':
      return true;
    case 'version':
      stdout.writeln(client.getVersion());
    case 'summary':
      stdout.writeln(client.graph.summary);
    case 'nodes':
      for (final n in client.graph.nodes.values) {
        stdout.writeln('  ${n.id}\t${n.state.name}\t${n.mediaClass}\t${n.name}');
      }
    case 'ports':
      final nodeFilter = rest.isNotEmpty ? int.parse(rest.first) : null;
      final ports = nodeFilter == null
          ? client.graph.ports.values
          : client.graph.portsForNode(nodeFilter);
      for (final p in ports) {
        stdout.writeln('  ${p.id}\tnode=${p.nodeId}\t${p.direction.name}\t${p.name}');
      }
    case 'links':
      for (final l in client.graph.links.values) {
        stdout.writeln('  ${l.id}\t${l.outputNodeId}:${l.outputPortId} -> '
            '${l.inputNodeId}:${l.inputPortId}\t[${l.state.name}]');
      }
    case 'devices':
      for (final d in client.graph.devices.values) {
        stdout.writeln('  ${d.id}');
      }
    case 'dump':
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(client.graph.toJson()));
    case 'getparams':
      _expect(rest, 1, 'getparams <node_id>');
      final params = await client.getNodeParams(int.parse(rest[0]));
      params.forEach((k, v) => stdout.writeln('  $k = $v'));
    case 'setparam':
      _expect(rest, 3, 'setparam <node_id> <key> <value>');
      final value = num.tryParse(rest[2]) ?? rest[2];
      await client.setNodeParam(int.parse(rest[0]), rest[1], value);
      stdout.writeln('ok');
    case 'link':
      _expect(rest, 2, 'link <out_port_id> <in_port_id>');
      final link = await client.createLink(int.parse(rest[0]), int.parse(rest[1]));
      stdout.writeln('created link ${link.id}');
    case 'unlink':
      _expect(rest, 1, 'unlink <link_id>');
      await client.destroyLink(int.parse(rest[0]));
      stdout.writeln('ok');
    case 'refresh':
      client.refreshGraph();
      stdout.writeln(client.graph.summary);
    default:
      stderr.writeln('unknown command: $cmd (try "help")');
  }
  return false;
}

void _expect(List<String> args, int n, String usage) {
  if (args.length < n) throw FormatException('usage: $usage');
}

const _help = '''
help                            show this help
version                         print PipeWire version info
summary                         show graph counts
nodes                           list nodes
ports [node_id]                 list ports (optionally filtered by node)
links                           list links
devices                         list devices
dump                            print full graph as JSON
getparams <node_id>             list a node's params
setparam <node_id> <key> <val>  set a node parameter
link <out_port_id> <in_port_id> create a link
unlink <link_id>                destroy a link
refresh                         refresh graph snapshot
quit                            exit''';
