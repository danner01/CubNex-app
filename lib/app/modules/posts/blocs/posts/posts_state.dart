import 'package:equatable/equatable.dart';

import '../../data/models/business_post_model.dart';

enum PostsStatus { initial, loading, success, failure, saving }

class PostsState extends Equatable {
  const PostsState({
    this.status = PostsStatus.initial,
    this.items = const [],
    this.businessItems = const [],
    this.comments = const {},
    this.message,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  final PostsStatus status;
  final List<BusinessPostModel> items;
  final List<BusinessPostModel> businessItems;
  final Map<String, List<PostCommentModel>> comments;
  final String? message;
  final bool hasMore;
  final bool isLoadingMore;

  PostsState copyWith({
    PostsStatus? status,
    List<BusinessPostModel>? items,
    List<BusinessPostModel>? businessItems,
    Map<String, List<PostCommentModel>>? comments,
    String? message,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return PostsState(
      status: status ?? this.status,
      items: items ?? this.items,
      businessItems: businessItems ?? this.businessItems,
      comments: comments ?? this.comments,
      message: message,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
    status,
    items,
    businessItems,
    comments,
    message,
    hasMore,
    isLoadingMore,
  ];
}
