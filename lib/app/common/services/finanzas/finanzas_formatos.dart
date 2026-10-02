String formatoDinero(num? value) {
  if (value == null) return '-';
  final numero = value.toDouble();
  if (numero % 1 == 0) {
    if (numero.abs() >= 1000000) {
      return '${(numero / 1000000).toStringAsFixed(numero % 1000000 == 0 ? 0 : 2)}M';
    }
    if (numero.abs() >= 1000) {
      return _agruparMiles(numero.toStringAsFixed(0));
    }
    return numero.toStringAsFixed(0);
  }
  return _agruparMiles(numero.toStringAsFixed(2));
}

String _agruparMiles(String texto) {
  final partes = texto.split('.');
  final entera = partes[0];
  final esNegativo = entera.startsWith('-');
  final sinSigno = esNegativo ? entera.substring(1) : entera;
  final buffer = StringBuffer();
  for (var i = 0; i < sinSigno.length; i++) {
    buffer.write(sinSigno[i]);
    final restantes = sinSigno.length - 1 - i;
    if (restantes > 0 && restantes % 3 == 0) buffer.write(',');
  }
  final enteraFormateada = '${esNegativo ? '-' : ''}$buffer';
  return partes.length > 1 ? '$enteraFormateada.${partes[1]}' : enteraFormateada;
}

String formatearTendencia(double? tendencia) {
  if (tendencia == null) return '--';
  final signo = tendencia > 0 ? '+' : '';
  return '$signo${tendencia.toStringAsFixed(1)}%';
}

String monedaAbreviada(String codigo) {
  return switch (codigo.toUpperCase()) {
    'MLC' => 'MLC',
    'USDT' => 'USDT',
    _ => codigo.toUpperCase(),
  };
}