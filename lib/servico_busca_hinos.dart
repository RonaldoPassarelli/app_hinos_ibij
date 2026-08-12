import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class ResultadoBuscaHino {
  const ResultadoBuscaHino({
    required this.id,
    required this.livro,
    required this.numeroFormatado,
    required this.titulo,
    required this.tom,
    required this.pontuacao,
  });

  final String id;
  final String livro;
  final String numeroFormatado;
  final String titulo;
  final String tom;
  final double pontuacao;
}

class _HinoIndice {
  const _HinoIndice({
    required this.id,
    required this.livro,
    required this.numeroFormatado,
    required this.titulo,
    required this.tom,
    required this.tituloNormalizado,
    required this.textoBusca,
  });

  factory _HinoIndice.fromJson(Map<String, dynamic> json) {
    return _HinoIndice(
      id: json['id'] as String,
      livro: json['livro'] as String,
      numeroFormatado: json['numeroFormatado'] as String,
      titulo: json['titulo'] as String,
      tom: json['tom'] as String,
      tituloNormalizado: json['tituloNormalizado'] as String,
      textoBusca: json['textoBusca'] as String,
    );
  }

  factory _HinoIndice.fromFirestore(
    String documentoId,
    Map<String, dynamic> dados,
  ) {
    final livro = dados['livro']?.toString() ?? documentoId.split('_').first;
    final numero = dados['numero'];
    final numeroFormatado =
        dados['numeroFormatado']?.toString() ??
        (numero is num ? numero.toInt().toString().padLeft(3, '0') : '');
    final titulo = dados['titulo']?.toString() ?? 'Sem título';
    final estrofes = (dados['estrofes'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .join(' ');
    final tituloNormalizado = dados['tituloNormalizado']?.toString().trim();
    final textoBusca = dados['textoBusca']?.toString().trim();

    return _HinoIndice(
      id: documentoId,
      livro: livro,
      numeroFormatado: numeroFormatado,
      titulo: titulo,
      tom: dados['tom']?.toString() ?? '',
      tituloNormalizado: tituloNormalizado?.isNotEmpty == true
          ? tituloNormalizado!
          : ServicoBuscaHinos.normalizar(titulo),
      textoBusca: textoBusca?.isNotEmpty == true
          ? textoBusca!
          : ServicoBuscaHinos.normalizar(estrofes),
    );
  }

  final String id;
  final String livro;
  final String numeroFormatado;
  final String titulo;
  final String tom;
  final String tituloNormalizado;
  final String textoBusca;
}

class ServicoBuscaHinos {
  factory ServicoBuscaHinos() => _instancia;

  ServicoBuscaHinos._();

  static final ServicoBuscaHinos _instancia = ServicoBuscaHinos._();

  List<_HinoIndice>? _indice;
  Future<void>? _carregamento;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _assinatura;

  Future<void> carregar() {
    return _carregamento ??= _carregarESincronizar();
  }

  Future<void> _carregarESincronizar() async {
    final conteudo = await rootBundle.loadString(
      'assets/indice_busca_hinos.json',
    );
    final lista = jsonDecode(conteudo) as List<dynamic>;
    _indice = lista
        .map((item) => _HinoIndice.fromJson(item as Map<String, dynamic>))
        .toList();

    final colecao = FirebaseFirestore.instance.collection('hinos_v2');

    // Atualiza a base empacotada com os dados disponíveis no Firestore. Quando
    // não houver internet, o próprio Firestore utiliza seu cache persistente.
    try {
      final consulta = await colecao.get();
      _aplicarSnapshot(consulta);
    } on FirebaseException {
      // A base local continua disponível. A assinatura abaixo tentará novamente
      // automaticamente quando a conexão for restabelecida.
    }

    _assinatura ??= colecao
        .snapshots(includeMetadataChanges: true)
        .listen(
          _aplicarSnapshot,
          onError: (_) {
            // Uma falha temporária não invalida o índice já carregado.
          },
        );
  }

  void _aplicarSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final recebidos = <String, _HinoIndice>{
      for (final documento in snapshot.docs)
        documento.id: _HinoIndice.fromFirestore(documento.id, documento.data()),
    };

    if (!snapshot.metadata.isFromCache) {
      _indice = recebidos.values.toList();
      return;
    }

    // Um snapshot vindo do cache pode conter somente parte da coleção. Nesse
    // caso fazemos mesclagem para não descartar o índice completo do APK.
    final mesclados = <String, _HinoIndice>{
      for (final hino in _indice ?? const <_HinoIndice>[]) hino.id: hino,
      ...recebidos,
    };
    _indice = mesclados.values.toList();
  }

  Future<List<ResultadoBuscaHino>> buscar(String consulta) async {
    await carregar();
    final textoConsulta = normalizar(consulta);
    if (textoConsulta.length < 2) return [];

    final resultados = <ResultadoBuscaHino>[];
    for (final hino in _indice!) {
      final pontuacao = _pontuar(textoConsulta, hino);
      if (pontuacao >= 0.52) {
        resultados.add(
          ResultadoBuscaHino(
            id: hino.id,
            livro: hino.livro,
            numeroFormatado: hino.numeroFormatado,
            titulo: hino.titulo,
            tom: hino.tom,
            pontuacao: pontuacao,
          ),
        );
      }
    }

    resultados.sort((a, b) {
      final porPontos = b.pontuacao.compareTo(a.pontuacao);
      if (porPontos != 0) return porPontos;
      return a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
    });
    return resultados.take(30).toList();
  }

  double _pontuar(String consulta, _HinoIndice hino) {
    if (hino.tituloNormalizado == consulta) return 1;
    if (hino.tituloNormalizado.startsWith(consulta)) return 0.96;
    if (hino.tituloNormalizado.contains(consulta)) return 0.92;

    final tokensConsulta = consulta
        .split(' ')
        .where((t) => t.length > 1)
        .toList();
    if (tokensConsulta.isEmpty) return 0;

    final tokensTitulo = hino.tituloNormalizado.split(' ');
    final listaTokensLetra = hino.textoBusca.split(' ');
    final tokensLetra = listaTokensLetra.toSet();
    var somaTitulo = 0.0;
    var somaLetra = 0.0;

    for (final token in tokensConsulta) {
      somaTitulo += _melhorSemelhanca(token, tokensTitulo);
      if (tokensLetra.contains(token)) {
        somaLetra += 1;
      } else {
        somaLetra += _melhorSemelhanca(
          token,
          tokensLetra.where(
            (palavra) => (palavra.length - token.length).abs() <= 2,
          ),
        );
      }
    }

    final titulo = somaTitulo / tokensConsulta.length;
    final letra = somaLetra / tokensConsulta.length;
    final fraseNaLetra = hino.textoBusca.contains(consulta) ? 1.0 : 0.0;
    final proximidade = _proximidade(tokensConsulta, listaTokensLetra);
    final similaridadeTitulo = _similaridade(consulta, hino.tituloNormalizado);

    if (fraseNaLetra == 1) {
      return 0.94 + (0.06 * titulo);
    }

    return [
      0.50 * titulo + 0.30 * letra + 0.20 * proximidade,
      0.58 * letra + 0.32 * proximidade + 0.10 * titulo,
      0.82 * similaridadeTitulo + 0.18 * letra,
    ].reduce((a, b) => a > b ? a : b);
  }

  double _proximidade(List<String> consulta, List<String> texto) {
    final procurados = consulta.toSet();
    if (procurados.isEmpty) return 0;

    final contagem = <String, int>{};
    var encontrados = 0;
    var inicio = 0;
    var menorJanela = texto.length + 1;

    for (var fim = 0; fim < texto.length; fim++) {
      final palavra = texto[fim];
      if (procurados.contains(palavra)) {
        final anterior = contagem[palavra] ?? 0;
        contagem[palavra] = anterior + 1;
        if (anterior == 0) encontrados++;
      }

      while (encontrados == procurados.length && inicio <= fim) {
        final tamanho = fim - inicio + 1;
        if (tamanho < menorJanela) menorJanela = tamanho;

        final primeira = texto[inicio];
        if (procurados.contains(primeira)) {
          final novaContagem = contagem[primeira]! - 1;
          contagem[primeira] = novaContagem;
          if (novaContagem == 0) encontrados--;
        }
        inicio++;
      }
    }

    if (menorJanela > texto.length) return 0;
    return procurados.length / menorJanela;
  }

  double _melhorSemelhanca(String token, Iterable<String> palavras) {
    var melhor = 0.0;
    for (final palavra in palavras) {
      final atual = _similaridade(token, palavra);
      if (atual > melhor) melhor = atual;
      if (melhor == 1) break;
    }
    return melhor >= 0.72 ? melhor : 0;
  }

  double _similaridade(String a, String b) {
    if (a == b) return 1;
    final maior = a.length > b.length ? a.length : b.length;
    if (maior == 0) return 1;
    return 1 - (_distanciaLevenshtein(a, b) / maior);
  }

  int _distanciaLevenshtein(String a, String b) {
    var anterior = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 0; i < a.length; i++) {
      final atual = <int>[i + 1];
      for (var j = 0; j < b.length; j++) {
        final custo = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        final insercao = atual[j] + 1;
        final remocao = anterior[j + 1] + 1;
        final troca = anterior[j] + custo;
        atual.add([insercao, remocao, troca].reduce((x, y) => x < y ? x : y));
      }
      anterior = atual;
    }
    return anterior.last;
  }

  static String normalizar(String texto) {
    const comAcentos = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
    const semAcentos = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
    var resultado = texto;
    for (var i = 0; i < comAcentos.length; i++) {
      resultado = resultado.replaceAll(comAcentos[i], semAcentos[i]);
    }
    return resultado
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
