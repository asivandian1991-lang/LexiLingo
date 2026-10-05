import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lexilingo_app/core/di/core_di.dart';
import 'package:lexilingo_app/core/services/ai_gateway_client.dart';
import 'package:lexilingo_app/core/di/service_locator.dart';
import 'package:lexilingo_app/features/lexi_chat/data/datasources/lexi_chat_data_source.dart';
import 'package:lexilingo_app/features/lexi_chat/data/repositories/lexi_chat_repository_impl.dart';
import 'package:lexilingo_app/features/lexi_chat/domain/repositories/lexi_chat_repository.dart';
import 'package:lexilingo_app/features/lexi_chat/presentation/providers/lexi_chat_provider.dart';

/// Register all Lexi Chat dependencies.
void registerLexiChatModule() {
  final naraApiKey =
      (dotenv.isInitialized ? dotenv.env['NARA_API_KEY'] : null) ?? '';
  final nvidiaApiKey =
      (dotenv.isInitialized ? dotenv.env['NVIDIA_API_KEY'] : null) ?? '';
  final naraBaseUrl =
      (dotenv.isInitialized ? dotenv.env['NARA_BASE_URL'] : null) ??
      'https://router.bynara.id/v1/chat/completions';
  final nvidiaBaseUrl =
      (dotenv.isInitialized ? dotenv.env['NVIDIA_BASE_URL'] : null) ??
      'https://integrate.api.nvidia.com/v1/chat/completions';
  final naraModel =
      (dotenv.isInitialized ? dotenv.env['NARA_MODEL'] : null) ?? 'auto/bynara';
  final nvidiaModel =
      (dotenv.isInitialized ? dotenv.env['NVIDIA_MODEL'] : null) ??
      'openai/gpt-oss-20b';

  sl.registerLazySingleton<AiGatewayClient>(
    () => AiGatewayClient(
      naraApiKey: naraApiKey,
      nvidiaApiKey: nvidiaApiKey,
      naraBaseUrl: naraBaseUrl,
      nvidiaBaseUrl: nvidiaBaseUrl,
      naraModel: naraModel,
      nvidiaModel: nvidiaModel,
    ),
  );

  // Keep the legacy AI backend for sessions/history, but use the external
  // gateway as a direct fallback for tutor chat when the backend is offline.
  sl.registerLazySingleton<LexiChatDataSource>(
    () => LexiChatDataSource(
      apiClient: sl<AiApiClient>(),
      aiGatewayClient: sl<AiGatewayClient>(),
    ),
  );

  // Repository
  sl.registerLazySingleton<LexiChatRepository>(
    () => LexiChatRepositoryImpl(dataSource: sl<LexiChatDataSource>()),
  );

  // Provider (factory → one per widget)
  sl.registerFactory<LexiChatProvider>(
    () => LexiChatProvider(
      repository: sl<LexiChatRepository>(),
      aiClient: sl<AiApiClient>(),
    ),
  );
}
