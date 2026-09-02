import 'package:supabase_flutter/supabase_flutter.dart';

/// Single client for the Gemini Edge Function. No Gemini credential is ever
/// included in the mobile application.
class GeminiAiService {
  GeminiAiService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final Map<String, _CachedAnswer> _cache = {};

  Future<String> getJourneyAdvice({
    required String question,
    required Map<String, dynamic> transportContext,
  }) => _ask(
        mode: 'journey',
        question: question,
        transportContext: transportContext,
      );

  Future<String> askSupport({
    required String question,
    required Map<String, dynamic> transportContext,
    List<Map<String, String>> recentMessages = const [],
  }) => _ask(
        mode: 'support',
        question: question,
        transportContext: transportContext,
        appContext: {
          'recentMessages': recentMessages.take(6).toList(),
          'features': {
            'liveMap': 'Open Live Map to view currently reported bus positions and refresh the feed.',
            'busLines': 'Use Bus Lines to search GTFS bus stops and view stop details.',
            'favourites': 'Open Favourites to view saved stops. Tap a stop star to add or remove it.',
            'journey': 'In Bus Lines, enter a destination and tap Plan journey with AI for a locally calculated journey recommendation.',
          },
        },
      );

  Future<String> _ask({
    required String mode,
    required String question,
    required Map<String, dynamic> transportContext,
    Map<String, dynamic> appContext = const {},
  }) async {
    final key = '$mode|$question|$transportContext|$appContext';
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.createdAt).inMinutes < 3) {
      return cached.answer;
    }
    try {
      final response = await _client.functions.invoke(
        'gemini-assistant',
        body: {
          'mode': mode,
          'question': question,
          'transportContext': transportContext,
          'appContext': appContext,
        },
      );
      final data = response.data;
      final answer = data is Map ? data['answer']?.toString().trim() : null;
      if (answer == null || answer.isEmpty) {
        throw const FormatException('The AI service returned an empty response.');
      }
      _cache[key] = _CachedAnswer(answer, DateTime.now());
      return answer;
    } on FunctionException catch (error) {
      final details = error.details;
      final serverMessage = details is Map ? details['error']?.toString() : null;
      if (serverMessage != null && serverMessage.isNotEmpty) {
        throw Exception(serverMessage);
      }
      if (error.status == 404) {
        throw Exception('The AI Edge Function has not been deployed yet.');
      }
      throw Exception('AI service error (${error.status}): ${error.reasonPhrase ?? 'Unknown error'}');
    } catch (error) {
      throw Exception('Unable to contact the AI service: $error');
    }
  }
}

class _CachedAnswer {
  const _CachedAnswer(this.answer, this.createdAt);
  final String answer;
  final DateTime createdAt;
}
