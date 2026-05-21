import 'package:flutter/material.dart';

//para realizar as requisições http
import 'package:http/http.dart' as http;
//para converter os valores da API para mapas (notações JSON)
//manipuláveis pelo Dart
import 'dart:convert';

//o método main deve ser async par realizar as requisições http
void main() async {
  runApp(MaterialApp(
    home: const Home(),
    theme: ThemeData(hintColor: Colors.green, primaryColor: Colors.white),
  ));
}

//função que acessa a API
//Future indica um retorno futuro
Future<Map> getData() async {
  var request = Uri.parse(
      'https://economia.awesomeapi.com.br/last/USD-BRL,EUR-BRL,BTC-BRL');
//aguarda a resposta do servidor da API e armazena em response
  http.Response response = await http.get(request);
  //mostra o objeto JSON retornado
  print(json.decode(response.body));

  return json.decode(response.body);
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  //Controladores para armazenar os valores das moedas fornecidos
  final realController = TextEditingController();
  final dolarController = TextEditingController();
  final euroController = TextEditingController();

  late String dolar; //armazena o valor do dólar retornado pelo API
  late String euro; //armazena o valor do euro retornado pelo API

  //método para limpar os 3 campos
  void _clearAll() {
    realController.text = "";
    dolarController.text = "";
    euroController.text = "";
  }

//método para alteração do valor em Real
  void _realChanged(String text) {
    if (text.isEmpty) {
      _clearAll();
      return;
    }
    double real = double.parse(text);
    dolarController.text = (real / double.parse(dolar)).toStringAsFixed(2);
    euroController.text = (real / double.parse(euro)).toStringAsFixed(2);
  }

//método para alteração do valor em Dólar
  void _dolarChanged(String text) {
    if (text.isEmpty) {
      _clearAll();
      return;
    }
    double dolar = double.parse(text);
    realController.text = (dolar * double.parse(this.dolar)).toStringAsFixed(2);
    euroController.text =
        (dolar * double.parse(this.dolar) / double.parse(euro))
            .toStringAsFixed(2);
  }

//método para alteração do valor em Euro
  void _euroChanged(String text) {
    if (text.isEmpty) {
      _clearAll();
      return;
    }
    double euro = double.parse(text);
    realController.text = (euro * double.parse(this.euro)).toStringAsFixed(2);
    dolarController.text =
        (euro * double.parse(this.euro) / double.parse(dolar))
            .toStringAsFixed(2);
  }

//método Build do Widget
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text("Conversor de moeda"),
          backgroundColor: Colors.green,
          centerTitle: true,
        ),

        //Monta o body assim que os dados chegarem da API (FutureBuilder)
        body: FutureBuilder<Map>(
            future: getData(),
            //snapshot se refere à conexão com a API
            builder: (context, snapshot) {
              switch (snapshot.connectionState) {
                case ConnectionState.none:
                case ConnectionState.waiting:
                  return const Center(
                      child: Text(
                        "Aguarde...",
                        style: TextStyle(color: Colors.green, fontSize: 30.0),
                        textAlign: TextAlign.center,
                      ));
                default:
                  if (snapshot.hasError) {
                    return const Center(
                        child: Text(
                          "Ops, houve uma falha ao buscar os dados",
                          style: TextStyle(color: Colors.green, fontSize: 25.0),
                          textAlign: TextAlign.center,
                        ));
                  } else {
                    dolar = snapshot.data!["USDBRL"]["high"];
                    euro = snapshot.data!["EURBRL"]["high"];
                    //retorna um Widget com relagem de tela
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const Icon(Icons.attach_money,
                              size: 180.0, color: Colors.green),
                          buildTextField(
                              "Reais", "R\$ ", realController, _realChanged),
                          const Divider(),
                          buildTextField(
                              "Euros", "€ ", euroController, _euroChanged),
                          const Divider(),
                          buildTextField("Dólares", "US\$ ", dolarController,
                              _dolarChanged),
                        ],
                      ),
                    );
                  }
              }
            }));
  }
}

//método para construir as caixas de texto
Widget buildTextField(
    String label, String prefix, TextEditingController c, Function(String) f) {
  return TextField(
    controller: c,
    decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.green),
        border: const OutlineInputBorder(),
        prefixText: prefix),
    style: const TextStyle(color: Colors.green, fontSize: 25.0),
    onChanged: f,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
  );
}