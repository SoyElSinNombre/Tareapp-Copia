import 'package:flutter/material.dart';
import '../models/materia.dart';
import '../models/nota_entry.dart';
import '../services/db_service.dart';

class MateriaDetailScreen extends StatefulWidget {
  final Materia materia;
  const MateriaDetailScreen({super.key, required this.materia});

  @override
  State<MateriaDetailScreen> createState() => _MateriaDetailScreenState();
}

class _MateriaDetailScreenState extends State<MateriaDetailScreen> {
  Future<void> _guardarCambios() async {
    await DBService.instance.actualizarMateria(widget.materia);
    setState(() {});
  }

  Future<void> _agregarNota(int periodoIndex) async {
    final valorCtrl = TextEditingController();
    DateTime fechaElegida = DateTime.now();

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Nueva nota'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: valorCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Nota'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                        '${fechaElegida.day}/${fechaElegida.month}/${fechaElegida.year}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final fecha = await showDatePicker(
                        context: context,
                        initialDate: fechaElegida,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now(),
                      );
                      if (fecha != null) {
                        setDialogState(() => fechaElegida = fecha);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (resultado == true) {
      if (valorCtrl.text.isEmpty) return;
      final valor = double.tryParse(valorCtrl.text);
      if (valor == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Escribe un número válido, ej: 4.5')),
          );
        }
        return;
      }
      if (valor < 0 || valor > 5) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('La nota debe estar entre 0 y 5')),
          );
        }
        return;
      }
      widget.materia.periodos[periodoIndex].notas
          .add(NotaEntry(fecha: fechaElegida, valor: valor));
      await _guardarCambios();
    }
  }

  Future<void> _eliminarNota(int periodoIndex, int notaIndex) async {
    widget.materia.periodos[periodoIndex].notas.removeAt(notaIndex);
    await _guardarCambios();
  }

  Future<void> _eliminarMateria() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar materia?'),
        content: Text(
          'Se va a borrar "${widget.materia.nombre}" y TODAS las tareas asociadas a esta materia. Esto no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    await DBService.instance.eliminarMateria(widget.materia.id!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final materia = widget.materia;
    final necesaria = materia.notaNecesariaRedondeada();

    return Scaffold(
      appBar: AppBar(
        title: Text(materia.nombre),
        actions: [
          IconButton(icon: const Icon(Icons.delete), onPressed: _eliminarMateria),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Avance actual: ${materia.avanceRedondeado.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  if (necesaria != null)
                    Text(
                      necesaria > 5
                          ? 'Ya no es posible aprobar con lo que falta'
                          : 'Necesitas ${necesaria.toStringAsFixed(1)} en promedio en lo que falta',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    )
                  else
                    Text(
                      materia.promedioActual >= materia.notaAprobacion
                          ? 'Materia ganada 🎉'
                          : 'Materia perdida',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(materia.numPeriodos, (i) {
            final periodo = materia.periodos[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Periodo ${i + 1} (${periodo.peso.toStringAsFixed(0)}%)',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          periodo.promedio == null
                              ? 'Sin notas'
                              : 'Prom: ${periodo.promedio!.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (periodo.notas.isEmpty)
                      const Text('Todavía no has agregado notas aquí.',
                          style: TextStyle(color: Colors.grey)),
                    ...periodo.notas.asMap().entries.map((entry) {
                      final j = entry.key;
                      final nota = entry.value;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(nota.valor.toStringAsFixed(1)),
                        subtitle: Text(
                            '${nota.fecha.day}/${nota.fecha.month}/${nota.fecha.year}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => _eliminarNota(i, j),
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: () => _agregarNota(i),
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar nota'),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
