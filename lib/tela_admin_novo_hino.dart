import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'servico_busca_hinos.dart';

class TelaAdminNovoHino extends StatefulWidget {
  const TelaAdminNovoHino({super.key, required this.nomeUsuario});

  final String nomeUsuario;

  @override
  State<TelaAdminNovoHino> createState() => _TelaAdminNovoHinoState();
}

class _TelaAdminNovoHinoState extends State<TelaAdminNovoHino> {
  static const _tons = [
    'C',
    'Cm',
    'C#',
    'C#m',
    'Db',
    'Dbm',
    'D',
    'Dm',
    'D#',
    'D#m',
    'Eb',
    'Ebm',
    'E',
    'Em',
    'F',
    'Fm',
    'F#',
    'F#m',
    'Gb',
    'Gbm',
    'G',
    'Gm',
    'G#',
    'G#m',
    'Ab',
    'Abm',
    'A',
    'Am',
    'A#',
    'A#m',
    'Bb',
    'Bbm',
    'B',
    'Bm',
  ];

  final _formulario = GlobalKey<FormState>();
  final _numeroController = TextEditingController();
  final _tituloController = TextEditingController();
  final _letraController = TextEditingController();

  String _livro = 'VM';
  String _tom = 'C';
  bool _salvando = false;
  bool _carregandoAssuntos = true;
  List<String> _assuntosDisponiveis = [];
  final Set<String> _assuntosSelecionados = {};
  String? _erro;
  String? _erroAssuntos;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _numeroController,
      _tituloController,
      _letraController,
    ]) {
      controller.addListener(_atualizarPrevia);
    }
    _carregarAssuntos();
  }

  @override
  void dispose() {
    for (final controller in [
      _numeroController,
      _tituloController,
      _letraController,
    ]) {
      controller
        ..removeListener(_atualizarPrevia)
        ..dispose();
    }
    super.dispose();
  }

  void _atualizarPrevia() {
    if (mounted) setState(() {});
  }

  int? get _numero => int.tryParse(_numeroController.text.trim());

  String get _numeroFormatado =>
      _numero == null ? '---' : _numero.toString().padLeft(3, '0');

  String get _hinoId => '${_livro}_$_numeroFormatado';

  List<String> get _assuntos {
    final assuntos = _assuntosSelecionados.toList()..sort();
    return assuntos;
  }

  List<String> get _estrofes => _letraController.text
      .replaceAll('\r\n', '\n')
      .split(RegExp(r'\n\s*\n'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  String? _validarNumero(String? valor) {
    final numero = int.tryParse(valor?.trim() ?? '');
    if (numero == null || numero <= 0) {
      return 'Informe um número válido.';
    }
    if (numero > 999) {
      return 'O número deve estar entre 1 e 999.';
    }
    return null;
  }

  String? _obrigatorio(String? valor) {
    return valor?.trim().isNotEmpty == true ? null : 'Campo obrigatório.';
  }

  Future<void> _carregarAssuntos() async {
    if (mounted) {
      setState(() {
        _carregandoAssuntos = true;
        _erroAssuntos = null;
      });
    }
    try {
      final consulta = await FirebaseFirestore.instance
          .collection('hinos_v2')
          .get();
      final assuntos = <String>{};
      for (final documento in consulta.docs) {
        final valores = documento.data()['assuntos'];
        if (valores is Iterable) {
          for (final valor in valores) {
            final assunto = valor.toString().trim().toUpperCase();
            if (assunto.isNotEmpty) assuntos.add(assunto);
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _assuntosDisponiveis = assuntos.toList()..sort();
        _carregandoAssuntos = false;
        _erroAssuntos = null;
      });
    } on FirebaseException catch (excecao) {
      if (!mounted) return;
      setState(() {
        _carregandoAssuntos = false;
        _erroAssuntos =
            'Não foi possível carregar os assuntos: '
            '${excecao.message ?? excecao.code}';
      });
    } catch (excecao) {
      if (!mounted) return;
      setState(() {
        _carregandoAssuntos = false;
        _erroAssuntos = 'Não foi possível carregar os assuntos: $excecao';
      });
    }
  }

  Future<void> _selecionarAssuntos() async {
    final selecionados = Set<String>.from(_assuntosSelecionados);
    var filtro = '';
    final resultado = await showDialog<Set<String>>(
      context: context,
      builder: (contextoDialogo) => StatefulBuilder(
        builder: (context, atualizarDialogo) {
          final assuntosFiltrados = _assuntosDisponiveis
              .where((assunto) => assunto.contains(filtro))
              .toList();
          return AlertDialog(
            title: const Text('Selecionar assuntos'),
            content: SizedBox(
              width: 520,
              height: 520,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Pesquisar assunto',
                    ),
                    onChanged: (valor) => atualizarDialogo(
                      () => filtro = valor.trim().toUpperCase(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: assuntosFiltrados.isEmpty
                        ? const Center(
                            child: Text('Nenhum assunto encontrado.'),
                          )
                        : ListView.builder(
                            itemCount: assuntosFiltrados.length,
                            itemBuilder: (context, indice) {
                              final assunto = assuntosFiltrados[indice];
                              return CheckboxListTile(
                                value: selecionados.contains(assunto),
                                title: Text(assunto),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                onChanged: (marcado) => atualizarDialogo(() {
                                  if (marcado == true) {
                                    selecionados.add(assunto);
                                  } else {
                                    selecionados.remove(assunto);
                                  }
                                }),
                              );
                            },
                          ),
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
                onPressed: () => Navigator.pop(contextoDialogo, selecionados),
                child: Text('Confirmar (${selecionados.length})'),
              ),
            ],
          );
        },
      ),
    );
    if (resultado == null || !mounted) return;
    setState(() {
      _assuntosSelecionados
        ..clear()
        ..addAll(resultado);
      _erro = null;
    });
  }

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();
    setState(() => _erro = null);
    if (!(_formulario.currentState?.validate() ?? false)) return;
    if (_assuntos.isEmpty) {
      setState(() => _erro = 'Informe pelo menos um assunto.');
      return;
    }
    if (_estrofes.isEmpty) {
      setState(() => _erro = 'Informe pelo menos uma estrofe.');
      return;
    }

    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) {
      setState(() => _erro = 'A sessão não está mais ativa.');
      return;
    }

    setState(() => _salvando = true);
    final titulo = _tituloController.text.trim();
    final dados = <String, dynamic>{
      'id': _hinoId,
      'obraId': 'obra_$_hinoId',
      'livro': _livro,
      'numero': _numero,
      'numeroFormatado': _numeroFormatado,
      'titulo': titulo,
      'tom': _tom,
      'assuntos': _assuntos,
      'estrofes': _estrofes,
      'tituloNormalizado': ServicoBuscaHinos.normalizar(titulo),
      'textoBusca': ServicoBuscaHinos.normalizar(_estrofes.join(' ')),
      'criadoPorUid': usuario.uid,
      'criadoPorNome': widget.nomeUsuario,
      'criadoEm': FieldValue.serverTimestamp(),
    };

    try {
      final banco = FirebaseFirestore.instance;
      final referencia = banco.collection('hinos_v2').doc(_hinoId);
      final historico = banco.collection('historico_hinos').doc();

      final cadastrado = await banco.runTransaction<bool>((transacao) async {
        final existente = await transacao.get(referencia);
        if (existente.exists) {
          return false;
        }
        transacao.set(referencia, dados);
        transacao.set(historico, {
          'hinoId': _hinoId,
          'hinoLivro': _livro,
          'hinoNumeroFormatado': _numeroFormatado,
          'hinoTitulo': titulo,
          'campo': 'cadastro',
          'valorAnterior': null,
          'valorNovo': dados,
          'alteradoPorUid': usuario.uid,
          'alteradoPorNome': widget.nomeUsuario,
          'alteradoEm': FieldValue.serverTimestamp(),
        });
        return true;
      });

      if (!cadastrado) {
        if (mounted) {
          setState(
            () => _erro = 'O hino $_hinoId já existe e não foi alterado.',
          );
        }
        return;
      }

      if (!mounted) return;
      final idCriado = _hinoId;
      _limparFormulario();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hino $idCriado cadastrado com sucesso.')),
      );
    } on FirebaseException catch (excecao) {
      if (mounted) {
        setState(
          () => _erro =
              'Não foi possível cadastrar: ${excecao.message ?? excecao.code}',
        );
      }
    } catch (excecao) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível cadastrar o hino: $excecao');
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _limparFormulario() {
    _formulario.currentState?.reset();
    _numeroController.clear();
    _tituloController.clear();
    _letraController.clear();
    setState(() {
      _livro = 'VM';
      _tom = 'C';
      _assuntosSelecionados.clear();
      _erro = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Novo hino',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Cadastre e confira a prévia antes de gravar no Firestore.',
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 520, child: _formularioCadastro(context)),
              const VerticalDivider(width: 1),
              Expanded(child: _previa(context)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _formularioCadastro(BuildContext context) {
    return Form(
      key: _formulario,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _livro,
                  decoration: const InputDecoration(labelText: 'Hinário'),
                  items: const [
                    DropdownMenuItem(value: 'CC', child: Text('CC')),
                    DropdownMenuItem(value: 'VM', child: Text('VM')),
                  ],
                  onChanged: _salvando
                      ? null
                      : (valor) => setState(() => _livro = valor ?? 'VM'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _numeroController,
                  enabled: !_salvando,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Número',
                    hintText: '436',
                  ),
                  validator: _validarNumero,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _tom,
                  decoration: const InputDecoration(labelText: 'Tom'),
                  items: [
                    for (final tom in _tons)
                      DropdownMenuItem(value: tom, child: Text(tom)),
                  ],
                  onChanged: _salvando
                      ? null
                      : (valor) => setState(() => _tom = valor ?? 'C'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _tituloController,
            enabled: !_salvando,
            decoration: const InputDecoration(labelText: 'Título'),
            validator: _obrigatorio,
          ),
          const SizedBox(height: 16),
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'Assuntos',
              helperText: _assuntos.isEmpty
                  ? 'Selecione pelo menos um assunto existente.'
                  : '${_assuntos.length} assunto(s) selecionado(s).',
              errorText: _erroAssuntos,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_assuntos.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final assunto in _assuntos)
                          InputChip(
                            label: Text(assunto),
                            onDeleted: _salvando
                                ? null
                                : () => setState(
                                    () => _assuntosSelecionados.remove(assunto),
                                  ),
                          ),
                      ],
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed:
                      _salvando ||
                          _carregandoAssuntos ||
                          _assuntosDisponiveis.isEmpty
                      ? null
                      : _selecionarAssuntos,
                  icon: _carregandoAssuntos
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.checklist),
                  label: Text(
                    _carregandoAssuntos
                        ? 'Carregando assuntos...'
                        : 'Selecionar assuntos',
                  ),
                ),
                if (_erroAssuntos != null)
                  TextButton.icon(
                    onPressed: _carregarAssuntos,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _letraController,
            enabled: !_salvando,
            minLines: 12,
            maxLines: 24,
            decoration: const InputDecoration(
              labelText: 'Letra',
              alignLabelWithHint: true,
              hintText:
                  'Digite a primeira estrofe...\n\nDigite a segunda estrofe...',
              helperText: 'Use uma linha em branco para separar as estrofes.',
            ),
            validator: _obrigatorio,
          ),
          if (_erro != null) ...[
            const SizedBox(height: 16),
            Text(
              _erro!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _salvando ? null : _salvar,
                  icon: _salvando
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(_salvando ? 'Cadastrando...' : 'Cadastrar hino'),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _salvando ? null : _limparFormulario,
                child: const Text('Limpar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previa(BuildContext context) {
    final titulo = _tituloController.text.trim();
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        Text('Prévia', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 20),
        Text(
          '$_livro $_numeroFormatado',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        Text(
          titulo.isEmpty ? 'Título do hino' : titulo,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text('Tom: $_tom'),
        if (_assuntos.isNotEmpty) ...[
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final assunto in _assuntos) Chip(label: Text(assunto)),
            ],
          ),
        ],
        const SizedBox(height: 28),
        if (_estrofes.isEmpty)
          Text(
            'A letra aparecerá aqui.',
            style: Theme.of(context).textTheme.bodyLarge,
          )
        else
          for (var indice = 0; indice < _estrofes.length; indice++) ...[
            Text(
              _estrofes[indice],
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
            if (indice < _estrofes.length - 1) const SizedBox(height: 24),
          ],
      ],
    );
  }
}
