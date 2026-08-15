import 'package:flutter/material.dart';

import 'tema_aplicativo.dart';

class TelaLetraHino extends StatelessWidget {
  const TelaLetraHino({super.key, required this.hino});

  final Map<String, dynamic> hino;

  @override
  Widget build(BuildContext context) {
    final estrofes = ((hino['estrofes'] as List<dynamic>?) ?? const [])
        .map((estrofe) => estrofe.toString().trim())
        .where((estrofe) => estrofe.isNotEmpty)
        .toList();
    final livro = hino['livro']?.toString() ?? '';
    final numero = hino['numeroFormatado']?.toString() ?? '';
    final titulo = hino['titulo']?.toString() ?? 'Sem título';
    final tom = hino['tom']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('$livro $numero'),
        actions: const [BotaoTema()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              Text(
                '$livro $numero — $titulo',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (tom.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Tonalidade: $tom',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
              const SizedBox(height: 20),
              if (estrofes.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'A letra deste hino ainda não está disponível.',
                    ),
                  ),
                )
              else
                ...List.generate(
                  estrofes.length,
                  (indice) => Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            estrofes[indice],
                            style: const TextStyle(fontSize: 18, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
