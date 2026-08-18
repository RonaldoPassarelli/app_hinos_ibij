import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'tela_acesso.dart';
import 'tela_admin_hinos.dart';
import 'tela_admin_novo_hino.dart';
import 'tela_admin_observacoes.dart';
import 'tela_apresentacao.dart';
import 'tema_aplicativo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await ControladorTema.instancia.carregar();
  runApp(const AppAdministrativoHinos());
}

class AppAdministrativoHinos extends StatelessWidget {
  const AppAdministrativoHinos({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ControladorTema.instancia,
      builder: (context, modo, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Hinos IBIJ',
        theme: criarTema(brilho: Brightness.light),
        darkTheme: criarTema(brilho: Brightness.dark),
        themeMode: modo,
        home: const _PortaAdministrativa(),
      ),
    );
  }
}

class _PortaAdministrativa extends StatelessWidget {
  const _PortaAdministrativa();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, autenticacao) {
        if (autenticacao.connectionState == ConnectionState.waiting) {
          return const _TelaCarregando();
        }

        final usuario = autenticacao.data;
        if (usuario == null) return const TelaAcesso();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('usuarios')
              .doc(usuario.uid)
              .snapshots(),
          builder: (context, perfil) {
            if (perfil.connectionState == ConnectionState.waiting) {
              return const _TelaCarregando();
            }
            if (perfil.hasError) {
              return _TelaAcessoNegado(
                usuario: usuario,
                mensagem: 'Não foi possível validar o perfil deste usuário.',
              );
            }

            final dados = perfil.data?.data();
            final papel = dados?['papel']?.toString() ?? '';
            final autorizado =
                dados?['ativo'] == true &&
                (papel == 'operador' || papel == 'editor' || papel == 'admin');
            if (!autorizado) {
              return _TelaAcessoNegado(
                usuario: usuario,
                mensagem: 'Esta conta não possui acesso ativo ao painel.',
              );
            }

            final nome = dados?['nome']?.toString().trim();
            final igrejaIds =
                ((dados?['igrejaIds'] as List<dynamic>?) ?? const [])
                    .map((id) => id.toString().trim())
                    .where((id) => id.isNotEmpty)
                    .toList();
            final igrejaPadraoId =
                dados?['igrejaPadraoId']?.toString().trim() ?? '';
            if (igrejaIds.isEmpty || igrejaPadraoId.isEmpty) {
              return _TelaAcessoNegado(
                usuario: usuario,
                mensagem: 'Esta conta não possui uma igreja vinculada.',
              );
            }
            return TelaAdministrativa(
              nomeUsuario: nome?.isNotEmpty == true
                  ? nome!
                  : usuario.email ?? 'Usuário',
              papel: papel,
              igrejaIds: igrejaIds,
              igrejaPadraoId: igrejaPadraoId,
            );
          },
        );
      },
    );
  }
}

class _TelaCarregando extends StatelessWidget {
  const _TelaCarregando();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _TelaAcessoNegado extends StatelessWidget {
  const _TelaAcessoNegado({required this.usuario, required this.mensagem});

  final User usuario;
  final String mensagem;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Acesso ao painel não autorizado',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(mensagem, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    usuario.email ?? '',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: FirebaseAuth.instance.signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sair'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TelaAdministrativa extends StatefulWidget {
  const TelaAdministrativa({
    super.key,
    required this.nomeUsuario,
    required this.papel,
    required this.igrejaIds,
    required this.igrejaPadraoId,
  });

  final String nomeUsuario;
  final String papel;
  final List<String> igrejaIds;
  final String igrejaPadraoId;

  @override
  State<TelaAdministrativa> createState() => _TelaAdministrativaState();
}

class _TelaAdministrativaState extends State<TelaAdministrativa> {
  var _indice = 0;
  var _igrejas = <_OpcaoIgreja>[];
  String? _igrejaSelecionadaId;
  String? _erroIgrejas;
  var _carregandoIgrejas = true;

  @override
  void initState() {
    super.initState();
    _carregarIgrejas();
  }

  Future<void> _carregarIgrejas() async {
    try {
      final consulta = await FirebaseFirestore.instance
          .collection('igrejas')
          .get();
      final permitidas = widget.igrejaIds.toSet();
      final igrejas =
          consulta.docs
              .where(
                (documento) =>
                    documento.data()['ativo'] == true &&
                    permitidas.contains(documento.id),
              )
              .map(_OpcaoIgreja.fromDocumento)
              .toList()
            ..sort((a, b) => a.nomeCurto.compareTo(b.nomeCurto));

      final preferencias = await SharedPreferences.getInstance();
      final salva = preferencias.getString('igreja_selecionada_painel');
      final idsDisponiveis = igrejas.map((igreja) => igreja.id).toSet();
      String? selecionada;
      if (igrejas.length == 1) {
        selecionada = igrejas.first.id;
      } else if (idsDisponiveis.contains(salva)) {
        selecionada = salva;
      } else if (idsDisponiveis.contains(widget.igrejaPadraoId)) {
        selecionada = widget.igrejaPadraoId;
      } else if (igrejas.isNotEmpty) {
        selecionada = igrejas.first.id;
      }

      if (!mounted) return;
      setState(() {
        _igrejas = igrejas;
        _igrejaSelecionadaId = selecionada;
        _erroIgrejas = igrejas.isEmpty
            ? 'Nenhuma igreja ativa está disponível para esta conta.'
            : null;
        _carregandoIgrejas = false;
      });
    } on FirebaseException catch (erro) {
      if (!mounted) return;
      setState(() {
        _erroIgrejas = erro.message ?? erro.code;
        _carregandoIgrejas = false;
      });
    }
  }

  Future<void> _selecionarIgreja(String igrejaId) async {
    setState(() => _igrejaSelecionadaId = igrejaId);
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setString('igreja_selecionada_painel', igrejaId);
  }

  List<_ItemPainel> get _itens {
    final podeAdministrar = widget.papel == 'admin';
    return [
      if (podeAdministrar) ...[
        const _ItemPainel(
          id: 'hinos',
          icone: Icons.library_music_outlined,
          titulo: 'Hinos',
        ),
        const _ItemPainel(
          id: 'observacoes',
          icone: Icons.note_alt_outlined,
          titulo: 'Observações',
        ),
        const _ItemPainel(
          id: 'novo_hino',
          icone: Icons.add_box_outlined,
          titulo: 'Novo hino',
        ),
        const _ItemPainel(
          id: 'hinarios',
          icone: Icons.collections_bookmark_outlined,
          titulo: 'Hinários',
          disponivel: false,
        ),
      ],
      const _ItemPainel(
        id: 'apresentacao',
        icone: Icons.slideshow_outlined,
        titulo: 'Apresentação',
      ),
    ];
  }

  String get _nomePapel => switch (widget.papel) {
    'admin' => 'Administrador',
    'editor' => 'Editor',
    'operador' => 'Operador',
    _ => widget.papel,
  };

  @override
  Widget build(BuildContext context) {
    final itens = _itens;
    if (_indice >= itens.length) _indice = 0;
    final itemSelecionado = itens[_indice];
    return Scaffold(
      body: Row(
        children: [
          _menuLateral(context),
          const VerticalDivider(width: 1),
          Expanded(child: _conteudo(itemSelecionado)),
        ],
      ),
    );
  }

  Widget _conteudo(_ItemPainel item) {
    final igrejaId = _igrejaSelecionadaId;
    if (_carregandoIgrejas) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erroIgrejas != null || igrejaId == null) {
      return _ModuloIndisponivel(
        titulo: 'Igreja indisponível',
        mensagem: _erroIgrejas ?? 'Nenhuma igreja foi selecionada.',
        onTentarNovamente: _carregarIgrejas,
      );
    }
    return switch (item.id) {
      'hinos' => const TelaAdminHinos(),
      'observacoes' => TelaAdminObservacoes(
        key: ValueKey('observacoes:$igrejaId'),
        nomeUsuario: widget.nomeUsuario,
        igrejaId: igrejaId,
      ),
      'novo_hino' => TelaAdminNovoHino(nomeUsuario: widget.nomeUsuario),
      'apresentacao' => TelaApresentacao(
        key: ValueKey('apresentacao:$igrejaId'),
        igrejaId: igrejaId,
      ),
      _ => _ModuloFuturo(titulo: item.titulo),
    };
  }

  Widget _menuLateral(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final itens = _itens;
    return SafeArea(
      child: SizedBox(
        width: 250,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(Icons.library_music, color: cores.primary, size: 34),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hinos IBIJ',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text('Painel', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const BotaoTema(),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _seletorIgreja(),
              const SizedBox(height: 18),
              for (var indice = 0; indice < itens.length; indice++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    selected: _indice == indice,
                    selectedTileColor: cores.secondaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Icon(itens[indice].icone),
                    title: Text(itens[indice].titulo),
                    trailing: itens[indice].disponivel
                        ? null
                        : const Icon(Icons.lock_clock_outlined, size: 17),
                    onTap: () => setState(() => _indice = indice),
                  ),
                ),
              const Spacer(),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(
                  widget.nomeUsuario,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(_nomePapel),
              ),
              OutlinedButton.icon(
                onPressed: FirebaseAuth.instance.signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sair'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _seletorIgreja() {
    if (_carregandoIgrejas) {
      return const LinearProgressIndicator();
    }
    if (_erroIgrejas != null || _igrejaSelecionadaId == null) {
      return ListTile(
        leading: const Icon(Icons.error_outline),
        title: const Text('Igreja indisponível'),
        trailing: IconButton(
          tooltip: 'Tentar novamente',
          onPressed: _carregarIgrejas,
          icon: const Icon(Icons.refresh),
        ),
      );
    }
    if (_igrejas.length == 1) {
      final igreja = _igrejas.first;
      return ListTile(
        leading: const Icon(Icons.church_outlined),
        title: Text(igreja.nomeCurto),
        subtitle: Text(
          igreja.nome,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    return DropdownMenu<String>(
      key: ValueKey(_igrejaSelecionadaId),
      initialSelection: _igrejaSelecionadaId,
      width: 222,
      label: const Text('Igreja'),
      leadingIcon: const Icon(Icons.church_outlined),
      dropdownMenuEntries: _igrejas
          .map(
            (igreja) => DropdownMenuEntry<String>(
              value: igreja.id,
              label: igreja.nomeCurto,
              labelWidget: Text(
                '${igreja.nomeCurto} — ${igreja.nome}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onSelected: (id) {
        if (id != null) _selecionarIgreja(id);
      },
    );
  }
}

class _OpcaoIgreja {
  const _OpcaoIgreja({
    required this.id,
    required this.nome,
    required this.nomeCurto,
  });

  factory _OpcaoIgreja.fromDocumento(
    QueryDocumentSnapshot<Map<String, dynamic>> documento,
  ) {
    final dados = documento.data();
    return _OpcaoIgreja(
      id: documento.id,
      nome: dados['nome']?.toString() ?? documento.id,
      nomeCurto: dados['nomeCurto']?.toString() ?? documento.id,
    );
  }

  final String id;
  final String nome;
  final String nomeCurto;
}

class _ItemPainel {
  const _ItemPainel({
    required this.id,
    required this.icone,
    required this.titulo,
    this.disponivel = true,
  });

  final String id;
  final IconData icone;
  final String titulo;
  final bool disponivel;
}

class _ModuloFuturo extends StatelessWidget {
  const _ModuloFuturo({required this.titulo});

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.construction_outlined, size: 56),
                const SizedBox(height: 18),
                Text(titulo, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 10),
                const Text(
                  'Este módulo será habilitado nas próximas etapas. '
                  'A primeira versão do painel opera somente em leitura.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModuloIndisponivel extends StatelessWidget {
  const _ModuloIndisponivel({
    required this.titulo,
    required this.mensagem,
    required this.onTentarNovamente,
  });

  final String titulo;
  final String mensagem;
  final VoidCallback onTentarNovamente;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 52),
              const SizedBox(height: 16),
              Text(titulo, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(mensagem, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onTentarNovamente,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
