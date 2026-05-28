import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../../home/data/models/business_model.dart';
import '../../data/models/menu_model.dart';
import 'menus_state.dart';

class MenusCubit extends Cubit<MenusState> {
  MenusCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const MenusState());

  final ApiClient _apiClient;

  Future<void> loadMine() async {
    emit(state.copyWith(status: MenusStatus.loading));
    final businessResult = await _apiClient.get<BusinessModel?>(
      '/negocios/mi-negocio',
      parser: (json) {
        if (json is List && json.isNotEmpty) {
          return BusinessModel.fromJson(
            Map<String, dynamic>.from(json.first as Map),
          );
        }
        return null;
      },
    );
    final businessId = businessResult.data?.id;
    if (!businessResult.isSuccess || businessId == null) {
      emit(
        state.copyWith(
          status: MenusStatus.failure,
          message: businessResult.error?.message ?? 'No tienes negocio creado.',
        ),
      );
      return;
    }

    final menusResult = await _apiClient.get<List<MenuModel>>(
      '/menus/$businessId',
      queryParameters: {'limit': 50, 'order': 'created_at.desc'},
      parser: _parseMenus,
    );

    if (!menusResult.isSuccess) {
      emit(
        state.copyWith(
          status: MenusStatus.failure,
          businessId: businessId,
          message: menusResult.error?.message ?? 'No se pudieron cargar menus.',
        ),
      );
      return;
    }

    final menus = menusResult.data ?? const [];
    final items = <String, List<MenuItemModel>>{};
    for (final menu in menus) {
      final result = await _apiClient.get<List<MenuItemModel>>(
        '/menus/${menu.id}/items',
        queryParameters: {'limit': 80, 'order': 'orden.asc'},
        parser: _parseItems,
      );
      items[menu.id] = result.data ?? const [];
    }

    emit(
      state.copyWith(
        status: MenusStatus.success,
        businessId: businessId,
        menus: menus,
        itemsByMenu: items,
      ),
    );
  }

  Future<void> createMenu({required String name, String? description}) async {
    final businessId = state.businessId;
    if (businessId == null) return;

    emit(state.copyWith(status: MenusStatus.saving));
    final result = await _apiClient.post<void>(
      '/menus',
      data: {
        'negocio_id': businessId,
        'nombre': name,
        'descripcion': description,
        'activo': true,
      },
      parser: (_) {},
    );
    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: MenusStatus.failure,
          message: result.error?.message ?? 'No se pudo crear menu.',
        ),
      );
      return;
    }
    emit(state.copyWith(status: MenusStatus.success, message: 'Menu creado.'));
    await loadMine();
  }

  Future<void> createItem({
    required String menuId,
    required String name,
    required double price,
    String? category,
    String? description,
    String currency = 'CUP',
  }) async {
    emit(state.copyWith(status: MenusStatus.saving));
    final result = await _apiClient.post<void>(
      '/menus/$menuId/items',
      data: {
        'nombre': name,
        'precio': price,
        'categoria': category,
        'descripcion': description,
        'moneda': currency,
        'disponible': true,
      },
      parser: (_) {},
    );
    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: MenusStatus.failure,
          message: result.error?.message ?? 'No se pudo crear item.',
        ),
      );
      return;
    }
    emit(state.copyWith(status: MenusStatus.success, message: 'Item agregado.'));
    await loadMine();
  }

  Future<void> generateQr(String menuId) async {
    emit(state.copyWith(status: MenusStatus.saving));
    final result = await _apiClient.post<void>(
      '/menus/$menuId/generar-qr',
      data: const {},
      parser: (_) {},
    );
    emit(
      state.copyWith(
        status: result.isSuccess ? MenusStatus.success : MenusStatus.failure,
        message: result.isSuccess
            ? 'QR generado.'
            : result.error?.message ?? 'No se pudo generar QR.',
      ),
    );
    await loadMine();
  }

  List<MenuModel> _parseMenus(dynamic json) {
    if (json is List) {
      return json
          .whereType<Map>()
          .map((item) => MenuModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    return const [];
  }

  List<MenuItemModel> _parseItems(dynamic json) {
    if (json is List) {
      return json
          .whereType<Map>()
          .map((item) => MenuItemModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    return const [];
  }
}
