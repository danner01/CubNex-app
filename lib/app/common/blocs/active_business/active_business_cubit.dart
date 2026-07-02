import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/http/api_client.dart';
import '../../../config/http/api_result.dart';
import '../../../modules/home/data/models/business_model.dart';

enum ActiveBusinessStatus { initial, loading, success, empty, failure }

class ActiveBusinessState extends Equatable {
  const ActiveBusinessState({
    this.status = ActiveBusinessStatus.initial,
    this.businesses = const [],
    this.activeBusiness,
    this.message,
  });

  final ActiveBusinessStatus status;
  final List<BusinessModel> businesses;
  final BusinessModel? activeBusiness;
  final String? message;

  bool get hasMultipleBusinesses => businesses.length > 1;

  ActiveBusinessState copyWith({
    ActiveBusinessStatus? status,
    List<BusinessModel>? businesses,
    BusinessModel? activeBusiness,
    bool clearActiveBusiness = false,
    String? message,
    bool clearMessage = false,
  }) {
    return ActiveBusinessState(
      status: status ?? this.status,
      businesses: businesses ?? this.businesses,
      activeBusiness: clearActiveBusiness
          ? null
          : activeBusiness ?? this.activeBusiness,
      message: clearMessage ? null : message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, businesses, activeBusiness, message];
}

class ActiveBusinessCubit extends Cubit<ActiveBusinessState> {
  ActiveBusinessCubit({
    required ApiClient apiClient,
    required SharedPreferences sharedPreferences,
  }) : _apiClient = apiClient,
       _sharedPreferences = sharedPreferences,
       super(const ActiveBusinessState());

  static const _storageKey = 'business.active.id';

  final ApiClient _apiClient;
  final SharedPreferences _sharedPreferences;

  Future<void> load() async {
    emit(
      state.copyWith(status: ActiveBusinessStatus.loading, clearMessage: true),
    );

    final result = await _safeLoadBusinesses();

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: ActiveBusinessStatus.failure,
          message:
              result.error?.message ??
              'No se pudieron cargar tus negocios. Revisa la conexion.',
        ),
      );
      return;
    }

    final businesses = result.data ?? const <BusinessModel>[];
    if (businesses.isEmpty) {
      await _sharedPreferences.remove(_storageKey);
      emit(const ActiveBusinessState(status: ActiveBusinessStatus.empty));
      return;
    }

    final savedId = _sharedPreferences.getString(_storageKey);
    final active = businesses.firstWhere(
      (business) => business.id == savedId,
      orElse: () => businesses.first,
    );
    await _sharedPreferences.setString(_storageKey, active.id);

    emit(
      ActiveBusinessState(
        status: ActiveBusinessStatus.success,
        businesses: businesses,
        activeBusiness: active,
      ),
    );
  }

  Future<ApiResult<List<BusinessModel>>> _safeLoadBusinesses() async {
    try {
      return await _apiClient
          .get<List<BusinessModel>>(
            '/negocios/mis-negocios',
            queryParameters: {'limit': 100, 'order': 'created_at.desc'},
            parser: (json) {
              if (json is List) {
                return json
                    .whereType<Map>()
                    .map(
                      (item) => BusinessModel.fromJson(
                        Map<String, dynamic>.from(item),
                      ),
                    )
                    .toList();
              }
              return const [];
            },
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      return const ApiResult.failure(
        ApiFailure(
          code: 'business_load_timeout',
          message: 'La carga de negocios tardo demasiado.',
        ),
      );
    }
  }

  Future<void> selectBusiness(BusinessModel business) async {
    if (!state.businesses.any((item) => item.id == business.id)) return;

    await _sharedPreferences.setString(_storageKey, business.id);
    emit(
      state.copyWith(
        status: ActiveBusinessStatus.success,
        activeBusiness: business,
        clearMessage: true,
      ),
    );
  }

  Future<void> clear() async {
    await _sharedPreferences.remove(_storageKey);
    emit(const ActiveBusinessState());
  }
}
