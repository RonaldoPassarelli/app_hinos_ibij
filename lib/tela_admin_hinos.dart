import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'servico_busca_hinos.dart';

class TelaAdminHinos extends StatefulWidget {
  const TelaAdminHinos({super.key});

  @override
  State<TelaAdminHinos> createState() => _TelaAdminHinosState();
}

class _TelaAdminHinosState extends State<TelaAdminHinos> {
  final _pesquisaController = TextEditingController();
  String _livro = 'Todos';
  String? _hinoSelecionadoId;

  @override
  void dispose() {
    _pesquisaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('hinos_v2').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _EstadoMensagem(
            icone: Icons.cloud_off_outlined,
            titulo: 'Não foi possível carregar os hinos',
            mensagem: snapshot.error.toString(),
          );
        }

        final todos =
            (snapshot.data?.docs ?? const [])
                .map(
                  (documento) => <String, dynamic>{
                    ...documento.data(),
                    'id': documento.id,
                  },
                )
                .toList()
              ..sort(_compararHinos);
        final filtrados = _filtrar(todos);
        final selecionado = _selecionar(filtrados);

        return Column(
          children: [
            _cabecalho(context, todos),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  SizedBox(width: 430, child: _lista(context, filtrados)),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: selecionado == null
                        ? const _EstadoMensagem(
                            icone: Icons.library_music_outlined,
                            titulo: 'Selecione um hino',
                            mensagem: 'Os detalhes aparecerão nesta área.',
                          )
                        : _DetalhesHino(
                            hino: selecionado,
                            correspondentes: _correspondentes(
                              todos,
                              selecionado,
                            ),
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

  Widget _cabecalho(BuildContext context, List<Map<String, dynamic>> todos) {
    final cc = todos.where((hino) => hino['livro'] == 'CC').length;
    final vm = todos.where((hino) => hino['livro'] == 'VM').length;
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
                  'Hinos',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text('${todos.length} cadastrados · CC $cc · VM $vm'),
              ],
            ),
          ),
          SizedBox(
            width: 380,
            child: TextField(
              controller: _pesquisaController,
              onChanged: (_) => setState(() => _hinoSelecionadoId = null),
              decoration: InputDecoration(
                labelText: 'Pesquisar hino',
                hintText: 'Número, título, assunto ou trecho',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _pesquisaController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar pesquisa',
                        onPressed: () {
                          _pesquisaController.clear();
                          setState(() => _hinoSelecionadoId = null);
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 130,
            child: DropdownButtonFormField<String>(
              initialValue: _livro,
              decoration: const InputDecoration(labelText: 'Hinário'),
              items: const [
                DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                DropdownMenuItem(value: 'CC', child: Text('CC')),
                DropdownMenuItem(value: 'VM', child: Text('VM')),
              ],
              onChanged: (valor) => setState(() {
                _livro = valor ?? 'Todos';
                _hinoSelecionadoId = null;
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lista(BuildContext context, List<Map<String, dynamic>> hinos) {
    if (hinos.isEmpty) {
      return const _EstadoMensagem(
        icone: Icons.search_off,
        titulo: 'Nenhum hino encontrado',
        mensagem: 'Altere o texto ou o filtro da pesquisa.',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('${hinos.length} resultado(s)'),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: hinos.length,
            itemBuilder: (context, indice) {
              final hino = hinos[indice];
              final id = hino['id'].toString();
              final selecionado =
                  id == _hinoSelecionadoId ||
                  (_hinoSelecionadoId == null && indice == 0);
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                child: ListTile(
                  selected: selecionado,
                  selectedTileColor: Theme.of(
                    context,
                  ).colorScheme.secondaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  leading: CircleAvatar(
                    child: Text(hino['livro']?.toString() ?? ''),
                  ),
                  title: Text(
                    '${hino['numeroFormatado'] ?? ''} — ${hino['titulo'] ?? 'Sem título'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('Tom ${hino['tom'] ?? '—'}'),
                  onTap: () => setState(() => _hinoSelecionadoId = id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _filtrar(List<Map<String, dynamic>> todos) {
    final consulta = ServicoBuscaHinos.normalizar(_pesquisaController.text);
    return todos.where((hino) {
      if (_livro != 'Todos' && hino['livro'] != _livro) return false;
      if (consulta.isEmpty) return true;
      final assuntos = ((hino['assuntos'] as List<dynamic>?) ?? const []).join(
        ' ',
      );
      final estrofes = ((hino['estrofes'] as List<dynamic>?) ?? const []).join(
        ' ',
      );
      final pesquisavel = ServicoBuscaHinos.normalizar(
        [
          hino['id'],
          hino['livro'],
          hino['numero'],
          hino['numeroFormatado'],
          hino['titulo'],
          hino['tom'],
          assuntos,
          estrofes,
        ].join(' '),
      );
      return pesquisavel.contains(consulta);
    }).toList();
  }

  Map<String, dynamic>? _selecionar(List<Map<String, dynamic>> filtrados) {
    if (_hinoSelecionadoId != null) {
      for (final hino in filtrados) {
        if (hino['id'] == _hinoSelecionadoId) return hino;
      }
    }
    return filtrados.isEmpty ? null : filtrados.first;
  }

  List<Map<String, dynamic>> _correspondentes(
    List<Map<String, dynamic>> todos,
    Map<String, dynamic> selecionado,
  ) {
    final obraId = selecionado['obraId'];
    if (obraId == null) return const [];
    return todos
        .where(
          (hino) => hino['obraId'] == obraId && hino['id'] != selecionado['id'],
        )
        .toList();
  }

  static int _compararHinos(Map<String, dynamic> a, Map<String, dynamic> b) {
    final livro = (a['livro']?.toString() ?? '').compareTo(
      b['livro']?.toString() ?? '',
    );
    if (livro != 0) return livro;
    final numeroA = a['numero'] is num ? (a['numero'] as num).toInt() : 0;
    final numeroB = b['numero'] is num ? (b['numero'] as num).toInt() : 0;
    return numeroA.compareTo(numeroB);
  }
}

class _DetalhesHino extends StatelessWidget {
  const _DetalhesHino({required this.hino, required this.correspondentes});

  final Map<String, dynamic> hino;
  final List<Map<String, dynamic>> correspondentes;

  @override
  Widget build(BuildContext context) {
    final assuntos = ((hino['assuntos'] as List<dynamic>?) ?? const [])
        .map((item) => item.toString())
        .toList();
    final estrofes = ((hino['estrofes'] as List<dynamic>?) ?? const [])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 32, 40),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              child: Text(hino['livro']?.toString() ?? ''),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${hino['livro'] ?? ''} ${hino['numeroFormatado'] ?? ''}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    hino['titulo']?.toString() ?? 'Sem título',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
            Chip(
              avatar: const Icon(Icons.music_note, size: 18),
              label: Text('Tom ${hino['tom'] ?? '—'}'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SecaoDetalhe(
          titulo: 'Cadastro',
          child: Wrap(
            spacing: 28,
            runSpacing: 12,
            children: [
              _CampoDetalhe(rotulo: 'ID', valor: hino['id']?.toString() ?? ''),
              _CampoDetalhe(
                rotulo: 'Obra',
                valor: hino['obraId']?.toString() ?? 'Não informada',
              ),
              _CampoDetalhe(rotulo: 'Estrofes', valor: '${estrofes.length}'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SecaoDetalhe(
          titulo: 'Assuntos',
          child: assuntos.isEmpty
              ? const Text('Nenhum assunto informado.')
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: assuntos
                      .map((assunto) => Chip(label: Text(assunto)))
                      .toList(),
                ),
        ),
        if (correspondentes.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SecaoDetalhe(
            titulo: 'Correspondente',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: correspondentes
                  .map(
                    (item) => Chip(
                      avatar: const Icon(Icons.link, size: 18),
                      label: Text(
                        '${item['livro']} ${item['numeroFormatado']} — ${item['titulo']}',
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _SecaoDetalhe(
          titulo: 'Letra',
          child: estrofes.isEmpty
              ? const Text('A letra ainda não está disponível.')
              : Column(
                  children: [
                    for (
                      var indice = 0;
                      indice < estrofes.length;
                      indice++
                    ) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SelectableText(
                          estrofes[indice],
                          style: const TextStyle(fontSize: 16, height: 1.45),
                        ),
                      ),
                      if (indice < estrofes.length - 1)
                        const Divider(height: 32),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _SecaoDetalhe extends StatelessWidget {
  const _SecaoDetalhe({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _CampoDetalhe extends StatelessWidget {
  const _CampoDetalhe({required this.rotulo, required this.valor});

  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          SelectableText(valor),
        ],
      ),
    );
  }
}

class _EstadoMensagem extends StatelessWidget {
  const _EstadoMensagem({
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
