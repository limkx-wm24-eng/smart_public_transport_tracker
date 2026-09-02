import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../core/eta_utils.dart';
import '../models/stop.dart';
import '../providers/transit_provider.dart';
import '../services/gemini_ai_service.dart';
import '../services/location_service.dart';

class AiSupportPage extends StatefulWidget {
  const AiSupportPage({super.key});
  @override
  State<AiSupportPage> createState() => _AiSupportPageState();
}

class _AiSupportPageState extends State<AiSupportPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _ai = GeminiAiService();
  final _location = LocationService();
  final List<_Message> _messages = [];
  bool _sending = false;

  @override
  void dispose() { _input.dispose(); _scroll.dispose(); super.dispose(); }

  Future<void> _send() async {
    final question = _input.text.trim();
    if (question.isEmpty || _sending) return;
    setState(() { _messages.add(_Message(question, true)); _sending = true; _input.clear(); });
    try {
      final transit = context.read<TransitProvider>();
      final position = await _location.getCurrentPosition();
      final stops = _nearestStops(transit.stops, position);
      final mentionedStops = _mentionedStops(question, transit.stops);
      final routes = _requestedRoutes(question, transit);
      final vehicles = (routes.isEmpty ? transit.vehicles.take(3) : transit.vehicles.where((v) => routes.contains(v.routeId)).take(3)).toList();
      final targetStop = mentionedStops.isNotEmpty
          ? mentionedStops.first
          : (stops.isEmpty ? null : stops.first);
      final answer = await _ai.askSupport(
        question: question,
        transportContext: {
          'currentLocation': position == null ? null : {'latitude': position.latitude, 'longitude': position.longitude},
          'nearbyStops': stops.map((s) => {'name': s.name, 'id': s.stopId}).toList(),
          'stopsMentionedInQuestion': mentionedStops.map((s) => {'name': s.name, 'id': s.stopId}).toList(),
          'etaTargetStop': targetStop == null ? null : {'name': targetStop.name, 'id': targetStop.stopId},
          'requestedRoutes': transit.routes.where((r) => routes.contains(r.routeId)).map((r) => {'id': r.routeId, 'label': r.displayLabel, 'name': r.longName}).toList(),
          'realtimeAvailable': transit.vehiclesStatus == LoadStatus.ready && transit.vehicles.isNotEmpty,
          'vehicles': vehicles.map((v) => {
            'id': v.vehicleId, 'routeId': v.routeId, 'latitude': v.lat, 'longitude': v.lng,
            'estimatedArrivalAtTargetStop': targetStop == null ? null : estimateEtaLabel(transit.distanceToVehicle(targetStop, v)),
          }).toList(),
        },
        recentMessages: _messages.take(6).map((m) => {'role': m.mine ? 'user' : 'assistant', 'content': m.text}).toList(),
      );
      if (mounted) setState(() => _messages.add(_Message(answer, false)));
    } catch (error) {
      if (mounted) {
        final message = error.toString().replaceFirst('Exception: ', '');
        setState(() => _messages.add(_Message('AI Support is unavailable: $message', false)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
      WidgetsBinding.instance.addPostFrameCallback((_) { if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut); });
    }
  }

  List<Stop> _nearestStops(List<Stop> stops, Position? position) {
    if (position == null) return [];
    final sorted = [...stops];
    sorted.sort((a, b) => Geolocator.distanceBetween(position.latitude, position.longitude, a.lat, a.lng).compareTo(Geolocator.distanceBetween(position.latitude, position.longitude, b.lat, b.lng)));
    return sorted.take(3).toList();
  }

  Set<String> _requestedRoutes(String question, TransitProvider transit) {
    final query = question.toLowerCase();
    return transit.routes.where((r) => query.contains(r.routeId.toLowerCase()) || (r.shortName.isNotEmpty && query.contains(r.shortName.toLowerCase()))).map((r) => r.routeId).toSet();
  }

  List<Stop> _mentionedStops(String question, List<Stop> stops) {
    final words = question.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((word) => word.length >= 3).toSet();
    if (words.isEmpty) return [];
    final matches = <_StopMatch>[];
    for (final stop in stops) {
      final stopWords = stop.name.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((word) => word.length >= 3).toSet();
      final score = words.intersection(stopWords).length;
      if (score > 0) matches.add(_StopMatch(stop, score));
    }
    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches.take(3).map((match) => match.stop).toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AI Support')),
    body: Column(children: [
      Expanded(child: _messages.isEmpty ? const Center(child: Text('Ask about buses or how to use the app.')) : ListView.builder(controller: _scroll, padding: const EdgeInsets.all(12), itemCount: _messages.length, itemBuilder: (_, i) => _bubble(_messages[i]))),
      if (_sending) const LinearProgressIndicator(),
      SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [Expanded(child: TextField(controller: _input, onSubmitted: (_) => _send(), decoration: const InputDecoration(hintText: 'Ask AI Support...'))), IconButton(onPressed: _sending ? null : _send, icon: const Icon(Icons.send))]))),
    ]),
  );

  Widget _bubble(_Message message) => Align(alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), constraints: const BoxConstraints(maxWidth: 300), decoration: BoxDecoration(color: message.mine ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)), child: Text(message.text)));
}

class _Message { const _Message(this.text, this.mine); final String text; final bool mine; }
class _StopMatch { const _StopMatch(this.stop, this.score); final Stop stop; final int score; }
