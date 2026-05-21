//para converter os valores da API para mapas (notações JSON)
//manipuláveis pelo Dart
import 'dart:convert';

import 'package:flutter/material.dart';
//para realizar as requisições http
import 'package:http/http.dart' as http;

//o método main deve ser async par realizar as requisições http
void main() async {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: const Home(),
    theme: ThemeData(
      primaryColor: const Color(0xFF6C63FF),
      scaffoldBackgroundColor: const Color(0xFFF5F7FB),
      fontFamily: 'Roboto',
    ),
  ));
}

//função que acessa a API
//Future indica um retorno futuro
Future<Map> getData() async {
  var request = Uri.parse('https://api.adviceslip.com/advice');
//aguarda a resposta do servidor da API e armazena em response
  http.Response response = await http.get(request);
  //mostra o objeto JSON retornado
  var textjsonConselho = json.decode(response.body);

  var request2 = Uri.parse(
      'https://api.mymemory.translated.net/get?q=${textjsonConselho["slip"]["advice"]}&langpair=en|pt');

  http.Response response2 = await http.get(request2);

  return json.decode(response2.body);
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String _conselho = "";
  bool _carregando = false;
  String? _erro;

  Future<void> _buscarConselho() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final data = await getData();
      setState(() {
        _conselho = data["responseData"]["translatedText"];
      });
    } catch (e) {
      setState(() {
        _erro = "Ops, houve uma falha ao buscar os dados";
      });
    } finally {
      setState(() {
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 32.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 64.0,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Spacer(flex: 1),
                        const Text(
                          "Conselho do Dia",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          "Receba uma dose de sabedoria",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 16.0,
                          ),
                        ),
                        const Spacer(flex: 1),
                        Center(
                          child: Container(
                            width: 140.0,
                            height: 140.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.15),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 2.0,
                              ),
                            ),
                            child: const Icon(
                              Icons.lightbulb_outline,
                              size: 80.0,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Spacer(flex: 1),
                        _buildAdviceCard(),
                        const SizedBox(height: 24.0),
                        _buildButton(),
                        if (_erro != null) ...[
                          const SizedBox(height: 16.0),
                          Container(
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.red),
                                const SizedBox(width: 8.0),
                                Expanded(
                                  child: Text(
                                    _erro!,
                                    style: TextStyle(
                                      color: Colors.red.shade900,
                                      fontSize: 14.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Spacer(flex: 1),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAdviceCard() {
    return Container(
      constraints: const BoxConstraints(minHeight: 160.0),
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20.0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.format_quote,
            size: 36.0,
            color: const Color(0xFF667EEA).withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12.0),
          Text(
            _conselho.isEmpty
                ? "Clique no botão abaixo para receber um conselho."
                : _conselho,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _conselho.isEmpty
                  ? Colors.grey.shade500
                  : const Color(0xFF2D3748),
              fontSize: 18.0,
              fontWeight:
                  _conselho.isEmpty ? FontWeight.normal : FontWeight.w500,
              fontStyle:
                  _conselho.isEmpty ? FontStyle.italic : FontStyle.normal,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12.0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF667EEA),
          padding: const EdgeInsets.symmetric(vertical: 18.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          elevation: 0,
        ),
        onPressed: _carregando ? null : _buscarConselho,
        child: _carregando
            ? const SizedBox(
                height: 24.0,
                width: 24.0,
                child: CircularProgressIndicator(
                  color: Color(0xFF667EEA),
                  strokeWidth: 2.5,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, size: 22.0),
                  SizedBox(width: 10.0),
                  Text(
                    "Pegar Conselho",
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
