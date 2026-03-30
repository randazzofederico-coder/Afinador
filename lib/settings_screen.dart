import 'package:flutter/material.dart';
import 'audio_tuner_service.dart';

class SettingsScreen extends StatelessWidget {
  final AudioTunerService tunerService;

  const SettingsScreen({super.key, required this.tunerService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Afinación de Referencia',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<double>(
            valueListenable: tunerService.referencePitch,
            builder: (context, refPitch, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      if (refPitch > 400.0) {
                        tunerService.setReferencePitch(refPitch - 1.0);
                      }
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                    iconSize: 40,
                  ),
                  const SizedBox(width: 20),
                  Text(
                    '${refPitch.toInt()} Hz',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    onPressed: () {
                      if (refPitch < 480.0) {
                        tunerService.setReferencePitch(refPitch + 1.0);
                      }
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    iconSize: 40,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              'Transposición de Instrumento',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          ValueListenableBuilder<int>(
            valueListenable: tunerService.transposition,
            builder: (context, transposeVal, _) {
              return DropdownButtonFormField<int>(
                value: transposeVal,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 0, child: Text("C (0, Sin transposición)")),
                  DropdownMenuItem(value: 1, child: Text("Db (+1)")),
                  DropdownMenuItem(value: 2, child: Text("D (+2)")),
                  DropdownMenuItem(value: 3, child: Text("Eb (+3, Saxo Alto/Barítono)")),
                  DropdownMenuItem(value: 4, child: Text("E (+4)")),
                  DropdownMenuItem(value: 5, child: Text("F (+5, Corno Francés)")),
                  DropdownMenuItem(value: 6, child: Text("Gb (+6)")),
                  DropdownMenuItem(value: -5, child: Text("G (-5)")),
                  DropdownMenuItem(value: -4, child: Text("Ab (-4)")),
                  DropdownMenuItem(value: -3, child: Text("A (-3)")),
                  DropdownMenuItem(value: -2, child: Text("Bb (-2, Trompeta/Clarinete/Tenor)")),
                  DropdownMenuItem(value: -1, child: Text("B (-1)")),
                ],
                onChanged: (int? newValue) {
                  if (newValue != null) {
                    tunerService.setTransposition(newValue);
                  }
                },
              );
            },
          ),
          const SizedBox(height: 32),
          const Divider(),
          ValueListenableBuilder<bool>(
            valueListenable: tunerService.keepScreenOn,
            builder: (context, keepOn, _) {
              return SwitchListTile(
                title: const Text('Mantener pantalla encendida', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Evita que el dispositivo se bloquee mientras afinas'),
                value: keepOn,
                onChanged: (bool value) {
                  tunerService.setKeepScreenOn(value);
                },
                activeColor: Colors.blueAccent,
              );
            },
          ),
        ],
      ),
    );
  }
}
