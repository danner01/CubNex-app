import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../../common/blocs/active_business/active_business_cubit.dart';
import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';

enum _Periodo { hoy, ayer, semana, mes }

double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

String _money(dynamic v) {
  final d = _n(v);
  return d == d.roundToDouble() ? d.toInt().toString() : d.toStringAsFixed(2);
}

/// IPV (inventario, precio, venta) y cierre del negocio para el
/// propietario, economico o sub-economico (permiso `ver_reportes`).
class BusinessIpvScreen extends StatefulWidget {
  const BusinessIpvScreen({super.key});

  @override
  State<BusinessIpvScreen> createState() => _BusinessIpvScreenState();
}

class _BusinessIpvScreenState extends State<BusinessIpvScreen> {
  final _api = sl<ApiClient>();
  _Periodo _periodo = _Periodo.hoy;
  Map<String, dynamic>? _ipv;
  List<Map<String, dynamic>> _cierres = const [];
  bool _loading = true;
  String? _error;

  String? get _businessId =>
      context.read<ActiveBusinessCubit>().state.activeBusiness?.id;
  String get _businessName =>
      context.read<ActiveBusinessCubit>().state.activeBusiness?.name ??
      'Negocio';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  (DateTime, DateTime) _range() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_periodo) {
      case _Periodo.hoy:
        return (today, now);
      case _Periodo.ayer:
        return (today.subtract(const Duration(days: 1)), today);
      case _Periodo.semana:
        return (today.subtract(const Duration(days: 6)), now);
      case _Periodo.mes:
        return (DateTime(now.year, now.month, 1), now);
    }
  }

  Future<void> _load() async {
    final id = _businessId;
    if (id == null) {
      setState(() {
        _loading = false;
        _error = 'Selecciona un negocio.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final (desde, hasta) = _range();
    final results = await Future.wait([
      _api.get<Map<String, dynamic>>(
        '/negocios/$id/ipv',
        queryParameters: {
          'desde': desde.toUtc().toIso8601String(),
          'hasta': hasta.toUtc().toIso8601String(),
        },
        parser: (j) => Map<String, dynamic>.from(j as Map),
      ),
      _api.get<List<Map<String, dynamic>>>(
        '/negocios/$id/cierres',
        parser: (j) => (j as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
      ),
    ]);
    if (!mounted) return;
    final ipvRes = results[0];
    setState(() {
      _loading = false;
      if (ipvRes.isSuccess) {
        _ipv = ipvRes.data as Map<String, dynamic>;
      } else {
        _error = ipvRes.error?.message ?? 'No se pudo cargar el IPV.';
      }
      final c = results[1];
      if (c.isSuccess) _cierres = c.data as List<Map<String, dynamic>>;
    });
  }

  Future<void> _cerrar() async {
    final id = _businessId;
    if (id == null) return;
    final efectivo = TextEditingController();
    final notas = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar negocio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Se guarda el IPV del periodo seleccionado como cierre.',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: efectivo,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Efectivo contado (opcional)',
              ),
            ),
            TextField(
              controller: notas,
              decoration: const InputDecoration(labelText: 'Notas'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final (desde, hasta) = _range();
    final res = await _api.post<Map<String, dynamic>>(
      '/negocios/$id/cierre',
      data: {
        'desde': desde.toUtc().toIso8601String(),
        'hasta': hasta.toUtc().toIso8601String(),
        if (double.tryParse(efectivo.text.replaceAll(',', '.')) != null)
          'efectivo_contado': double.parse(efectivo.text.replaceAll(',', '.')),
        if (notas.text.trim().isNotEmpty) 'notas': notas.text.trim(),
      },
      parser: (j) => Map<String, dynamic>.from(j as Map),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res.isSuccess
              ? 'Cierre guardado.'
              : res.error?.message ?? 'No se pudo cerrar.',
        ),
      ),
    );
    if (res.isSuccess) _load();
  }

  Future<void> _exportPdf(Map<String, dynamic> ipv) async {
    final filas = (ipv['filas'] as List? ?? const []).whereType<Map>();
    final t = Map<String, dynamic>.from(ipv['totales'] as Map? ?? const {});
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(
            'IPV - $_businessName',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('${ipv['desde']}  ->  ${ipv['hasta']}'),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headers: const [
              'Producto',
              'Inicial',
              'Entradas',
              'Ventas',
              'Salidas',
              'Final',
              'Precio',
              'Importe',
            ],
            data: [
              for (final f in filas)
                [
                  '${f['nombre']}',
                  _money(f['inicial']),
                  _money(f['entradas']),
                  _money(f['ventas']),
                  _money(f['salidas']),
                  _money(f['final']),
                  _money(f['precio']),
                  _money(f['importe_ventas']),
                ],
              [
                'TOTAL',
                _money(t['inicial']),
                _money(t['entradas']),
                _money(t['ventas_unidades']),
                _money(t['salidas']),
                _money(t['final']),
                '',
                _money(t['importe_ventas']),
              ],
            ],
          ),
        ],
      ),
    );
    final bytes = await doc.save();
    await Share.shareXFiles([
      XFile.fromData(
        bytes,
        mimeType: 'application/pdf',
        name: 'ipv_${DateTime.now().millisecondsSinceEpoch}.pdf',
      ),
    ], fileNameOverrides: ['ipv.pdf']);
  }

  @override
  Widget build(BuildContext context) {
    final ipv = _ipv;
    return Scaffold(
      appBar: AppBar(
        title: const Text('IPV y cierre'),
        actions: [
          IconButton(
            tooltip: 'Exportar PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: ipv == null ? null : () => _exportPdf(ipv),
          ),
        ],
      ),
      floatingActionButton: ipv == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _cerrar,
              icon: const Icon(Icons.lock_clock_outlined),
              label: const Text('Cerrar negocio'),
            ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            SegmentedButton<_Periodo>(
              segments: const [
                ButtonSegment(value: _Periodo.hoy, label: Text('Hoy')),
                ButtonSegment(value: _Periodo.ayer, label: Text('Ayer')),
                ButtonSegment(value: _Periodo.semana, label: Text('7 dias')),
                ButtonSegment(value: _Periodo.mes, label: Text('Mes')),
              ],
              selected: {_periodo},
              onSelectionChanged: (s) {
                setState(() => _periodo = s.first);
                _load();
              },
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              )
            else if (ipv != null)
              ..._content(ipv),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(Map<String, dynamic> ipv) {
    final t = Map<String, dynamic>.from(ipv['totales'] as Map? ?? const {});
    final filas = (ipv['filas'] as List? ?? const []).whereType<Map>().toList();
    final users = (ipv['por_usuario'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final moneda = '${ipv['moneda'] ?? 'CUP'}';
    return [
      Row(
        children: [
          _Kpi('Ventas', '${_money(t['importe_ventas'])} $moneda'),
          _Kpi('Unidades', _money(t['ventas_unidades'])),
          _Kpi('Bajo stock', _money(t['bajo_stock'])),
        ],
      ),
      const SizedBox(height: 12),
      Text('Inventario por producto', style: _h(context)),
      const SizedBox(height: 6),
      if (filas.isEmpty)
        const Text('Sin movimientos en este periodo.')
      else
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 14,
            headingRowHeight: 36,
            dataRowMinHeight: 34,
            dataRowMaxHeight: 40,
            columns: const [
              DataColumn(label: Text('Producto')),
              DataColumn(label: Text('Ini'), numeric: true),
              DataColumn(label: Text('Ent'), numeric: true),
              DataColumn(label: Text('Vend'), numeric: true),
              DataColumn(label: Text('Sal'), numeric: true),
              DataColumn(label: Text('Fin'), numeric: true),
              DataColumn(label: Text('Importe'), numeric: true),
            ],
            rows: [
              for (final f in filas)
                DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 130,
                        child: Text(
                          '${f['nombre']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(Text(_money(f['inicial']))),
                    DataCell(Text(_money(f['entradas']))),
                    DataCell(Text(_money(f['ventas']))),
                    DataCell(Text(_money(f['salidas']))),
                    DataCell(Text(_money(f['final']))),
                    DataCell(Text(_money(f['importe_ventas']))),
                  ],
                ),
            ],
          ),
        ),
      if (users.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('Ventas por empleado', style: _h(context)),
        for (final u in users)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text('${u['nombre'] ?? 'Usuario'}'),
            trailing: Text(
              '${_money(u['importe'])} $moneda · ${_money(u['unidades'])} u.',
            ),
          ),
      ],
      if (_cierres.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('Cierres anteriores', style: _h(context)),
        for (final c in _cierres)
          Builder(
            builder: (_) {
              final d = Map<String, dynamic>.from(
                (c['datos_nuevos'] as Map?) ?? const {},
              );
              final tot = Map<String, dynamic>.from(
                (d['totales'] as Map?) ?? const {},
              );
              final diff = d['diferencia_efectivo'];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_outline),
                title: Text('${d['cerrado_en'] ?? c['created_at']}'),
                subtitle: Text(
                  'Ventas ${_money(tot['importe_ventas'])}'
                  '${diff == null ? '' : ' · Dif. efectivo ${_money(diff)}'}',
                ),
              );
            },
          ),
      ],
    ];
  }

  TextStyle? _h(BuildContext c) => Theme.of(
    c,
  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              Text(label, style: const TextStyle(fontSize: 11.5)),
            ],
          ),
        ),
      ),
    );
  }
}
