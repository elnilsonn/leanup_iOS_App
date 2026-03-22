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

### 10. Inventar controles custom cuando Apple ya ofrece un patron nativo

Que paso:

- Para la busqueda dentro del detalle de `Materia` y `Electiva` se intento primero un overlay custom con lupa flotante y panel propio.

Por que paso:

- Se priorizo resolver rapido la interaccion sin verificar primero si `SwiftUI` ya tenia una API nativa del sistema para ese flujo.
- Eso rompia el criterio acordado del proyecto: antes de inventar UI nueva, revisar siempre la guia Apple y las APIs nativas disponibles.

Como se soluciono:

- Se reemplazo ese enfoque por busqueda nativa del sistema con `searchable`, disparada desde la barra superior.
- Se dejo el comportamiento dentro del mismo panel, sin abrir una ventana nueva.

Regla:

- En LeanUp, antes de crear overlays, botones flotantes, buscadores o navegacion custom, revisar primero si Apple ya resuelve ese patron en `SwiftUI` o `UIKit`.
- Si existe una solucion nativa razonable, usarla primero.
- Solo crear una solucion custom cuando la alternativa nativa no cubra bien la necesidad real.
