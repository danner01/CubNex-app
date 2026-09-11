import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../../config/theme/app_colors.dart';
import '../../blocs/posts/posts_cubit.dart';
import '../../blocs/posts/posts_state.dart';
import '../../data/models/business_post_model.dart';

class PostsFeedScreen extends StatelessWidget {
  const PostsFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PostsCubit>()..loadFeed(),
      child: const _PostsFeedView(),
    );
  }
}

class _PostsFeedView extends StatelessWidget {
  const _PostsFeedView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<PostsCubit, PostsState>(
        listener: (context, state) {
          if (state.message != null) {
            showSnackOrAuthDialog(context, state.message);
          }
        },
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: () => context.read<PostsCubit>().loadFeed(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Text(
                  'Feed ConKkao',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Publicaciones premium de negocios, ofertas y novedades.'),
                const SizedBox(height: 16),
                if (state.status == PostsStatus.loading && state.items.isEmpty)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(28),
                    child: CircularProgressIndicator(),
                  ))
                else if (state.items.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('Aun no hay publicaciones activas.'),
                    ),
                  )
                else
                  ...state.items.map((post) => _PostCard(post: post)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});

  final BusinessPostModel post;

  @override
  Widget build(BuildContext context) {
    final business = post.business;
    final imageUrl = post.mediaUrls.isNotEmpty
        ? post.mediaUrls.first
        : business?.bannerUrl;
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.16),
              backgroundImage: business?.logoUrl?.isNotEmpty == true
                  ? NetworkImage(business!.logoUrl!)
                  : null,
              child: business?.logoUrl?.isNotEmpty == true
                  ? null
                  : const Icon(Icons.storefront_rounded),
            ),
            title: Text(
              business?.name ?? 'Negocio',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text([business?.province, post.type].whereType<String>().join(' · ')),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Premium',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
            onTap: business == null ? null : () => context.go(AppRoutes.store(business.id)),
          ),
          if (imageUrl != null && imageUrl.isNotEmpty)
            AspectRatio(
              aspectRatio: 1,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported_outlined),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _PostAction(
                      icon: Icons.favorite_border_rounded,
                      label: '${post.likesCount}',
                      onTap: () => context.read<PostsCubit>().like(post.id),
                    ),
                    _PostAction(
                      icon: Icons.mode_comment_outlined,
                      label: '${post.commentsCount}',
                      onTap: () => _showComments(context, post),
                    ),
                    _PostAction(
                      icon: Icons.ios_share_rounded,
                      label: '${post.sharesCount}',
                      onTap: () async {
                        final link =
                            await context.read<PostsCubit>().share(post.id);
                        final title =
                            post.title ?? business?.name ?? 'Publicacion ConKkao';
                        final text = [
                          title,
                          if (post.content.trim().isNotEmpty) post.content.trim(),
                          if (link != null && link.isNotEmpty) link,
                        ].join('\n');
                        await Share.share(
                          text,
                          subject: post.title ?? business?.name ?? 'ConKkao',
                        );
                      },
                    ),
                    const Spacer(),
                    if (post.views > 0)
                      Text(
                        '${post.views} vistas',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (post.title?.isNotEmpty == true)
                  Text(
                    post.title!,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                if (post.title?.isNotEmpty == true) const SizedBox(height: 4),
                Text(post.content),
                if (post.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: post.tags
                        .map(
                          (tag) => Text(
                            '#$tag',
                            style: TextStyle(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showComments(BuildContext context, BusinessPostModel post) {
    context.read<PostsCubit>().loadComments(post.id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<PostsCubit>(),
        child: _CommentsSheet(post: post),
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  const _PostAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.post});

  final BusinessPostModel post;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 16),
      child: BlocConsumer<PostsCubit, PostsState>(
        listener: (context, state) {
          if (state.message != null) {
            showSnackOrAuthDialog(context, state.message);
          }
        },
        builder: (context, state) {
          final comments = state.comments[widget.post.id] ?? const [];
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Comentarios',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: comments.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Text('Se el primero en comentar.'),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: comments.length,
                        separatorBuilder: (_, __) => const Divider(height: 18),
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundImage: comment.avatarUrl?.isNotEmpty == true
                                  ? NetworkImage(comment.avatarUrl!)
                                  : null,
                              child: comment.avatarUrl?.isNotEmpty == true
                                  ? null
                                  : const Icon(Icons.person_outline_rounded),
                            ),
                            title: Text(
                              comment.userName ?? 'Usuario',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            subtitle: Text(comment.comment),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(hintText: 'Escribe un comentario'),
                      minLines: 1,
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: state.status == PostsStatus.saving
                        ? null
                        : () {
                            context.read<PostsCubit>().comment(widget.post.id, _controller.text);
                            _controller.clear();
                          },
                    child: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
