import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'servico_busca_hinos.dart';

class TelaAdminObservacoes extends StatefulWidget {
  const TelaAdminObservacoes({super.key, required this.nomeUsuario});

  final String nomeUsuario;

  @override
  State<TelaAdminObservacoes> createState() => _TelaAdminObservacoesState();
}

class _TelaAdminObservacoesState extends State<TelaAdminObservacoes> {
  final _pesquisaController = TextEditingController();
  String? _cultoSelecionadoId;

  @override
  void dispose() {
    _pesquisaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('cultos_v2').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Mensagem(
            icone: Icons.cloud_off_outlined,
            titulo: 'Não foi possível carregar os cultos',
            mensagem: snapshot.error.toString(),
          );
        }

        final cultos =
            (snapshot.data?.docs ?? const [])
                .map(
                  (documento) => <String, dynamic>{
                    ...documento.data(),
                    'id': documento.id,
                  },
                )
                .where(
                  (culto) =>
                      culto['observacoes']?.toString().trim().isNotEmpty ==
                      true,
                )
                .toList()
              ..sort(_compararCultos);
        final filtrados = _filtrar(cultos);
        final selecionado = _selecionar(filtrados);

        return Column(
          children: [
            _cabecalho(context, cultos.length),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  SizedBox(width: 430, child: _lista(context, filtrados)),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: selecionado == null
                        ? const _Mensagem(
                            icone: Icons.event_note_outlined,
                            titulo: 'Nenhuma observação de culto',
                            mensagem:
                                'As observações anotadas nos cultos aparecerão aqui.',
                          )
                        : _DetalheCulto(
                            culto: selecionado,
                            nomeUsuario: widget.nomeUsuario,
                          ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _cabecalho(BuildContext context, int quantidade) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Observações dos cultos',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text('$quantidade culto(s) com observações'),
              ],
            ),
          ),
          SizedBox(
            width: 420,
            child: TextField(
              controller: _pesquisaController,
              onChanged: (_) => setState(() => _cultoSelecionadoId = null),
              decoration: InputDecoration(
                labelText: 'Pesquisar nos cultos',
                hintText: 'Título, data ou observação',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _pesquisaController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar pesquisa',
                        onPressed: () {
                          _pesquisaController.clear();
                          setState(() => _cultoSelecionadoId = null);
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lista(BuildContext context, List<Map<String, dynamic>> cultos) {
    if (cultos.isEmpty) {
      return const _Mensagem(
        icone: Icons.search_off,
        titulo: 'Nenhum culto encontrado',
        mensagem: 'Altere a pesquisa ou registre uma observação em um culto.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      itemCount: cultos.length,
      itemBuilder: (context, indice) {
        final culto = cultos[indice];
        final id = culto['id'].toString();
        final selecionado =
            id == _cultoSelecionadoId ||
            (_cultoSelecionadoId == null && indice == 0);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: ListTile(
            selected: selecionado,
            selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            leading: const CircleAvatar(child: Icon(Icons.event_note_outlined)),
            title: Text(
              culto['titulo']?.toString() ?? 'Culto',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${_formatarData(culto['dataHora'])} · ${culto['observacoes']}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => setState(() => _cultoSelecionadoId = id),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _filtrar(List<Map<String, dynamic>> cultos) {
    final consulta = ServicoBuscaHinos.normalizar(_pesquisaController.text);
    if (consulta.isEmpty) return cultos;
    return cultos.where((culto) {
      final texto = ServicoBuscaHinos.normalizar(
        [
          culto['titulo'],
          culto['observacoes'],
          _formatarData(culto['dataHora']),
        ].join(' '),
      );
      return texto.contains(consulta);
    }).toList();
  }

  Map<String, dynamic>? _selecionar(List<Map<String, dynamic>> cultos) {
    if (_cultoSelecionadoId != null) {
      for (final culto in cultos) {
        if (culto['id'] == _cultoSelecionadoId) return culto;
      }
    }
    return cultos.isEmpty ? null : cultos.first;
  }

  static int _compararCultos(Map<String, dynamic> a, Map<String, dynamic> b) {
    final dataA = a['dataHora'] is Timestamp
        ? (a['dataHora'] as Timestamp).millisecondsSinceEpoch
        : 0;
    final dataB = b['dataHora'] is Timestamp
        ? (b['dataHora'] as Timestamp).millisecondsSinceEpoch
        : 0;
    return dataB.compareTo(dataA);
  }
}

class _DetalheCulto extends StatelessWidget {
  const _DetalheCulto({required this.culto, required this.nomeUsuario});

  final Map<String, dynamic> culto;
  final String nomeUsuario;

  @override
  Widget build(BuildContext context) {
    final cultoId = culto['id'].toString();
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 32, 40),
      children: [
        Text(
          culto['titulo']?.toString() ?? 'Culto',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(_formatarData(culto['dataHora'])),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Observação',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                SelectableText(
                  culto['observacoes']?.toString() ?? '',
                  style: const TextStyle(fontSize: 17, height: 1.45),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Hinos deste culto',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('itens_culto_v2')
              .where('cultoId', isEqualTo: cultoId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text(
                'Não foi possível carregar os hinos: ${snapshot.error}',
              );
            }
            final itens =
                (snapshot.data?.docs ?? const [])
                    .map((documento) => documento.data())
                    .toList()
                  ..sort((a, b) {
                    final ordemA = (a['ordem'] as num?)?.toInt() ?? 0;
                    final ordemB = (b['ordem'] as num?)?.toInt() ?? 0;
                    return ordemA.compareTo(ordemB);
                  });
            if (itens.isEmpty) return const Text('Nenhum hino neste culto.');
            return Column(
              children: itens
                  .map(
                    (item) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(item['livro']?.toString() ?? ''),
                        ),
                        title: Text(
                          '${item['livro']} ${item['numeroFormatado']} — '
                          '${item['titulo']}',
                        ),
                        subtitle: Text(
                          'Tom usado: ${item['tomEscolhido'] ?? '—'}',
                        ),
                        trailing: FilledButton.tonalIcon(
                          onPressed: () => _abrirEditorLetra(
                            context,
                            hinoId: item['hinoId'].toString(),
                            culto: culto,
                            nomeUsuario: nomeUsuario,
                          ),
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Corrigir letra'),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

Future<void> _abrirEditorLetra(
  BuildContext context, {
  required String hinoId,
  required Map<String, dynamic> culto,
  required String nomeUsuario,
}) async {
  final referencia = FirebaseFirestore.instance
      .collection('hinos_v2')
      .doc(hinoId);
  final documento = await referencia.get();
  if (!context.mounted) return;
  if (!documento.exists) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Hino $hinoId não encontrado.')));
    return;
  }

  final hino = documento.data()!;
  final anteriores = ((hino['estrofes'] as List<dynamic>?) ?? const [])
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
  final controller = TextEditingController(text: anteriores.join('\n\n'));
  var salvando = false;
  var gravacaoConcluida = false;
  String? erro;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (contextoDialogo) => StatefulBuilder(
      builder: (contextoDialogo, atualizarDialogo) {
        Future<void> salvar() async {
          final novas = controller.text
              .split(RegExp(r'\n\s*\n'))
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList();
          if (novas.isEmpty) {
            atualizarDialogo(() => erro = 'A letra não pode ficar vazia.');
            return;
          }
          if (_listasIguais(anteriores, novas)) {
            atualizarDialogo(() => erro = 'Nenhuma alteração foi realizada.');
            return;
          }
          final usuario = FirebaseAuth.instance.currentUser;
          if (usuario == null) {
            atualizarDialogo(() => erro = 'A sessão não está mais ativa.');
            return;
          }

          atualizarDialogo(() {
            salvando = true;
            erro = null;
          });
          try {
            final banco = FirebaseFirestore.instance;
            final historico = banco.collection('historico_hinos').doc();
            final lote = banco.batch();
            lote.update(referencia, {
              'estrofes': novas,
              'textoBusca': ServicoBuscaHinos.normalizar(novas.join(' ')),
            });
            lote.set(historico, {
              'hinoId': hinoId,
              'hinoLivro': hino['livro'],
              'hinoNumeroFormatado': hino['numeroFormatado'],
              'hinoTitulo': hino['titulo'],
              'campo': 'estrofes',
              'valorAnterior': anteriores,
              'valorNovo': novas,
              'alteradoPorUid': usuario.uid,
              'alteradoPorNome': nomeUsuario,
              'alteradoEm': FieldValue.serverTimestamp(),
              'origemCultoId': culto['id'],
              'origemCultoTitulo': culto['titulo'],
              'observacaoCulto': culto['observacoes'],
            });
            await lote.commit();
            gravacaoConcluida = true;
            if (!contextoDialogo.mounted) return;
            Navigator.pop(contextoDialogo);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Letra corrigida e histórico registrado.'),
                ),
              );
            }
          } on FirebaseException catch (excecao) {
            if (contextoDialogo.mounted) {
              atualizarDialogo(
                () => erro =
                    'Não foi possível salvar: ${excecao.message ?? excecao.code}',
              );
            }
          } finally {
            if (!gravacaoConcluida && contextoDialogo.mounted) {
              atualizarDialogo(() => salvando = false);
            }
          }
        }

        return AlertDialog(
          title: Text('Corrigir letra — $hinoId'),
          content: SizedBox(
            width: 760,
            height: 560,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  hino['titulo']?.toString() ?? '',
                  style: Theme.of(contextoDialogo).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Revise com atenção. Separe as estrofes com uma linha em branco.',
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: TextField(
                    controller: controller,
                    expands: true,
                    minLines: null,
                    maxLines: null,
                    enabled: !salvando,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      labelText: 'Letra completa',
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                if (erro != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    erro!,
                    style: TextStyle(
                      color: Theme.of(contextoDialogo).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: salvando ? null : () => Navigator.pop(contextoDialogo),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: salvando ? null : salvar,
              icon: salvando
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Salvar correção'),
            ),
          ],
        );
      },
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
}

bool _listasIguais(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var indice = 0; indice < a.length; indice++) {
    if (a[indice] != b[indice]) return false;
  }
  return true;
}

class _Mensagem extends StatelessWidget {
  const _Mensagem({
    required this.icone,
    required this.titulo,
    required this.mensagem,
  });

  final IconData icone;
  final String titulo;
  final String mensagem;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 52),
            const SizedBox(height: 14),
            Text(titulo, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(mensagem, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

String _formatarData(Object? valor) {
  if (valor is! Timestamp) return '';
  final data = valor.toDate().toLocal();
  String dois(int numero) => numero.toString().padLeft(2, '0');
  return '${dois(data.day)}/${dois(data.month)}/${data.year} '
      '${dois(data.hour)}:${dois(data.minute)}';
}
