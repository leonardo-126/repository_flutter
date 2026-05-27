import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' show join;
import 'package:sqflite/sqflite.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MainApp());
}

// ============================================================
// MODEL
// ============================================================
class Entrega {
  final int? id;
  final String codigo;
  final String destinatario;
  final String endereco;
  final String status;
  final double latitude;
  final double longitude;
  final String dataEntrega;

  Entrega({
    this.id,
    required this.codigo,
    required this.destinatario,
    required this.endereco,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.dataEntrega,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'codigo': codigo,
        'destinatario': destinatario,
        'endereco': endereco,
        'status': status,
        'latitude': latitude,
        'longitude': longitude,
        'dataEntrega': dataEntrega,
      };

  factory Entrega.fromMap(Map<String, dynamic> map) => Entrega(
        id: map['id'] as int?,
        codigo: map['codigo'] as String,
        destinatario: map['destinatario'] as String,
        endereco: map['endereco'] as String,
        status: map['status'] as String,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        dataEntrega: map['dataEntrega'] as String,
      );
}

// ============================================================
// DATABASE
// ============================================================
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  Database? _db;

  Future<Database> get database async =>
      _db ??= await openDatabase(
        join(await getDatabasesPath(), 'entrega_database.db'),
        onCreate: (db, _) => db.execute(
          'CREATE TABLE entregas('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'codigo TEXT, destinatario TEXT, endereco TEXT, status TEXT, '
          'latitude REAL, longitude REAL, dataEntrega TEXT)',
        ),
        version: 1,
      );

  Future<int> insertEntrega(Entrega e) async => (await database).insert(
        'entregas',
        e.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<List<Entrega>> getEntregas() async {
    final maps = await (await database).query('entregas', orderBy: 'id DESC');
    return maps.map(Entrega.fromMap).toList();
  }

  Future<int> updateEntrega(Entrega e) async => (await database).update(
        'entregas',
        e.toMap(),
        where: 'id = ?',
        whereArgs: [e.id],
      );

  Future<int> deleteEntrega(int id) async =>
      (await database).delete('entregas', where: 'id = ?', whereArgs: [id]);
}

// ============================================================
// STATUS
// ============================================================
const _statusOpcoes = ['pendente', 'saiu para entrega', 'em transporte', 'entregue'];

({Color color, IconData icon}) _statusInfo(String s) => switch (s) {
      'pendente' => (color: const Color(0xFF6B7280), icon: Icons.schedule),
      'saiu para entrega' => (
          color: const Color(0xFFEA580C),
          icon: Icons.local_shipping_outlined,
        ),
      'em transporte' => (
          color: const Color(0xFF2563EB),
          icon: Icons.directions_car_filled_outlined,
        ),
      'entregue' => (
          color: const Color(0xFF16A34A),
          icon: Icons.check_circle_outline,
        ),
      _ => (color: const Color(0xFF6B7280), icon: Icons.help_outline),
    };

String _fmtData(String iso) {
  try {
    final d = DateTime.parse(iso).toLocal();
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year} ${p(d.hour)}:${p(d.minute)}';
  } catch (_) {
    return iso;
  }
}

// ============================================================
// APP
// ============================================================
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5));
    return MaterialApp(
      title: 'Entregas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// ============================================================
// HOME
// ============================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Entrega>> _future;

  @override
  void initState() {
    super.initState();
    _recarregar();
  }

  void _recarregar() => setState(() {
        _future = DatabaseHelper.instance.getEntregas();
      });

  Future<void> _abrirForm({Entrega? entrega}) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EntregaFormScreen(entrega: entrega)),
    );
    if (ok == true) _recarregar();
  }

  Future<void> _excluir(Entrega e) async {
    if (e.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir entrega'),
        content: Text('Deseja excluir ${e.codigo}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await DatabaseHelper.instance.deleteEntrega(e.id!);
      _recarregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entregas'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<List<Entrega>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Erro: ${snap.error}'));
          final entregas = snap.data ?? [];
          if (entregas.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text('Nenhuma entrega cadastrada',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Toque em + para adicionar',
                        style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _recarregar(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              itemCount: entregas.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _EntregaCard(
                entrega: entregas[i],
                onTap: () => _abrirForm(entrega: entregas[i]),
                onDelete: () => _excluir(entregas[i]),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirForm(),
        icon: const Icon(Icons.add),
        label: const Text('Nova'),
      ),
    );
  }
}

// ============================================================
// CARD
// ============================================================
class _EntregaCard extends StatelessWidget {
  final Entrega entrega;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _EntregaCard({
    required this.entrega,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final info = _statusInfo(entrega.status);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: info.color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(info.icon, color: info.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entrega.destinatario,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: info.color.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            entrega.status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: info.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text('#${entrega.codigo}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    Text(entrega.endereco,
                        style: const TextStyle(fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(_fmtData(entrega.dataEntrega),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.grey.shade500),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// FORM
// ============================================================
class EntregaFormScreen extends StatefulWidget {
  final Entrega? entrega;
  const EntregaFormScreen({super.key, this.entrega});
  @override
  State<EntregaFormScreen> createState() => _EntregaFormScreenState();
}

class _EntregaFormScreenState extends State<EntregaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codigoCtrl = TextEditingController();
  final _destinatarioCtrl = TextEditingController();
  final _enderecoCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  String _status = 'pendente';
  bool _obtendoLoc = false;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entrega;
    if (e != null) {
      _codigoCtrl.text = e.codigo;
      _destinatarioCtrl.text = e.destinatario;
      _enderecoCtrl.text = e.endereco;
      _latCtrl.text = e.latitude.toString();
      _lngCtrl.text = e.longitude.toString();
      _status = e.status;
    }
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _destinatarioCtrl.dispose();
    _enderecoCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _capturarLoc() async {
    setState(() => _obtendoLoc = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _msg('Ative o GPS do dispositivo.');
        return;
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        _msg('Permissão de localização negada.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _latCtrl.text = pos.latitude.toString();
      _lngCtrl.text = pos.longitude.toString();
    } catch (e) {
      _msg('Erro ao obter localização: $e');
    } finally {
      if (mounted) setState(() => _obtendoLoc = false);
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    final e = Entrega(
      id: widget.entrega?.id,
      codigo: _codigoCtrl.text.trim(),
      destinatario: _destinatarioCtrl.text.trim(),
      endereco: _enderecoCtrl.text.trim(),
      status: _status,
      latitude: double.tryParse(_latCtrl.text.replaceAll(',', '.')) ?? 0,
      longitude: double.tryParse(_lngCtrl.text.replaceAll(',', '.')) ?? 0,
      dataEntrega: DateTime.now().toIso8601String(),
    );
    if (widget.entrega == null) {
      await DatabaseHelper.instance.insertEntrega(e);
    } else {
      await DatabaseHelper.instance.updateEntrega(e);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  String? _obrig(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null;

  String? _num(String? v) {
    if (v == null || v.trim().isEmpty) return 'Campo obrigatório';
    if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Número inválido';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.entrega != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editando ? 'Editar entrega' : 'Nova entrega'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            TextFormField(
              controller: _codigoCtrl,
              decoration: const InputDecoration(
                labelText: 'Código',
                prefixIcon: Icon(Icons.qr_code_2_outlined),
              ),
              validator: _obrig,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _destinatarioCtrl,
              decoration: const InputDecoration(
                labelText: 'Destinatário',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: _obrig,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _enderecoCtrl,
              decoration: const InputDecoration(
                labelText: 'Endereço',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              validator: _obrig,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                prefixIcon: Icon(Icons.label_outline),
              ),
              items: _statusOpcoes
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _status = v ?? 'pendente'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latCtrl,
                    decoration: const InputDecoration(labelText: 'Latitude'),
                    keyboardType: const TextInputType.numberWithOptions(
                        signed: true, decimal: true),
                    validator: _num,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _lngCtrl,
                    decoration: const InputDecoration(labelText: 'Longitude'),
                    keyboardType: const TextInputType.numberWithOptions(
                        signed: true, decimal: true),
                    validator: _num,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _obtendoLoc ? null : _capturarLoc,
              icon: _obtendoLoc
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: const Text('Usar localização atual'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _salvando ? null : _salvar,
            icon: const Icon(Icons.save_outlined),
            label: Text(editando ? 'Atualizar' : 'Salvar'),
          ),
        ),
      ),
    );
  }
}
