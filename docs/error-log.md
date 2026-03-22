# LeanUp Error Log

Actualizado: 2026-03-21
Estado: bitacora viva de errores, causas y soluciones

## Como usar este archivo

- Consultarlo antes de hacer cambios grandes.
- Registrar aqui cada error nuevo importante.
- Anotar siempre:
  - que paso
  - por que paso
  - como se soluciono
  - que regla deja para futuro

## Errores registrados

### 1. Split de AppDelegate rompio compilacion de Swift

Que paso:

- Al separar `AppDelegate` en varios archivos, el proyecto dejo de compilar.

Por que paso:

- Habia propiedades compartidas marcadas como `private` que luego fueron usadas desde extensiones en otros archivos.
- Tambien quedo una propiedad almacenada dentro de una extension.

Como se soluciono:

- Se movio la propiedad almacenada de vuelta a `AppDelegate.swift`.
- Se ajusto la visibilidad de las propiedades compartidas.

Regla:

- En Swift, una extension en otro archivo no puede depender de miembros `private`.
- Nunca poner propiedades almacenadas dentro de extensiones.

### 2. Dashboard nuevo rompio compilacion por nombres de propiedades

Que paso:

- El rediseño del `Dashboard` intento usar `professionalHeadline` y `professionalSummary`, y el build fallo.

Por que paso:

- El modelo ya tenia la misma informacion, pero expuesta con otros nombres:
  - `profileHeadline`
  - `profileSummary`

Como se soluciono:

- Se añadieron alias en `LeanUpModels.swift` para que la capa de UI y la capa de datos quedaran alineadas.

Regla:

- Antes de usar nuevas propiedades en una vista, confirmar que existen en el modelo real o crearlas en la misma iteracion.

### 3. Cambio de tema no aplicaba visualmente

Que paso:

- Los botones de `Claro`, `Oscuro` y `Sistema` se podian tocar, pero la app no cambiaba de apariencia.

Por que paso:

- El estado de SwiftUI no estaba forzando por si solo el cambio real de estilo en UIKit.

Como se soluciono:

- Se conecto `themeMode` con `overrideUserInterfaceStyle` desde `NativeRootViewController`.

Regla:

- Cuando una preferencia visual afecta toda la app iOS, validar tambien la capa UIKit y no solo la de SwiftUI.

### 4. Malla nativa no cargaba la base academica

Que paso:

- La `Malla` mostraba error de carga aunque la app abria bien.

Por que paso:

- La app dependia de rutas demasiado fragiles para encontrar la base academica dentro del bundle.

Como se soluciono:

- Se creo `native-academics.json` como recurso nativo claro y luego se dejo como unica fuente empaquetada para iPhone.

Regla:

- Evitar depender de rutas ambiguas dentro del bundle.
- Si un dato es critico para la app, debe existir como recurso nativo directo y estable.

### 5. Boton Copiar rompia compilacion al cambiar estilos condicionalmente

Que paso:

- El build fallo cuando el boton `Copiar` alternaba entre estilos distintos con un ternario.

Por que paso:

- SwiftUI esperaba tipos compatibles, pero el cambio dinamico de `buttonStyle` volvia ambigua la expresion.

Como se soluciono:

- Se mantuvo un solo estilo de boton y el feedback visual se paso a color, fondo, icono y animacion.

Regla:

- Evitar ternarios que cambien entre tipos de `buttonStyle` distintos.

### 6. Regresion de fluidez por efectos visuales pesados

Que paso:

- Tras el rediseño inicial del `Dashboard`, el scroll en iPhone se empezo a sentir con lag.

Por que paso:

- Se introdujeron efectos caros para render en muchas vistas:
  - blurs grandes en el fondo
  - sombras amplias repetidas en tarjetas
  - decoracion visual mas pesada de la necesaria

Como se soluciono:

- Se simplifico `LeanUpPageBackground`.
- Se eliminaron blurs grandes.
- Se redujeron sombras en hero y tarjetas.
- Se priorizo fluidez por encima de decoracion.

Regla:

- En LeanUp, la fluidez tiene prioridad sobre los adornos visuales.
- Antes de dejar un fondo o tarjeta nueva, revisar si usa:
  - `blur` grande
  - sombras repetidas
  - demasiadas capas decorativas

### 7. Dependencia residual de Capacitor despues de la migracion

Que paso:

- Aunque la app ya era nativa, el proyecto iOS seguia arrastrando referencias a `Capacitor`, `cap sync` y `public/index.html`.

Por que paso:

- Quedaban artefactos de la etapa hibrida en el target, el workflow y el bundle.

Como se soluciono:

- Se limpiaron `project.pbxproj`, `build.yml`, `Info.plist` y el bundle iOS.

Regla:

- Cuando una migracion se cierra, hay que retirar tambien los restos del build y del proyecto, no solo del runtime.

### 8. Logica imperativa dentro de un ViewBuilder en SwiftUI

Que paso:

- La reorganizacion de `Malla` rompio compilacion con un error tipo `type '()' cannot conform to 'View'`.

Por que paso:

- Dentro del `body` de una vista se dejo una pequena logica imperativa con asignaciones y `switch` para calcular estados auxiliares.
- En ciertas posiciones, SwiftUI interpreta eso como expresiones del `ViewBuilder` y termina rompiendo el tipado.

Como se soluciono:

- La logica se movio a propiedades calculadas (`status`, `isFailed`, `isPending`) fuera del flujo visual del `body`.

Regla:

- En LeanUp, evitar meter bloques de asignacion y `switch` dentro del `body` de una vista.
- Si un valor auxiliar se usa para render, convertirlo en propiedad calculada privada.

### 9. Helpers de filtro fuera de MainActor consultando el modelo UI

Que paso:

- La nueva `Malla` por periodos rompio compilacion con errores del tipo `call to main actor-isolated instance method ... in a synchronous nonisolated context`.

Por que paso:

- Los helpers `matches(course:model:)` y `matches(group:model:)` vivian en una extension privada normal.
- Esos helpers consultaban metodos de `LeanUpAppModel` que estan aislados al `MainActor`, pero el compilador no podia asumir ese contexto en la extension.

Como se soluciono:

- Se marco la extension privada de `LeanUpMallaFilter` con `@MainActor`.

Regla:

- Si un helper de SwiftUI consulta estado del modelo observable de pantalla, debe vivir en `MainActor` o recibir valores ya resueltos.

### 10. Mojibake en `native-academics.json`

Que paso:

- La app empezo a mostrar textos con jeroglificos del tipo `TeÃ³rica`, `AprenderÃ¡s` y `AnÃ¡lisis`.

Por que paso:

- El archivo `ios/App/App/native-academics.json` quedo con texto mojibake por una conversion de codificacion incorrecta entre UTF-8 y Windows-1252.
- El problema estaba en los datos academicos, no en `Dashboard`, `Malla` ni los componentes compartidos.

Como se soluciono:

- Se hizo una reparacion de codificacion directamente sobre `native-academics.json`.
- Se volvio a barrer todo `ios/App/App` buscando patrones tipicos (`Ã`, `Â`, `â`, `ð`, `�`) para confirmar que no quedaran restos visibles.

Regla:

- Si aparecen jeroglificos en LeanUp, revisar primero `native-academics.json` antes de tocar vistas o layout.
- Despues de editar o importar texto masivo, pasar una verificacion automatica de mojibake sobre `ios/App/App`.

### 11. Rebound lateral del Dashboard provocado por texto dinamico

Que paso:

- El `Dashboard` parecia "moverse" o estirarse lateralmente solo con ciertas versiones de `native-academics.json`.

Por que paso:

- El problema no venia de toda la pantalla ni del contenedor general.
- El unico bloque del `Dashboard` que usa texto dinamico real del JSON es `Lectura de rendimiento`.
- Esa tarjeta mostraba dos columnas lado a lado en iPhone con nombres reales de materias. Al corregir acentos y volver a cadenas Unicode normales, pequenas diferencias de ancho hacian mas facil que esa composicion empujara lateralmente.

Como se soluciono:

- Se reforzo solo `LeanUpDashboardPerformanceCard` para que en ancho compacto apile las columnas en vertical.
- Dentro de cada fila se fijo mejor el wrapping del nombre de la materia con `fixedSize(horizontal: false, vertical: true)` y un `frame` lider para el bloque de texto.

Regla:

- Si un bug visual del `Dashboard` cambia segun el contenido del JSON, revisar primero las tarjetas que pintan texto dinamico real antes de tocar `NativeRoot` o el scroll global.

### 12. Correccion manual definitiva del JSON por parte del usuario

Que paso:

- Tras varias pruebas, el usuario corrigio manualmente los caracteres problematicos dentro de `native-academics.json`.
- Con esa correccion manual desaparecieron tanto los jeroglificos como el comportamiento raro del `Dashboard`.

Como se cerro:

- Se toma como version valida la correccion manual hecha por el usuario.
- No se deben reescribir ni "normalizar" esos textos otra vez sin comparar primero contra esta version ya estable.

Regla:

- Si vuelve a aparecer un problema parecido, tomar primero la version manual estable del usuario como referencia de verdad antes de intentar otra conversion automatica.

### 13. Rebound lateral del Dashboard al subir las materias en curso

Que paso:

- El `Dashboard` podia volver a estirarse lateralmente cuando el usuario marcaba mas de 4 materias en curso.

Por que paso:

- El disparador mas probable estaba en `LeanUpDashboardPaceCard`.
- Esa tarjeta renderizaba tres bloques de estadistica dentro de un `HStack`, y esos valores cambian justamente cuando sube `inProgressCount`.
- En iPhone compacto, pequenos cambios de contenido en esas tres tarjetas podian empujar el ancho ideal del bloque y activar el rebote lateral.

Como se soluciono:

- Se mantuvo el mismo diseno visual general, pero el contenedor interno de esas tres estadisticas se paso a `LazyVGrid` de tres columnas flexibles.
- Tambien se reforzo el wrapping y escalado minimo de los textos dentro de `LeanUpDashboardAccentStat`.

Regla:

- Si una fila de metricas del `Dashboard` depende de valores dinamicos, preferir `LazyVGrid` o columnas flexibles controladas antes que un `HStack` simple en ancho compacto.

### 14. El problema no era un numero magico, sino el ancho efectivo del dashboard

Que paso:

- El fallo parecia activarse con 5 o 7 materias en curso, pero no con 6, lo que indicaba que no habia una regla logica fija sino una reaccion del layout a ciertos contenidos.

Por que paso:

- El `Dashboard` no tenia su ancho util completamente fijado al viewport.
- Segun la combinacion de textos y metricas, algunas composiciones empujaban ligeramente el ancho ideal del contenido y activaban el rebote lateral.

Como se soluciono:

- Se fijo el ancho del `VStack` principal del `Dashboard` al ancho real disponible de la pantalla mediante `GeometryReader`.
- Asi el contenido ya no puede negociar un ancho mayor que el viewport aunque cambien los datos.

Regla:

- Si un `ScrollView` vertical de LeanUp empieza a moverse lateralmente solo con ciertos datos, fijar primero el ancho real del contenido al viewport antes de perseguir "umbrales" numericos.

### 15. Rebound lateral en Malla por ancho negociado

Que paso:

- `Malla` tambien empezo a moverse o estirarse lateralmente con ciertas combinaciones de banners y contenido.

Por que paso:

- Igual que en `Dashboard`, el `ScrollView` vertical de `Malla` estaba dejando que el contenido negociara un ancho ideal ligeramente mayor al viewport.
- El problema no venia de una sola tarjeta concreta sino del ancho util completo de la pantalla.

Como se soluciono:

- Se envolvio `Malla` en `GeometryReader` y se fijo el ancho real del `VStack` principal al viewport disponible.

Regla:

- Si una pantalla vertical de LeanUp empieza a hacer rebote lateral sin tener un `ScrollView(.horizontal)`, revisar primero si el contenido principal esta verdaderamente anclado al ancho del viewport.

### 16. Busqueda de Malla resuelta con una vista aparte en vez de inline

Que paso:

- La lupa de `Malla` seguia abriendo una pantalla aparte de busqueda.

Por que paso:

- Aunque existia una solucion funcional, no seguia el patron nativo que el usuario queria para iOS 26: buscar dentro de la misma vista con la lupa expandiendose a barra.

Como se soluciono:

- Se retiro el flujo de sheet para la busqueda principal de `Malla`.
- Se paso a `searchable` inline sobre la propia pantalla con `searchToolbarBehavior(.minimize)` en iOS 26.
- Los resultados ahora viven dentro de la misma `Malla`.

Regla:

- Si el requerimiento de busqueda es "ahi mismo", no resolverlo con una pantalla aparte aunque sea funcional.
- En iOS 26, priorizar `searchable` y el comportamiento del toolbar del sistema antes que un sheet o una vista secundaria.
