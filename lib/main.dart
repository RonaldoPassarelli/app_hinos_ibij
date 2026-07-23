import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'servico_busca_hinos.dart';
import 'tela_acesso.dart';
import 'tela_cultos.dart';
import 'tela_letra_hino.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AppHinos());
}

class AppHinos extends StatelessWidget {
  const AppHinos({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hinos IBIJ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const TelaPrincipal(),
    );
  }
}

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  var _indice = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, autenticacao) {
        final usuario = autenticacao.data;
        if (usuario == null) return _conteudo(false);

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('usuarios')
              .doc(usuario.uid)
              .snapshots(),
          builder: (context, perfil) {
            final dados = perfil.data?.data();
            final podeEditar =
                dados?['ativo'] == true &&
                (dados?['papel'] == 'editor' || dados?['papel'] == 'admin');
            return _conteudo(podeEditar);
          },
        );
      },
    );
  }

  Widget _conteudo(bool podeEditar) {
    return Scaffold(
      body: IndexedStack(
        index: _indice,
        children: [
          const TelaConsultaHinos(),
          TelaCultos(podeEditar: podeEditar),
          const TelaAcesso(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (indice) {
          setState(() => _indice = indice);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music),
            label: 'Hinos',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: 'Cultos',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Acesso',
          ),
        ],
      ),
    );
  }
}

class TelaConsultaHinos extends StatefulWidget {
  const TelaConsultaHinos({super.key});

  @override
  State<TelaConsultaHinos> createState() => _TelaConsultaHinosState();
}

class _TelaConsultaHinosState extends State<TelaConsultaHinos> {
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

  final _numeroController = TextEditingController();
  final _textoController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _servicoBusca = ServicoBuscaHinos();
  final _chaveDetalhes = GlobalKey();
  final _controleRolagem = ScrollController();

  String _modo = 'numero';
  String _livro = 'CC';
  String _assuntoSelecionado = 'LOUVOR E ADORAÇÃO';
  bool _carregando = false;
  String? _mensagem;
  Map<String, dynamic>? _hino;
  List<Map<String, dynamic>> _correspondentes = [];
  List<Map<String, dynamic>> _resultadosAssunto = [];
  List<ResultadoBuscaHino> _resultadosTexto = [];

  @override
  void initState() {
    super.initState();
    _servicoBusca.carregar();
  }

  @override
  void dispose() {
    _numeroController.dispose();
    _textoController.dispose();
    _controleRolagem.dispose();
    super.dispose();
  }

  String _rotuloAssunto(String assunto) {
    return switch (assunto) {
      'FE E CONFIANÇA' => 'FÉ E CONFIANÇA',
      'FAMILIA E CASAMENTO' => 'FAMÍLIA E CASAMENTO',
      _ => assunto,
    };
  }

  void _limparResultados() {
    _mensagem = null;
    _hino = null;
    _correspondentes = [];
    _resultadosAssunto = [];
    _resultadosTexto = [];
  }

  Future<void> _buscarPorNumero() async {
    FocusScope.of(context).unfocus();
    final numero = int.tryParse(_numeroController.text.trim());
    if (numero == null || numero <= 0) {
      setState(() {
        _limparResultados();
        _mensagem = 'Digite um número de hino válido.';
      });
      return;
    }

    final numeroFormatado = numero.toString().padLeft(3, '0');
    await _carregarPorId('${_livro}_$numeroFormatado');
  }

  Future<void> _carregarPorId(String id) async {
    setState(() {
      _carregando = true;
      _mensagem = null;
      _hino = null;
      _correspondentes = [];
    });

    try {
      final documento = await _firestore.collection('hinos_v2').doc(id).get();
      if (!documento.exists) {
        if (!mounted) return;
        setState(() {
          _mensagem = 'Hino $id não encontrado.';
        });
        return;
      }
      await _carregarDetalhes(documento.data()!);
    } on FirebaseException catch (erro) {
      if (!mounted) return;
      setState(() {
        _mensagem = 'Erro do Firebase: ${erro.message ?? erro.code}';
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _mensagem = 'Não foi possível realizar a consulta: $erro';
      });
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  Future<void> _carregarDetalhes(Map<String, dynamic> hino) async {
    final consulta = await _firestore
        .collection('hinos_v2')
        .where('obraId', isEqualTo: hino['obraId'])
        .get();

    final correspondentes = consulta.docs
        .where((doc) => doc.id != hino['id'])
        .map((doc) => doc.data())
        .toList();

    if (!mounted) return;
    setState(() {
      _hino = hino;
      _correspondentes = correspondentes;
      _mensagem = correspondentes.isEmpty
          ? 'Este hino não possui correspondente no outro livro.'
          : null;
    });
  }

  Future<void> _buscarPorAssunto() async {
    setState(() {
      _carregando = true;
      _limparResultados();
    });

    try {
      final consulta = await _firestore
          .collection('hinos_v2')
          .where('assuntos', arrayContains: _assuntoSelecionado)
          .get();

      final resultados = consulta.docs.map((doc) => doc.data()).toList()
        ..sort((a, b) {
          final porLivro = (a['livro'] as String).compareTo(
            b['livro'] as String,
          );
          if (porLivro != 0) return porLivro;
          return (a['tituloNormalizado'] as String).compareTo(
            b['tituloNormalizado'] as String,
          );
        });

      if (!mounted) return;
      setState(() {
        _resultadosAssunto = resultados;
        if (resultados.isEmpty) {
          _mensagem = 'Nenhum hino encontrado para este assunto.';
        }
      });
    } on FirebaseException catch (erro) {
      if (!mounted) return;
      setState(() {
        _mensagem = 'Erro do Firebase: ${erro.message ?? erro.code}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  Future<void> _abrirResultado(Map<String, dynamic> hino) async {
    var carregado = false;
    setState(() {
      _carregando = true;
      _hino = null;
      _correspondentes = [];
      _mensagem = null;
    });
    try {
      await _carregarDetalhes(hino);
      carregado = true;
    } on FirebaseException catch (erro) {
      if (!mounted) return;
      setState(() {
        _mensagem = 'Erro do Firebase: ${erro.message ?? erro.code}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
    if (carregado && mounted) await _rolarParaDetalhes();
  }

  Future<void> _abrirResultadoTexto(ResultadoBuscaHino resultado) async {
    await _carregarPorId(resultado.id);
    if (_hino != null && mounted) await _rolarParaDetalhes();
  }

  void _abrirLetra(Map<String, dynamic> hino) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TelaLetraHino(hino: hino)),
    );
  }

  Future<void> _abrirLetraPorId(String id) async {
    setState(() => _carregando = true);
    try {
      final documento = await _firestore.collection('hinos_v2').doc(id).get();
      if (!mounted) return;
      if (!documento.exists) {
        setState(() => _mensagem = 'Hino $id não encontrado.');
        return;
      }
      _abrirLetra(documento.data()!);
    } on FirebaseException catch (erro) {
      if (!mounted) return;
      setState(() {
        _mensagem = 'Erro ao carregar a letra: ${erro.message ?? erro.code}';
      });
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _buscarPorTexto() async {
    FocusScope.of(context).unfocus();
    final consulta = _textoController.text.trim();
    if (consulta.length < 2) {
      setState(() {
        _limparResultados();
        _mensagem = 'Digite pelo menos dois caracteres para pesquisar.';
      });
      return;
    }

    setState(() {
      _carregando = true;
      _limparResultados();
    });
    try {
      final resultados = await _servicoBusca.buscar(consulta);
      if (!mounted) return;
      setState(() {
        _resultadosTexto = resultados;
        if (resultados.isEmpty) {
          _mensagem = 'Nenhum hino semelhante foi encontrado.';
        }
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _mensagem = 'Não foi possível pesquisar no índice local: $erro';
      });
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  Future<void> _rolarParaDetalhes() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final contexto = _chaveDetalhes.currentContext;
    if (contexto == null || !contexto.mounted) return;
    await Scrollable.ensureVisible(
      contexto,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      alignment: 0.02,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consulta de hinos')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            controller: _controleRolagem,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            _limparResultados();
                          });
                        },
                ),
                const SizedBox(height: 24),
                if (_modo == 'numero')
                  _painelNumero()
                else if (_modo == 'assunto')
                  _painelAssunto()
                else
                  _painelTexto(),
                if (_carregando) ...[
                  const SizedBox(height: 24),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (_hino != null) ...[
                  const SizedBox(height: 24),
                  KeyedSubtree(
                    key: _chaveDetalhes,
                    child: _CartaoHino(
                      tituloSecao: 'Hino selecionado',
                      hino: _hino!,
                      rotuloAssunto: _rotuloAssunto,
                      onVerLetra: () => _abrirLetra(_hino!),
                    ),
                  ),
                ],
                if (_correspondentes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ..._correspondentes.map(
                    (hino) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CartaoHino(
                        tituloSecao: 'Correspondente',
                        hino: hino,
                        rotuloAssunto: _rotuloAssunto,
                        onVerLetra: () => _abrirLetra(hino),
                      ),
                    ),
                  ),
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
                if (_resultadosAssunto.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    '${_resultadosAssunto.length} hinos encontrados',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ..._resultadosAssunto.map(
                    (hino) => Card(
                      child: ListTile(
                        title: Text(
                          '${hino['livro']} ${hino['numeroFormatado']} — ${hino['titulo']}',
                        ),
                        subtitle: Text('Tonalidade: ${hino['tom']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Ver letra',
                              onPressed: () => _abrirLetra(hino),
                              icon: const Icon(Icons.visibility_outlined),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => _abrirResultado(hino),
                      ),
                    ),
                  ),
                ],
                if (_resultadosTexto.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    '${_resultadosTexto.length} resultados mais relevantes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ..._resultadosTexto.map(
                    (resultado) => Card(
                      child: ListTile(
                        title: Text(
                          '${resultado.livro} ${resultado.numeroFormatado} — ${resultado.titulo}',
                        ),
                        subtitle: Text('Tonalidade: ${resultado.tom}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Ver letra',
                              onPressed: _carregando
                                  ? null
                                  : () => _abrirLetraPorId(resultado.id),
                              icon: const Icon(Icons.visibility_outlined),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => _abrirResultadoTexto(resultado),
                      ),
                    ),
                  ),
                ],
              ],
            ),
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
          onSelectionChanged: _carregando
              ? null
              : (selecao) {
                  setState(() {
                    _livro = selecao.first;
                    _hino = null;
                    _correspondentes = [];
                    _mensagem = null;
                  });
                },
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _numeroController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Número do hino',
            hintText: 'Ex.: 60',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.numbers),
          ),
          onSubmitted: (_) {
            if (!_carregando) _buscarPorNumero();
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _carregando ? null : _buscarPorNumero,
            icon: const Icon(Icons.search),
            label: const Text('Buscar'),
          ),
        ),
      ],
    );
  }

  Widget _painelAssunto() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _assuntoSelecionado,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Assunto',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.category_outlined),
          ),
          items: _assuntos
              .map(
                (assunto) => DropdownMenuItem(
                  value: assunto,
                  child: Text(_rotuloAssunto(assunto)),
                ),
              )
              .toList(),
          onChanged: _carregando
              ? null
              : (assunto) {
                  if (assunto == null) return;
                  setState(() {
                    _assuntoSelecionado = assunto;
                    _limparResultados();
                  });
                },
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _carregando ? null : _buscarPorAssunto,
            icon: const Icon(Icons.search),
            label: const Text('Buscar por assunto'),
          ),
        ),
      ],
    );
  }

  Widget _painelTexto() {
    return Column(
      children: [
        TextField(
          controller: _textoController,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Título ou trecho da letra',
            hintText: 'Ex.: firme promesas',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.manage_search),
          ),
          onSubmitted: (_) {
            if (!_carregando) _buscarPorTexto();
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _carregando ? null : _buscarPorTexto,
            icon: const Icon(Icons.search),
            label: const Text('Buscar por texto'),
          ),
        ),
      ],
    );
  }
}

class _CartaoHino extends StatelessWidget {
  const _CartaoHino({
    required this.tituloSecao,
    required this.hino,
    required this.rotuloAssunto,
    required this.onVerLetra,
  });

  final String tituloSecao;
  final Map<String, dynamic> hino;
  final String Function(String) rotuloAssunto;
  final VoidCallback onVerLetra;

  @override
  Widget build(BuildContext context) {
    final assuntos = List<String>.from(hino['assuntos'] as List<dynamic>);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tituloSecao, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(
              '${hino['livro']} ${hino['numeroFormatado']} — ${hino['titulo']}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Tonalidade: ${hino['tom']}'),
            const SizedBox(height: 8),
            Text('Assuntos: ${assuntos.map(rotuloAssunto).join(', ')}'),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onVerLetra,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Ver letra'),
            ),
          ],
        ),
      ),
    );
  }
}
