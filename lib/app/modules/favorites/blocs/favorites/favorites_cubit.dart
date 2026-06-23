import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../data/models/favorite_model.dart';
import 'favorites_state.dart';

class FavoritesCubit extends Cubit<FavoritesState> {
  FavoritesCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const FavoritesState());

  final ApiClient _apiClient;

  Future<void> load() async {
    emit(state.copyWith(status: FavoritesStatus.loading, message: null));
    final result = await _apiClient.get<List<FavoriteModel>>(
      '/favoritos',
      queryParameters: {'order': 'created_at.desc'},
      parser: (json) {
        if (json is List) {
          return json
              .whereType<Map>()
              .map((item) => FavoriteModel.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
        return const [];
      },
    );

    if (result.isSuccess) {
      final enriched = await Future.wait(
        (result.data ?? const []).map(_enrichFavorite),
      );
      emit(
        state.copyWith(
          status: FavoritesStatus.success,
          items: enriched,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: FavoritesStatus.failure,
        errorMessage: result.error?.message ?? 'No se pudieron cargar favoritos.',
      ),
    );
  }

  Future<void> deleteFavorite(String favoriteId) async {
    final previousItems = state.items;
    emit(
      state.copyWith(
        status: FavoritesStatus.deleting,
        items: previousItems.where((item) => item.id != favoriteId).toList(),
        message: null,
      ),
    );

    final result = await _apiClient.delete<bool>(
      '/favoritos/$favoriteId',
      parser: (_) => true,
    );

    if (result.isSuccess) {
      emit(
        state.copyWith(
          status: FavoritesStatus.success,
          message: 'Favorito eliminado.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: FavoritesStatus.failure,
        items: previousItems,
        errorMessage: result.error?.message ?? 'No se pudo eliminar favorito.',
      ),
    );
  }

  Future<FavoriteModel> _enrichFavorite(FavoriteModel favorite) async {
    final endpoint = _detailEndpoint(favorite);
    if (endpoint == null) return favorite;

    final result = await _apiClient.get<Map<String, dynamic>?>(
      endpoint,
      parser: (json) {
        if (json is List && json.isNotEmpty && json.first is Map) {
          return Map<String, dynamic>.from(json.first as Map);
        }
        if (json is Map) {
          return Map<String, dynamic>.from(json);
        }
        return null;
      },
    );

    final data = result.data;
    if (!result.isSuccess || data == null) return favorite;

    return favorite.copyWith(
      title: _titleFrom(data),
      subtitle: _subtitleFrom(favorite.entityType, data),
      imageUrl: _imageFrom(favorite.entityType, data),
    );
  }

  String? _detailEndpoint(FavoriteModel favorite) {
    return switch (favorite.entityType) {
      'producto' => '/productos/${favorite.entityId}',
      'negocio' => '/negocios/${favorite.entityId}',
      'propiedad' => '/propiedades/${favorite.entityId}',
      'servicio' => '/transporte/${favorite.entityId}',
      _ => null,
    };
  }

  String _titleFrom(Map<String, dynamic> data) {
    return '${data['nombre'] ?? data['titulo'] ?? 'Favorito'}';
  }

  String? _subtitleFrom(String entityType, Map<String, dynamic> data) {
    return switch (entityType) {
      'producto' => [
          data['marca'],
          data['precio'] == null
              ? null
              : '${data['precio']} ${data['moneda'] ?? 'CUP'}',
        ].where((value) => value != null && '$value'.isNotEmpty).join(' - '),
      'negocio' => [
          data['municipio'],
          data['provincia'],
          data['descripcion'],
        ].where((value) => value != null && '$value'.isNotEmpty).join(' - '),
      'propiedad' => [
          data['tipo'],
          data['municipio'],
          data['provincia'],
          data['precio'] == null
              ? null
              : '${data['precio']} ${data['moneda'] ?? 'CUP'}',
        ].where((value) => value != null && '$value'.isNotEmpty).join(' - '),
      'servicio' => [
          data['tipo'],
          data['vehiculo_tipo'],
          data['precio_base'] == null
              ? null
              : '${data['precio_base']} ${data['moneda'] ?? 'CUP'}',
        ].where((value) => value != null && '$value'.isNotEmpty).join(' - '),
      _ => null,
    };
  }

  String? _imageFrom(String entityType, Map<String, dynamic> data) {
    final images = data['imagenes'];
    if (entityType == 'negocio') {
      return data['banner_url']?.toString().isNotEmpty == true
          ? data['banner_url']?.toString()
          : data['logo_url']?.toString();
    }
    if (images is List && images.isNotEmpty) {
      return images.first?.toString();
    }
    return data['imagen_url']?.toString() ?? data['logo_url']?.toString();
  }
}
