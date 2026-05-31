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
      parser: (json) {
        if (json is List) {
          return json
              .whereType<Map>()
              .map((item) => BusinessPostModel.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
        return const [];
      },
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

    emit(state.copyWith(status: PostsStatus.success, items: result.data ?? const []));
  }

  Future<void> like(String postId) async {
    final result = await _apiClient.post<Map<String, dynamic>>(
      '/publicaciones/$postId/like',
      data: const {},
      parser: (json) => json is Map ? Map<String, dynamic>.from(json) : const {},
    );

    if (!result.isSuccess) {
      emit(state.copyWith(status: PostsStatus.failure, message: result.error?.message));
      return;
    }

    final nextCount = int.tryParse('${result.data?['likes_count'] ?? ''}');
    emit(
      state.copyWith(
        status: PostsStatus.success,
        items: state.items
            .map((item) => item.id == postId
                ? item.copyWith(likesCount: nextCount ?? item.likesCount + 1)
                : item)
            .toList(),
      ),
    );
  }

  Future<void> share(String postId) async {
    final result = await _apiClient.post<Map<String, dynamic>>(
      '/publicaciones/$postId/compartir',
      data: const {},
      parser: (json) => json is Map ? Map<String, dynamic>.from(json) : const {},
    );

    if (!result.isSuccess) {
      emit(state.copyWith(status: PostsStatus.failure, message: result.error?.message));
      return;
    }

    final nextCount = int.tryParse('${result.data?['compartidos_count'] ?? ''}');
    emit(
      state.copyWith(
        status: PostsStatus.success,
        items: state.items
            .map((item) => item.id == postId
                ? item.copyWith(sharesCount: nextCount ?? item.sharesCount + 1)
                : item)
            .toList(),
      ),
    );
  }

  Future<void> loadComments(String postId) async {
    final result = await _apiClient.get<List<PostCommentModel>>(
      '/publicaciones/$postId/comentarios',
      queryParameters: {'limit': 50, 'order': 'created_at.desc'},
      parser: (json) {
        if (json is List) {
          return json
              .whereType<Map>()
              .map((item) => PostCommentModel.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
        return const [];
      },
    );

    if (!result.isSuccess) {
      emit(state.copyWith(status: PostsStatus.failure, message: result.error?.message));
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
      emit(state.copyWith(status: PostsStatus.failure, message: result.error?.message));
      return;
    }

    final nextItems = state.items
        .map((item) => item.id == postId ? item.copyWith(commentsCount: item.commentsCount + 1) : item)
        .toList();
    emit(state.copyWith(status: PostsStatus.success, items: nextItems));
    await loadComments(postId);
  }
}
