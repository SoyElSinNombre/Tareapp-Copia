# TareApp

App de Android para que estudiantes lleven el control de sus notas y tareas, con soporte opcional para grupos compartidos entre un salón de clase — para que un profesor publique tareas y todos los estudiantes se enteren, con recordatorios automáticos.

Construida con **Flutter**, pensada desde el principio para funcionar sin depender de ningún servicio de pago.

## Por qué existe

Nació de un problema real de salón: los compañeros olvidaban constantemente sus tareas. Empezó como una libreta de calificaciones personal y creció hasta incluir grupos compartidos, notificaciones push reales y una identidad visual propia.

## Funciones principales

**Notas y materias (100% locales, sin internet)**
- Periodos configurables (3, 4, o los que use tu colegio) con su porcentaje cada uno
- Registro de notas individuales por fecha; el promedio de cada periodo se calcula solo
- Calcula automáticamente qué nota necesitas en lo que falta para aprobar
- Redondeo a una décima, como se acostumbra en los colegios

**Tareas personales**
- Prioridad calculada combinando la fecha de entrega y qué tan bien vas en esa materia
- Recordatorios locales (24h y 2h antes de la entrega)
- Descripción, edición, y aviso de tareas urgentes al abrir la app

**Grupos compartidos (opcional, con cuenta)**
- Cuentas con correo/contraseña o Google
- Un profesor crea un grupo con código de invitación; los estudiantes se unen con ese código
- Soporte para varios co-profesores por grupo
- Tareas publicadas por el profesor, visibles para todo el grupo
- Cada estudiante marca su propio avance — visible para todos, sin afectar el de los demás
- Foto o sigla personalizada para el grupo (ej: "10A")

**Notificaciones push reales**
- En vez de depender de que el celular "se recuerde solo" (poco confiable en varios fabricantes que matan apps en segundo plano), un servidor externo gratuito envía las notificaciones — ver [TareApp-Notificaciones](https://github.com/SoyElSinNombre/Tareapp-notificaciones)
- Bandeja de notificaciones dentro de la app, separada en "Nuevas tareas" y "Urgentes"

## Capturas

<p float="left">
  <img src="screenshot_materias.png" width="260" />
  <img src="screenshot_grupo.png" width="260" />
</p>

## Stack técnico

| Parte | Tecnología |
|---|---|
| App | Flutter (Android) |
| Datos personales | SQLite (`sqflite`), 100% local |
| Cuentas | Firebase Authentication (correo/contraseña + Google) |
| Datos de grupo | Cloud Firestore |
| Notificaciones locales | `flutter_local_notifications` |
| Notificaciones push | Firebase Cloud Messaging + [script en GitHub Actions](https://github.com/SoyElSinNombre/Tareapp-notificaciones) |
| Tipografía/diseño | `google_fonts` (Lora + Inter), paleta académica navy/dorado propia |

Todo el proyecto está diseñado para vivir dentro de las capas **gratuitas** de Firebase y GitHub — sin tarjeta de crédito, sin plan de pago.

## Cómo correrlo

```bash
git clone https://github.com/SoyElSinNombre/Tareapp-Copia.git
cd Tareapp-Copia
flutter pub get
flutter run
```

Necesitas tu propio proyecto de Firebase (Authentication + Firestore activados) y correr `flutterfire configure` para generar tu propio `lib/firebase_options.dart` — ese archivo no se sube al repositorio por buenas prácticas, aunque sus datos no son secretos.

## Licencia

Todos los derechos reservados. El código es visible con fines de transparencia y aprendizaje, pero no está bajo ninguna licencia de código abierto.

---

Proyecto personal de un estudiante de secundaria en Colombia, construido para resolver un problema real de su salón de clase.
