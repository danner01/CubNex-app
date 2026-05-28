import 'package:equatable/equatable.dart';

import '../../data/models/menu_model.dart';

enum MenusStatus { initial, loading, success, failure, saving }

class MenusState extends Equatable {
  const MenusState({
    this.status = MenusStatus.initial,
    this.businessId,
    this.menus = const [],
    this.itemsByMenu = const {},
    this.message,
  });

  final MenusStatus status;
  final String? businessId;
  final List<MenuModel> menus;
  final Map<String, List<MenuItemModel>> itemsByMenu;
  final String? message;

  MenusState copyWith({
    MenusStatus? status,
    String? businessId,
    List<MenuModel>? menus,
    Map<String, List<MenuItemModel>>? itemsByMenu,
    String? message,
  }) {
    return MenusState(
      status: status ?? this.status,
      businessId: businessId ?? this.businessId,
      menus: menus ?? this.menus,
      itemsByMenu: itemsByMenu ?? this.itemsByMenu,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, businessId, menus, itemsByMenu, message];
}
