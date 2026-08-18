import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'abridor_apresentacoes.dart';

const _toleranciaCultoEmAndamento = Duration(hours: 2);

bool _cultoAindaPlanejado(DateTime dataHora) {
  return DateTime.now().isBefore(dataHora.add(_toleranciaCultoEmAndamento));
}

bool _mesmoDia(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class TelaApresentacao extends StatefulWidget {
  const TelaApresentacao({super.key, required this.igrejaId});

  final String igrejaId;

  @override
  State<TelaApresentacao> createState() => _TelaApresentacaoState();
}

class _TelaApresentacaoState extends State<TelaApresentacao> {
  String? _cultoSelecionadoId;
  var _mostrarPlanejados = true;
  DateTime? _dataSelecionada;
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    _relogio = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _relogio?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('cultos_v2')
          .where('igrejaId', isEqualTo: widget.igrejaId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _mensagem(
            Icons.cloud_off_outlined,
            'Não foi possível carregar os cultos',
            snapshot.error.toString(),
          );
        }

        final todos = [...?snapshot.data?.docs]
          ..sort((a, b) {
            final dataA = a.data()['dataHora'] as Timestamp;
            final dataB = b.data()['dataHora'] as Timestamp;
            return dataA.compareTo(dataB);
          });
        final cultos = _filtrarCultos(todos);
        final selecionado = _selecionar(cultos);
        return Column(
          children: [
            _cabecalho(context, cultos.length),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  SizedBox(width: 390, child: _listaCultos(cultos)),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: selecionado == null
                        ? _mensagem(
                            Icons.event_busy_outlined,
                            _mostrarPlanejados
                                ? 'Nenhum culto planejado'
                                : 'Nenhum culto realizado',
                            _dataSelecionada == null
                                ? 'Não há cultos nesta categoria.'
                                : 'Não há cultos na data selecionada.',
                          )
                        : _DetalheApresentacao(culto: selecionado),
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
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Apresentação do culto',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '$quantidade culto(s) · escolha um culto e abra os hinos na ordem.',
                ),
              ],
            ),
          ),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                icon: Icon(Icons.event_available_outlined),
                label: Text('Planejados'),
              ),
              ButtonSegment(
                value: false,
                icon: Icon(Icons.history_outlined),
                label: Text('Realizados'),
              ),
            ],
            selected: {_mostrarPlanejados},
            onSelectionChanged: (selecao) {
              setState(() {
                _mostrarPlanejados = selecao.first;
                _cultoSelecionadoId = null;
              });
            },
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _escolherData,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
              _dataSelecionada == null
                  ? 'Escolher data'
                  : _formatarSomenteData(_dataSelecionada!),
            ),
          ),
          if (_dataSelecionada != null)
            IconButton(
              tooltip: 'Limpar data',
              onPressed: () => setState(() {
                _dataSelecionada = null;
                _cultoSelecionadoId = null;
              }),
              icon: const Icon(Icons.close),
            ),
          if (!AbridorApresentacoes.disponivel)
            const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Tooltip(
                message:
                    'A abertura dos arquivos está disponível somente no Windows',
                child: Icon(Icons.computer_outlined),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _escolherData() async {
    final hoje = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada ?? hoje,
      firstDate: DateTime(2020),
      lastDate: DateTime(hoje.year + 10),
      helpText: 'Escolher data do culto',
      cancelText: 'Cancelar',
      confirmText: 'Selecionar',
    );
    if (escolhida == null || !mounted) return;
    setState(() {
      _dataSelecionada = escolhida;
      _cultoSelecionadoId = null;
    });
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtrarCultos(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> todos,
  ) {
    final cultos = todos.where((documento) {
      final dados = documento.data();
      if (dados['status'] == 'cancelado') return false;
      final valor = dados['dataHora'];
      if (valor is! Timestamp) return false;
      final data = valor.toDate();
      final planejado = _cultoAindaPlanejado(data);
      if (planejado != _mostrarPlanejados) return false;
      final filtro = _dataSelecionada;
      return filtro == null || _mesmoDia(data, filtro);
    }).toList();
    if (!_mostrarPlanejados) {
      cultos.sort((a, b) {
        final dataA = (a.data()['dataHora'] as Timestamp).toDate();
        final dataB = (b.data()['dataHora'] as Timestamp).toDate();
        return dataB.compareTo(dataA);
      });
    }
    return cultos;
  }

  Widget _listaCultos(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cultos,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: cultos.length,
      itemBuilder: (context, indice) {
        final documento = cultos[indice];
        final dados = documento.data();
        final selecionado =
            documento.id == _cultoSelecionadoId ||
            (_cultoSelecionadoId == null && indice == 0);
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            selected: selecionado,
            selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: const CircleAvatar(child: Icon(Icons.church_outlined)),
            title: Text(
              dados['titulo']?.toString() ?? 'Culto',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(_rotuloDataHora(dados['dataHora'])),
            onTap: () => setState(() => _cultoSelecionadoId = documento.id),
          ),
        );
      },
    );
  }

  QueryDocumentSnapshot<Map<String, dynamic>>? _selecionar(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cultos,
  ) {
    if (_cultoSelecionadoId != null) {
      for (final culto in cultos) {
        if (culto.id == _cultoSelecionadoId) return culto;
      }
    }
    return cultos.isEmpty ? null : cultos.first;
  }
}

class _DetalheApresentacao extends StatelessWidget {
  const _DetalheApresentacao({required this.culto});

  final QueryDocumentSnapshot<Map<String, dynamic>> culto;

  @override
  Widget build(BuildContext context) {
    final dados = culto.data();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dados['titulo']?.toString() ?? 'Culto',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(_formatarDataHora(dados['dataHora'])),
                  ],
                ),
              ),
              _BotaoAbrirTodos(cultoId: culto.id),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('itens_culto_v2')
                .where('cultoId', isEqualTo: culto.id)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _mensagem(
                  Icons.cloud_off_outlined,
                  'Não foi possível carregar os hinos',
                  snapshot.error.toString(),
                );
              }
              final itens =
                  (snapshot.data?.docs ?? const [])
                      .map((documento) => documento.data())
                      .toList()
                    ..sort(
                      (a, b) => ((a['ordem'] as num?)?.toInt() ?? 0).compareTo(
                        (b['ordem'] as num?)?.toInt() ?? 0,
                      ),
                    );
              if (itens.isEmpty) {
                return _mensagem(
                  Icons.music_off_outlined,
                  'Nenhum hino neste culto',
                  'Adicione os hinos pelo aplicativo antes da apresentação.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 18, 28, 36),
                itemCount: itens.length,
                itemBuilder: (context, indice) =>
                    _CartaoHino(ordem: indice + 1, item: itens[indice]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BotaoAbrirTodos extends StatefulWidget {
  const _BotaoAbrirTodos({required this.cultoId});

  final String cultoId;

  @override
  State<_BotaoAbrirTodos> createState() => _BotaoAbrirTodosState();
}

class _BotaoAbrirTodosState extends State<_BotaoAbrirTodos> {
  var _processando = false;

  Future<void> _abrirTodos() async {
    final consulta = await FirebaseFirestore.instance
        .collection('itens_culto_v2')
        .where('cultoId', isEqualTo: widget.cultoId)
        .get();
    final itens = consulta.docs.map((documento) => documento.data()).toList()
      ..sort(
        (a, b) => ((a['ordem'] as num?)?.toInt() ?? 0).compareTo(
          (b['ordem'] as num?)?.toInt() ?? 0,
        ),
      );
    if (!mounted) return;
    if (itens.isEmpty) {
      _mostrarAviso('Este culto não possui hinos.');
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (contextoDialogo) => AlertDialog(
        title: const Text('Abrir todas as apresentações?'),
        content: Text(
          'O PowerPoint abrirá ${itens.length} apresentação(ões), '
          'na ordem deste culto.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contextoDialogo, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(contextoDialogo, true),
            icon: const Icon(Icons.slideshow_outlined),
            label: const Text('Abrir todos'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _processando = true);
    var abertos = 0;
    final ausentes = <String>[];
    try {
      for (final item in itens) {
        final livro = item['livro']?.toString() ?? '';
        final numero = item['numeroFormatado']?.toString() ?? '';
        final arquivo = await AbridorApresentacoes.localizar(
          livro: livro,
          numeroFormatado: numero,
        );
        if (!arquivo.encontrado) {
          ausentes.add('$livro $numero'.trim());
          continue;
        }
        await AbridorApresentacoes.abrir(arquivo.caminho!);
        abertos++;
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
      if (!mounted) return;
      final resumo = StringBuffer('$abertos apresentação(ões) aberta(s).');
      if (ausentes.isNotEmpty) {
        resumo.write(' Arquivos ausentes: ${ausentes.join(', ')}.');
      }
      _mostrarAviso(resumo.toString());
    } catch (erro) {
      if (mounted) _mostrarAviso('A abertura foi interrompida: $erro');
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  void _mostrarAviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: !AbridorApresentacoes.disponivel || _processando
          ? null
          : _abrirTodos,
      icon: _processando
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.playlist_play_outlined),
      label: Text(_processando ? 'Abrindo...' : 'Abrir todos'),
    );
  }
}

class _CartaoHino extends StatefulWidget {
  const _CartaoHino({required this.ordem, required this.item});

  final int ordem;
  final Map<String, dynamic> item;

  @override
  State<_CartaoHino> createState() => _CartaoHinoState();
}

class _CartaoHinoState extends State<_CartaoHino> {
  late Future<ArquivoApresentacao> _arquivo;

  @override
  void initState() {
    super.initState();
    _localizar();
  }

  @override
  void didUpdateWidget(covariant _CartaoHino oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item['livro'] != widget.item['livro'] ||
        oldWidget.item['numeroFormatado'] != widget.item['numeroFormatado']) {
      _localizar();
    }
  }

  void _localizar() {
    _arquivo = AbridorApresentacoes.localizar(
      livro: widget.item['livro']?.toString() ?? '',
      numeroFormatado: widget.item['numeroFormatado']?.toString() ?? '',
    );
  }

  Future<void> _abrir(String caminho) async {
    try {
      await AbridorApresentacoes.abrir(caminho);
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Não foi possível abrir: $erro')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final identificacao =
        '${item['livro'] ?? ''} ${item['numeroFormatado'] ?? ''}'.trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(child: Text('${widget.ordem}')),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$identificacao — ${item['titulo'] ?? ''}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text('Tom escolhido: ${item['tomEscolhido'] ?? '—'}'),
                ],
              ),
            ),
            const SizedBox(width: 16),
            FutureBuilder<ArquivoApresentacao>(
              future: _arquivo,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                final arquivo = snapshot.data;
                if (arquivo?.encontrado != true) {
                  return Tooltip(
                    message: AbridorApresentacoes.disponivel
                        ? 'Arquivo não encontrado'
                        : 'Disponível somente no Windows',
                    child: Chip(
                      avatar: const Icon(Icons.error_outline, size: 18),
                      label: Text(
                        AbridorApresentacoes.disponivel
                            ? 'Arquivo ausente'
                            : 'Indisponível',
                      ),
                    ),
                  );
                }
                return FilledButton.tonalIcon(
                  onPressed: () => _abrir(arquivo!.caminho!),
                  icon: const Icon(Icons.slideshow_outlined),
                  label: const Text('Abrir'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

Widget _mensagem(IconData icone, String titulo, String mensagem) {
  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 56),
            const SizedBox(height: 16),
            Text(titulo, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(mensagem, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

String _formatarDataHora(dynamic valor) {
  if (valor is! Timestamp) return 'Data não informada';
  final data = valor.toDate();
  String dois(int numero) => numero.toString().padLeft(2, '0');
  return '${dois(data.day)}/${dois(data.month)}/${data.year} às '
      '${dois(data.hour)}:${dois(data.minute)}';
}

String _formatarSomenteData(DateTime data) {
  String dois(int numero) => numero.toString().padLeft(2, '0');
  return '${dois(data.day)}/${dois(data.month)}/${data.year}';
}

String _rotuloDataHora(dynamic valor) {
  if (valor is! Timestamp) return 'Data não informada';
  final data = valor.toDate();
  final hoje = DateTime.now();
  final amanha = hoje.add(const Duration(days: 1));
  String dois(int numero) => numero.toString().padLeft(2, '0');
  final hora = '${dois(data.hour)}:${dois(data.minute)}';
  if (_mesmoDia(data, hoje)) return 'Hoje às $hora';
  if (_mesmoDia(data, amanha)) return 'Amanhã às $hora';
  return '${_formatarSomenteData(data)} às $hora';
}
