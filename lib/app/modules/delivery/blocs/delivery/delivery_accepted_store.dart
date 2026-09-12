import 'package:flutter/foundation.dart';

import '../../data/models/delivery_entrega_model.dart';

class DeliveryAcceptedStore {
  final ValueNotifier<DeliveryEntregaModel?> accepted = ValueNotifier(null);

  void accept(DeliveryEntregaModel entrega) => accepted.value = entrega;
}
