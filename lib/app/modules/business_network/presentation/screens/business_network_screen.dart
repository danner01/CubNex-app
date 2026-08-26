import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/blocs/active_business/active_business_cubit.dart';
import '../../../../common/services/contact_service.dart';
import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/http/api_client.dart';
import '../../../../config/http/api_result.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../business/presentation/widgets/business_switcher.dart';
import '../../../home/data/models/business_model.dart';
import '../../../home/data/models/product_model.dart';
import '../../data/models/business_connection_model.dart';

class BusinessNetworkScreen extends StatefulWidget {
  const BusinessNetworkScreen({super.key});

  @override
  State<BusinessNetworkScreen> createState() => _BusinessNetworkScreenState();
}

class _BusinessNetworkScreenState extends State<BusinessNetworkScreen> {
  final _apiClient = sl<ApiClient>();
  final _contactService = sl<ContactService>();
  static const _connectionsLoadTimeout = Duration(seconds: 8);
  var _loading = true;
  var _searching = false;
  String? _error;
  String? _warning;
  String? _searchError;
  String _searchQuery = '';
  String? _loadedBusinessId;
  int _loadRequestId = 0;
  int _searchRequestId = 0;
  bool _requestSheetOpen = false;
  List<BusinessConnectionModel> _connections = const [];
  List<BusinessModel> _candidates = const [];
  final _connectionsCache = <String, List<BusinessConnectionModel>>{};
  final _businessCache = <String, BusinessModel>{};
  final _catalogCache = <String, List<ProductModel>>{};

  void _log(String message) {
    debugPrint('[BUSINESS_NETWORK] $message');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_reloadForActiveBusiness()),
    );
  }

  Future<void> _reloadForActiveBusiness() async {
    var activeBusiness = context.read<ActiveBusinessCubit>().state.activeBusiness;
    if (activeBusiness == null) {
      await context.read<ActiveBusinessCubit>().load();
      if (!mounted) return;
      activeBusiness = context.read<ActiveBusinessCubit>().state.activeBusiness;
    }
    _log(
      'reload:start activeBusiness=${activeBusiness?.id}',
    );
    if (activeBusiness == null) {
      await _load();
      return;
    }

    // Pintamos la ultima respuesta del negocio activo sin esperar la red.
    // La consulta fresca y los candidatos se recuperan en paralelo.
    final cached = _connectionsCache[activeBusiness.id];
    if (cached != null && mounted) {
      setState(() {
        _loadedBusinessId = activeBusiness!.id;
        _connections = cached;
        _loading = false;
        _error = null;
      });
      _log('reload:cache-hit business=${activeBusiness.id} connections=${cached.length}');
    }
    await Future.wait<void>([
      _load(expectedBusinessId: activeBusiness.id),
      _searchBusinesses(_searchQuery, business: activeBusiness),
    ]);
    _log(
      'reload:done loadedBusiness=$_loadedBusinessId connections=${_connections.length} candidates=${_candidates.length}',
    );
  }

  Future<void> _load({String? expectedBusinessId}) async {
    final requestId = ++_loadRequestId;
    final loadStopwatch = Stopwatch()..start();
    var activeBusinessState = context.read<ActiveBusinessCubit>().state;
    var businessId = expectedBusinessId ?? activeBusinessState.activeBusiness?.id;
    _log(
      'load[$requestId]:start business=$businessId status=${activeBusinessState.status.name}',
    );
    if (businessId == null &&
        activeBusinessState.status != ActiveBusinessStatus.loading) {
      await context.read<ActiveBusinessCubit>().load();
      if (!mounted || requestId != _loadRequestId) {
        _log(
          'load[$requestId]:discarded after active business load (mounted=$mounted latest=${_loadRequestId == requestId})',
        );
        return;
      }
      activeBusinessState = context.read<ActiveBusinessCubit>().state;
      businessId = activeBusinessState.activeBusiness?.id;
      _log('load[$requestId]:active business resolved=$businessId');
    }

    if (businessId == null) {
      if (!mounted || requestId != _loadRequestId) {
        _log(
          'load[$requestId]:discarded null business (mounted=$mounted latest=${_loadRequestId == requestId})',
        );
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Selecciona un negocio activo.';
        _warning = null;
      });
      _log('load[$requestId]:failed no active business');
      return;
    }

    final cached = _connectionsCache[businessId];
    setState(() {
      _loadedBusinessId = businessId;
      if (cached != null) _connections = cached;
      _loading = cached == null;
      _error = null;
      _warning = null;
    });

    // Reintenta hasta 2 veces en errores 5xx transitorios (ej. 503 OWNERSHIP_CHECK_UNAVAILABLE).
    ApiResult<List<BusinessConnectionModel>> result = const ApiResult.failure(
      ApiFailure(code: 'NOT_STARTED', message: ''),
    );
    const maxAttempts = 2;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        if (!mounted || requestId != _loadRequestId) return;
        _log(
          'load[$requestId]:retry attempt=$attempt after ${attempt}s delay '
          'code=${result.error?.code}',
        );
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      result = await _apiClient
          .get<List<BusinessConnectionModel>>(
            '/red-negocios',
            queryParameters: {
              'negocio_id': businessId,
              'limit': 30,
              'order': 'created_at.desc',
            },
            parser: (json) {
              final rows = _asList(json);
              return rows
                  .map((item) => BusinessConnectionModel.fromJson(item))
                  .toList();
            },
          )
          .timeout(
            _connectionsLoadTimeout,
            onTimeout: () => const ApiResult.failure(
              ApiFailure(
                code: 'red_timeout',
                message: 'La carga de conexiones tardo demasiado.',
              ),
            ),
          );
      // Reintenta solo en errores de servidor (5xx) y sin statusCode (timeout/red);
      // errores 4xx (auth, permiso) y éxito son definitivos.
      final errStatus = result.error?.statusCode;
      final isDefinitive = result.isSuccess ||
          (errStatus != null && errStatus >= 400 && errStatus < 500);
      if (isDefinitive) break;
    }
    final connections = _dedupeConnections(
      result.data ?? const <BusinessConnectionModel>[],
    );
    if (result.isSuccess && connections.isNotEmpty) {
      for (final connection in connections) {
        _cacheConnectionData(connection);
      }
    }

    if (!mounted || requestId != _loadRequestId) {
      _log(
        'load[$requestId]:discarded response business=$businessId (mounted=$mounted latest=${_loadRequestId == requestId})',
      );
      return;
    }
    setState(() {
      _loading = false;
      _loadedBusinessId = businessId;
      if (result.isSuccess) {
        _connections = connections;
        _connectionsCache[businessId!] = connections;
        _error = null;
        _warning = null;
      } else {
        final message =
            result.error?.message ??
            'No se pudieron cargar las conexiones. Intenta de nuevo.';
        final retained = _connectionsCache[businessId];
        if (retained != null) _connections = retained;
        _error = _connections.isEmpty ? message : null;
        _warning = _connections.isEmpty ? null : message;
      }
    });
    if (result.isSuccess) {
      _log(
        'load[$requestId]:success business=$businessId connections=${_connections.length} '
        'elapsedMs=${loadStopwatch.elapsedMilliseconds}',
      );
      unawaited(_hydrateConnectionsInBackground(businessId, connections));
    } else {
      _log(
        'load[$requestId]:failure business=$businessId code=${result.error?.code} '
        'message=${result.error?.message} kept=${_connections.isNotEmpty} '
        'elapsedMs=${loadStopwatch.elapsedMilliseconds} timeoutMs=${_connectionsLoadTimeout.inMilliseconds}',
      );
    }
  }

  void _cacheConnectionData(BusinessConnectionModel connection) {
    final business = connection.connectedBusiness;
    if (business != null && business.id.isNotEmpty) {
      _businessCache[business.id] = business;
    }
    if (connection.connectedBusinessId.isNotEmpty &&
        connection.products.isNotEmpty) {
      _catalogCache[connection.connectedBusinessId] = connection.products;
    }
  }

  List<BusinessConnectionModel> _dedupeConnections(
    List<BusinessConnectionModel> input,
  ) {
    int priority(BusinessConnectionModel connection) {
      final activeBonus = connection.isActive ? 100 : 0;
      final pendingIncomingBonus =
          connection.isPending && connection.isIncomingRequest ? 10 : 0;
      final outgoingBonus = connection.relationDirection == 'saliente' ? 1 : 0;
      return activeBonus + pendingIncomingBonus + outgoingBonus;
    }

    final byBusiness = <String, BusinessConnectionModel>{};
    for (final connection in input) {
      final key = connection.connectedBusinessId.isNotEmpty
          ? connection.connectedBusinessId
          : connection.id;
      final current = byBusiness[key];
      if (current == null || priority(connection) > priority(current)) {
        byBusiness[key] = connection;
      }
    }
    return byBusiness.values.toList();
  }

  BusinessConnectionModel? _relationForBusinessId(String businessId) {
    final matches = _connections
        .where((connection) => connection.connectedBusinessId == businessId)
        .toList();
    if (matches.isEmpty) return null;

    final active = matches.where((connection) => connection.isActive).firstOrNull;
    if (active != null) return active;

    final incoming = matches.where((connection) => connection.isIncomingRequest).firstOrNull;
    if (incoming != null) return incoming;

    return matches.first;
  }

  Future<void> _openBusinessAction(BusinessModel target) async {
    final relation = _relationForBusinessId(target.id);
    if (relation != null) {
      _showConnectionDetails(relation);
      return;
    }

    await _connectBusiness(target);
  }

  Future<void> _hydrateConnectionsInBackground(
    String businessId,
    List<BusinessConnectionModel> connections,
  ) async {
    if (connections.isEmpty ||
        !connections.any(
          (connection) =>
              connection.connectedBusiness == null &&
              connection.connectedBusinessId.isNotEmpty,
        )) {
      return;
    }

    final enriched = await _enrichConnections(
      connections,
    ).timeout(const Duration(seconds: 7), onTimeout: () => connections);
    if (!mounted || _loadedBusinessId != businessId) return;

    var changed = false;
    final byId = {for (final connection in enriched) connection.id: connection};
    final next = _connections.map((current) {
      final hydrated = byId[current.id];
      if (hydrated == null || hydrated.connectedBusiness == null) {
        return current;
      }
      if (current.connectedBusiness?.id == hydrated.connectedBusiness?.id) {
        return current;
      }
      changed = true;
      _cacheConnectionData(hydrated);
      return current.copyWith(connectedBusiness: hydrated.connectedBusiness);
    }).toList();

    if (changed) {
      setState(() {
        _connections = next;
        _connectionsCache[businessId] = next;
      });
    }
  }

  Future<void> _searchBusinesses(
    String query, {
    BusinessModel? business,
  }) async {
    final requestId = ++_searchRequestId;
    final activeBusiness = business ??
        context.read<ActiveBusinessCubit>().state.activeBusiness;
    if (activeBusiness == null) {
      _log('search[$requestId]:skipped no active business query="$query"');
      return;
    }

    _log(
      'search[$requestId]:start business=${activeBusiness.id} query="$query"',
    );

    setState(() {
      _searching = true;
      _searchQuery = query;
      _searchError = null;
    });

    final filters = <String, Object>{
      'limit': 12,
      'order': 'destacado.desc,created_at.desc',
    };
    if (query.trim().isNotEmpty) {
      filters['q'] = query.trim();
    }

    final result = await _apiClient
        .get<List<BusinessModel>>(
          '/negocios',
          queryParameters: filters,
          parser: (json) {
            final businesses = _asList(json)
                .map(BusinessModel.fromJson)
                .where((business) => business.id != activeBusiness.id);
            if (query.trim().isNotEmpty) {
              return businesses.toList();
            }
            final parentCategory = activeBusiness.businessParentCategory;
            final related = parentCategory?.isNotEmpty == true
                ? businesses
                      .where(
                        (business) =>
                            business.businessParentCategory == parentCategory,
                      )
                      .toList()
                : <BusinessModel>[];
            return related.isNotEmpty ? related : businesses.toList();
          },
        )
        .timeout(
          const Duration(seconds: 20),
          onTimeout: () => const ApiResult.failure(
            ApiFailure(
              code: 'business_search_timeout',
              message: 'La busqueda de negocios tardo demasiado.',
            ),
          ),
        );

    if (!mounted || requestId != _searchRequestId) {
      _log(
        'search[$requestId]:discarded response query="$query" (mounted=$mounted latest=${_searchRequestId == requestId})',
      );
      return;
    }
    setState(() {
      _searching = false;
      if (result.isSuccess) {
        _candidates = result.data ?? const [];
        for (final business in _candidates) {
          _businessCache[business.id] = business;
        }
      }
      _searchError = result.isSuccess ? null : result.error?.message;
    });
    if (result.isSuccess) {
      _log(
        'search[$requestId]:success query="$query" candidates=${_candidates.length}',
      );
    } else {
      _log(
        'search[$requestId]:failure query="$query" code=${result.error?.code} message=${result.error?.message}',
      );
    }
  }

  Future<List<BusinessConnectionModel>> _enrichConnections(
    List<BusinessConnectionModel> connections,
  ) async {
    final enriched = await Future.wait(
      connections.map(_enrichConnectionBusiness),
    );
    return enriched;
  }

  Future<BusinessConnectionModel> _enrichConnectionBusiness(
    BusinessConnectionModel connection,
  ) async {
    final connectedBusiness = connection.connectedBusiness;
    if (connectedBusiness != null && connectedBusiness.id.isNotEmpty) {
      _businessCache[connectedBusiness.id] = connectedBusiness;
      return connection;
    }

    final businessId = connection.connectedBusinessId;
    if (businessId.isEmpty) return connection;

    final cached = _businessCache[businessId];
    if (cached != null) {
      return connection.copyWith(connectedBusiness: cached);
    }

    final loaded = await _loadBusinessById(businessId);
    if (loaded == null) return connection;
    _businessCache[businessId] = loaded;
    return connection.copyWith(connectedBusiness: loaded);
  }

  Future<BusinessModel?> _loadBusinessById(String id) async {
    if (id.isEmpty) return null;
    final cached = _businessCache[id];
    if (cached != null) return cached;

    final result = await _apiClient
        .get<BusinessModel?>('/negocios/$id', parser: _businessFromJson)
        .timeout(
          const Duration(seconds: 6),
          onTimeout: () => const ApiResult.failure(
            ApiFailure(
              code: 'business_lookup_timeout',
              message: 'La carga del negocio conectado tardo demasiado.',
            ),
          ),
        );
    if (!result.isSuccess || result.data == null) return null;
    _businessCache[id] = result.data!;
    return result.data;
  }

  Future<BusinessConnectionModel> _ensureConnectionCatalog(
    BusinessConnectionModel connection,
  ) async {
    if (connection.products.isNotEmpty) return connection;

    final connectedBusinessId = connection.connectedBusinessId;
    if (connectedBusinessId.isEmpty) return connection;

    final cached = _catalogCache[connectedBusinessId];
    if (cached != null) {
      return connection.copyWith(products: cached);
    }

    final result = await _apiClient
        .get<List<ProductModel>>(
          '/productos',
          queryParameters: {
            'negocio_id': connectedBusinessId,
            'limit': 40,
            'order': 'destacado.desc,created_at.desc',
          },
          parser: (json) => _asList(json).map(ProductModel.fromJson).toList(),
        )
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => const ApiResult.failure(
            ApiFailure(
              code: 'catalog_timeout',
              message: 'La carga del catalogo tardo demasiado.',
            ),
          ),
        );

    if (!result.isSuccess) {
      if (!mounted) return connection;
      showSnackOrAuthDialog(
        context,
        result.error?.message ??
            'No se pudo cargar el catalogo del negocio conectado.',
      );
      return connection;
    }

    final products = result.data ?? const <ProductModel>[];
    _catalogCache[connectedBusinessId] = products;
    final enriched = connection.copyWith(products: products);
    if (mounted) {
      setState(() {
        _connections = _connections
            .map((item) => item.id == connection.id ? enriched : item)
            .toList();
        if (_loadedBusinessId != null) {
          _connectionsCache[_loadedBusinessId!] = _connections;
        }
      });
    }
    return enriched;
  }

  Future<void> _connectBusiness(BusinessModel target) async {
    final activeBusiness = context
        .read<ActiveBusinessCubit>()
        .state
        .activeBusiness;
    if (activeBusiness == null) {
      showSnackOrAuthDialog(context, 'Selecciona un negocio activo.');
      return;
    }

    final existingRelation = _relationForBusinessId(target.id);
    if (existingRelation != null) {
      _showConnectionDetails(existingRelation);
      return;
    }

    final payload = await showModalBottomSheet<_ConnectionPayload>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ConnectBusinessSheet(target: target),
    );
    if (payload == null || !mounted) return;

    final result = await _apiClient.post<BusinessConnectionModel?>(
      '/red-negocios/conectar/${target.id}',
      data: {
        'negocio_id': activeBusiness.id,
        'tipo_relacion': payload.relationType,
        'notificaciones': payload.notifications,
        'productos_interes': payload.productsOfInterest,
        if (payload.notes.isNotEmpty) 'notas': payload.notes,
      },
      parser: (json) => _firstConnectionFromJson(json),
    );

    if (!mounted) return;
    showSnackOrAuthDialog(
      context,
      result.isSuccess
          ? 'Conexion creada con ${target.name}.'
          : result.error?.message ?? 'No se pudo crear la conexion.',
    );
    if (result.isSuccess) {
      final remote = result.data;
      final created = remote == null
          ? BusinessConnectionModel(
              id: '${DateTime.now().microsecondsSinceEpoch}',
              businessId: activeBusiness.id,
              connectedBusinessId: target.id,
              notifications: payload.notifications,
              relationType: payload.relationType,
              status: 'solicitada',
              relationDirection: 'saliente',
              connectedBusiness: target,
              notes: payload.notes.isEmpty ? null : payload.notes,
              productsOfInterest: payload.productsOfInterest,
              products: const [],
            )
          : remote.copyWith(
              businessId: remote.businessId.isEmpty
                  ? activeBusiness.id
                  : remote.businessId,
              connectedBusinessId: remote.connectedBusinessId.isEmpty
                  ? target.id
                  : remote.connectedBusinessId,
              connectedBusiness: remote.connectedBusiness ?? target,
              relationType: remote.relationType.isEmpty
                  ? payload.relationType
                  : remote.relationType,
              relationDirection: remote.relationDirection.isEmpty
                  ? 'saliente'
                  : remote.relationDirection,
              notes: (remote.notes == null || remote.notes!.isEmpty)
                  ? (payload.notes.isEmpty ? null : payload.notes)
                  : remote.notes,
              productsOfInterest: remote.productsOfInterest.isEmpty
                  ? payload.productsOfInterest
                  : remote.productsOfInterest,
            );
      _cacheConnectionData(created);
      setState(() {
        _connections = _dedupeConnections([
          created,
          ..._connections.where(
            (item) => item.connectedBusinessId != created.connectedBusinessId,
          ),
        ]);
        _connectionsCache[activeBusiness.id] = _connections;
        _error = null;
        _warning = null;
      });
      unawaited(_reloadForActiveBusiness());
    }
  }

  Future<void> _editConnection(BusinessConnectionModel connection) async {
    final payload = await showModalBottomSheet<_ConnectionPayload>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditConnectionSheet(connection: connection),
    );
    if (payload == null || !mounted) return;

    final localUpdate = connection.copyWith(
      relationType: payload.relationType,
      notifications: payload.notifications,
      productsOfInterest: payload.productsOfInterest,
      notes: payload.notes,
    );
    setState(() {
      _connections = _connections
          .map((item) => item.id == connection.id ? localUpdate : item)
          .toList();
      if (_loadedBusinessId != null) {
        _connectionsCache[_loadedBusinessId!] = _connections;
      }
    });

    final result = await _apiClient.put<BusinessConnectionModel?>(
      '/red-negocios/${connection.id}',
      data: {
        'tipo_relacion': payload.relationType,
        'notificaciones': payload.notifications,
        'productos_interes': payload.productsOfInterest,
        'notas': payload.notes,
      },
      parser: (json) => _firstConnectionFromJson(json),
    );

    if (!mounted) return;
    if (result.isSuccess) {
      final remote = result.data;
      if (remote != null) {
        final enrichedRemote = remote.copyWith(
          connectedBusiness:
              remote.connectedBusiness ?? connection.connectedBusiness,
          products: remote.products.isEmpty
              ? connection.products
              : remote.products,
        );
        setState(() {
          _connections = _connections
              .map((item) => item.id == connection.id ? enrichedRemote : item)
              .toList();
          if (_loadedBusinessId != null) {
            _connectionsCache[_loadedBusinessId!] = _connections;
          }
        });
      }
      showSnackOrAuthDialog(context, 'Conexion actualizada.');
    } else {
      showSnackOrAuthDialog(
        context,
        result.error?.message ?? 'No se pudo actualizar la conexion.',
      );
      unawaited(_reloadForActiveBusiness());
    }
  }

  Future<void> _acceptConnection(BusinessConnectionModel connection) async {
    final result = await _apiClient.put<List<BusinessConnectionModel>>(
      '/red-negocios/${connection.id}',
      data: {'estado': 'activa'},
      parser: (json) {
        final rows = _asList(json);
        return rows.map(BusinessConnectionModel.fromJson).toList();
      },
    );
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() {
        _connections = _connections
            .map(
              (item) => item.id == connection.id
                  ? item.copyWith(status: 'activa')
                  : item,
            )
            .toList();
        if (_loadedBusinessId != null) {
          _connectionsCache[_loadedBusinessId!] = _connections;
        }
      });
      showSnackOrAuthDialog(context, 'Conexion aceptada.');
      unawaited(_reloadForActiveBusiness());
    } else {
      showSnackOrAuthDialog(
        context,
        result.error?.message ?? 'No se pudo aceptar la conexion.',
      );
    }
  }

  Future<void> _deleteConnection(BusinessConnectionModel connection) async {
    final businessName = _connectionBusinessName(
      connection,
      fallback: 'este negocio',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar conexion'),
        content: Text('Se eliminara la conexion con $businessName.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final previous = _connections;
    setState(() {
      _connections = _connections
          .where((item) => item.id != connection.id)
          .toList();
      if (_loadedBusinessId != null) {
        _connectionsCache[_loadedBusinessId!] = _connections;
      }
    });

    final result = await _apiClient.delete<void>(
      '/red-negocios/${connection.id}',
      parser: (_) {},
    );
    if (!mounted) return;
    if (result.isSuccess) {
      showSnackOrAuthDialog(context, 'Conexion eliminada.');
      unawaited(_searchBusinesses(_searchQuery));
    } else {
      setState(() {
        _connections = previous;
        if (_loadedBusinessId != null) {
          _connectionsCache[_loadedBusinessId!] = previous;
        }
      });
      showSnackOrAuthDialog(
        context,
        result.error?.message ?? 'No se pudo eliminar la conexion.',
      );
    }
  }

  Future<void> _toggleNotifications(
    BusinessConnectionModel connection,
    bool value,
  ) async {
    setState(() {
      _connections = _connections
          .map(
            (item) => item.id == connection.id
                ? item.copyWith(notifications: value)
                : item,
            )
            .toList();
      if (_loadedBusinessId != null) {
        _connectionsCache[_loadedBusinessId!] = _connections;
      }
    });
    final result = await _apiClient.put<void>(
      '/red-negocios/${connection.id}',
      data: {'notificaciones': value},
      parser: (_) {},
    );
    if (!result.isSuccess && mounted) {
      showSnackOrAuthDialog(
        context,
        result.error?.message ?? 'No se pudo actualizar la conexion.',
      );
      unawaited(_reloadForActiveBusiness());
    }
  }

  Future<void> _requestProduct(BusinessConnectionModel connection) async {
    if (_requestSheetOpen) {
      _log('request_product:ignored duplicate open for connection=${connection.id}');
      return;
    }

    final current = _connections
        .where((item) => item.id == connection.id)
        .firstOrNull;
    final sourceConnection = current ?? connection;
    final enrichedConnection = await _ensureConnectionCatalog(sourceConnection);
    if (!mounted) return;

    _requestSheetOpen = true;
    final product = await showModalBottomSheet<_SupplyRequestPayload>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SupplyRequestSheet(connection: enrichedConnection),
    ).whenComplete(() {
      _requestSheetOpen = false;
    });
    if (product == null || !mounted) return;

    final result = await _apiClient.post<void>(
      '/solicitudes-red',
      data: {
        'conexion_id': enrichedConnection.id,
        'negocio_solicitante_id': enrichedConnection.businessId,
        'negocio_destino_id': enrichedConnection.connectedBusinessId,
        if (product.productId != null) 'producto_id': product.productId,
        'nombre_producto': product.productName,
        'cantidad': product.quantity,
        'unidad': product.unit,
        'mensaje': product.message,
        if (product.price != null) 'precio_referencia': product.price,
        'moneda': product.currency,
      },
      parser: (_) {},
    );

    if (!mounted) return;
    showSnackOrAuthDialog(
      context,
      result.isSuccess
          ? 'Solicitud enviada a la red.'
          : result.error?.message ?? 'No se pudo enviar la solicitud.',
    );
  }

  Future<void> _showSubscribersSheet() async {
    final activeBusiness = context
        .read<ActiveBusinessCubit>()
        .state
        .activeBusiness;
    if (activeBusiness == null) {
      showSnackOrAuthDialog(context, 'Selecciona un negocio activo.');
      return;
    }

    final result = await _apiClient.get<List<_BusinessSubscriber>>(
      '/suscripciones',
      queryParameters: {
        'negocio_id': activeBusiness.id,
        'limit': 30,
      },
      parser: (json) =>
          _asList(json).map(_BusinessSubscriber.fromJson).toList(),
    );

    if (!mounted) return;
    if (!result.isSuccess) {
      showSnackOrAuthDialog(
        context,
        result.error?.message ?? 'No se pudieron cargar los clientes suscritos.',
      );
      return;
    }

    final subscribers = result.data ?? const <_BusinessSubscriber>[];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SubscribersSheet(
        businessName: activeBusiness.name,
        subscribers: subscribers,
        onWhatsApp: (subscriber) async {
          final message = await _contactService.openWhatsApp(
            subscriber.whatsapp ?? subscriber.phone,
            message:
                'Hola ${subscriber.displayName}, tenemos una promocion para ti en ${activeBusiness.name}.',
          );
          if (mounted && message != null) {
            showSnackOrAuthDialog(context, message);
          }
        },
        onPhone: (subscriber) async {
          final message = await _contactService.openPhone(subscriber.phone);
          if (mounted && message != null) {
            showSnackOrAuthDialog(context, message);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeBusiness = context
        .watch<ActiveBusinessCubit>()
        .state
        .activeBusiness;
    return DefaultTabController(
      length: 2,
      child: BlocListener<ActiveBusinessCubit, ActiveBusinessState>(
        listenWhen: (previous, current) =>
            previous.activeBusiness?.id != current.activeBusiness?.id,
        listener: (context, state) {
          final businessId = state.activeBusiness?.id;
          if (businessId == null || businessId == _loadedBusinessId) return;
          unawaited(_reloadForActiveBusiness());
        },
        child: Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _reloadForActiveBusiness,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Conexiones',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: _reloadForActiveBusiness,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: _showSubscribersSheet,
                        icon: const Icon(Icons.groups_rounded),
                        tooltip: 'Clientes suscritos',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  BusinessSwitcher(onChanged: _reloadForActiveBusiness),
                  const SizedBox(height: 16),
                  Text(
                    'Conecta proveedores, clientes mayoristas, aliados y deliverys. Recibe avisos cuando actualicen productos o solicita abastecimiento con antelacion.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  _BusinessSearchPanel(
                    candidates: _candidates,
                    searching: _searching,
                    error: _searchError,
                    onChanged: (query) => _searchBusinesses(query),
                    onConnect: _openBusinessAction,
                    relationForBusinessId: _relationForBusinessId,
                  ),
                  const SizedBox(height: 16),
                  const TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.list_alt_rounded), text: 'Lista'),
                      Tab(icon: Icon(Icons.hub_outlined), text: 'Modo Red'),
                    ],
                  ),
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.64,
                    child: TabBarView(
                      children: [
                        _NetworkList(
                          loading: _loading,
                          error: _error,
                          warning: _warning,
                          connections: _connections,
                          onToggleNotifications: _toggleNotifications,
                          onRequestProduct: _requestProduct,
                          onEdit: _editConnection,
                          onDelete: _deleteConnection,
                          onRefresh: _reloadForActiveBusiness,
                        ),
                        _NetworkDiagram(
                          centerName: activeBusiness?.name ?? 'Mi negocio',
                          centerLogo: activeBusiness?.logoUrl,
                          connections: _connections,
                          onTap: (connection) =>
                              _showConnectionDetails(connection),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showConnectionDetails(BusinessConnectionModel connection) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ConnectionDetailsSheet(
        connection: connection,
        onToggleNotifications: (value) =>
            _toggleNotifications(connection, value),
        onRequestProduct: () => _requestProduct(connection),
        onEdit: () => _editConnection(connection),
        onDelete: () => _deleteConnection(connection),
        onAccept: connection.isPending && connection.isIncomingRequest
            ? () => _acceptConnection(connection)
            : null,
      ),
    );
  }
}

List<Map<String, dynamic>> _asList(dynamic json) {
  if (json is List) {
    return json
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
  if (json is Map) {
    final values = json['items'] ?? json['datos'] ?? json['negocios'];
    if (values is List) {
      return values
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
  }
  return const [];
}

String _connectionBusinessName(
  BusinessConnectionModel connection, {
  String fallback = 'Cargando negocio...',
}) {
  final name = connection.connectedBusiness?.name.trim();
  if (name != null && name.isNotEmpty) return name;
  if (connection.connectedBusinessId.isNotEmpty) return fallback;
  return 'Conexion sin negocio';
}

String _connectionBusinessLocation(BusinessConnectionModel connection) {
  final business = connection.connectedBusiness;
  if (business == null) return 'Datos del negocio cargando...';
  final parts = [business.municipality, business.province]
      .where((item) => item?.trim().isNotEmpty == true)
      .map((item) => item!.trim());
  final text = parts.join(' - ');
  return text.isEmpty ? 'Sin ubicacion definida' : text;
}

BusinessModel? _businessFromJson(dynamic json) {
  final rows = _asList(json);
  if (rows.isNotEmpty) return BusinessModel.fromJson(rows.first);
  if (json is Map) {
    final data = json['datos'];
    if (data is Map) {
      return BusinessModel.fromJson(Map<String, dynamic>.from(data));
    }
    if (json['id'] != null) {
      return BusinessModel.fromJson(Map<String, dynamic>.from(json));
    }
  }
  return null;
}

BusinessConnectionModel? _firstConnectionFromJson(dynamic json) {
  final rows = _asList(json);
  if (rows.isEmpty) {
    if (json is Map) {
      return BusinessConnectionModel.fromJson(Map<String, dynamic>.from(json));
    }
    return null;
  }
  return BusinessConnectionModel.fromJson(rows.first);
}

class _NetworkList extends StatelessWidget {
  const _NetworkList({
    required this.loading,
    required this.connections,
    required this.onToggleNotifications,
    required this.onRequestProduct,
    required this.onEdit,
    required this.onDelete,
    required this.onRefresh,
    this.error,
    this.warning,
  });

  final bool loading;
  final String? error;
  final String? warning;
  final List<BusinessConnectionModel> connections;
  final Future<void> Function() onRefresh;
  final void Function(BusinessConnectionModel connection, bool value)
  onToggleNotifications;
  final void Function(BusinessConnectionModel connection) onRequestProduct;
  final void Function(BusinessConnectionModel connection) onEdit;
  final void Function(BusinessConnectionModel connection) onDelete;

  @override
  Widget build(BuildContext context) {
    if (connections.isNotEmpty) {
      return Column(
        children: [
          if (loading) const LinearProgressIndicator(minHeight: 2),
          if (warning != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warning!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.separated(
              primary: false,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 14),
              itemCount: connections.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final connection = connections[index];
                return _ConnectionCard(
                  connection: connection,
                  onToggleNotifications: (value) =>
                      onToggleNotifications(connection, value),
                  onRequestProduct: () => onRequestProduct(connection),
                  onOpenBusiness: () => context.push(
                    AppRoutes.store(
                      connection.connectedBusiness?.id.isNotEmpty == true
                          ? connection.connectedBusiness!.id
                          : connection.connectedBusinessId,
                    ),
                  ),
                  onEdit: () => onEdit(connection),
                  onDelete: () => onDelete(connection),
                );
              },
            ),
          ),
        ],
      );
    }

    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (connections.isEmpty) {
      return const Center(
        child: Text(
          'Aun no tienes conexiones. Entra a un negocio desde el buscador y toca Conectar.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.connection,
    required this.onToggleNotifications,
    required this.onRequestProduct,
    required this.onOpenBusiness,
    required this.onEdit,
    required this.onDelete,
  });

  final BusinessConnectionModel connection;
  final ValueChanged<bool> onToggleNotifications;
  final VoidCallback onRequestProduct;
  final VoidCallback onOpenBusiness;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final business = connection.connectedBusiness;
    final businessName = _connectionBusinessName(connection);
    final targetBusinessId =
        business?.id.isNotEmpty == true ? business!.id : connection.connectedBusinessId;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: targetBusinessId.isEmpty ? null : onOpenBusiness,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundImage: business?.logoUrl?.isNotEmpty == true
                        ? NetworkImage(business!.logoUrl!)
                        : null,
                    child: business?.logoUrl?.isNotEmpty == true
                        ? null
                        : const Icon(Icons.storefront_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          businessName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          connection.relationLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(connection.statusLabel),
                          ),
                        ),
                        Text(
                          _connectionBusinessLocation(connection),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: connection.notifications,
                    onChanged: onToggleNotifications,
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Editar conexion'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Eliminar conexion'),
                      ),
                    ],
                  ),
                ],
              ),
              if (connection.products.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Productos actuales',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                ...connection.products
                    .take(4)
                    .map(
                      (product) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${(product.currentPrice ?? 0).toStringAsFixed(0)} ${product.currency ?? 'CUP'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppColors.greenLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: onRequestProduct,
                icon: const Icon(Icons.playlist_add_check_circle_outlined),
                label: const Text('Solicitar producto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetworkDiagram extends StatefulWidget {
  const _NetworkDiagram({
    required this.centerName,
    required this.connections,
    required this.onTap,
    this.centerLogo,
  });

  final String centerName;
  final String? centerLogo;
  final List<BusinessConnectionModel> connections;
  final ValueChanged<BusinessConnectionModel> onTap;

  @override
  State<_NetworkDiagram> createState() => _NetworkDiagramState();
}

class _NetworkDiagramState extends State<_NetworkDiagram>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.connections.isEmpty) {
      return const Center(
        child: Text('El modo red aparecera cuando conectes negocios.'),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final center = Offset(size.width / 2, size.height / 2);
            final radius = math.min(size.width, size.height) * 0.34;
            return Stack(
              children: [
                CustomPaint(
                  size: size,
                  painter: _NetworkPainter(
                    connections: widget.connections,
                    progress: _controller.value,
                    radius: radius,
                    center: center,
                  ),
                ),
                Positioned(
                  left: center.dx - 42,
                  top: center.dy - 42,
                  child: _NetworkAvatar(
                    label: widget.centerName,
                    imageUrl: widget.centerLogo,
                    highlighted: true,
                  ),
                ),
                ...List.generate(widget.connections.length, (index) {
                  final angle =
                      (math.pi * 2 / widget.connections.length) * index -
                      math.pi / 2;
                  final x = center.dx + math.cos(angle) * radius - 34;
                  final y = center.dy + math.sin(angle) * radius - 34;
                  final connection = widget.connections[index];
                  return Positioned(
                    left: x,
                    top: y,
                    child: GestureDetector(
                      onTap: () => widget.onTap(connection),
                      child: _NetworkAvatar(
                        label: _connectionBusinessName(connection),
                        imageUrl: connection.connectedBusiness?.logoUrl,
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }
}

class _NetworkPainter extends CustomPainter {
  const _NetworkPainter({
    required this.connections,
    required this.progress,
    required this.radius,
    required this.center,
  });

  final List<BusinessConnectionModel> connections;
  final double progress;
  final double radius;
  final Offset center;

  @override
  void paint(Canvas canvas, Size size) {
    final count = connections.length;
    if (count == 0) return;

    final baseGlowPaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.14)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final baseLinePaint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final baseAccentPaint = Paint()
      ..color = AppColors.greenLight.withValues(alpha: 0.32)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final pulsePaint = Paint()
      ..color = AppColors.greenLight.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    final pulseRingPaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.38)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < count; i++) {
      final connection = connections[i];
      if (!connection.isActive) {
        continue;
      }
      final angle = (math.pi * 2 / count) * i - math.pi / 2;
      final target = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      final direction = target - center;
      final distance = direction.distance;
      final normal = distance == 0
          ? Offset.zero
          : Offset(-direction.dy / distance, direction.dx / distance);
      final curveMagnitude = count == 1 ? 34.0 : (i.isEven ? 26.0 : -26.0);
      final curveOffset = normal * curveMagnitude;
      final control = Offset.lerp(center, target, 0.5)! + curveOffset;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..quadraticBezierTo(control.dx, control.dy, target.dx, target.dy);

      final isAlly = connection.relationType == 'aliado';
      final strokeWidth = isAlly ? 3.4 : 2.0;
      final glowPaint = Paint()
        ..color = baseGlowPaint.color
        ..strokeCap = baseGlowPaint.strokeCap
        ..style = baseGlowPaint.style
        ..strokeWidth = isAlly ? 10 : 8;
      final linePaint = Paint()
        ..shader = LinearGradient(
          colors: isAlly
              ? [
                  AppColors.gold.withValues(alpha: 0.95),
                  AppColors.greenLight.withValues(alpha: 0.9),
                ]
              : [
                  AppColors.gold.withValues(alpha: 0.75),
                  AppColors.greenLight.withValues(alpha: 0.7),
                ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..strokeCap = baseLinePaint.strokeCap
        ..style = baseLinePaint.style
        ..strokeWidth = strokeWidth;
      final accentPaint = Paint()
        ..color = baseAccentPaint.color
        ..strokeCap = baseAccentPaint.strokeCap
        ..style = baseAccentPaint.style
        ..strokeWidth = isAlly ? 1.2 : 0.9;

      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, linePaint);
      if (i.isOdd) {
        canvas.drawPath(path.shift(normal * 3), accentPaint);
      }

      final relationType = connection.relationType;
      final isBidirectional = relationType == 'aliado';
      final isIncomingOnly =
          !isBidirectional && connection.relationDirection == 'entrante';
      final pulseCount = math.max(1, math.min(10, connection.products.length));
      for (var pulseIndex = 0; pulseIndex < pulseCount; pulseIndex++) {
        final phase = (progress + i / count + pulseIndex / pulseCount) % 1;
        final outgoingT = phase;
        final incomingT = 1 - phase;

        final t = isIncomingOnly ? incomingT : outgoingT;
        final pulse = _quadraticPoint(center, control, target, t);
        canvas.drawCircle(pulse, 5.5, pulseRingPaint);
        canvas.drawCircle(pulse, 3.4, pulsePaint);

        if (isBidirectional) {
          final reversePulse = _quadraticPoint(
            center,
            control,
            target,
            incomingT,
          );
          canvas.drawCircle(reversePulse, 5.5, pulseRingPaint);
          canvas.drawCircle(reversePulse, 3.4, pulsePaint);
        }
      }
    }
  }

  Offset _quadraticPoint(Offset start, Offset control, Offset end, double t) {
    final oneMinusT = 1 - t;
    return Offset(
      oneMinusT * oneMinusT * start.dx +
          2 * oneMinusT * t * control.dx +
          t * t * end.dx,
      oneMinusT * oneMinusT * start.dy +
          2 * oneMinusT * t * control.dy +
          t * t * end.dy,
    );
  }

  @override
  bool shouldRepaint(covariant _NetworkPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.connections.length != connections.length ||
        oldDelegate.connections != connections;
  }
}

class _NetworkAvatar extends StatelessWidget {
  const _NetworkAvatar({
    required this.label,
    this.imageUrl,
    this.highlighted = false,
  });

  final String label;
  final String? imageUrl;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(highlighted ? 4 : 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: highlighted ? AppColors.gold : AppColors.greenLight,
              width: highlighted ? 3 : 2,
            ),
          ),
          child: CircleAvatar(
            radius: highlighted ? 38 : 30,
            backgroundImage: imageUrl?.isNotEmpty == true
                ? NetworkImage(imageUrl!)
                : null,
            child: imageUrl?.isNotEmpty == true
                ? null
                : const Icon(Icons.storefront_rounded),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: highlighted ? 110 : 84,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}

class _BusinessSubscriber {
  const _BusinessSubscriber({
    required this.id,
    required this.clientId,
    required this.displayName,
    required this.phone,
    required this.whatsapp,
    required this.status,
  });

  final String id;
  final String clientId;
  final String displayName;
  final String? phone;
  final String? whatsapp;
  final String status;

  factory _BusinessSubscriber.fromJson(Map<String, dynamic> json) {
    final rawProfile = json['perfiles'] ?? json['cliente'] ?? json['perfil'];
    final profile = rawProfile is List
        ? rawProfile.isNotEmpty && rawProfile.first is Map
            ? Map<String, dynamic>.from(rawProfile.first as Map)
            : <String, dynamic>{}
        : rawProfile is Map
            ? Map<String, dynamic>.from(rawProfile)
            : <String, dynamic>{};
    final name = '${profile['nombre_completo'] ?? profile['nombre'] ?? 'Cliente'}'.trim();
    return _BusinessSubscriber(
      id: '${json['id'] ?? ''}',
      clientId: '${json['cliente_id'] ?? ''}',
      displayName: name.isEmpty ? 'Cliente' : name,
      phone: profile['telefono']?.toString(),
      whatsapp: profile['whatsapp']?.toString(),
      status: '${json['estado'] ?? 'activo'}',
    );
  }
}

class _SubscribersSheet extends StatelessWidget {
  const _SubscribersSheet({
    required this.businessName,
    required this.subscribers,
    required this.onWhatsApp,
    required this.onPhone,
  });

  final String businessName;
  final List<_BusinessSubscriber> subscribers;
  final Future<void> Function(_BusinessSubscriber subscriber) onWhatsApp;
  final Future<void> Function(_BusinessSubscriber subscriber) onPhone;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Clientes suscritos de $businessName',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Aqui puedes contactar clientes habituales y enviarles promociones por WhatsApp.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            if (subscribers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('Todavia no hay clientes suscritos registrados.'),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.65,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: subscribers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final subscriber = subscribers[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  child: Text(
                                    subscriber.displayName.isNotEmpty
                                        ? subscriber.displayName.substring(0, 1).toUpperCase()
                                        : 'C',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        subscriber.displayName,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      Text(
                                        subscriber.status == 'activo' || subscriber.status == 'activa'
                                            ? 'Cliente frecuente'
                                            : subscriber.status,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: () => onWhatsApp(subscriber),
                                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                                  label: const Text('WhatsApp'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: subscriber.phone?.isNotEmpty == true
                                      ? () => onPhone(subscriber)
                                      : null,
                                  icon: const Icon(Icons.call_outlined),
                                  label: const Text('Llamar'),
                                ),
                                FilledButton.icon(
                                  onPressed: () => onWhatsApp(subscriber),
                                  icon: const Icon(Icons.campaign_outlined),
                                  label: const Text('Promocion'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionDetailsSheet extends StatelessWidget {
  const _ConnectionDetailsSheet({
    required this.connection,
    required this.onToggleNotifications,
    required this.onRequestProduct,
    required this.onEdit,
    required this.onDelete,
    this.onAccept,
  });

  final BusinessConnectionModel connection;
  final ValueChanged<bool> onToggleNotifications;
  final VoidCallback onRequestProduct;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final businessName = _connectionBusinessName(connection);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    businessName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onEdit();
                  },
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onDelete();
                  },
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
            Text(connection.relationLabel),
            const SizedBox(height: 4),
            Text(
              connection.statusLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: connection.isActive
                    ? AppColors.greenLight
                    : Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: connection.notifications,
              onChanged: onToggleNotifications,
              contentPadding: EdgeInsets.zero,
              title: const Text('Recibir alertas de mercado'),
              subtitle: const Text(
                'Avisos por nuevos productos, stock y cambios de precio.',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onRequestProduct();
              },
              icon: const Icon(Icons.playlist_add_rounded),
              label: const Text('Solicitar abastecimiento'),
            ),
            if (onAccept != null) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onAccept?.call();
                },
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Aceptar conexion'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onDelete();
                },
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Rechazar conexion'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SupplyRequestPayload {
  const _SupplyRequestPayload({
    required this.productName,
    required this.quantity,
    required this.currency,
    this.productId,
    this.unit,
    this.price,
    this.message,
  });

  final String productName;
  final double quantity;
  final String currency;
  final String? productId;
  final String? unit;
  final double? price;
  final String? message;
}

class _SupplyRequestSheet extends StatefulWidget {
  const _SupplyRequestSheet({required this.connection});

  final BusinessConnectionModel connection;

  @override
  State<_SupplyRequestSheet> createState() => _SupplyRequestSheetState();
}

class _SupplyRequestSheetState extends State<_SupplyRequestSheet> {
  final _nameController = TextEditingController();
  final _productSearchController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _unitController = TextEditingController();
  final _messageController = TextEditingController();
  String? _productId;
  double? _price;
  var _currency = 'CUP';
  String _productQuery = '';

  @override
  void dispose() {
    _nameController.dispose();
    _productSearchController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _selectProduct(String productId) {
    final product = widget.connection.products.firstWhere(
      (item) => item.id == productId,
    );
    setState(() {
      _productId = product.id;
      _nameController.text = product.name;
      _price = product.currentPrice;
      _currency = product.currency ?? 'CUP';
    });
  }

  List<ProductModel> get _filteredProducts {
    final query = _productQuery.trim().toLowerCase();
    final products = widget.connection.products;
    if (query.isEmpty) return products.take(12).toList();
    return products
        .where((product) {
          final text = [
            product.name,
            product.brand,
            product.description,
            product.currency,
            product.businessName,
          ].whereType<String>().join(' ').toLowerCase();
          return text.contains(query);
        })
        .take(12)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final products = _filteredProducts;
    final businessName = _connectionBusinessName(widget.connection);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Solicitar producto a $businessName',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            if (widget.connection.products.isNotEmpty) ...[
              TextField(
                controller: _productSearchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  labelText: 'Buscar producto o servicio publicado',
                  hintText: 'Arroz, cerveza, delivery, carne...',
                ),
                onChanged: (value) {
                  setState(() => _productQuery = value);
                },
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: products.isEmpty
                    ? const _EmptyCatalogHint()
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: products.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          final selected = product.id == _productId;
                          return _CatalogProductTile(
                            product: product,
                            selected: selected,
                            onTap: () => _selectProduct(product.id),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.6),
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Este negocio aun no tiene productos publicados cargados. Puedes escribir la solicitud manualmente.',
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Producto o servicio requerido',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cantidad'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _unitController,
                    decoration: const InputDecoration(labelText: 'Unidad'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Mensaje',
                hintText: 'Ej: necesito 5 sacos para el viernes.',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                final name = _nameController.text.trim();
                final quantity =
                    double.tryParse(
                      _quantityController.text.trim().replaceAll(',', '.'),
                    ) ??
                    0;
                if (name.isEmpty || quantity <= 0) {
                  showSnackOrAuthDialog(
                    context,
                    'Completa producto y cantidad.',
                  );
                  return;
                }
                Navigator.of(context).pop(
                  _SupplyRequestPayload(
                    productId: _productId,
                    productName: name,
                    quantity: quantity,
                    unit: _unitController.text.trim().isEmpty
                        ? null
                        : _unitController.text.trim(),
                    price: _price,
                    currency: _currency,
                    message: _messageController.text.trim().isEmpty
                        ? null
                        : _messageController.text.trim(),
                  ),
                );
              },
              icon: const Icon(Icons.send_outlined),
              label: const Text('Enviar solicitud'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCatalogHint extends StatelessWidget {
  const _EmptyCatalogHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'No hay coincidencias en el catalogo. Puedes escribir el producto manualmente debajo.',
      ),
    );
  }
}

class _CatalogProductTile extends StatelessWidget {
  const _CatalogProductTile({
    required this.product,
    required this.selected,
    required this.onTap,
  });

  final ProductModel product;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final price = product.currentPrice;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.18)
              : Theme.of(context).colorScheme.surface.withValues(alpha: 0.55),
          border: Border.all(
            color: selected
                ? AppColors.gold
                : Theme.of(context).dividerColor.withValues(alpha: 0.65),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: product.imageUrl?.isNotEmpty == true
                  ? Image.network(
                      product.imageUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _CatalogProductIcon(),
                    )
                  : const _CatalogProductIcon(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      product.brand,
                      price == null
                          ? null
                          : '${price.toStringAsFixed(0)} ${product.currency ?? 'CUP'}',
                      product.stock == null ? null : 'Stock ${product.stock}',
                    ].whereType<String>().join(' - '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.add_circle_outline_rounded,
              color: selected ? AppColors.gold : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogProductIcon extends StatelessWidget {
  const _CatalogProductIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      color: AppColors.greenLight.withValues(alpha: 0.16),
      child: const Icon(Icons.inventory_2_outlined),
    );
  }
}

class _BusinessSearchPanel extends StatefulWidget {
  const _BusinessSearchPanel({
    required this.candidates,
    required this.searching,
    required this.onChanged,
    required this.onConnect,
    required this.relationForBusinessId,
    this.error,
  });

  final List<BusinessModel> candidates;
  final bool searching;
  final String? error;
  final ValueChanged<String> onChanged;
  final ValueChanged<BusinessModel> onConnect;
  final BusinessConnectionModel? Function(String businessId)
      relationForBusinessId;

  @override
  State<_BusinessSearchPanel> createState() => _BusinessSearchPanelState();
}

class _BusinessSearchPanelState extends State<_BusinessSearchPanel> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      widget.onChanged(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Encontrar negocios para conectar',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: widget.onChanged,
              decoration: InputDecoration(
                hintText: 'Buscar proveedor, mayorista, delivery...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: widget.searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            if (widget.error != null) ...[
              Text(
                widget.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
            ],
            if (widget.candidates.isEmpty)
              Text(
                widget.searching
                    ? 'Buscando...'
                    : 'Te mostraremos sugerencias por tipo de negocio o por busqueda.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              SizedBox(
                height: 188,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.candidates.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final business = widget.candidates[index];
                    final relation = widget.relationForBusinessId(business.id);
                    final label = relation == null
                        ? 'Conectar'
                        : relation.isActive
                        ? 'Ver conexion'
                        : relation.isIncomingRequest
                        ? 'Revisar solicitud'
                        : 'Solicitud enviada';
                    final icon = relation == null
                        ? Icons.hub_outlined
                        : relation.isActive
                        ? Icons.visibility_outlined
                        : relation.isIncomingRequest
                        ? Icons.mark_email_unread_outlined
                        : Icons.schedule_outlined;
                    return SizedBox(
                      width: 220,
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => widget.onConnect(business),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundImage:
                                          business.logoUrl?.isNotEmpty == true
                                          ? NetworkImage(business.logoUrl!)
                                          : null,
                                      child:
                                          business.logoUrl?.isNotEmpty == true
                                          ? null
                                          : const Icon(
                                              Icons.storefront_rounded,
                                            ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        business.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  business.businessTypeName ??
                                      business.province ??
                                      'Negocio',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (business.province?.isNotEmpty == true &&
                                    business.businessTypeName?.isNotEmpty ==
                                        true) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    business.province!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  height: 42,
                                  child: FilledButton.tonalIcon(
                                    onPressed: () => widget.onConnect(business),
                                    icon: Icon(icon, size: 18),
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(label),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionPayload {
  const _ConnectionPayload({
    required this.relationType,
    required this.notifications,
    required this.productsOfInterest,
    required this.notes,
  });

  final String relationType;
  final bool notifications;
  final List<String> productsOfInterest;
  final String notes;
}

class _ConnectBusinessSheet extends StatefulWidget {
  const _ConnectBusinessSheet({required this.target});

  final BusinessModel target;

  @override
  State<_ConnectBusinessSheet> createState() => _ConnectBusinessSheetState();
}

class _ConnectBusinessSheetState extends State<_ConnectBusinessSheet> {
  final _productsController = TextEditingController();
  final _notesController = TextEditingController();
  var _relationType = 'proveedor';
  var _notifications = true;

  @override
  void dispose() {
    _productsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conectar con ${widget.target.name}',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _relationType,
              decoration: const InputDecoration(labelText: 'Tipo de conexion'),
              items: const [
                DropdownMenuItem(
                  value: 'proveedor',
                  child: Text('Este negocio me provee'),
                ),
                DropdownMenuItem(
                  value: 'cliente_mayorista',
                  child: Text('Yo le suministro'),
                ),
                DropdownMenuItem(
                  value: 'aliado',
                  child: Text('Aliado comercial'),
                ),
                DropdownMenuItem(
                  value: 'delivery',
                  child: Text('Delivery asociado'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _relationType = value ?? 'proveedor'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _productsController,
              decoration: const InputDecoration(
                labelText: 'Productos o servicios de interes',
                hintText: 'arroz, cerveza, delivery, pan...',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notas o condiciones',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _notifications,
              onChanged: (value) => setState(() => _notifications = value),
              title: const Text('Recibir notificaciones'),
              subtitle: const Text(
                'Cambios de precio, stock, publicaciones y solicitudes.',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                final interests = _productsController.text
                    .split(',')
                    .map((item) => item.trim())
                    .where((item) => item.isNotEmpty)
                    .toList();
                Navigator.of(context).pop(
                  _ConnectionPayload(
                    relationType: _relationType,
                    notifications: _notifications,
                    productsOfInterest: interests,
                    notes: _notesController.text.trim(),
                  ),
                );
              },
              icon: const Icon(Icons.hub_outlined),
              label: const Text('Crear conexion'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditConnectionSheet extends StatefulWidget {
  const _EditConnectionSheet({required this.connection});

  final BusinessConnectionModel connection;

  @override
  State<_EditConnectionSheet> createState() => _EditConnectionSheetState();
}

class _EditConnectionSheetState extends State<_EditConnectionSheet> {
  late final TextEditingController _productsController;
  late final TextEditingController _notesController;
  late String _relationType;
  late bool _notifications;

  @override
  void initState() {
    super.initState();
    _relationType = widget.connection.relationType.isEmpty
        ? 'proveedor'
        : widget.connection.relationType;
    _notifications = widget.connection.notifications;
    _productsController = TextEditingController(
      text: widget.connection.productsOfInterest.join(', '),
    );
    _notesController = TextEditingController(text: widget.connection.notes);
  }

  @override
  void dispose() {
    _productsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Editar conexion',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(widget.connection.connectedBusiness?.name ?? 'Negocio'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _relationType,
              decoration: const InputDecoration(labelText: 'Tipo de conexion'),
              items: const [
                DropdownMenuItem(
                  value: 'proveedor',
                  child: Text('Este negocio me provee'),
                ),
                DropdownMenuItem(
                  value: 'cliente_mayorista',
                  child: Text('Yo le suministro'),
                ),
                DropdownMenuItem(
                  value: 'aliado',
                  child: Text('Aliado comercial'),
                ),
                DropdownMenuItem(
                  value: 'delivery',
                  child: Text('Delivery asociado'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _relationType = value ?? 'proveedor'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _productsController,
              decoration: const InputDecoration(
                labelText: 'Productos o servicios de interes',
                hintText: 'arroz, cerveza, delivery, pan...',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notas o condiciones',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _notifications,
              onChanged: (value) => setState(() => _notifications = value),
              title: const Text('Recibir notificaciones'),
              subtitle: const Text(
                'Cambios de precio, stock, publicaciones y solicitudes.',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                final interests = _productsController.text
                    .split(',')
                    .map((item) => item.trim())
                    .where((item) => item.isNotEmpty)
                    .toList();
                Navigator.of(context).pop(
                  _ConnectionPayload(
                    relationType: _relationType,
                    notifications: _notifications,
                    productsOfInterest: interests,
                    notes: _notesController.text.trim(),
                  ),
                );
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}
