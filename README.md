# TaskFlow

Aplicación Flutter para organizar tareas con autenticación Firebase,
recordatorios locales, calendario, temas claro/oscuro, tareas recurrentes y
subtareas.

Las tareas recurrentes pueden repetirse cada día, semana o mes al marcarlas
como completadas; las subtareas se reinician para el siguiente ciclo.

La pantalla principal muestra el estado de sincronización de Firestore. En
Android e iOS, Firestore conserva su caché local y encola escrituras sin
conexión para enviarlas al recuperar la red. Las actualizaciones de campos
distintos no reemplazan el documento completo; si dos dispositivos cambian el
mismo campo, prevalece la última escritura recibida por Firestore.

## Desarrollo

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

El ícono de la aplicación se genera desde `taskflow2.png` para Android,
iOS, web, Windows y macOS. Después de reemplazar ese archivo, ejecuta
`dart run flutter_launcher_icons` para regenerar los íconos.

La búsqueda, los filtros y el orden se aplican a las tareas cargadas en la
pantalla. Usa **Cargar más tareas** para ampliar los resultados.

## Reglas de Firebase

Las reglas de [Firestore](./firestore.rules) restringen las tareas al usuario
autenticado y validan los campos. El perfil usa un avatar con iniciales, por lo
que no requiere Firebase Storage ni subir imágenes.

Después de verificar el proyecto Firebase seleccionado, despliega las reglas
de Firestore con:

```powershell
firebase deploy --only firestore:rules
```

No despliegues estas reglas sin comprobarlas primero en el proyecto destino.

## Pruebas de reglas

Las pruebas con emuladores están aisladas en `tests/firebase`:

```powershell
cd tests\firebase
npm install
npm run test:rules
```

Las reglas se prueban localmente en los emuladores; estas pruebas no realizan
lecturas ni escrituras en el proyecto Firebase de producción.
