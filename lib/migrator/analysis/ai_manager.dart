/// LLM-assisted migration guidance with deterministic fallbacks.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/graph_models.dart';
import '../models/ir_models.dart';
import 'architecture_intelligence.dart';
import 'governance_engine.dart';

/// Where an [AiGuidance] recommendation originated.
enum AiGuidanceSource {
  /// Response came from the Anthropic cloud API (via `MIGRATOR_AI_KEY`).
  cloudLlm,

  /// Response came from the local Ollama endpoint.
  localLlm,

  /// LLM was unavailable; guidance was generated deterministically from the graph.
  deterministicFallback,
}

/// A single piece of migration or architecture guidance produced by [AIManager].
class AiGuidance {
  /// Short headline for the guidance card.
  final String title;

  /// Component name or method path this guidance addresses.
  final String subject;

  /// Category tag: `'logic-refactor'`, `'architecture'`, or `'governance'`.
  final String category;

  /// Why this guidance was triggered.
  final String rationale;

  /// The actual migration or remediation advice.
  final String recommendation;

  /// Prompt that was sent to the LLM (or would have been sent).
  final String prompt;

  /// Whether this came from the LLM or the deterministic fallback.
  final AiGuidanceSource source;

  /// `'model@endpoint'` string identifying the LLM backend used.
  final String? backend;

  /// Why the LLM was not used (only set when [source] is [AiGuidanceSource.deterministicFallback]).
  final String? fallbackReason;

  /// Raw text returned by the LLM (only set when [source] is [AiGuidanceSource.localLlm]).
  final String? rawResponse;

  /// Creates an [AiGuidance].
  const AiGuidance({
    required this.title,
    required this.subject,
    required this.category,
    required this.rationale,
    required this.recommendation,
    required this.prompt,
    required this.source,
    this.backend,
    this.fallbackReason,
    this.rawResponse,
  });

  /// Serialises this guidance to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'title': title,
    'subject': subject,
    'category': category,
    'rationale': rationale,
    'recommendation': recommendation,
    'prompt': prompt,
    'source': source.name,
    if (backend != null) 'backend': backend,
    if (fallbackReason != null) 'fallbackReason': fallbackReason,
    if (rawResponse != null) 'rawResponse': rawResponse,
  };
}

/// Produces [AiGuidance] by querying an LLM or falling back to deterministic
/// recommendations derived from the architecture graph.
///
/// Priority order:
/// 1. **Anthropic cloud API** — used when `MIGRATOR_AI_KEY` is set in the
///    environment (or [cloudApiKey] is provided explicitly). Calls
///    `https://api.anthropic.com/v1/messages` with `claude-haiku-4-5-20251001`.
/// 2. **Local Ollama** — tried when no cloud key is present.
///    Defaults to `http://localhost:11434/api/generate`.
/// 3. **Deterministic fallback** — used when both LLM options are unavailable.
class AIManager {
  /// Creates an [AIManager].
  ///
  /// [cloudApiKey] defaults to the `MIGRATOR_AI_KEY` environment variable.
  /// Pass a custom [client] in tests to mock HTTP responses.
  AIManager({
    http.Client? client,
    String? cloudApiKey,
    this.ollamaEndpoint = 'http://localhost:11434/api/generate',
    this.model = 'llama3.1',
    this.requestTimeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _cloudApiKey =
           cloudApiKey ?? Platform.environment['MIGRATOR_AI_KEY'];

  static const _anthropicEndpoint = 'https://api.anthropic.com/v1/messages';
  static const _cloudModel = 'claude-haiku-4-5-20251001';

  final http.Client _client;
  final bool _ownsClient;
  final String? _cloudApiKey;

  /// Ollama-compatible API endpoint used for LLM completions.
  final String ollamaEndpoint;

  /// Name of the Ollama model to use, e.g. `'llama3.1'`.
  final String model;

  /// Maximum time to wait for a single LLM response before falling back.
  final Duration requestTimeout;

  /// Closes the underlying HTTP client when this manager owns it.
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  /// Returns [AiGuidance] for refactoring a single method body.
  ///
  /// Sends a prompt to the local LLM; falls back deterministically when
  /// the LLM is unavailable.
  Future<AiGuidance> refactorMethodBody({
    required String className,
    required List<String> stateFields,
    required String methodName,
    required String methodBody,
    NotifierType notifierType = NotifierType.stateNotifier,
  }) async {
    final prompt = _buildMethodPrompt(
      className: className,
      stateFields: stateFields,
      methodName: methodName,
      methodBody: methodBody,
      notifierType: notifierType,
    );
    final fallback = _fallbackMethodGuidance(
      className: className,
      stateFields: stateFields,
      methodName: methodName,
      notifierType: notifierType,
    );

    return _completeGuidance(
      title: 'Refactor $className.$methodName',
      subject: '$className.$methodName',
      category: 'logic-refactor',
      rationale:
          '$className.$methodName mutates local state and should move to immutable Riverpod state transitions.',
      prompt: prompt,
      fallbackRecommendation: fallback,
    );
  }

  /// Produces one [AiGuidance] per smell and per governance violation in the graph.
  Future<List<AiGuidance>> buildArchitectureGuidance({
    required ArchitectureGraph graph,
    required List<ArchitectureSmell> smells,
    required List<GovernanceViolation> violations,
  }) async {
    final guidance = <AiGuidance>[];

    for (final smell in smells) {
      final node = graph.nodes[smell.nodeId];
      if (node == null) {
        continue;
      }

      final title = 'Address ${smell.name} in ${_nodeLabel(node)}';
      final rationale = smell.description;
      guidance.add(
        await _completeGuidance(
          title: title,
          subject: _nodeLabel(node),
          category: 'architecture',
          rationale: rationale,
          prompt: _buildSmellPrompt(node: node, smell: smell, graph: graph),
          fallbackRecommendation: _fallbackSmellRecommendation(
            smell: smell,
            node: node,
            graph: graph,
          ),
        ),
      );
    }

    for (final violation in violations) {
      final node = graph.nodes[violation.nodeId];
      if (node == null) {
        continue;
      }

      final title = 'Resolve ${violation.ruleName} for ${_nodeLabel(node)}';
      guidance.add(
        await _completeGuidance(
          title: title,
          subject: _nodeLabel(node),
          category: 'governance',
          rationale: violation.message,
          prompt: _buildViolationPrompt(node: node, violation: violation),
          fallbackRecommendation: _fallbackViolationRecommendation(
            violation: violation,
            node: node,
          ),
        ),
      );
    }

    return guidance;
  }

  Future<AiGuidance> _completeGuidance({
    required String title,
    required String subject,
    required String category,
    required String rationale,
    required String prompt,
    required String fallbackRecommendation,
  }) async {
    // Try cloud API first when a key is present.
    if (_cloudApiKey != null) {
      final cloudResult = await _requestCloudCompletion(prompt);
      if (cloudResult.response != null) {
        return AiGuidance(
          title: title,
          subject: subject,
          category: category,
          rationale: rationale,
          recommendation: cloudResult.response!,
          prompt: prompt,
          source: AiGuidanceSource.cloudLlm,
          backend: '$_cloudModel@$_anthropicEndpoint',
          rawResponse: cloudResult.response,
        );
      }
      // Cloud failed — still try Ollama before giving up.
    }

    final llmResult = await _requestOllamaCompletion(prompt);
    if (llmResult.response != null) {
      return AiGuidance(
        title: title,
        subject: subject,
        category: category,
        rationale: rationale,
        recommendation: llmResult.response!,
        prompt: prompt,
        source: AiGuidanceSource.localLlm,
        backend: '$model@$ollamaEndpoint',
        rawResponse: llmResult.response,
      );
    }

    return AiGuidance(
      title: title,
      subject: subject,
      category: category,
      rationale: rationale,
      recommendation: fallbackRecommendation,
      prompt: prompt,
      source: AiGuidanceSource.deterministicFallback,
      backend: _cloudApiKey != null ? '$_cloudModel@$_anthropicEndpoint' : '$model@$ollamaEndpoint',
      fallbackReason: llmResult.failureReason,
    );
  }

  /// Calls the Anthropic Messages API using [_cloudApiKey].
  Future<_LlmResult> _requestCloudCompletion(String prompt) async {
    try {
      final response = await _client
          .post(
            Uri.parse(_anthropicEndpoint),
            headers: {
              HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
              'x-api-key': _cloudApiKey!,
              'anthropic-version': '2023-06-01',
            },
            body: jsonEncode({
              'model': _cloudModel,
              'max_tokens': 512,
              'messages': [
                {'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode != 200) {
        return _LlmResult.failure(
          'Anthropic API returned status ${response.statusCode}.',
        );
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        return const _LlmResult.failure(
          'Anthropic API returned an invalid JSON payload.',
        );
      }

      final content = payload['content'];
      if (content is! List || content.isEmpty) {
        return const _LlmResult.failure('Anthropic API response content was empty.');
      }
      final text = (content.first as Map<String, dynamic>)['text'];
      if (text is! String || text.trim().isEmpty) {
        return const _LlmResult.failure('Anthropic API text block was empty.');
      }

      return _LlmResult.success(text.trim());
    } on TimeoutException {
      return _LlmResult.failure(
        'Timed out waiting for the Anthropic API.',
      );
    } on SocketException catch (error) {
      return _LlmResult.failure(
        'Could not reach the Anthropic API: ${error.message}',
      );
    } on http.ClientException catch (error) {
      return _LlmResult.failure(
        'HTTP client error while contacting the Anthropic API: ${error.message}',
      );
    } on FormatException catch (error) {
      return _LlmResult.failure(
        'Could not decode Anthropic API response: ${error.message}',
      );
    }
  }

  Future<_LlmResult> _requestOllamaCompletion(String prompt) async {
    try {
      final response = await _client
          .post(
            Uri.parse(ollamaEndpoint),
            headers: const {
              HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
              HttpHeaders.acceptHeader: 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'prompt': prompt,
              'stream': false,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode != 200) {
        return _LlmResult.failure(
          'Local LLM returned status ${response.statusCode}.',
        );
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        return const _LlmResult.failure(
          'Local LLM returned an invalid JSON payload.',
        );
      }

      final text = payload['response'];
      if (text is! String || text.trim().isEmpty) {
        return const _LlmResult.failure('Local LLM response was empty.');
      }

      return _LlmResult.success(text.trim());
    } on TimeoutException {
      return _LlmResult.failure(
        'Timed out waiting for the local LLM at $ollamaEndpoint.',
      );
    } on SocketException catch (error) {
      return _LlmResult.failure(
        'Could not reach the local LLM at $ollamaEndpoint: ${error.message}',
      );
    } on http.ClientException catch (error) {
      return _LlmResult.failure(
        'HTTP client error while contacting the local LLM: ${error.message}',
      );
    } on FormatException catch (error) {
      return _LlmResult.failure(
        'Could not decode local LLM response: ${error.message}',
      );
    }
  }

  String _buildMethodPrompt({
    required String className,
    required List<String> stateFields,
    required String methodName,
    required String methodBody,
    required NotifierType notifierType,
  }) {
    final stateFieldSummary = stateFields.isEmpty
        ? 'none'
        : stateFields.join(', ');
    return '''
You are assisting a Flutter Riverpod migration.

Task: refactor the method below into an immutable Riverpod update strategy.
Class: $className
Method: $methodName
Suggested notifier type: ${notifierType.name}
Tracked state fields: $stateFieldSummary

Original method body:
$methodBody

Constraints:
1. Preserve behavior.
2. Replace mutable field writes with `state = state.copyWith(...)` guidance.
3. Remove notifyListeners(), emit(), and direct mutable UI side effects.
4. Mention AsyncNotifier only when async work is present.
5. Return concise migration guidance or a replacement method body only.
''';
  }

  String _buildSmellPrompt({
    required ProviderNode node,
    required ArchitectureSmell smell,
    required ArchitectureGraph graph,
  }) {
    final dependencies = graph.getDependencies(_nodeId(node, graph)).length;
    return '''
You are reviewing a Flutter architecture migration.

Component: ${_nodeLabel(node)}
Kind: ${node.runtimeType}
Issue: ${smell.name}
Evidence: ${smell.description}
Direct dependencies: $dependencies

Return a concise recommendation with:
1. the architectural problem,
2. the safest Riverpod-aligned remediation,
3. one concrete next change to make in code.
''';
  }

  String _buildViolationPrompt({
    required ProviderNode node,
    required GovernanceViolation violation,
  }) {
    return '''
You are enforcing Flutter architecture governance during a Riverpod migration.

Component: ${_nodeLabel(node)}
Issue: ${violation.ruleName}
Evidence: ${violation.message}

Return a concise recommendation with:
1. the contract being violated,
2. why the current dependency is risky,
3. the smallest safe remediation step.
''';
  }

  String _fallbackMethodGuidance({
    required String className,
    required List<String> stateFields,
    required String methodName,
    required NotifierType notifierType,
  }) {
    final publicFields = stateFields
        .map((field) => field.startsWith('_') ? field.substring(1) : field)
        .toList();
    final firstField = publicFields.isEmpty
        ? '/* stateField */'
        : publicFields.first;
    final notifierHint = notifierType == NotifierType.asyncNotifier
        ? 'Use AsyncNotifier state transitions if this method coordinates loading or error states.'
        : 'Keep the method inside a Riverpod Notifier and express mutations through copyWith.';
    return '''
$notifierHint

Recommended migration shape for $className.$methodName:
1. Read from `state` instead of mutable fields.
2. Compute the next value locally.
3. Commit a single immutable update:

state = state.copyWith(
  $firstField: state.$firstField,
);

Then remove notifyListeners()/emit() side effects from the original method.
''';
  }

  String _fallbackSmellRecommendation({
    required ArchitectureSmell smell,
    required ProviderNode node,
    required ArchitectureGraph graph,
  }) {
    switch (smell.name) {
      case 'God Component':
        return 'Split ${_nodeLabel(node)} into smaller notifiers or services. Move unrelated responsibilities behind focused Riverpod providers before migrating the UI wiring.';
      case 'State Explosion':
        return 'Group related state in a dedicated state model for ${_nodeLabel(node)} so Riverpod updates happen through a small number of cohesive copyWith transitions.';
      case 'High Coupling':
        return 'Reduce direct dependencies owned by ${_nodeLabel(node)}. Introduce an interface, repository boundary, or orchestration provider to keep the notifier focused.';
      case 'Improper Async Pattern':
        return 'Promote ${_nodeLabel(node)} to AsyncNotifier or isolate async work behind a dedicated provider so loading, data, and error states remain explicit.';
      case 'Circular Dependency':
        final nodeId = _nodeId(node, graph);
        List<String>? cycle;
        for (final entry in graph.findCycles()) {
          if (entry.contains(nodeId)) {
            cycle = entry;
            break;
          }
        }
        if (cycle != null) {
          return 'Break the dependency cycle `${cycle.join(' -> ')}` by introducing an abstraction or mediator provider between the participating components.';
        }
        return 'Break the circular dependency by introducing an abstraction, event boundary, or orchestration provider.';
      default:
        return smell.description;
    }
  }

  String _fallbackViolationRecommendation({
    required GovernanceViolation violation,
    required ProviderNode node,
  }) {
    switch (violation.ruleName) {
      case 'Forbidden Dependency':
        return 'Move the forbidden dependency behind an allowed boundary for ${_nodeLabel(node)}. A presentation layer should depend on an application-facing interface, not the restricted implementation directly.';
      case 'Max Dependencies Exceeded':
        return 'Trim the dependency surface of ${_nodeLabel(node)} by extracting collaborator groups into dedicated providers or services.';
      case 'Max Dependency Depth Exceeded':
        return 'Flatten the dependency chain under ${_nodeLabel(node)}. Pull orchestration upward and inject simpler collaborators into the notifier.';
      default:
        return violation.message;
    }
  }

  String _nodeLabel(ProviderNode node) {
    if (node is LogicUnitNode) {
      return node.name;
    }
    if (node is WidgetNode) {
      return node.widgetName;
    }
    if (node is StateNode) {
      return node.stateClassName;
    }
    return node.filePath.isEmpty ? node.runtimeType.toString() : node.filePath;
  }

  String _nodeId(ProviderNode node, ArchitectureGraph graph) {
    return graph.nodes.entries
        .firstWhere((entry) => identical(entry.value, node))
        .key;
  }
}

class _LlmResult {
  final String? response;
  final String? failureReason;

  const _LlmResult.success(this.response) : failureReason = null;

  const _LlmResult.failure(this.failureReason) : response = null;
}
