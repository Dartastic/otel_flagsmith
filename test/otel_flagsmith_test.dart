// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_flagsmith/otel_flagsmith.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_flagsmith-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('identities.flags records identity + segment + local eval', () async {
    await tracedFlagsmith<String>(
      operation: 'identities.flags',
      deployment: 'self_hosted',
      invoke: () async => const FlagsmithCallResult(
        value: 'ok',
        result: FlagsmithResult(
          featureName: 'dark_mode',
          enabled: true,
          valueKind: 'string',
          environmentKey: 'env-1',
          identityIdentifier: 'u-1',
          matchedSegment: 'beta_users',
          localEvaluation: true,
          deployment: 'self_hosted',
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('flagsmith identities.flags')!);
    expect(a['flagsmith.feature.name'], 'dark_mode');
    expect(a['flagsmith.matched_segment'], 'beta_users');
    expect(a['flagsmith.local_evaluation'], true);
    expect(a['flagsmith.deployment'], 'self_hosted');
  });

  test('suppression skips spans', () async {
    await runWithoutFlagsmithInstrumentationAsync(() async {
      await tracedFlagsmith<String>(
        operation: 'features.list',
        invoke: () async => const FlagsmithCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('flagsmith '), isEmpty);
  });
}
