class ArquivoApresentacao {
  const ArquivoApresentacao({this.caminho});

  final String? caminho;
  bool get encontrado => caminho != null;
}

class AbridorApresentacoes {
  static bool get disponivel => false;

  static Future<ArquivoApresentacao> localizar({
    required String livro,
    required String numeroFormatado,
  }) async {
    return const ArquivoApresentacao();
  }

  static Future<void> abrir(String caminho) {
    throw UnsupportedError(
      'A abertura de PowerPoints está disponível somente no aplicativo Windows.',
    );
  }
}
