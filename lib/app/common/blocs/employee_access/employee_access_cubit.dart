import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../config/http/api_client.dart';
import '../../../modules/business/data/models/business_employee_model.dart';
import '../../entities/employee_permissions.dart';

enum EmployeeAccessStatus { initial, loading, ready, failure }

class EmployeeAccessState extends Equatable {
  const EmployeeAccessState({
    this.status = EmployeeAccessStatus.initial,
    this.memberships = const [],
    this.pendingInvites = const [],
    this.message,
  });

  final EmployeeAccessStatus status;
  final List<BusinessEmployeeModel> memberships;
  final List<BusinessEmployeeModel> pendingInvites;
  final String? message;

  bool get hasActiveMembership => memberships.isNotEmpty;

  bool get hasDeliveryMembership =>
      memberships.any((item) => item.isDelivery && item.isActive);

  Map<String, bool> permissionsForBusiness(String? businessId) {
    if (businessId == null || businessId.isEmpty) {
      return EmployeePermissionKeys.normalize(null);
    }
    final match = memberships.where((item) => item.businessId == businessId);
    if (match.isEmpty) {
      return EmployeePermissionKeys.normalize(null);
    }
    return match.first.permissions;
  }

  bool can(String businessId, String permission) {
    return EmployeePermissionKeys.allows(
      permissionsForBusiness(businessId),
      permission,
    );
  }

  EmployeeAccessState copyWith({
    EmployeeAccessStatus? status,
    List<BusinessEmployeeModel>? memberships,
    List<BusinessEmployeeModel>? pendingInvites,
    String? message,
    bool clearMessage = false,
  }) {
    return EmployeeAccessState(
      status: status ?? this.status,
      memberships: memberships ?? this.memberships,
      pendingInvites: pendingInvites ?? this.pendingInvites,
      message: clearMessage ? null : message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, memberships, pendingInvites, message];
}

class EmployeeAccessCubit extends Cubit<EmployeeAccessState> {
  EmployeeAccessCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const EmployeeAccessState());

  final ApiClient _apiClient;

  Future<void> load() async {
    emit(
      state.copyWith(status: EmployeeAccessStatus.loading, clearMessage: true),
    );

    final result = await _apiClient.get<List<BusinessEmployeeModel>>(
      '/empleados/mis-empleos',
      queryParameters: {'limit': 100, 'order': 'updated_at.desc'},
      parser: (json) {
        if (json is! List) return const <BusinessEmployeeModel>[];
        return json
            .whereType<Map>()
            .map(
              (item) => BusinessEmployeeModel.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();
      },
    );

    if (!result.isSuccess) {
      if (state.memberships.isNotEmpty) {
        emit(
          state.copyWith(
            status: EmployeeAccessStatus.ready,
            message: result.error?.message ?? 'No se pudieron cargar empleos.',
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: EmployeeAccessStatus.failure,
            memberships: const [],
            pendingInvites: const [],
            message: result.error?.message ?? 'No se pudieron cargar empleos.',
          ),
        );
      }
      return;
    }

    final rows = result.data ?? const <BusinessEmployeeModel>[];
    emit(
      EmployeeAccessState(
        status: EmployeeAccessStatus.ready,
        memberships: rows.where((item) => item.isActive).toList(),
        pendingInvites: rows.where((item) => item.isPending).toList(),
      ),
    );
  }

  Future<String?> respondToInvite({
    required String employeeId,
    required bool accept,
  }) async {
    final result = await _apiClient.post<Map<String, dynamic>>(
      '/empleados/$employeeId/${accept ? 'aceptar' : 'rechazar'}',
      parser: (json) {
        if (json is Map<String, dynamic>) return json;
        if (json is Map) return Map<String, dynamic>.from(json);
        return <String, dynamic>{};
      },
    );

    if (!result.isSuccess) {
      return result.error?.message ?? 'No se pudo responder la invitacion.';
    }

    await load();
    return null;
  }

  Future<void> clear() async {
    emit(const EmployeeAccessState());
  }
}
