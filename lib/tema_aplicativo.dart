import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _chaveTemaEscuro = 'tema_escuro';

class ControladorTema extends ValueNotifier<ThemeMode> {
  ControladorTema._() : super(ThemeMode.dark);

  static final instancia = ControladorTema._();

  Future<void> carregar() async {
    final preferencias = await SharedPreferences.getInstance();
    final escuro = preferencias.getBool(_chaveTemaEscuro) ?? true;
    value = escuro ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> alternar() async {
    final escuro = value != ThemeMode.dark;
    value = escuro ? ThemeMode.dark : ThemeMode.light;
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setBool(_chaveTemaEscuro, escuro);
  }
}

ThemeData criarTema({required Brightness brilho}) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.green,
      brightness: brilho,
    ),
    useMaterial3: true,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );
}

class BotaoTema extends StatelessWidget {
  const BotaoTema({super.key});

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: escuro ? 'Usar tema claro' : 'Usar tema escuro',
      onPressed: ControladorTema.instancia.alternar,
      icon: Icon(escuro ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
    );
  }
}
