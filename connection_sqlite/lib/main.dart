import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' show join;
import 'package:sqflite/sqflite.dart';

import 'crud/fetch_data.dart';
import 'crud/insert_data.dart';
import 'crud/update_data.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializa o Firebase. Se falhar (ex.: sem configuração na plataforma),
  // o app continua funcionando apenas com o SQLite local.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Cache offline nativo do Realtime Database (Android/iOS):
    // mantém os últimos dados e enfileira escritas feitas offline.
    if (!kIsWeb) {
      FirebaseDatabase.instance.setPersistenceEnabled(true);
    }
  } catch (e) {
    debugPrint('Firebase indisponível, usando apenas SQLite: $e');
  }
  runApp(const MainApp());
}

class Entrega {
  /// Chave única compartilhada pelos dois bancos (SQLite e Realtime Database),
  /// o que mantém os dois sempre sincronizados pelo mesmo identificador.
  final String id;
  final String codigo;
  final String destinatario;
  final String endereco;
  final String status;
  final double latitude;
  final double longitude;
  final String dataEntrega;

  Entrega({
    required this.id,
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
        id: map['id'].toString(),
        codigo: map['codigo'] as String,
        destinatario: map['destinatario'] as String,
        endereco: map['endereco'] as String,
        status: map['status'] as String,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        dataEntrega: map['dataEntrega'] as String,
      );
}

/// Acesso ao banco local SQLite. Funciona como cache offline: tudo que vem do
/// Firebase é espelhado aqui para ser exibido quando não houver conexão.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  Database? _db;

  Future<Database> get database async =>
      _db ??= await openDatabase(
        join(await getDatabasesPath(), 'entrega_database.db'),
        onCreate: (db, _) => db.execute(
          'CREATE TABLE entregas('
          'id TEXT PRIMARY KEY, '
          'codigo TEXT, destinatario TEXT, endereco TEXT, status TEXT, '
          'latitude REAL, longitude REAL, dataEntrega TEXT)',
        ),
        version: 2,
      );

  /// Insere ou atualiza (mesmo id sobrescreve) uma entrega.
  Future<void> upsertEntrega(Entrega e) async => (await database).insert(
        'entregas',
        e.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<List<Entrega>> getEntregas() async {
    final maps =
        await (await database).query('entregas', orderBy: 'dataEntrega DESC');
    return maps.map(Entrega.fromMap).toList();
  }

  Future<void> deleteEntrega(String id) async =>
      (await database).delete('entregas', where: 'id = ?', whereArgs: [id]);

  /// Substitui todo o conteúdo local pela lista vinda do Firebase, mantendo
  /// o SQLite como espelho fiel do banco remoto.
  Future<void> replaceAll(List<Entrega> entregas) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('entregas');
    for (final e in entregas) {
      batch.insert('entregas', e.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }
}

/// Resultado emitido pelo repositório: a lista de entregas e se os dados estão
/// vindo do Firebase em tempo real (online) ou do cache local (offline).
class EntregaSnapshot {
  final List<Entrega> entregas;
  final bool online;
  const EntregaSnapshot(this.entregas, {required this.online});
}

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Stream<EntregaSnapshot> _stream;

  @override
  void initState() {
    super.initState();
    _stream = observarEntregas();
  }

  Future<void> _abrirForm({Entrega? entrega}) async {
    // O stream em tempo real já atualiza a lista sozinho após salvar.
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EntregaFormScreen(entrega: entrega)),
    );
  }

  Future<void> _verNoMapa(Entrega e) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MapaVisualizacaoScreen(entrega: e)),
    );
  }

  Future<void> _excluir(Entrega e) async {
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
      await excluirEntrega(e.id);
    }
  }

  Widget _vazio() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text('Nenhuma entrega cadastrada',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Toque em + para adicionar',
                  style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entregas'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<EntregaSnapshot>(
        stream: _stream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final online = snap.data!.online;
          final entregas = snap.data!.entregas;
          return Column(
            children: [
              _BannerConexao(online: online),
              Expanded(
                child: entregas.isEmpty
                    ? _vazio()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                        itemCount: entregas.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _EntregaCard(
                          entrega: entregas[i],
                          onTap: () => _abrirForm(entrega: entregas[i]),
                          onDelete: () => _excluir(entregas[i]),
                          onVerMapa: () => _verNoMapa(entregas[i]),
                        ),
                      ),
              ),
            ],
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

/// Faixa que indica se os dados estão sincronizados com o Firebase (online)
/// ou sendo exibidos a partir do cache local do SQLite (offline).
class _BannerConexao extends StatelessWidget {
  final bool online;
  const _BannerConexao({required this.online});

  @override
  Widget build(BuildContext context) {
    final cor = online ? const Color(0xFF16A34A) : const Color(0xFFEA580C);
    return Container(
      width: double.infinity,
      color: cor.withValues(alpha: .12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
              size: 16, color: cor),
          const SizedBox(width: 6),
          Text(
            online
                ? 'Sincronizado em tempo real com o Firebase'
                : 'Offline — exibindo dados locais (SQLite)',
            style: TextStyle(
                fontSize: 12, color: cor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
class _EntregaCard extends StatelessWidget {
  final Entrega entrega;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onVerMapa;

  const _EntregaCard({
    required this.entrega,
    required this.onTap,
    required this.onDelete,
    required this.onVerMapa,
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
                    const SizedBox(height: 4),
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
                icon: Icon(Icons.map_outlined,
                    color: Theme.of(context).colorScheme.primary),
                tooltip: 'Ver no mapa',
                onPressed: onVerMapa,
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.grey.shade500),
                tooltip: 'Excluir',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MapaVisualizacaoScreen extends StatefulWidget {
  final Entrega entrega;
  const MapaVisualizacaoScreen({super.key, required this.entrega});

  @override
  State<MapaVisualizacaoScreen> createState() => _MapaVisualizacaoScreenState();
}

class _MapaVisualizacaoScreenState extends State<MapaVisualizacaoScreen> {
  final MapController _mapController = MapController();
  LatLng? _minhaLocalizacao;

  @override
  void initState() {
    super.initState();
    _obterMinhaLocalizacao();
  }

  Future<void> _obterMinhaLocalizacao() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _minhaLocalizacao = LatLng(pos.latitude, pos.longitude);
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final destino = LatLng(widget.entrega.latitude, widget.entrega.longitude);
    final info = _statusInfo(widget.entrega.status);

    return Scaffold(
      appBar: AppBar(
        title: Text('Entrega #${widget.entrega.codigo}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: destino,
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.connection_sqlite',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: destino,
                    width: 40,
                    height: 40,
                    child: Icon(Icons.location_pin, color: info.color, size: 40),
                  ),
                  if (_minhaLocalizacao != null)
                    Marker(
                      point: _minhaLocalizacao!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_pin, color: Color(0xFF2563EB), size: 40),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 20,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: info.color.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(info.icon, color: info.color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.entrega.destinatario,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700),
                              ),
                              Text(
                                '#${widget.entrega.codigo}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: info.color.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.entrega.status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: info.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.place_outlined,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.entrega.endereco,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.entrega.latitude.toStringAsFixed(5)}, '
                          '${widget.entrega.longitude.toStringAsFixed(5)}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: FloatingActionButton.small(
              heroTag: 'center',
              onPressed: () {
                _mapController.move(destino, 15);
              },
              tooltip: 'Centralizar no destino',
              child: const Icon(Icons.center_focus_strong),
            ),
          ),
        ],
      ),
    );
  }
}

class MapaSelecionarScreen extends StatefulWidget {
  final LatLng? inicial;
  const MapaSelecionarScreen({super.key, this.inicial});

  @override
  State<MapaSelecionarScreen> createState() => _MapaSelecionarScreenState();
}

class _MapaSelecionarScreenState extends State<MapaSelecionarScreen> {
  LatLng? _selecionado;
  bool _carregandoLoc = false;

  @override
  void initState() {
    super.initState();
    _selecionado = widget.inicial;
  }

  Future<void> _irParaMinhaLocalizacao(MapController ctrl) async {
    setState(() => _carregandoLoc = true);
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permissão de localização negada.')),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      final loc = LatLng(pos.latitude, pos.longitude);
      ctrl.move(loc, 16);
      setState(() => _selecionado = loc);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _carregandoLoc = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = MapController();
    final centro = _selecionado ?? const LatLng(-15.7801, -47.9292);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecionar localização'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_selecionado != null)
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(_selecionado),
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('Confirmar',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: ctrl,
            options: MapOptions(
              initialCenter: centro,
              initialZoom: 14,
              onTap: (_, point) {
                setState(() => _selecionado = point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.connection_sqlite',
              ),
              if (_selecionado != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selecionado!,
                      width: 40,
                      height: 40,
                      child: Builder(
                        builder: (context) => Icon(
                          Icons.location_pin,
                          color: Theme.of(context).colorScheme.primary,
                          size: 40,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .08),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.touch_app_outlined,
                      color: Theme.of(context).colorScheme.primary, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Toque no mapa para marcar a localização de entrega',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: _selecionado != null ? 90 : 20,
            child: FloatingActionButton.small(
              heroTag: 'myLoc',
              onPressed: _carregandoLoc
                  ? null
                  : () => _irParaMinhaLocalizacao(ctrl),
              tooltip: 'Minha localização',
              child: _carregandoLoc
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
          if (_selecionado != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 20,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      Icon(Icons.location_on,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Local selecionado',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                            Text(
                              'Lat: ${_selecionado!.latitude.toStringAsFixed(5)}  '
                              'Lng: ${_selecionado!.longitude.toStringAsFixed(5)}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: () =>
                            Navigator.of(context).pop(_selecionado),
                        child: const Text('Usar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _selecionarNoMapa() async {
    LatLng? inicial;
    final lat = double.tryParse(_latCtrl.text.replaceAll(',', '.'));
    final lng = double.tryParse(_lngCtrl.text.replaceAll(',', '.'));
    if (lat != null && lng != null) {
      inicial = LatLng(lat, lng);
    }

    final resultado = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => MapaSelecionarScreen(inicial: inicial),
      ),
    );

    if (resultado != null) {
      setState(() {
        _latCtrl.text = resultado.latitude.toStringAsFixed(6);
        _lngCtrl.text = resultado.longitude.toStringAsFixed(6);
      });
    }
  }

  Future<void> _capturarLoc() async {
    setState(() => _obtendoLoc = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _msg('Ative o GPS do dispositivo.');
        return;
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        _msg('Permissão de localização negada.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        _latCtrl.text = pos.latitude.toStringAsFixed(6);
        _lngCtrl.text = pos.longitude.toStringAsFixed(6);
      });
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
      // Mantém o id ao editar; gera um novo (válido nos dois bancos) ao criar.
      id: widget.entrega?.id ?? novoIdEntrega(),
      codigo: _codigoCtrl.text.trim(),
      destinatario: _destinatarioCtrl.text.trim(),
      endereco: _enderecoCtrl.text.trim(),
      status: _status,
      latitude: double.tryParse(_latCtrl.text.replaceAll(',', '.')) ?? 0,
      longitude:
          double.tryParse(_lngCtrl.text.replaceAll(',', '.')) ?? 0,
      dataEntrega: DateTime.now().toIso8601String(),
    );
    // Grava nos DOIS bancos (SQLite + Realtime Database).
    if (widget.entrega == null) {
      await inserirEntrega(e); // crud/insert_data.dart
    } else {
      await atualizarEntrega(e); // crud/update_data.dart
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  String? _obrig(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null;

  String? _num(String? v) {
    if (v == null || v.trim().isEmpty) return 'Campo obrigatório';
    if (double.tryParse(v.replaceAll(',', '.')) == null) {
      return 'Número inválido';
    }
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
                  .map((s) =>
                      DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _status = v ?? 'pendente'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        signed: true, decimal: true),
                    validator: _num,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _lngCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        signed: true, decimal: true),
                    validator: _num,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _selecionarNoMapa,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Selecionar no mapa'),
              style: FilledButton.styleFrom(
                backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _obtendoLoc ? null : _capturarLoc,
              icon: _obtendoLoc
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: const Text('Usar localização atual (GPS)'),
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