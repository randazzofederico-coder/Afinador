import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'audio_tuner_service.dart';
import 'pwa_install_service.dart';

/// Returns true when running on a desktop-class platform (web, Windows, macOS, Linux).
bool get _isDesktopPlatform {
  if (kIsWeb) return true;
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}

class SettingsScreen extends StatefulWidget {
  final AudioTunerService tunerService;

  const SettingsScreen({super.key, required this.tunerService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    if (_isDesktopPlatform) {
      widget.tunerService.listInputDevices();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pwaService = PwaInstallService();

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
            valueListenable: widget.tunerService.referencePitch,
            builder: (context, refPitch, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      if (refPitch > 400.0) {
                        widget.tunerService.setReferencePitch(refPitch - 1.0);
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
                        widget.tunerService.setReferencePitch(refPitch + 1.0);
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
            valueListenable: widget.tunerService.transposition,
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
                    widget.tunerService.setTransposition(newValue);
                  }
                },
              );
            },
          ),
          const SizedBox(height: 32),
          const Divider(),
          ValueListenableBuilder<bool>(
            valueListenable: widget.tunerService.keepScreenOn,
            builder: (context, keepOn, _) {
              return SwitchListTile(
                title: const Text('Mantener pantalla encendida', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Evita que el dispositivo se bloquee mientras afinas'),
                value: keepOn,
                onChanged: (bool value) {
                  widget.tunerService.setKeepScreenOn(value);
                },
                activeColor: Colors.blueAccent,
              );
            },
          ),

          // --- Microphone Input Selection (only on desktop/web) ---
          if (_isDesktopPlatform) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            _MicrophoneSelector(tunerService: widget.tunerService),
          ],

          // --- PWA Install Section (only visible on web) ---
          if (kIsWeb) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            ValueListenableBuilder<bool>(
              valueListenable: pwaService.isInstalled,
              builder: (context, isInstalled, _) {
                if (isInstalled) {
                  return const _InstalledBanner();
                }

                return ValueListenableBuilder<bool>(
                  valueListenable: pwaService.canInstall,
                  builder: (context, canInstall, _) {
                    if (canInstall) {
                      return _InstallButton(
                        onPressed: () async {
                          await pwaService.promptInstall();
                        },
                      );
                    }

                    // Browser doesn't support install prompt or conditions not met
                    return const _ManualInstallInfo();
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Microphone selection dropdown widget.
class _MicrophoneSelector extends StatelessWidget {
  final AudioTunerService tunerService;

  const _MicrophoneSelector({required this.tunerService});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<InputDevice>>(
      valueListenable: tunerService.availableDevices,
      builder: (context, devices, _) {
        return ValueListenableBuilder<InputDevice?>(
          valueListenable: tunerService.selectedDevice,
          builder: (context, selected, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.mic, color: Colors.blueAccent, size: 24),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Micrófono de Entrada',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 22),
                      tooltip: 'Actualizar dispositivos',
                      onPressed: () {
                        tunerService.listInputDevices();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Seleccioná qué micrófono usar para la afinación',
                  style: TextStyle(fontSize: 13, color: Colors.white54),
                ),
                const SizedBox(height: 12),
                if (devices.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No se detectaron dispositivos de entrada.',
                            style: TextStyle(fontSize: 13, color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: selected?.id,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      prefixIcon: const Icon(Icons.settings_input_component, size: 20),
                      suffixIcon: selected != null
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              tooltip: 'Usar micrófono por defecto del sistema',
                              onPressed: () {
                                tunerService.setSelectedDevice(null);
                              },
                            )
                          : null,
                    ),
                    isExpanded: true,
                    hint: const Text('Micrófono por defecto del sistema'),
                    items: devices.map((device) {
                      return DropdownMenuItem<String>(
                        value: device.id,
                        child: Text(
                          device.label.isNotEmpty ? device.label : 'Dispositivo ${device.id}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (String? deviceId) {
                      if (deviceId != null) {
                        final device = devices.firstWhere((d) => d.id == deviceId);
                        tunerService.setSelectedDevice(device);
                      }
                    },
                  ),
                if (selected != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Colors.blueAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Usando: ${selected.label.isNotEmpty ? selected.label : selected.id}',
                            style: const TextStyle(fontSize: 12, color: Colors.blueAccent),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ValueListenableBuilder<double>(
                  valueListenable: tunerService.currentVolume,
                  builder: (context, volume, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Actividad del Micrófono',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Stack(
                                  children: [
                                    ClipRect(
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: volume.clamp(0.0, 1.0),
                                        child: Container(
                                          width: constraints.maxWidth,
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [Colors.redAccent, Colors.amber, Colors.greenAccent],
                                              stops: [0.0, 0.5, 1.0],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Button shown when the browser supports PWA install and the prompt is available.
class _InstallButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _InstallButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.download_rounded, size: 48, color: Colors.blueAccent),
        const SizedBox(height: 12),
        const Text(
          'Instalar Aplicación',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Instalá el Afinador en tu dispositivo para acceso rápido y uso sin conexión.',
          style: TextStyle(fontSize: 14, color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.install_mobile),
            label: const Text('Instalar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Banner shown when the app is already installed (running in standalone mode).
class _InstalledBanner extends StatelessWidget {
  const _InstalledBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.greenAccent, size: 32),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'App Instalada',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                ),
                SizedBox(height: 4),
                Text(
                  'Estás usando la versión instalada del Afinador.',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Info card shown when the browser doesn't support the install prompt
/// (e.g. Safari, Firefox) with manual installation instructions.
class _ManualInstallInfo extends StatelessWidget {
  const _ManualInstallInfo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blueAccent, size: 28),
              SizedBox(width: 10),
              Text(
                'Instalar Aplicación',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Podés instalar esta app desde el menú de tu navegador:',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          SizedBox(height: 10),
          _InstructionStep(
            icon: Icons.phone_android,
            label: 'Chrome (Android)',
            detail: 'Menú ⋮ → "Instalar aplicación" o "Añadir a pantalla de inicio"',
          ),
          _InstructionStep(
            icon: Icons.desktop_windows,
            label: 'Chrome (PC)',
            detail: 'Icono de instalación en la barra de direcciones o Menú ⋮ → "Instalar app"',
          ),
          _InstructionStep(
            icon: Icons.phone_iphone,
            label: 'Safari (iOS)',
            detail: 'Tocar el botón Compartir → "Agregar a pantalla de inicio"',
          ),
        ],
      ),
    );
  }
}

/// A single instruction step row used in the manual install info.
class _InstructionStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;

  const _InstructionStep({
    required this.icon,
    required this.label,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.white54),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  TextSpan(
                    text: detail,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
