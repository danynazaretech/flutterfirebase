import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// CONFIGURAÇÃO: copie do Console Firebase > Configurações do projeto > Geral
// ---------------------------------------------------------------------------
const String projectId = 'COLE_AQUI_O_projectId';
const String apiKey = 'COLE_AQUI_O_apiKey';

// URL base da coleção "alunos" na API REST do Firestore
const String _baseUrl =
    'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/alunos';

// ---------------------------------------------------------------------------
// SERVIÇO: toda a comunicação com o Firestore fica aqui
// ---------------------------------------------------------------------------
class AlunoService {
  /// Envia um aluno (POST). Lança exceção se o Firestore recusar.
  static Future<void> cadastrar(Map<String, String> aluno) async {
    // Cada valor precisa informar o tipo: stringValue, timestampValue, etc.
    final fields = <String, dynamic>{
      for (final e in aluno.entries) e.key: {'stringValue': e.value},
      'dataCadastro': {
        'timestampValue': DateTime.now().toUtc().toIso8601String(),
      },
    };

    final resposta = await http.post(
      Uri.parse('$_baseUrl?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'fields': fields}),
    );

    if (resposta.statusCode != 200) {
      throw Exception('HTTP ${resposta.statusCode}: ${resposta.body}');
    }
  }

  /// Busca os alunos (GET), do mais recente para o mais antigo.
  static Future<List<Map<String, String>>> listar() async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'key': apiKey,
      'pageSize': '100',
      'orderBy': 'dataCadastro desc',
    });

    final resposta = await http.get(uri);
    if (resposta.statusCode != 200) {
      throw Exception('HTTP ${resposta.statusCode}: ${resposta.body}');
    }

    final json = jsonDecode(resposta.body) as Map<String, dynamic>;
    final documentos = (json['documents'] as List?) ?? []; // vazio = sem chave

    return documentos.map<Map<String, String>>((doc) {
      final campos = doc['fields'] as Map<String, dynamic>;
      // Converte {"nome": {"stringValue": "Maria"}} em {"nome": "Maria"}
      return {
        for (final e in campos.entries)
          e.key: (e.value['stringValue'] ?? e.value['timestampValue'] ?? '')
              .toString(),
      };
    }).toList();
  }
}

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cadastro de Aluno (REST)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: const CadastroAlunoPage(),
    );
  }
}

// ---------------------------------------------------------------------------
// TELA 1: Formulário
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
    for (final c in [_nome, _email, _cpf, _telefone, _curso, _dataNascimento]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    try {
      await AlunoService.cadastrar({
        'nome': _nome.text.trim(),
        'email': _email.text.trim(),
        'cpf': _cpf.text.trim(),
        'telefone': _telefone.text.trim(),
        'curso': _curso.text.trim(),
        'dataNascimento': _dataNascimento.text.trim(),
      });

      if (!mounted) return;
      _mensagem('Aluno cadastrado com sucesso!');
      for (final c in [_nome, _email, _cpf, _telefone, _curso, _dataNascimento]) {
        c.clear();
      }
    } catch (erro) {
      if (!mounted) return;
      _mensagem('Erro ao cadastrar: $erro');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _mensagem(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Widget _campo(String rotulo, TextEditingController controller,
      {TextInputType tipo = TextInputType.text}) {
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
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Preencha este campo' : null,
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
// TELA 2: Lista (recarregada manualmente, pois REST não tem tempo real)
// ---------------------------------------------------------------------------
class ListaAlunosPage extends StatefulWidget {
  const ListaAlunosPage({super.key});

  @override
  State<ListaAlunosPage> createState() => _ListaAlunosPageState();
}

class _ListaAlunosPageState extends State<ListaAlunosPage> {
  late Future<List<Map<String, String>>> _futuro = AlunoService.listar();

  void _recarregar() => setState(() => _futuro = AlunoService.listar());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alunos cadastrados'),
        actions: [
          IconButton(
            tooltip: 'Recarregar',
            icon: const Icon(Icons.refresh),
            onPressed: _recarregar,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, String>>>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }

          final alunos = snapshot.data!;
          if (alunos.isEmpty) {
            return const Center(child: Text('Nenhum aluno cadastrado ainda.'));
          }

          return ListView.separated(
            itemCount: alunos.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final aluno = alunos[i];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(aluno['nome'] ?? ''),
                subtitle:
                    Text('${aluno['curso'] ?? ''} • ${aluno['email'] ?? ''}'),
              );
            },
          );
        },
      ),
    );
  }
}
