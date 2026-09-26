import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../common/blocs/active_business/active_business_cubit.dart';
import '../../../../common/entities/employee_permissions.dart';
import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import '../../../business/presentation/widgets/business_switcher.dart';
import '../../blocs/posts/posts_cubit.dart';
import '../../blocs/posts/posts_state.dart';
import '../../data/models/business_post_model.dart';

class BusinessPostsScreen extends StatelessWidget {
  const BusinessPostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PostsCubit>(),
      child: const _BusinessPostsView(),
    );
  }
}

class _BusinessPostsView extends StatefulWidget {
  const _BusinessPostsView();

  @override
  State<_BusinessPostsView> createState() => _BusinessPostsViewState();
}

class _BusinessPostsViewState extends State<_BusinessPostsView> {
  String _filter = 'todas';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final business = context.read<ActiveBusinessCubit>().state.activeBusiness;
    if (business != null) {
      context.read<PostsCubit>().loadBusinessPosts(business.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final business = context.watch<ActiveBusinessCubit>().state.activeBusiness;
    final canManage =
        business?.canEmployee(EmployeePermissionKeys.gestionarPublicaciones) ??
        false;
    return Scaffold(
      floatingActionButton: canManage && business != null
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(context, business.id),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Crear'),
            )
          : null,
      body: BlocConsumer<PostsCubit, PostsState>(
        listener: (context, state) {
          if (state.message != null) {
            showSnackOrAuthDialog(context, state.message);
          }
        },
        builder: (context, state) {
          final posts = state.businessItems.where((post) {
            return _filter == 'todas' || post.status == _filter;
          }).toList();
          return RefreshIndicator(
            onRefresh: () async {
              if (business != null) {
                await context.read<PostsCubit>().loadBusinessPosts(business.id);
              }
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              children: [
                Text(
                  'Publicaciones',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  business == null
                      ? 'Selecciona un negocio para gestionar su contenido.'
                      : 'Crea contenido, guárdalo como borrador y sigue su moderación.',
                ),
                BusinessSwitcher(
                  onChanged: () {
                    final active = context
                        .read<ActiveBusinessCubit>()
                        .state
                        .activeBusiness;
                    if (active != null) {
                      context.read<PostsCubit>().loadBusinessPosts(active.id);
                    }
                  },
                ),
                const SizedBox(height: 14),
                if (!canManage && business != null)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'No tienes permiso para gestionar publicaciones de este negocio.',
                      ),
                    ),
                  ),
                if (business != null && canManage) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'todas', label: Text('Todas')),
                        ButtonSegment(
                          value: 'borrador',
                          label: Text('Borradores'),
                        ),
                        ButtonSegment(
                          value: 'pendiente_revision',
                          label: Text('En revisión'),
                        ),
                        ButtonSegment(
                          value: 'publicado',
                          label: Text('Publicadas'),
                        ),
                        ButtonSegment(
                          value: 'rechazado',
                          label: Text('Rechazadas'),
                        ),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (value) =>
                          setState(() => _filter = value.first),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (state.status == PostsStatus.loading &&
                      state.businessItems.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(30),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (posts.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No hay publicaciones en este estado.'),
                      ),
                    )
                  else
                    ...posts.map(
                      (post) => _BusinessPostCard(
                        post: post,
                        onEdit: () =>
                            _openEditor(context, business.id, post: post),
                        onDelete: () => _deletePost(context, business.id, post),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    String businessId, {
    BusinessPostModel? post,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          // A pushed route is a sibling of this page's route, not its child.
          // Give the editor its own cubit and reload the list when it returns.
          create: (_) => sl<PostsCubit>(),
          child: _PostEditorScreen(businessId: businessId, post: post),
        ),
      ),
    );
    if (saved == true && context.mounted) {
      await context.read<PostsCubit>().loadBusinessPosts(businessId);
    }
  }

  Future<void> _deletePost(
    BuildContext context,
    String businessId,
    BusinessPostModel post,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar publicación'),
        content: const Text(
          'Esta acción eliminará el contenido y sus interacciones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<PostsCubit>().deleteBusinessPost(businessId, post.id);
    }
  }
}

class _BusinessPostCard extends StatelessWidget {
  const _BusinessPostCard({
    required this.post,
    required this.onEdit,
    required this.onDelete,
  });

  final BusinessPostModel post;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final image = post.mediaUrls.isEmpty ? null : post.mediaUrls.first;
    final (label, color) = switch (post.status) {
      'borrador' => ('Borrador', Colors.blueGrey),
      'pendiente_revision' => ('En revisión', Colors.orange),
      'publicado' => ('Publicada', Colors.green),
      'rechazado' => ('Rechazada', Colors.red),
      'pausado' => ('Pausada', Colors.grey),
      _ => (post.status, Colors.grey),
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (image != null)
            AspectRatio(
              aspectRatio: 2.2,
              child: Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(Icons.image_not_supported_outlined),
                ),
              ),
            ),
          ListTile(
            title: Text(
              post.title?.isNotEmpty == true ? post.title! : post.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${post.likesCount} me gusta · ${post.commentsCount} comentarios · ${post.views} vistas',
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => value == 'editar' ? onEdit() : onDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'editar', child: Text('Editar')),
                PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(
                  label: Text(label),
                  avatar: Icon(Icons.circle, color: color, size: 12),
                ),
                if (post.scheduledAt != null) Chip(label: Text('Programada')),
                if (post.rejectionReason?.isNotEmpty == true)
                  Chip(
                    label: Text(post.rejectionReason!),
                    avatar: const Icon(Icons.info_outline, size: 16),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PostEditorScreen extends StatefulWidget {
  const _PostEditorScreen({required this.businessId, this.post});

  final String businessId;
  final BusinessPostModel? post;

  @override
  State<_PostEditorScreen> createState() => _PostEditorScreenState();
}

class _PostEditorScreenState extends State<_PostEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _content;
  late final TextEditingController _tags;
  late final TextEditingController _link;
  late final TextEditingController _cta;
  late final TextEditingController _price;
  late List<String> _mediaUrls;
  String _type = 'post';
  bool _uploading = false;
  bool _saving = false;
  DateTime? _scheduledAt;

  @override
  void initState() {
    super.initState();
    final post = widget.post;
    _title = TextEditingController(text: post?.title);
    _content = TextEditingController(text: post?.content);
    _tags = TextEditingController(text: post?.tags.join(', '));
    _link = TextEditingController(text: post?.linkUrl);
    _cta = TextEditingController(text: post?.ctaText);
    _price = TextEditingController(
      text: post?.precio == null ? null : post!.precio!.toStringAsFixed(2),
    );
    _mediaUrls = [...?post?.mediaUrls];
    _type = post?.type ?? 'post';
    _scheduledAt = post?.scheduledAt;
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _tags.dispose();
    _link.dispose();
    _cta.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.post == null ? 'Nueva publicación' : 'Editar publicación',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Título opcional'),
              maxLength: 100,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _content,
              decoration: const InputDecoration(labelText: 'Contenido'),
              minLines: 5,
              maxLines: 10,
              maxLength: 2200,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Escribe el contenido de la publicación.'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Tipo de publicación',
              ),
              items: const [
                DropdownMenuItem(value: 'post', child: Text('Publicación')),
                DropdownMenuItem(value: 'promocion', child: Text('Promoción')),
                DropdownMenuItem(value: 'historia', child: Text('Historia')),
                DropdownMenuItem(value: 'reel', child: Text('Reel')),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _type = value ?? 'post'),
            ),
            if (_type == 'promocion') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Precio del producto o servicio',
                  hintText: 'Ej: 1500',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Indica el precio de la promocion.';
                  }
                  final parsed = double.tryParse(
                    value.trim().replaceAll(',', '.'),
                  );
                  if (parsed == null || parsed < 0) {
                    return 'Precio invalido.';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 12),
            _MediaPicker(
              urls: _mediaUrls,
              uploading: _uploading,
              onAdd: _uploadImage,
              onRemove: (url) => setState(() => _mediaUrls.remove(url)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tags,
              decoration: const InputDecoration(
                labelText: 'Etiquetas',
                hintText: 'oferta, verano, la-habana',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _link,
              decoration: const InputDecoration(
                labelText: 'Enlace de destino opcional',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cta,
              decoration: const InputDecoration(
                labelText: 'Texto del botón opcional',
                hintText: 'Ver oferta',
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_outlined),
              title: Text(
                _scheduledAt == null
                    ? 'Publicar después de la aprobación'
                    : 'Programada: ${_scheduledAt!.day}/${_scheduledAt!.month}/${_scheduledAt!.year}',
              ),
              trailing: TextButton(
                onPressed: _saving ? null : _pickSchedule,
                child: Text(_scheduledAt == null ? 'Programar' : 'Cambiar'),
              ),
            ),
            if (_scheduledAt != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _scheduledAt = null),
                  child: const Text('Quitar programación'),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving || _uploading ? null : () => _save(false),
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: const Text('Enviar a revisión'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving || _uploading ? null : () => _save(true),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar borrador'),
            ),
            const SizedBox(height: 18),
            Text(
              'Al enviar, la publicación será revisada antes de aparecer en el feed.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (image == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final result = await sl<ApiClient>().post<Map<String, dynamic>>(
        '/storage/subir',
        data: {
          'archivo_base64': base64Encode(await image.readAsBytes()),
          'nombre_archivo':
              'post-${widget.businessId}-${DateTime.now().millisecondsSinceEpoch}.jpg',
          'content_type': 'image/jpeg',
          'bucket': 'negocios',
          'scope': 'publicaciones',
          'negocio_id': widget.businessId,
        },
        parser: (json) => json is Map ? Map<String, dynamic>.from(json) : {},
      );
      final url = result.data?['public_url']?.toString();
      if (!mounted) return;
      if (!result.isSuccess || url == null || url.isEmpty) {
        showSnackOrAuthDialog(
          context,
          result.error?.message ?? 'No se pudo subir la imagen.',
        );
      } else {
        setState(() => _mediaUrls.add(url));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickSchedule() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _scheduledAt ?? DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt ?? DateTime.now()),
    );
    if (time != null) {
      setState(
        () => _scheduledAt = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> _save(bool draft) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final tags = _tags.text
        .split(',')
        .map((tag) => tag.trim().replaceFirst(RegExp(r'^#'), ''))
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
    final saved = await context.read<PostsCubit>().saveBusinessPost(
      businessId: widget.businessId,
      postId: widget.post?.id,
      content: _content.text,
      title: _title.text,
      type: _type,
      mediaUrls: _mediaUrls,
      mediaType: _type == 'reel' ? 'video' : 'imagen',
      tags: tags,
      precio: _type == 'promocion'
          ? double.tryParse(_price.text.trim().replaceAll(',', '.'))
          : null,
      linkUrl: _link.text,
      ctaText: _cta.text,
      scheduledAt: _scheduledAt,
      saveAsDraft: draft,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.pop(context, true);
  }
}

class _MediaPicker extends StatelessWidget {
  const _MediaPicker({
    required this.urls,
    required this.uploading,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> urls;
  final bool uploading;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Imágenes')),
            TextButton.icon(
              onPressed: uploading ? null : onAdd,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(uploading ? 'Subiendo...' : 'Agregar'),
            ),
          ],
        ),
        if (urls.isNotEmpty)
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: urls.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      urls[index],
                      width: 112,
                      height: 112,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: IconButton.filledTonal(
                      onPressed: () => onRemove(urls[index]),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
