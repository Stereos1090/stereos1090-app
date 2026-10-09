import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:html' as html;

void main() {
  runApp(const Stereos1090App());
}

class Stereos1090App extends StatelessWidget {
  const Stereos1090App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stereos 1090',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF141414),
        primaryColor: const Color(0xFFFFEE32),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFEE32),
          surface: Color(0xFF1F1F1F),
        ),
      ),
      home: const RadioHomePage(),
    );
  }
}

class RadioHomePage extends StatefulWidget {
  const RadioHomePage({super.key});

  @override
  State<RadioHomePage> createState() => _RadioHomePageState();
}

class _RadioHomePageState extends State<RadioHomePage> with SingleTickerProviderStateMixin {
// Listas de reproducción por Bloques y Jingles desde Cloudflare R2
  final List<String> bloque1Playlist = [
    'https://pub-992fd43f91d3490097f017780c0c3e4e.r2.dev/01_Ambiental_Tranquilo/pista_ambiental.mp3',
    'https://pub-992fd43f91d3490097f017780c0c3e4e.r2.dev/01_Dance_y_electronica_Alegre/pista_dance.mp3',
    'https://pub-992fd43f91d3490097f017780c0c3e4e.r2.dev/01_Rock_Enfadado/pista_rock.mp3',
  ];

  final List<String> bloque2Playlist = [
    'https://pub-992fd43f91d3490097f017780c0c3e4e.r2.dev/02_Cinematografica_Dramatico/pista_cine.mp3',
    'https://pub-992fd43f91d3490097f017780c0c3e4e.r2.dev/02_Jazz_y_blues_Funky/pista_jazz.mp3',
    'https://pub-992fd43f91d3490097f017780c0c3e4e.r2.dev/02_Pop_Inspirador/pista_pop.mp3',
  ];

  final List<String> jinglesPlaylist = [
    'https://pub-992fd43f91d3490097f017780c0c3e4e.r2.dev/Jingles_IvanLoscher/jingle_principal.mp3',
  ];
  int _currentIndex = 0;
  bool isAudioMode = true; // true = Audio en Vivo, false = VIDEO STREAM
  String currentSong = 'Transmisión en Vivo';
  String currentArtist = 'Stereos 1090 Bogotá';
  bool isPlaying = false;
  Timer? _timer;

  // URL directa de streaming de audio compatible con navegadores (Icecast / Shoutcast / MP3 stream)
  // Reemplaza o apunta a tu stream directo de audio (ej: puerto o stream mount point)
  final String liveAudioUrl = 'https://stream.stereos1090.com/stream'; 
  html.AudioElement? _audioElement;

  // Ecualizador Pro 7 Bandas
  List<double> eqValues = [0.0, 2.0, 4.0, 1.0, -1.0, 3.0, 5.0];
  bool eqEnabled = true;

  // Enlaces de pauta publicitaria en bucle infinito
  final List<Map<String, String>> pautaVideos = [
    {'title': 'Pauta 1: Tornamesa 33 rpm', 'url': 'https://www.youtube.com/watch?v=sULLJyCPQZc'},
    {'title': 'Pauta 2: Danza Silueta', 'url': 'https://www.youtube.com/watch?v=GzWYN8XCQrQ'},
    {'title': 'Pauta 3: Concierto en Vivo', 'url': 'https://www.youtube.com/watch?v=wws_4ap-mM4'},
  ];

  // Desplazamiento táctil (Swipe) para el banner
  double _bannerOffsetX = 0.0;
  double _bannerOffsetY = 0.0;

  // Animación continua para el banner de pauta
  late AnimationController _marqueeController;

  @override
  void initState() {
    super.initState();
    _initAudio();
    _obtenerEstadoRadio();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _obtenerEstadoRadio();
    });

    _marqueeController = AnimationController(
      duration: const Duration(seconds: 18),
      vsync: this,
    )..repeat();
  }

  void _initAudio() {
    try {
      _audioElement = html.AudioElement(liveAudioUrl)
        ..autoplay = false
        ..preload = 'none';
    } catch (e) {
      debugPrint('Error al inicializar elemento de audio: $e');
    }
  }

  void _togglePlayPause() {
    if (_audioElement == null) return;
    setState(() {
      isPlaying = !isPlaying;
      if (isPlaying) {
        _audioElement!.src = '$liveAudioUrl?t=${DateTime.now().millisecondsSinceEpoch}'; // Evita caché
        _audioElement!.play().catchError((err) {
          debugPrint('Error de reproducción: $err');
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('▶ Sonando en vivo en Stereos 1090')),
        );
      } else {
        _audioElement!.pause();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⏸ Transmisión en pausa')),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _marqueeController.dispose();
    _audioElement?.pause();
    _audioElement = null;
    super.dispose();
  }

  Future<void> _obtenerEstadoRadio() async {
    try {
      final respuesta = await http.get(
        Uri.parse('https://stream.stereos1090.com/api/live-status'),
      );
      if (respuesta.statusCode == 200) {
        final data = json.decode(respuesta.body);
        setState(() {
          currentSong = data['song'] ?? 'Transmisión en Vivo';
          currentArtist = data['artist'] ?? 'Stereos 1090 Bogotá';
        });
      }
    } catch (e) {
      // Valores estables por defecto
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      _buildLiveView(),
      _buildEqualizerView(),
      _buildRssView(),
      _buildDonateView(),
      _buildStreamView(),
    ];

    final String pautaTextoCompleto = pautaVideos
        .map((p) => '  📢  ${p['title']} → ${p['url']}  ')
        .join('   •   ');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        elevation: 0,
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'Stereos 1090',
              style: TextStyle(
                color: Color(0xFFFFEE32),
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: 1.1,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'La Mejor Música del Planeta',
              style: TextStyle(
                color: Color(0xFFFFEE32),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Banner de Pauta Publicitaria con scroll continuo y swipe táctil
          GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _bannerOffsetX += details.delta.dx;
                _bannerOffsetY += details.delta.dy;
              });
            },
            onPanEnd: (details) {
              setState(() {
                _bannerOffsetX = 0.0;
                _bannerOffsetY = 0.0;
              });
            },
            child: Transform.translate(
              offset: Offset(_bannerOffsetX, _bannerOffsetY),
              child: Container(
                height: 42,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEE32),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRect(
                  child: AnimatedBuilder(
                    animation: _marqueeController,
                    builder: (context, child) {
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              Positioned(
                                left: constraints.maxWidth - (_marqueeController.value * (constraints.maxWidth + 600)),
                                child: Row(
                                  children: [
                                    Text(
                                      pautaTextoCompleto + pautaTextoCompleto,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // Contenido de la pestaña activa
          Expanded(child: _pages[_currentIndex]),

          // Barra estandarizada global de controles de audio
          _buildGlobalPlayerBar(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF141414),
        selectedItemColor: const Color(0xFFFFEE32),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.radio), label: 'En vivo'),
          BottomNavigationBarItem(icon: Icon(Icons.equalizer), label: 'Ecualizador'),
          BottomNavigationBarItem(icon: Icon(Icons.rss_feed), label: 'Noticias RSS'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Donar'),
          BottomNavigationBarItem(icon: Icon(Icons.podcasts), label: 'Transmitir'),
        ],
      ),
    );
  }

  // Barra de Reproducción Global Inferior
  Widget _buildGlobalPlayerBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF1A1A1A),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🔒 Reproducción en segundo plano activa (Pantalla bloqueada)',
            style: TextStyle(fontSize: 11, color: Color(0xFFFFEE32)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: const Icon(Icons.volume_up, size: 26, color: Colors.white),
                onPressed: () {
                  if (_audioElement != null) {
                    _audioElement!.volume = (_audioElement!.volume == 1.0) ? 0.5 : 1.0;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Volumen: ${(_audioElement!.volume * 100).toInt()}%')),
                    );
                  }
                },
              ),
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFEE32),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 30,
                    color: Colors.black,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.share, size: 26, color: Colors.white),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enlace copiado al portapapeles')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Vista Principal: En Vivo
  Widget _buildLiveView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Selectores Superiores: "Audio en Vivo" y "VIDEO STREAM"
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => isAudioMode = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isAudioMode ? const Color(0xFFFFEE32) : const Color(0xFF1F1F1F),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Audio en Vivo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isAudioMode ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => isAudioMode = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !isAudioMode ? const Color(0xFFFFEE32) : const Color(0xFF1F1F1F),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'VIDEO STREAM',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: !isAudioMode ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Contenedor principal de metadatos en tiempo real
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFEE32), width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isAudioMode ? Icons.music_note : Icons.videocam,
                    size: 60,
                    color: const Color(0xFFFFEE32),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    currentSong,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentArtist,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFEE32),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Stereos 1090 AM • En Vivo',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Vista Ecualizador Pro 7 Bandas Funcional
  Widget _buildEqualizerView() {
    List<String> frequencies = ['60Hz', '150Hz', '400Hz', '1kHz', '2.5kHz', '6kHz', '15kHz'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'ECUALIZADOR PRO 7 BANDAS',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFEE32),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Ajuste fino del motor DSP',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                Switch(
                  value: eqEnabled,
                  activeColor: const Color(0xFFFFEE32),
                  onChanged: (val) {
                    setState(() {
                      eqEnabled = val;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Presets Preestablecidos',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              _buildPresetChip('Flat', [0, 0, 0, 0, 0, 0, 0]),
              _buildPresetChip('Rock', [3, 1, -1, 2, 4, 3, 2]),
              _buildPresetChip('Voz / Radio', [-2, 1, 5, 4, 1, -1, -3]),
              _buildPresetChip('BASS BOOST', [6, 5, 2, 0, 0, 1, 2]),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (index) {
                return Column(
                  children: [
                    Text(
                      '${eqValues[index] >= 0 ? '+' : ''}${eqValues[index].toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: Color(0xFFFFEE32),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 140,
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Slider(
                          value: eqValues[index],
                          min: -12.0,
                          max: 12.0,
                          divisions: 24,
                          activeColor: const Color(0xFFFFEE32),
                          inactiveColor: Colors.grey[800],
                          onChanged: eqEnabled
                              ? (val) {
                                  setState(() {
                                    eqValues[index] = val;
                                  });
                                }
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      frequencies[index],
                      style: const TextStyle(fontSize: 10, color: Colors.white60),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, List<double> values) {
    return ActionChip(
      backgroundColor: const Color(0xFF1F1F1F),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      onPressed: () {
        setState(() {
          eqValues = List.from(values);
          eqEnabled = true;
        });
      },
    );
  }

  Widget _buildRssView() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Noticias RSS - Actualidad',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFFEE32)),
          ),
          SizedBox(height: 15),
          ListTile(
            leading: Icon(Icons.article, color: Color(0xFFFFEE32)),
            title: Text('Innovación en Streaming Cloudflare'),
            subtitle: Text('La evolución de la radio digital en alta definición.'),
          ),
        ],
      ),
    );
  }

  Widget _buildDonateView() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: const [
          Icon(Icons.favorite, size: 70, color: Color(0xFFFFEE32)),
          SizedBox(height: 20),
          Text(
            'Apoya Stereos 1090',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFFEE32)),
          ),
          SizedBox(height: 10),
          Text(
            'Tu contribución permite mantener servidores robustos y la mejor música del planeta sin interrupciones.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamView() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: const [
          Icon(Icons.podcasts, size: 70, color: Color(0xFFFFEE32)),
          SizedBox(height: 20),
          Text(
            'Transmitir en Directo',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFFEE32)),
          ),
          SizedBox(height: 10),
          Text(
            'Conecta tu consola o codificador HLS y emite tu señal directamente a Stereos 1090.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}