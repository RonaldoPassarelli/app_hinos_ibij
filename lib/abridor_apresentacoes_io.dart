import 'dart:io';

class ArquivoApresentacao {
  const ArquivoApresentacao({this.caminho});

  final String? caminho;
  bool get encontrado => caminho != null;
}

class AbridorApresentacoes {
  static const _pastas = <String, String>{
    'CC': r'C:\HINOS\CC',
    'VM': r'C:\HINOS\VM',
  };

  static bool get disponivel => Platform.isWindows;

  static Future<ArquivoApresentacao> localizar({
    required String livro,
    required String numeroFormatado,
  }) async {
    if (!disponivel) return const ArquivoApresentacao();
    final pasta = _pastas[livro.toUpperCase()];
    if (pasta == null) return const ArquivoApresentacao();

    final diretorio = Directory(pasta);
    if (!await diretorio.exists()) return const ArquivoApresentacao();

    final numero = int.tryParse(numeroFormatado.replaceAll(RegExp(r'\D'), ''));
    if (numero == null) return const ArquivoApresentacao();

    final candidatos = <File>[];
    await for (final entidade in diretorio.list()) {
      if (entidade is! File) continue;
      final nome = entidade.uri.pathSegments.last;
      final extensao = nome.toLowerCase();
      if (!extensao.endsWith('.ppt') && !extensao.endsWith('.pptx')) continue;
      final numeros = RegExp(r'\d+').allMatches(nome);
      if (numeros.any((trecho) => int.tryParse(trecho.group(0)!) == numero)) {
        candidatos.add(entidade);
      }
    }

    if (candidatos.isEmpty) return const ArquivoApresentacao();
    candidatos.sort((a, b) {
      final nomeA = a.uri.pathSegments.last.toLowerCase();
      final nomeB = b.uri.pathSegments.last.toLowerCase();
      final alvo = numeroFormatado.toLowerCase();
      final exatoA = nomeA.startsWith(alvo) ? 0 : 1;
      final exatoB = nomeB.startsWith(alvo) ? 0 : 1;
      if (exatoA != exatoB) return exatoA.compareTo(exatoB);
      final pptxA = nomeA.endsWith('.pptx') ? 0 : 1;
      final pptxB = nomeB.endsWith('.pptx') ? 0 : 1;
      if (pptxA != pptxB) return pptxA.compareTo(pptxB);
      return nomeA.compareTo(nomeB);
    });
    return ArquivoApresentacao(caminho: candidatos.first.path);
  }

  static Future<void> abrir(String caminho) async {
    if (!disponivel) {
      throw UnsupportedError('Este recurso exige o aplicativo Windows.');
    }
    final arquivo = File(caminho);
    if (!await arquivo.exists()) {
      throw FileSystemException(
        'A apresentação não existe mais neste caminho.',
        caminho,
      );
    }
    await Process.start('explorer.exe', [
      caminho,
    ], mode: ProcessStartMode.detached);
  }
}
