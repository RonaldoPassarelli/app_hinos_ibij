import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'tela_acesso.dart';
import 'tela_admin_hinos.dart';
import 'tela_admin_observacoes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AppAdministrativoHinos());
}

class AppAdministrativoHinos extends StatelessWidget {
  const AppAdministrativoHinos({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hinos IBIJ — Administração',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const _PortaAdministrativa(),
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
                (papel == 'editor' || papel == 'admin');
            if (!autorizado) {
              return _TelaAcessoNegado(
                usuario: usuario,
                mensagem: 'Esta conta não possui acesso administrativo ativo.',
              );
            }

            final nome = dados?['nome']?.toString().trim();
            return TelaAdministrativa(
              nomeUsuario: nome?.isNotEmpty == true
                  ? nome!
                  : usuario.email ?? 'Usuário',
              papel: papel,
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
                    'Acesso administrativo não autorizado',
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
  });

  final String nomeUsuario;
  final String papel;

  @override
  State<TelaAdministrativa> createState() => _TelaAdministrativaState();
}

class _TelaAdministrativaState extends State<TelaAdministrativa> {
  var _indice = 0;

  static const _itens = [
    (icone: Icons.library_music_outlined, titulo: 'Hinos'),
    (icone: Icons.note_alt_outlined, titulo: 'Observações'),
    (icone: Icons.add_box_outlined, titulo: 'Novo hino'),
    (icone: Icons.collections_bookmark_outlined, titulo: 'Hinários'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _menuLateral(context),
          const VerticalDivider(width: 1),
          Expanded(
            child: switch (_indice) {
              0 => const TelaAdminHinos(),
              1 => TelaAdminObservacoes(nomeUsuario: widget.nomeUsuario),
              _ => _ModuloFuturo(titulo: _itens[_indice].titulo),
            },
          ),
        ],
      ),
    );
  }

  Widget _menuLateral(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
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
                          Text('Administração', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              for (var indice = 0; indice < _itens.length; indice++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    selected: _indice == indice,
                    selectedTileColor: cores.secondaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Icon(_itens[indice].icone),
                    title: Text(_itens[indice].titulo),
                    trailing: indice <= 1
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
                subtitle: Text(widget.papel),
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
