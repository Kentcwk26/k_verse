// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_prompt.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(systemPrompt)
const systemPromptProvider = SystemPromptProvider._();

final class SystemPromptProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  const SystemPromptProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'systemPromptProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$systemPromptHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return systemPrompt(ref);
  }
}

String _$systemPromptHash() => r'2e11385a5edf1ddc66793b64db8a27cfe7579a3b';
