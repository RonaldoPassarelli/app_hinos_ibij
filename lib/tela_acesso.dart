import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TelaAcesso extends StatefulWidget {
  const TelaAcesso({super.key});

  @override
  State<TelaAcesso> createState() => _TelaAcessoState();
}

class _TelaAcessoState extends State<TelaAcesso> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  var _processando = false;
  var _ocultarSenha = true;
  String? _erro;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final email = _emailController.text.trim();
    final senha = _senhaController.text;
    if (email.isEmpty || senha.isEmpty) {
      setState(() => _erro = 'Informe o e-mail e a senha.');
      return;
    }

    setState(() {
      _processando = true;
      _erro = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );
      _senhaController.clear();
    } on FirebaseAuthException catch (erro) {
      if (!mounted) return;
      setState(
        () => _erro = switch (erro.code) {
          'invalid-credential' => 'E-mail ou senha incorretos.',
          'invalid-email' => 'O endereço de e-mail é inválido.',
          'too-many-requests' =>
            'Muitas tentativas. Aguarde um pouco e tente novamente.',
          _ => erro.message ?? 'Não foi possível entrar.',
        },
      );
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _sair() => FirebaseAuth.instance.signOut();

  Future<void> _recuperarSenha() async {
    final emailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    final email = await showDialog<String>(
      context: context,
      builder: (contextoDialogo) => AlertDialog(
        title: const Text('Redefinir senha'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Informe o e-mail usado no acesso. Você receberá as instruções para criar uma nova senha.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (valor) {
                  final email = valor.trim();
                  if (email.isNotEmpty) Navigator.pop(contextoDialogo, email);
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
              final email = emailController.text.trim();
              if (email.isNotEmpty) Navigator.pop(contextoDialogo, email);
            },
            child: const Text('Enviar link'),
          ),
        ],
      ),
    );
    emailController.dispose();
    if (email == null || !mounted) return;

    setState(() {
      _processando = true;
      _erro = null;
    });
    try {
      await FirebaseAuth.instance.setLanguageCode('pt-BR');
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Se o e-mail estiver cadastrado, as instruções de redefinição serão enviadas.',
          ),
        ),
      );
    } on FirebaseAuthException catch (erro) {
      if (!mounted) return;
      if (erro.code == 'user-not-found') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Se o e-mail estiver cadastrado, as instruções de redefinição serão enviadas.',
            ),
          ),
        );
        return;
      }
      setState(
        () => _erro = switch (erro.code) {
          'invalid-email' => 'O endereço de e-mail é inválido.',
          'too-many-requests' =>
            'Muitas solicitações. Aguarde um pouco e tente novamente.',
          _ => 'Não foi possível solicitar a redefinição agora.',
        },
      );
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acesso')),
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          final usuario = snapshot.data;
          if (usuario == null) return _formularioLogin();
          return _painelUsuario(usuario);
        },
      ),
    );
  }

  Widget _formularioLogin() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.admin_panel_settings_outlined, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    'Acesso dos responsáveis',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A consulta é pública. Entre somente para criar ou editar cultos.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _senhaController,
                    obscureText: _ocultarSenha,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) {
                      if (!_processando) _entrar();
                    },
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: _ocultarSenha
                            ? 'Mostrar senha'
                            : 'Ocultar senha',
                        onPressed: () {
                          setState(() => _ocultarSenha = !_ocultarSenha);
                        },
                        icon: Icon(
                          _ocultarSenha
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                  ),
                  if (_erro != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _erro!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _processando ? null : _entrar,
                    icon: _processando
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: const Text('Entrar'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _processando ? null : _recuperarSenha,
                    child: const Text('Esqueci minha senha'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _painelUsuario(User usuario) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuario.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final dados = snapshot.data?.data();
        final autorizado =
            dados?['ativo'] == true &&
            (dados?['papel'] == 'editor' || dados?['papel'] == 'admin');
        final nome = (dados?['nome'] as String?)?.trim();

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        autorizado
                            ? Icons.verified_user_outlined
                            : Icons.person_outline,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        nome?.isNotEmpty == true
                            ? nome!
                            : usuario.email ?? 'Usuário',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(usuario.email ?? ''),
                      const SizedBox(height: 16),
                      Text(
                        autorizado
                            ? 'Acesso de edição autorizado.'
                            : 'Conta autenticada, mas sem permissão de edição.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _sair,
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
      },
    );
  }
}
