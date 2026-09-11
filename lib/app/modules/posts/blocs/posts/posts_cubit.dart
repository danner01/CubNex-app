import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../data/models/business_post_model.dart';
import 'posts_state.dart';

class PostsCubit extends Cubit<PostsState> {
  PostsCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const PostsState());

  final ApiClient _apiClient;

  Future<void> loadFeed() async {
    emit(state.copyWith(status: PostsStatus.loading, message: null));
    final result = await _apiClient.get<List<BusinessPostModel>>(
      '/publicaciones/feed',
      queryParameters: {'limit': 30, 'order': 'created_at.desc'},
      parser: _parsePosts,
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: PostsStatus.failure,
          message: result.error?.message ?? 'No se pudo cargar el feed.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: PostsStatus.success,
        items: result.data ?? const [],
      ),
    );
  }

  Future<void> loadBusinessPosts(String businessId) async {
    emit(state.copyWith(status: PostsStatus.loading, message: null));
    final result = await _apiClient.get<List<BusinessPostModel>>(
      '/publicaciones/negocio/$businessId',
      queryParameters: {'order': 'created_at.desc'},
      parser: _parsePosts,
    );
    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: PostsStatus.failure,
          message:
              result.error?.message ??
              'No se pudieron cargar tus publicaciones.',
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: PostsStatus.success,
        businessItems: result.data ?? const [],
      ),
    );
  }

  Future<bool> saveBusinessPost({
    required String businessId,
    String? postId,
    required String content,
    String? title,
    required String type,
    required List<String> mediaUrls,
    required String mediaType,
    required List<String> tags,
    String? linkUrl,
    String? ctaText,
    DateTime? scheduledAt,
    required bool saveAsDraft,
  }) async {
    emit(state.copyWith(status: PostsStatus.saving, message: null));
    final data = <String, dynamic>{
      'negocio_id': businessId,
      'contenido': content.trim(),
      'titulo': title?.trim(),
      'tipo': type,
      'media_urls': mediaUrls,
      'media_tipo': mediaType,
      'tags': tags,
      'enlace_url': linkUrl?.trim(),
      'cta_texto': ctaText?.trim(),
      'fecha_programada': scheduledAt?.toIso8601String(),
      'estado': saveAsDraft ? 'borrador' : 'pendiente_revision',
    }..removeWhere((_, value) => value == null || value == '');
    final result = postId == null
        ? await _apiClient.post<List<BusinessPostModel>>(
            '/publicaciones',
            data: data,
            parser: _parsePosts,
          )
        : await _apiClient.put<List<BusinessPostModel>>(
            '/publicaciones/$postId',
            data: data,
            parser: _parsePosts,
          );
    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: PostsStatus.failure,
          message:
              result.error?.message ?? 'No se pudo guardar la publicación.',
        ),
      );
      return false;
    }
    await loadBusinessPosts(businessId);
    return true;
  }

  Future<bool> deleteBusinessPost(String businessId, String postId) async {
    emit(state.copyWith(status: PostsStatus.saving, message: null));
    final result = await _apiClient.delete<void>(
      '/publicaciones/$postId',
      parser: (_) {},
    );
    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: PostsStatus.failure,
          message:
              result.error?.message ?? 'No se pudo eliminar la publicación.',
        ),
      );
      return false;
    }
    await loadBusinessPosts(businessId);
    return true;
  }

  List<BusinessPostModel> _parsePosts(dynamic json) {
    if (json is! List) return const [];
    return json
        .whereType<Map>()
        .map(
          (item) => BusinessPostModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<void> like(String postId) async {
    final result = await _apiClient.post<Map<String, dynamic>>(
      '/publicaciones/$postId/like',
      data: const {},
      parser: (json) =>
          json is Map ? Map<String, dynamic>.from(json) : const {},
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: PostsStatus.failure,
          message: result.error?.message,
        ),
      );
      return;
    }

    final nextCount = int.tryParse('${result.data?['likes_count'] ?? ''}');
    emit(
      state.copyWith(
        status: PostsStatus.success,
        items: state.items
            .map(
              (item) => item.id == postId
                  ? item.copyWith(likesCount: nextCount ?? item.likesCount + 1)
                  : item,
            )
            .toList(),
      ),
    );
  }

  Future<String?> share(String postId) async {
    final result = await _apiClient.post<Map<String, dynamic>>(
      '/publicaciones/$postId/compartir',
      data: const {},
      parser: (json) =>
          json is Map ? Map<String, dynamic>.from(json) : const {},
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: PostsStatus.failure,
          message: result.error?.message,
        ),
      );
      return null;
    }

    final nextCount = int.tryParse(
      '${result.data?['compartidos_count'] ?? ''}',
    );
    emit(
      state.copyWith(
        status: PostsStatus.success,
        items: state.items
            .map(
              (item) => item.id == postId
                  ? item.copyWith(
                      sharesCount: nextCount ?? item.sharesCount + 1,
                    )
                  : item,
            )
            .toList(),
      ),
    );

    final url = result.data?['url'];
    return url is String && url.isNotEmpty ? url : null;
  }

  Future<void> loadComments(String postId) async {
    final result = await _apiClient.get<List<PostCommentModel>>(
      '/publicaciones/$postId/comentarios',
      queryParameters: {'limit': 50, 'order': 'created_at.desc'},
      parser: (json) {
        if (json is List) {
          return json
              .whereType<Map>()
              .map(
                (item) =>
                    PostCommentModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
        }
        return const [];
      },
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: PostsStatus.failure,
          message: result.error?.message,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: PostsStatus.success,
        comments: {...state.comments, postId: result.data ?? const []},
      ),
    );
  }

  Future<void> comment(String postId, String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    emit(state.copyWith(status: PostsStatus.saving, message: null));
    final result = await _apiClient.post<void>(
      '/publicaciones/$postId/comentarios',
      data: {'comentario': cleanText},
      parser: (_) {},
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: PostsStatus.failure,
          message: result.error?.message,
        ),
      );
      return;
    }

    final nextItems = state.items
        .map(
          (item) => item.id == postId
              ? item.copyWith(commentsCount: item.commentsCount + 1)
              : item,
        )
        .toList();
    emit(state.copyWith(status: PostsStatus.success, items: nextItems));
    await loadComments(postId);
  }
}
