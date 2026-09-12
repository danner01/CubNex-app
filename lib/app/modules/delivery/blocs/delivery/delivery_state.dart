import 'package:equatable/equatable.dart';

import '../../data/models/delivery_entrega_model.dart';
import '../../data/models/delivery_profile_model.dart';

enum DeliveryStatus { initial, loading, ready, failure }

class DeliveryState extends Equatable {
  const DeliveryState({
    this.status = DeliveryStatus.initial,
    this.profile,
    this.availableEntregas = const [],
    this.acceptedEntrega,
    this.isUpdatingProfile = false,
    this.refreshingQueue = false,
    this.acceptingEntregaId,
    this.errorMessage,
    this.queueError,
  });

  final DeliveryStatus status;
  final DeliveryProfileModel? profile;
  final List<DeliveryEntregaModel> availableEntregas;
  final DeliveryEntregaModel? acceptedEntrega;
  final bool isUpdatingProfile;
  final bool refreshingQueue;
  final String? acceptingEntregaId;
  final String? errorMessage;
  final String? queueError;

  static const _unset = Object();

  DeliveryState copyWith({
    DeliveryStatus? status,
    Object? profile = _unset,
    List<DeliveryEntregaModel>? availableEntregas,
    Object? acceptedEntrega = _unset,
    bool? isUpdatingProfile,
    bool? refreshingQueue,
    Object? acceptingEntregaId = _unset,
    Object? errorMessage = _unset,
    Object? queueError = _unset,
  }) {
    return DeliveryState(
      status: status ?? this.status,
      profile: identical(profile, _unset)
          ? this.profile
          : profile as DeliveryProfileModel?,
      availableEntregas: availableEntregas ?? this.availableEntregas,
      acceptedEntrega: identical(acceptedEntrega, _unset)
          ? this.acceptedEntrega
          : acceptedEntrega as DeliveryEntregaModel?,
      isUpdatingProfile: isUpdatingProfile ?? this.isUpdatingProfile,
      refreshingQueue: refreshingQueue ?? this.refreshingQueue,
      acceptingEntregaId: identical(acceptingEntregaId, _unset)
          ? this.acceptingEntregaId
          : acceptingEntregaId as String?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      queueError: identical(queueError, _unset)
          ? this.queueError
          : queueError as String?,
    );
  }

  @override
  List<Object?> get props => [
    status,
    profile,
    availableEntregas,
    acceptedEntrega,
    isUpdatingProfile,
    refreshingQueue,
    acceptingEntregaId,
    errorMessage,
    queueError,
  ];
}
