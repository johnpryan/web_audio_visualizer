import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

late FragmentProgram fragmentProgram;

main() async {
  fragmentProgram =
  await FragmentProgram.fromAsset('assets/shaders/visualizer.frag');
  runApp(const WebAudioVisualizerApp());
}

class WebAudioVisualizerApp extends StatelessWidget {
  const WebAudioVisualizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const WebAudioVisualizerScreen(),
    );
  }
}

enum PlayerState {
  init,
  loading,
  playing,
}

class WebAudioVisualizerScreen extends StatefulWidget {
  const WebAudioVisualizerScreen({super.key});

  @override
  State<WebAudioVisualizerScreen> createState() =>
      _WebAudioVisualizerScreenState();
}

class _WebAudioVisualizerScreenState extends State<WebAudioVisualizerScreen> {
  Uint8List? freqData;
  Uint8List? timeData;
  PlayerState playerState = PlayerState.init;

  double get audioIntensity {
    var value = (freqData?.first.toDouble() ?? 0.0) / 150;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: switch (playerState) {
        PlayerState.init => Center(
          child: IconButton(
            onPressed: _handlePlay,
            icon: const Icon(Icons.play_arrow),
          ),
        ),
        PlayerState.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        PlayerState.playing => SizedBox.expand(
          child: WebAudioVisualizer(
            intensity: audioIntensity,
          ),
        )
      },
    );
  }

  Future<void> _handlePlay() async {
    setState(() {
      playerState = PlayerState.loading;
    });
    var audioFile = await http.get(Uri.parse('/audio.mp3'));
    var audioContext = web.AudioContext();
    var analyser = audioContext.createAnalyser();
    analyser.connect(audioContext.destination);

    // A JSUint8Array
    var jsArrayBuffer = audioFile.bodyBytes.buffer.toJS;

    // Decode the audio file
    var buffer = await audioContext.decodeAudioData(jsArrayBuffer).toDart
    as web.AudioBuffer;

    // Play the sound
    var source = audioContext.createBufferSource();
    source.buffer = buffer;
    source.connect(analyser);
    source.start();

    // Tickers / postFrameCallback
    // WidgetsBinding
    Stream.periodic(const Duration(milliseconds: 16)).listen((event) {
      var fftSize = analyser.fftSize.toInt();
      var freqByteData = Uint8List(analyser.frequencyBinCount.toInt()).toJS;
      var timeByteData = Uint8List(fftSize.toInt()).toJS;
      analyser.getByteFrequencyData(freqByteData);
      analyser.getByteTimeDomainData(timeByteData);
      setState(() {
        freqData = freqByteData.toDart;
        timeData = timeByteData.toDart;
      });
    });
    setState(() {
      playerState = PlayerState.playing;
    });
  }
}

class WebAudioVisualizer extends StatefulWidget {
  final double intensity;
  const WebAudioVisualizer({required this.intensity, super.key});

  @override
  State<WebAudioVisualizer> createState() => _WebAudioVisualizerState();
}

class _WebAudioVisualizerState extends State<WebAudioVisualizer>
    with TickerProviderStateMixin {
  late final AnimationController _colorController;
  late final Animation<Color?> _colorAnimation;

  void initState() {
    _colorController = AnimationController(vsync: this)
      ..addListener(() {
        setState(() {});
      })
      ..repeat(reverse: true, period: const Duration(seconds: 5));
    _colorAnimation = ColorTween(begin: Colors.red, end: Colors.blue)
        .animate(_colorController);
    super.initState();
  }

  void dispose() {
    super.dispose();
    _colorController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: AudioVisualizerPainter(
        color: _colorAnimation.value ?? Colors.white,
        shader: fragmentProgram.fragmentShader(),
        intensity: widget.intensity,
      ),
    );
  }
}

class AudioVisualizerPainter extends CustomPainter {
  final FragmentShader shader;
  final double intensity;
  final Color color;

  AudioVisualizerPainter(
      {required this.shader, required this.color, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, color.red.toDouble() / 255);
    shader.setFloat(3, color.green.toDouble() / 255);
    shader.setFloat(4, color.blue.toDouble() / 255);
    shader.setFloat(5, color.alpha.toDouble() / 255);
    shader.setFloat(6, intensity);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(AudioVisualizerPainter oldDelegate) {
    return intensity != oldDelegate.intensity;
  }
}
