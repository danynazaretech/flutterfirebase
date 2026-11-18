// flutter pub add firebase_core cloud_firestore

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  // Necessário antes de usar qualquer plugin de forma assíncrona
  WidgetsFlutterBinding.ensureInitialized();

  // Conecta o app ao projeto Firebase (configuração manual, sem CLI).
  // Copie os valores de: Console Firebase > Configurações do projeto >
  // Geral > Seus apps > Configuração do SDK.
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'COLE_AQUI_O_apiKey',
      appId: 'COLE_AQUI_O_appId',
      messagingSenderId: 'COLE_AQUI_O_messagingSenderId',
      projectId: 'COLE_AQUI_O_projectId',
      storageBucket: 'COLE_AQUI_O_storageBucket',
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cadastro de Aluno',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: const CadastroAlunoPage(),
    );
  }
}

// ---------------------------------------------------------------------------
// TELA 1: Formulário de cadastro
// ---------------------------------------------------------------------------
class CadastroAlunoPage extends StatefulWidget {
  const CadastroAlunoPage({super.key});

  @override
  State<CadastroAlunoPage> createState() => _CadastroAlunoPageState();
}

class _CadastroAlunoPageState extends State<CadastroAlunoPage> {
  final _formKey = GlobalKey<FormState>();

  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _cpf = TextEditingController();
  final _telefone = TextEditingController();
  final _curso = TextEditingController();
  final _dataNascimento = TextEditingController();

  bool _salvando = false;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _cpf.dispose();
    _telefone.dispose();
    _curso.dispose();
    _dataNascimento.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    // Valida os campos (nenhum pode estar vazio)
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    try {
      // Grava um novo documento na coleção "alunos".
      // O Firestore cria a coleção automaticamente se ela não existir.
      await FirebaseFirestore.instance.collection('alunos').add({
        'nome': _nome.text.trim(),
        'email': _email.text.trim(),
        'cpf': _cpf.text.trim(),
        'telefone': _telefone.text.trim(),
        'curso': _curso.text.trim(),
        'dataNascimento': _dataNascimento.text.trim(),
        'dataCadastro': FieldValue.serverTimestamp(), // hora do servidor
      });

      if (!mounted) return;
      _mostrarMensagem('Aluno cadastrado com sucesso!');
      _formKey.currentState!.reset();
      for (final c in [_nome, _email, _cpf, _telefone, _curso, _dataNascimento]) {
        c.clear();
      }
    } catch (erro) {
      if (!mounted) return;
      _mostrarMensagem('Erro ao cadastrar: $erro');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _mostrarMensagem(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  // Cria um campo de texto padrão (evita repetir código 6 vezes)
  Widget _campo(
    String rotulo,
    TextEditingController controller, {
    TextInputType tipo = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: tipo,
        decoration: InputDecoration(
          labelText: rotulo,
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (valor) =>
            (valor == null || valor.trim().isEmpty) ? 'Preencha este campo' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de Aluno'),
        actions: [
          IconButton(
            tooltip: 'Ver alunos cadastrados',
            icon: const Icon(Icons.list),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ListaAlunosPage()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _campo('Nome', _nome),
                _campo('E-mail', _email, tipo: TextInputType.emailAddress),
                _campo('CPF (fictício)', _cpf, tipo: TextInputType.number),
                _campo('Telefone', _telefone, tipo: TextInputType.phone),
                _campo('Curso', _curso),
                _campo('Data de nascimento', _dataNascimento,
                    tipo: TextInputType.datetime),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _salvando ? null : _salvar,
                    child: _salvando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Cadastrar Aluno',
                            style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TELA 2: Lista em tempo real (lê os dados do Firestore)
// ---------------------------------------------------------------------------
class ListaAlunosPage extends StatelessWidget {
  const ListaAlunosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alunos cadastrados')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // snapshots() atualiza a tela automaticamente quando alguém grava algo
        stream: FirebaseFirestore.instance
            .collection('alunos')
            .orderBy('dataCadastro', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final alunos = snapshot.data!.docs;
          if (alunos.isEmpty) {
            return const Center(child: Text('Nenhum aluno cadastrado ainda.'));
          }

          return ListView.separated(
            itemCount: alunos.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final aluno = alunos[i].data();
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(aluno['nome'] ?? ''),
                subtitle: Text('${aluno['curso'] ?? ''} • ${aluno['email'] ?? ''}'),
              );
            },
          );
        },
      ),
    );
  }
}
