// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_flagsmith_suppression.dart';

const _tracerName = 'dartastic_otel_libs_flagsmith';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class FlagsmithResult {
  const FlagsmithResult({
    this.featureName,
    this.enabled,
    this.valueKind,
    this.environmentKey,
    this.identityIdentifier,
    this.matchedSegment,
    this.localEvaluation,
    this.deployment,
    this.requestId,
    this.statusCode,
  });

  /// Flag name.
  final String? featureName;

  /// Whether the flag is enabled for this evaluation.
  final bool? enabled;

  /// `string` / `int` / `float` / `bool` / `null` — multivariate
  /// value kind.
  final String? valueKind;

  /// Environment API key fingerprint (not the full key — short suffix
  /// only to keep cardinality bounded).
  final String? environmentKey;

  /// Identity identifier when evaluation was per-identity.
  final String? identityIdentifier;

  /// Matched segment id (when override applied).
  final String? matchedSegment;

  /// True when local evaluation SDK answered, false when remote.
  final bool? localEvaluation;

  /// `cloud` / `self_hosted` — Flagsmith is often self-hosted.
  final String? deployment;

  /// `X-Request-Id`.
  final String? requestId;

  final int? statusCode;
}

class FlagsmithCallResult<T> {
  const FlagsmithCallResult({required this.value, this.result});
  final T value;
  final FlagsmithResult? result;
}

/// Wraps a Flagsmith API call in a CLIENT span. [operation] is one of
/// `flags.get`, `identities.get`, `identities.flags`, `traits.set`,
/// `traits.bulk_set`, `features.list`, `features.create`,
/// `features.update`, `segments.list`, `environments.list`,
/// `audit_logs.list`, `webhooks.create`.
Future<T> tracedFlagsmith<T>({
  required String operation,
  required Future<FlagsmithCallResult<T>> Function() invoke,
  String? deployment,
}) async {
  if (flagsmithInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'flagsmith',
    'rpc.method': operation,
    'flagsmith.operation': operation,
  };
  if (deployment != null) m['flagsmith.deployment'] = deployment;

  final span = _tracer().startSpan(
    'flagsmith $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.featureName != null) {
        extras.add(OTel.attributeString(
          'flagsmith.feature.name',
          r.result!.featureName!,
        ));
      }
      if (r.result!.enabled != null) {
        extras.add(OTel.attributeBool(
          'flagsmith.enabled',
          r.result!.enabled!,
        ));
      }
      if (r.result!.valueKind != null) {
        extras.add(OTel.attributeString(
          'flagsmith.value.kind',
          r.result!.valueKind!,
        ));
      }
      if (r.result!.environmentKey != null) {
        extras.add(OTel.attributeString(
          'flagsmith.environment.key',
          r.result!.environmentKey!,
        ));
      }
      if (r.result!.identityIdentifier != null) {
        extras.add(OTel.attributeString(
          'flagsmith.identity.identifier',
          r.result!.identityIdentifier!,
        ));
      }
      if (r.result!.matchedSegment != null) {
        extras.add(OTel.attributeString(
          'flagsmith.matched_segment',
          r.result!.matchedSegment!,
        ));
      }
      if (r.result!.localEvaluation != null) {
        extras.add(OTel.attributeBool(
          'flagsmith.local_evaluation',
          r.result!.localEvaluation!,
        ));
      }
      if (r.result!.deployment != null) {
        extras.add(OTel.attributeString(
          'flagsmith.deployment',
          r.result!.deployment!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'flagsmith.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Flagsmith HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
