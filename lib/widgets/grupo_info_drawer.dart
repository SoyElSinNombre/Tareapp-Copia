import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/grupo.dart';
import '../services/grupo_service.dart';
import '../theme/app_theme.dart';
import '../widgets/seal_avatar.dart';

/// El panel que se desliza desde la derecha con todo lo relacionado al
/// grupo en sí (no a las tareas): el sello/foto, el nombre, el código
/// para compartir, la lista de miembros, y la opción de salir.
class GrupoInfoDrawer extends StatefulWidget {
  final Grupo grupo;
  final String rol;
  final VoidCallback onGrupoActualizado;
  final VoidCallback onSalir;

  const GrupoInfoDrawer({
    super.key,
    required this.grupo,
    required this.rol,
    required this.onGrupoActualizado,
    required this.onSalir,
  });

  @override
  State<GrupoInfoDrawer> createState() => _GrupoInfoDrawerState();
}

class _GrupoInfoDrawerState extends State<GrupoInfoDrawer> {
  bool _subiendoFoto = false;
  bool _enviandoRecordatorio = false;

  Future<void> _enviarRecordatorioManual() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Enviar recordatorio ahora?'),
        content: const Text(
          'Se le va a mandar una notificación a todos los estudiantes que aún no '
          'han completado alguna tarea del grupo. Puede tardar hasta unos '
          'minutos en llegar.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enviar')),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _enviandoRecordatorio = true);
    await GrupoService.instance.solicitarRecordatorioManual(widget.grupo.codigo);
    if (mounted) {
      setState(() => _enviandoRecordatorio = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada. Llegará en los próximos minutos.')),
      );
    }
  }

  Future<void> _tocarAvatar() async {
    final tieneFoto = widget.grupo.fotoBase64 != null && widget.grupo.fotoBase64!.isNotEmpty;

    final opcion = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Elegir foto'),
              onTap: () => Navigator.pop(context, 'cambiar'),
            ),
            if (tieneFoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.maroon),
                title: const Text('Quitar foto (usar sigla)', style: TextStyle(color: AppColors.maroon)),
                onTap: () => Navigator.pop(context, 'quitar'),
              ),
          ],
        ),
      ),
    );

    if (opcion == 'cambiar') {
      await _cambiarFoto();
    } else if (opcion == 'quitar') {
      await GrupoService.instance.quitarFotoDeGrupo(widget.grupo.codigo);
      widget.onGrupoActualizado();
    }
  }

  Future<void> _cambiarFoto() async {
    setState(() => _subiendoFoto = true);
    final error = await GrupoService.instance.cambiarFotoDeGrupo(widget.grupo.codigo);
    if (mounted) setState(() => _subiendoFoto = false);

    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }
    widget.onGrupoActualizado();
  }

  Future<void> _editarSigla() async {
    final ctrl = TextEditingController(text: widget.grupo.sigla ?? '');
    final resultado = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sigla del grupo'),
        content: TextField(
          controller: ctrl,
          maxLength: 3,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Ej: 10A, 9B, 8C',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (resultado == null || resultado.trim().isEmpty) return;
    await GrupoService.instance.establecerSigla(widget.grupo.codigo, resultado);
    widget.onGrupoActualizado();
  }

  @override
  Widget build(BuildContext context) {
    final esProfesor = widget.rol == 'profesor';

    return Drawer(
      width: 300,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              color: AppColors.navy,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: esProfesor ? _tocarAvatar : null,
                    child: SealAvatar(
                      fotoBase64: widget.grupo.fotoBase64,
                      sigla: widget.grupo.sigla,
                      letra: widget.grupo.nombre,
                      radius: 52,
                      overlay: _subiendoFoto
                          ? const CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.black45,
                              child: SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                            )
                          : esProfesor
                              ? Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: AppColors.gold,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.edit, size: 14, color: AppColors.navyDeep),
                                  ),
                                )
                              : null,
                    ),
                  ),
                  if (esProfesor) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _editarSigla,
                      icon: const Icon(Icons.short_text, size: 16, color: Colors.white70),
                      label: Text(
                        widget.grupo.sigla == null ? 'Poner sigla (ej: 10A)' : 'Cambiar sigla',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    widget.grupo.nombre,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lora(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    esProfesor ? 'Profesor' : 'Estudiante',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                  ),
                ],
              ),
            ),
            if (esProfesor) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CÓDIGO PARA ESTUDIANTES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      widget.grupo.codigo,
                      style: GoogleFonts.lora(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                        color: AppColors.gold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _enviandoRecordatorio ? null : _enviarRecordatorioManual,
                      icon: _enviandoRecordatorio
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                       : const Icon(Icons.campaign_outlined),
                      label: const Text('Enviar recordatorio ahora'),
                    ),
                  ],
                ),
              ),
            ],
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Divider(height: 1),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'MIEMBROS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: GrupoService.instance.obtenerMiembros(widget.grupo.codigo),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final miembros = snapshot.data!;
                return Column(
                  children: miembros
                      .map((m) => ListTile(
                            dense: true,
                            leading: SealAvatar(letra: m['nombre'] as String, radius: 16),
                            title: Text(m['nombre'] as String, style: const TextStyle(fontSize: 14)),
                            trailing: m['rol'] == 'profesor'
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.gold.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'Profesor',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.gold),
                                    ),
                                  )
                                : null,
                          ))
                      .toList(),
                );
              },
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Divider(height: 1),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: widget.onSalir,
                icon: const Icon(Icons.exit_to_app, color: AppColors.maroon),
                label: const Text('Salir del grupo', style: TextStyle(color: AppColors.maroon)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.maroon),
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
