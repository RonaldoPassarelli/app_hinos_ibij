import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'servico_busca_hinos.dart';

const _toleranciaCultoEmAndamento = Duration(hours: 2);

bool _cultoAindaPlanejado(DateTime dataHora) {
  final limite = dataHora.add(_toleranciaCultoEmAndamento);
  return DateTime.now().isBefore(limite);
}

class TelaCultos extends StatefulWidget {
  const TelaCultos({super.key, required this.podeEditar});

  final bool podeEditar;

  @override
  State<TelaCultos> createState() => _TelaCultosState();
}

class _TelaCultosState extends State<TelaCultos> {
  final _firestore = FirebaseFirestore.instance;
  var _filtroStatus = 'planejado';
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

  CollectionReference<Map<String, dynamic>> get _cultos =>
      _firestore.collection('cultos_v2');

  Future<void> _abrirNovoCulto() async {
    final tituloController = TextEditingController();
    var dataEscolhida = DateTime.now().add(const Duration(days: 1));
    dataEscolhida = DateTime(
      dataEscolhida.year,
      dataEscolhida.month,
      dataEscolhida.day,
      19,
    );

    final resultado = await showDialog<_DadosNovoCulto>(
      context: context,
      builder: (contextoDialogo) {
        return StatefulBuilder(
          builder: (context, atualizarDialogo) {
            return AlertDialog(
              title: const Text('Novo culto'),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: tituloController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Título ou descrição',
                        hintText: 'Ex.: Culto de domingo à noite',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_month),
                      title: const Text('Data'),
                      subtitle: Text(_formatarData(dataEscolhida)),
                      onTap: () async {
                        final data = await showDatePicker(
                          context: context,
                          initialDate: dataEscolhida,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
                        );
                        if (data == null) return;
                        atualizarDialogo(() {
                          dataEscolhida = DateTime(
                            data.year,
                            data.month,
                            data.day,
                            dataEscolhida.hour,
                            dataEscolhida.minute,
                          );
                        });
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule),
                      title: const Text('Horário'),
                      subtitle: Text(_formatarHora(dataEscolhida)),
                      onTap: () async {
                        final horario = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(dataEscolhida),
                        );
                        if (horario == null) return;
                        atualizarDialogo(() {
                          dataEscolhida = DateTime(
                            dataEscolhida.year,
                            dataEscolhida.month,
                            dataEscolhida.day,
                            horario.hour,
                            horario.minute,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(contextoDialogo),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final titulo = tituloController.text.trim();
                    if (titulo.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Informe um título para o culto.'),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(
                      contextoDialogo,
                      _DadosNovoCulto(titulo: titulo, dataHora: dataEscolhida),
                    );
                  },
                  child: const Text('Criar culto'),
                ),
              ],
            );
          },
        );
      },
    );

    tituloController.dispose();
    if (resultado == null || !mounted) return;

    try {
      await _cultos.add({
        'titulo': resultado.titulo,
        'dataHora': Timestamp.fromDate(resultado.dataHora),
        'observacoes': '',
        'status': 'planejado',
        'criadoEm': FieldValue.serverTimestamp(),
        'atualizadoEm': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Culto criado com sucesso.')),
      );
    } on FirebaseException catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao criar culto: ${erro.message}')),
      );
    }
  }

  static String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    return '$dia/$mes/${data.year}';
  }

  static String _formatarHora(DateTime data) {
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');
    return '$hora:$minuto';
  }

  static String _statusCalculado(
    Map<String, dynamic> dados,
    DateTime dataHora,
  ) {
    if (dados['status'] == 'cancelado') return 'cancelado';
    return _cultoAindaPlanejado(dataHora) ? 'planejado' : 'realizado';
  }

  static String _rotuloStatus(String status) => switch (status) {
    'planejado' => 'Planejado',
    'realizado' => 'Realizado',
    'cancelado' => 'Cancelado',
    _ => status,
  };

  static IconData _iconeStatus(String status) => switch (status) {
    'planejado' => Icons.schedule,
    'realizado' => Icons.check_circle_outline,
    'cancelado' => Icons.event_busy,
    _ => Icons.event,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cultos'),
        actions: widget.podeEditar
            ? [
                IconButton(
                  tooltip: 'Novo culto',
                  onPressed: _abrirNovoCulto,
                  icon: const Icon(Icons.add),
                ),
              ]
            : null,
      ),
      floatingActionButton: widget.podeEditar
          ? FloatingActionButton.extended(
              onPressed: _abrirNovoCulto,
              icon: const Icon(Icons.add),
              label: const Text('Novo culto'),
            )
          : null,
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'todos', label: Text('Todos')),
                ButtonSegment(value: 'planejado', label: Text('Planejados')),
                ButtonSegment(value: 'realizado', label: Text('Realizados')),
                ButtonSegment(value: 'cancelado', label: Text('Cancelados')),
              ],
              selected: {_filtroStatus},
              onSelectionChanged: (selecao) {
                setState(() => _filtroStatus = selecao.first);
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _cultos.orderBy('dataHora').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Erro ao carregar cultos: ${snapshot.error}'),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final documentos = (snapshot.data?.docs ?? []).where((
                  documento,
                ) {
                  if (_filtroStatus == 'todos') return true;
                  final dados = documento.data();
                  final dataHora = (dados['dataHora'] as Timestamp).toDate();
                  return _statusCalculado(dados, dataHora) == _filtroStatus;
                }).toList();
                if (documentos.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_note, size: 64),
                          SizedBox(height: 16),
                          Text(
                            'Nenhum culto cadastrado.',
                            style: TextStyle(fontSize: 18),
                          ),
                          SizedBox(height: 8),
                          Text('Nenhum culto encontrado neste filtro.'),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: documentos.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, indice) {
                    final documento = documentos[indice];
                    final dados = documento.data();
                    final timestamp = dados['dataHora'] as Timestamp;
                    final dataHora = timestamp.toDate();
                    final status = _statusCalculado(dados, dataHora);
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(_iconeStatus(status)),
                        ),
                        title: Text(dados['titulo'] as String),
                        subtitle: Text(
                          '${_formatarData(dataHora)} às ${_formatarHora(dataHora)} · ${_rotuloStatus(status)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TelaDetalheCulto(
                                cultoId: documento.id,
                                titulo: dados['titulo'] as String,
                                dataHora: dataHora,
                                observacoes:
                                    (dados['observacoes'] as String?) ?? '',
                                cancelado: dados['status'] == 'cancelado',
                                podeEditar: widget.podeEditar,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DadosNovoCulto {
  const _DadosNovoCulto({required this.titulo, required this.dataHora});

  final String titulo;
  final DateTime dataHora;
}

class TelaDetalheCulto extends StatefulWidget {
  const TelaDetalheCulto({
    super.key,
    required this.cultoId,
    required this.titulo,
    required this.dataHora,
    required this.observacoes,
    required this.cancelado,
    required this.podeEditar,
  });

  final String cultoId;
  final String titulo;
  final DateTime dataHora;
  final String observacoes;
  final bool cancelado;
  final bool podeEditar;

  @override
  State<TelaDetalheCulto> createState() => _TelaDetalheCultoState();
}

class _TelaDetalheCultoState extends State<TelaDetalheCulto> {
  final _firestore = FirebaseFirestore.instance;
  var _processando = false;
  late String _tituloAtual;
  late DateTime _dataHoraAtual;
  late String _observacoesAtuais;
  late bool _cancelado;
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    _tituloAtual = widget.titulo;
    _dataHoraAtual = widget.dataHora;
    _observacoesAtuais = widget.observacoes;
    _cancelado = widget.cancelado;
    _relogio = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _relogio?.cancel();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> get _itens =>
      _firestore.collection('itens_culto_v2');

  Future<void> _iniciarAdicao() async {
    final escolha = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const TelaSelecionarHinoCulto()),
    );
    if (escolha == null || !mounted) return;

    setState(() => _processando = true);
    try {
      final documento = await _firestore
          .collection('hinos_v2')
          .doc(escolha)
          .get();
      if (!documento.exists) {
        _mostrarMensagem('Hino $escolha não encontrado.');
        return;
      }

      final hino = documento.data()!;
      final itensAtuais = await _itens
          .where('cultoId', isEqualTo: widget.cultoId)
          .get();
      final jaAdicionado = itensAtuais.docs.any(
        (doc) => doc.data()['obraId'] == hino['obraId'],
      );
      if (jaAdicionado) {
        _mostrarMensagem('Esta música já foi adicionada ao culto.');
        return;
      }

      final correspondentesConsulta = await _firestore
          .collection('hinos_v2')
          .where('obraId', isEqualTo: hino['obraId'])
          .get();
      final correspondentes = correspondentesConsulta.docs
          .where((doc) => doc.id != hino['id'])
          .map((doc) => doc.data())
          .toList();

      final usosAnteriores = await _itens
          .where('obraId', isEqualTo: hino['obraId'])
          .get();
      final anteriores =
          usosAnteriores.docs.map((doc) => doc.data()).where((uso) {
            final data = (uso['dataCulto'] as Timestamp).toDate();
            return data.isBefore(_dataHoraAtual);
          }).toList()..sort((a, b) {
            final dataA = (a['dataCulto'] as Timestamp).toDate();
            final dataB = (b['dataCulto'] as Timestamp).toDate();
            return dataB.compareTo(dataA);
          });

      if (!mounted) return;
      final confirmacao = await _dialogoConfirmarHino(
        hino: hino,
        correspondentes: correspondentes,
        ultimoUso: anteriores.isEmpty ? null : anteriores.first,
      );
      if (confirmacao == null || !mounted) return;

      final maiorOrdem = itensAtuais.docs.fold<int>(0, (maior, doc) {
        final ordem = (doc.data()['ordem'] as num?)?.toInt() ?? 0;
        return ordem > maior ? ordem : maior;
      });

      await _itens.add({
        'cultoId': widget.cultoId,
        'hinoId': hino['id'],
        'obraId': hino['obraId'],
        'livro': hino['livro'],
        'numero': hino['numero'],
        'numeroFormatado': hino['numeroFormatado'],
        'titulo': hino['titulo'],
        'tomOriginal': hino['tom'],
        'tomEscolhido': confirmacao.tomEscolhido,
        'ordem': maiorOrdem + 1,
        'dataCulto': Timestamp.fromDate(_dataHoraAtual),
        'correspondentes': correspondentes
            .map(
              (outro) => {
                'id': outro['id'],
                'livro': outro['livro'],
                'numeroFormatado': outro['numeroFormatado'],
                'titulo': outro['titulo'],
                'tom': outro['tom'],
              },
            )
            .toList(),
        'adicionadoEm': FieldValue.serverTimestamp(),
      });
      _mostrarMensagem('Hino adicionado ao culto.');
    } on FirebaseException catch (erro) {
      _mostrarMensagem('Erro do Firebase: ${erro.message ?? erro.code}');
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<_ConfirmacaoHino?> _dialogoConfirmarHino({
    required Map<String, dynamic> hino,
    required List<Map<String, dynamic>> correspondentes,
    required Map<String, dynamic>? ultimoUso,
  }) async {
    final tomController = TextEditingController(text: hino['tom'] as String);
    final resultado = await showDialog<_ConfirmacaoHino>(
      context: context,
      builder: (contextoDialogo) {
        return AlertDialog(
          title: const Text('Confirmar hino'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${hino['livro']} ${hino['numeroFormatado']} — ${hino['titulo']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('Tom original: ${hino['tom']}'),
                  if (correspondentes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Correspondente:'),
                    ...correspondentes.map(
                      (outro) => Text(
                        '${outro['livro']} ${outro['numeroFormatado']} — ${outro['titulo']} — tom ${outro['tom']}',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (ultimoUso == null)
                    const Text('Último uso: nenhum registro anterior.')
                  else
                    Text(
                      'Último uso: ${_formatarData((ultimoUso['dataCulto'] as Timestamp).toDate())} — '
                      '${ultimoUso['livro']} ${ultimoUso['numeroFormatado']} — '
                      'tom ${ultimoUso['tomEscolhido']}',
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: tomController,
                    decoration: const InputDecoration(
                      labelText: 'Tom escolhido para este culto',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contextoDialogo),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final tom = tomController.text.trim();
                if (tom.isEmpty) return;
                Navigator.pop(
                  contextoDialogo,
                  _ConfirmacaoHino(tomEscolhido: tom),
                );
              },
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
    tomController.dispose();
    return resultado;
  }

  void _mostrarMensagem(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _editarCulto() async {
    final tituloController = TextEditingController(text: _tituloAtual);
    final observacoesController = TextEditingController(
      text: _observacoesAtuais,
    );
    var novaDataHora = _dataHoraAtual;
    var novoCancelado = _cancelado;

    final edicao = await showDialog<_DadosEdicaoCulto>(
      context: context,
      builder: (contextoDialogo) {
        return StatefulBuilder(
          builder: (context, atualizarDialogo) {
            return AlertDialog(
              title: const Text('Editar culto'),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: tituloController,
                      decoration: const InputDecoration(
                        labelText: 'Título ou descrição',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: observacoesController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Observações',
                        hintText: 'Opcional',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_month),
                      title: const Text('Data'),
                      subtitle: Text(_formatarData(novaDataHora)),
                      onTap: () async {
                        final data = await showDatePicker(
                          context: context,
                          initialDate: novaDataHora,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 3650),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
                        );
                        if (data == null) return;
                        atualizarDialogo(() {
                          novaDataHora = DateTime(
                            data.year,
                            data.month,
                            data.day,
                            novaDataHora.hour,
                            novaDataHora.minute,
                          );
                        });
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Culto cancelado'),
                      subtitle: const Text(
                        'Use somente quando o culto realmente não acontecer.',
                      ),
                      value: novoCancelado,
                      onChanged: (valor) {
                        atualizarDialogo(() => novoCancelado = valor);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule),
                      title: const Text('Horário'),
                      subtitle: Text(_formatarHora(novaDataHora)),
                      onTap: () async {
                        final horario = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(novaDataHora),
                        );
                        if (horario == null) return;
                        atualizarDialogo(() {
                          novaDataHora = DateTime(
                            novaDataHora.year,
                            novaDataHora.month,
                            novaDataHora.day,
                            horario.hour,
                            horario.minute,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(contextoDialogo),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final titulo = tituloController.text.trim();
                    if (titulo.isEmpty) return;
                    Navigator.pop(
                      contextoDialogo,
                      _DadosEdicaoCulto(
                        titulo: titulo,
                        dataHora: novaDataHora,
                        observacoes: observacoesController.text.trim(),
                        cancelado: novoCancelado,
                      ),
                    );
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
    tituloController.dispose();
    observacoesController.dispose();
    if (edicao == null || !mounted) return;

    if (edicao.cancelado && !_cancelado) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (contextoDialogo) => AlertDialog(
          title: const Text('Cancelar culto?'),
          content: const Text(
            'O culto continuará registrado, mas aparecerá como cancelado.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contextoDialogo, false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(contextoDialogo, true),
              child: const Text('Confirmar cancelamento'),
            ),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;
    }

    setState(() => _processando = true);
    try {
      final itensDoCulto = await _itens
          .where('cultoId', isEqualTo: widget.cultoId)
          .get();
      final lote = _firestore.batch();
      final referenciaCulto = _firestore
          .collection('cultos_v2')
          .doc(widget.cultoId);
      final timestamp = Timestamp.fromDate(edicao.dataHora);

      lote.update(referenciaCulto, {
        'titulo': edicao.titulo,
        'dataHora': timestamp,
        'observacoes': edicao.observacoes,
        'status': edicao.cancelado ? 'cancelado' : 'planejado',
        'atualizadoEm': FieldValue.serverTimestamp(),
      });
      for (final item in itensDoCulto.docs) {
        lote.update(item.reference, {'dataCulto': timestamp});
      }
      await lote.commit();

      if (!mounted) return;
      setState(() {
        _tituloAtual = edicao.titulo;
        _dataHoraAtual = edicao.dataHora;
        _observacoesAtuais = edicao.observacoes;
        _cancelado = edicao.cancelado;
      });
      _mostrarMensagem('Culto atualizado com sucesso.');
    } on FirebaseException catch (erro) {
      _mostrarMensagem('Erro ao atualizar culto: ${erro.message ?? erro.code}');
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _removerItem(String itemId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover hino'),
        content: const Text('Deseja remover este hino do culto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmar == true) await _itens.doc(itemId).delete();
  }

  Future<void> _editarTom(
    DocumentReference<Map<String, dynamic>> referencia,
    String tomAtual,
  ) async {
    final controller = TextEditingController(text: tomAtual);
    final novoTom = await showDialog<String>(
      context: context,
      builder: (contextoDialogo) => AlertDialog(
        title: const Text('Editar tom escolhido'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tom',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contextoDialogo),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final tom = controller.text.trim();
              if (tom.isNotEmpty) Navigator.pop(contextoDialogo, tom);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (novoTom == null) return;
    await referencia.update({'tomEscolhido': novoTom});
    _mostrarMensagem('Tom atualizado.');
  }

  Future<void> _reordenar(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documentos,
    int indiceAntigo,
    int indiceNovo,
  ) async {
    if (!widget.podeEditar) return;
    if (indiceNovo == indiceAntigo) return;

    final novaLista = [...documentos];
    final movido = novaLista.removeAt(indiceAntigo);
    novaLista.insert(indiceNovo, movido);

    setState(() => _processando = true);
    try {
      final lote = _firestore.batch();
      for (var indice = 0; indice < novaLista.length; indice++) {
        lote.update(novaLista[indice].reference, {'ordem': indice + 1});
      }
      await lote.commit();
      _mostrarMensagem('Ordem dos hinos atualizada.');
    } on FirebaseException catch (erro) {
      _mostrarMensagem('Erro ao reordenar: ${erro.message ?? erro.code}');
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  static String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    return '$dia/$mes/${data.year}';
  }

  static String _formatarHora(DateTime data) {
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');
    return '$hora:$minuto';
  }

  String get _statusAtual {
    if (_cancelado) return 'Cancelado';
    return _cultoAindaPlanejado(_dataHoraAtual) ? 'Planejado' : 'Realizado';
  }

  IconData get _iconeStatusAtual {
    if (_cancelado) return Icons.event_busy;
    return _cultoAindaPlanejado(_dataHoraAtual)
        ? Icons.schedule
        : Icons.check_circle_outline;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tituloAtual),
        actions: widget.podeEditar
            ? [
                IconButton(
                  tooltip: 'Editar culto',
                  onPressed: _processando ? null : _editarCulto,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ]
            : null,
      ),
      floatingActionButton: widget.podeEditar
          ? FloatingActionButton.extended(
              onPressed: _processando ? null : _iniciarAdicao,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar hino'),
            )
          : null,
      body: Column(
        children: [
          ListTile(
            leading: Icon(_iconeStatusAtual),
            title: Text(_formatarData(_dataHoraAtual)),
            subtitle: Text('${_formatarHora(_dataHoraAtual)} · $_statusAtual'),
          ),
          if (_observacoesAtuais.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.notes),
              title: const Text('Observações'),
              subtitle: Text(_observacoesAtuais),
            ),
          const Divider(height: 1),
          if (_processando) const LinearProgressIndicator(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _itens
                  .where('cultoId', isEqualTo: widget.cultoId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Erro: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final documentos = [...?snapshot.data?.docs]
                  ..sort((a, b) {
                    final ordemA = (a.data()['ordem'] as num).toInt();
                    final ordemB = (b.data()['ordem'] as num).toInt();
                    return ordemA.compareTo(ordemB);
                  });
                if (documentos.isEmpty) {
                  return const Center(
                    child: Text('Nenhum hino adicionado a este culto.'),
                  );
                }
                return ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  buildDefaultDragHandles: false,
                  itemCount: documentos.length,
                  onReorderItem: (antigo, novo) =>
                      _reordenar(documentos, antigo, novo),
                  itemBuilder: (context, indice) {
                    final documento = documentos[indice];
                    final item = documento.data();
                    final correspondentes = List<Map<String, dynamic>>.from(
                      item['correspondentes'] as List<dynamic>,
                    );
                    return Card(
                      key: ValueKey(documento.id),
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${item['ordem']}')),
                        title: Text(
                          '${item['livro']} ${item['numeroFormatado']} — ${item['titulo']}',
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tom escolhido: ${item['tomEscolhido']}'),
                            if (correspondentes.isNotEmpty)
                              Text(
                                'Correspondente: ${correspondentes.map((c) => '${c['livro']} ${c['numeroFormatado']} (${c['tom']})').join(', ')}',
                              ),
                          ],
                        ),
                        trailing: widget.podeEditar
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PopupMenuButton<String>(
                                    tooltip: 'Opções',
                                    onSelected: (opcao) {
                                      if (opcao == 'tom') {
                                        _editarTom(
                                          documento.reference,
                                          item['tomEscolhido'] as String,
                                        );
                                      } else if (opcao == 'remover') {
                                        _removerItem(documento.id);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'tom',
                                        child: ListTile(
                                          leading: Icon(Icons.music_note),
                                          title: Text('Editar tom'),
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'remover',
                                        child: ListTile(
                                          leading: Icon(Icons.delete_outline),
                                          title: Text('Remover'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  ReorderableDragStartListener(
                                    index: indice,
                                    child: const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Icon(Icons.drag_handle),
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmacaoHino {
  const _ConfirmacaoHino({required this.tomEscolhido});

  final String tomEscolhido;
}

class _DadosEdicaoCulto {
  const _DadosEdicaoCulto({
    required this.titulo,
    required this.dataHora,
    required this.observacoes,
    required this.cancelado,
  });

  final String titulo;
  final DateTime dataHora;
  final String observacoes;
  final bool cancelado;
}

class TelaSelecionarHinoCulto extends StatefulWidget {
  const TelaSelecionarHinoCulto({super.key});

  @override
  State<TelaSelecionarHinoCulto> createState() =>
      _TelaSelecionarHinoCultoState();
}

class _TelaSelecionarHinoCultoState extends State<TelaSelecionarHinoCulto> {
  static const _assuntos = [
    'AMOR DE CRISTO/DEUS',
    'ARREPENDIMENTO E PERDÃO',
    'CONSAGRAÇÃO',
    'CONVITE A SALVAÇÃO',
    'CRIANÇAS',
    'CRUZ DE CRISTO',
    'CUIDADO DE DEUS',
    'CÉU',
    'DIREÇÃO DE DEUS',
    'ESPÍRITO SANTO',
    'EVANGELISMO',
    'FAMILIA E CASAMENTO',
    'FE E CONFIANÇA',
    'FUNERAIS',
    'GRATIDÃO',
    'GRAÇA DE DEUS',
    'IGREJA',
    'JESUS CRISTO',
    'LOUVOR E ADORAÇÃO',
    'MISSÕES',
    'MOCIDADE',
    'NATAL',
    'OBEDIÊNCIA',
    'ORAÇÃO',
    'PALAVRA DE DEUS',
    'PAZ',
    'PAZ E ALEGRIA',
    'PODER E MAJESTADE DE DEUS',
    'PÁTRIOS',
    'RESSURREIÇÃO DE CRISTO',
    'SALVAÇÃO',
    'SANGUE DE CRISTO',
    'SAUDAÇÕES DESPEDIDAS',
    'SEGUNDA VINDA DE CRISTO',
    'SEGURANÇA',
    'SERVIÇO CRISTÃO',
    'TESTEMUNHO',
    'VIDA COM CRISTO',
    'VITÓRIA',
  ];

  final _firestore = FirebaseFirestore.instance;
  final _servicoBusca = ServicoBuscaHinos();
  final _numeroController = TextEditingController();
  final _textoController = TextEditingController();

  var _modo = 'numero';
  var _livro = 'CC';
  var _assunto = 'LOUVOR E ADORAÇÃO';
  var _carregando = false;
  String? _mensagem;
  List<_OpcaoHino> _resultados = [];

  @override
  void initState() {
    super.initState();
    _servicoBusca.carregar();
  }

  @override
  void dispose() {
    _numeroController.dispose();
    _textoController.dispose();
    super.dispose();
  }

  String _rotuloAssunto(String assunto) {
    return switch (assunto) {
      'FE E CONFIANÇA' => 'FÉ E CONFIANÇA',
      'FAMILIA E CASAMENTO' => 'FAMÍLIA E CASAMENTO',
      _ => assunto,
    };
  }

  void _limpar() {
    _resultados = [];
    _mensagem = null;
  }

  Future<void> _buscarNumero() async {
    final numero = int.tryParse(_numeroController.text.trim());
    if (numero == null || numero <= 0) {
      setState(() {
        _limpar();
        _mensagem = 'Digite um número válido.';
      });
      return;
    }
    await _executar(() async {
      final id = '${_livro}_${numero.toString().padLeft(3, '0')}';
      final documento = await _firestore.collection('hinos_v2').doc(id).get();
      return documento.exists
          ? [_OpcaoHino.fromMap(documento.data()!)]
          : <_OpcaoHino>[];
    });
  }

  Future<void> _buscarAssunto() async {
    await _executar(() async {
      final consulta = await _firestore
          .collection('hinos_v2')
          .where('assuntos', arrayContains: _assunto)
          .get();
      final itens =
          consulta.docs.map((doc) => _OpcaoHino.fromMap(doc.data())).toList()
            ..sort((a, b) {
              final livro = a.livro.compareTo(b.livro);
              if (livro != 0) return livro;
              return a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
            });
      return itens;
    });
  }

  Future<void> _buscarTexto() async {
    final texto = _textoController.text.trim();
    if (texto.length < 2) {
      setState(() {
        _limpar();
        _mensagem = 'Digite pelo menos dois caracteres.';
      });
      return;
    }
    await _executar(() async {
      final encontrados = await _servicoBusca.buscar(texto);
      return encontrados
          .map(
            (item) => _OpcaoHino(
              id: item.id,
              livro: item.livro,
              numeroFormatado: item.numeroFormatado,
              titulo: item.titulo,
              tom: item.tom,
            ),
          )
          .toList();
    });
  }

  Future<void> _executar(Future<List<_OpcaoHino>> Function() consulta) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _carregando = true;
      _limpar();
    });
    try {
      final resultados = await consulta();
      if (!mounted) return;
      setState(() {
        _resultados = resultados;
        if (resultados.isEmpty) _mensagem = 'Nenhum hino encontrado.';
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() => _mensagem = 'Erro durante a busca: $erro');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escolher hino')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'numero',
                    icon: Icon(Icons.numbers),
                    label: Text('Número'),
                  ),
                  ButtonSegment(
                    value: 'assunto',
                    icon: Icon(Icons.category_outlined),
                    label: Text('Assunto'),
                  ),
                  ButtonSegment(
                    value: 'texto',
                    icon: Icon(Icons.manage_search),
                    label: Text('Texto'),
                  ),
                ],
                selected: {_modo},
                onSelectionChanged: _carregando
                    ? null
                    : (selecao) {
                        setState(() {
                          _modo = selecao.first;
                          _limpar();
                        });
                      },
              ),
              const SizedBox(height: 20),
              if (_modo == 'numero')
                _painelNumero()
              else if (_modo == 'assunto')
                _painelAssunto()
              else
                _painelTexto(),
              if (_carregando) ...[
                const SizedBox(height: 20),
                const Center(child: CircularProgressIndicator()),
              ],
              if (_mensagem != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_mensagem!),
                  ),
                ),
              ],
              if (_resultados.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  '${_resultados.length} hinos encontrados',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ..._resultados.map(
                  (hino) => Card(
                    child: ListTile(
                      title: Text(
                        '${hino.livro} ${hino.numeroFormatado} — ${hino.titulo}',
                      ),
                      subtitle: Text('Tonalidade: ${hino.tom}'),
                      trailing: const Icon(Icons.add_circle_outline),
                      onTap: () => Navigator.pop(context, hino.id),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _painelNumero() {
    return Column(
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'CC', label: Text('Cantor Cristão')),
            ButtonSegment(value: 'VM', label: Text('Voz de Melodia')),
          ],
          selected: {_livro},
          onSelectionChanged: (selecao) =>
              setState(() => _livro = selecao.first),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _numeroController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Número',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _buscarNumero(),
        ),
        const SizedBox(height: 12),
        _botaoBuscar('Buscar por número', _buscarNumero),
      ],
    );
  }

  Widget _painelAssunto() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _assunto,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Assunto',
            border: OutlineInputBorder(),
          ),
          items: _assuntos
              .map(
                (assunto) => DropdownMenuItem(
                  value: assunto,
                  child: Text(_rotuloAssunto(assunto)),
                ),
              )
              .toList(),
          onChanged: (valor) {
            if (valor != null) setState(() => _assunto = valor);
          },
        ),
        const SizedBox(height: 12),
        _botaoBuscar('Buscar por assunto', _buscarAssunto),
      ],
    );
  }

  Widget _painelTexto() {
    return Column(
      children: [
        TextField(
          controller: _textoController,
          decoration: const InputDecoration(
            labelText: 'Título ou trecho da letra',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _buscarTexto(),
        ),
        const SizedBox(height: 12),
        _botaoBuscar('Buscar por texto', _buscarTexto),
      ],
    );
  }

  Widget _botaoBuscar(String texto, VoidCallback acao) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _carregando ? null : acao,
        icon: const Icon(Icons.search),
        label: Text(texto),
      ),
    );
  }
}

class _OpcaoHino {
  const _OpcaoHino({
    required this.id,
    required this.livro,
    required this.numeroFormatado,
    required this.titulo,
    required this.tom,
  });

  factory _OpcaoHino.fromMap(Map<String, dynamic> dados) {
    return _OpcaoHino(
      id: dados['id'] as String,
      livro: dados['livro'] as String,
      numeroFormatado: dados['numeroFormatado'] as String,
      titulo: dados['titulo'] as String,
      tom: dados['tom'] as String,
    );
  }

  final String id;
  final String livro;
  final String numeroFormatado;
  final String titulo;
  final String tom;
}
