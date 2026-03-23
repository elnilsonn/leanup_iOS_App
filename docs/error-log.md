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

### 17. `swipeActions` chocando con filas envueltas en `Button`

Que paso:

- El gesto para marcar `En curso` desde la lista de `Malla` no estaba respondiendo aunque la logica del cambio de estado si existia.

Por que paso:

- Las filas estaban envueltas en `Button`, lo que hacia mas facil que el tap y el gesto horizontal compitieran en lugar de dejar pasar el swipe.

Como se soluciono:

- Se quitaron los `Button` contenedores de las filas principales.
- Las filas quedaron como vistas con `contentShape(Rectangle())`, `onTapGesture` para abrir el detalle y `swipeActions` sobre la propia fila.

Regla:

- Si una fila necesita tap + swipe en SwiftUI, evitar envolver toda la fila en `Button` salvo que este comprobado que el gesto no se rompe.

### 18. La busqueda principal de Malla necesita ocultar cabecera durante el foco

Que paso:

- Aunque la busqueda principal ya era inline, seguian quedando banners visibles arriba y la transicion al cerrar la lupa se sentia sucia.

Por que paso:

- El contenido superior seguia vivo mientras el sistema minimizaba o cerraba la busqueda.

Como se soluciono:

- Mientras la busqueda esta presentada o tiene texto, `Malla` oculta banners y sticky header.
- Al cerrarse la busqueda, se limpia el query con un pequeno delay para acompanar mejor la animacion del sistema.

Regla:

- Si la busqueda inline debe dominar la pantalla, esconder temporalmente la cabecera para no mezclar dos jerarquias visuales al mismo tiempo.

### 19. Firma moderna de `onChange` incompatible con iOS 15

Que paso:

- `Malla` volvio a romper compilacion despues del ajuste de busqueda inline.

Por que paso:

- Se uso la variante moderna de `onChange` con dos parametros (`oldValue`, `newValue`).
- Esa firma no es valida para el target minimo actual del proyecto, que sigue compilando contra iOS 15.

Como se soluciono:

- Se volvio a la firma compatible `onChange(of:) { newValue in ... }`.

Regla:

- Aunque la app se pruebe en iOS 26, cualquier firma nueva de SwiftUI debe validarse contra el deployment target real del proyecto antes de dejarla en codigo.

### 20. Referencia colgante al quitar la busqueda interna de detalle

Que paso:

- Despues de retirar la busqueda interna de `Electiva`, la compilacion rompio con `cannot find 'hasActiveSearch' in scope`.

Por que paso:

- Se elimino la propiedad `hasActiveSearch` del detalle, pero quedo una referencia vieja dentro de `optionCountText`.

Como se soluciono:

- Se limpio la condicion sobrante y `optionCountText` volvio a usar solo el conteo filtrado vigente.

Regla:

- Cuando se retire una feature de una vista, barrer tambien computadas auxiliares y textos derivados para evitar referencias colgantes.

### 21. Busqueda inline de Malla demasiado controlada desde estado propio

Que paso:

- La barra de busqueda de `Malla` seguia teniendo glitches visuales al cerrar y daba sensacion de que la pantalla "cambiaba" al enfocarla.

Por que paso:

- Se estaba mezclando el patron del sistema (`searchable`) con control programatico de apertura mediante `isPresented`.
- Para este caso, esa combinacion volvia mas fragil la transicion entre icono, barra, teclado y contenido.

Como se soluciono:

- Se simplifico `Malla` a `searchable(text:prompt:)` como fuente principal.
- En iOS 26 se mantuvo `searchToolbarBehavior(.minimize)` para aprovechar el comportamiento del sistema.
- Los resultados se muestran solo cuando el query ya tiene texto.

Regla:

- Si la busqueda principal debe sentirse nativa y estable, preferir el flujo base del sistema y evitar controlar a mano la presentacion salvo que sea estrictamente necesario.

### 22. Mensajes masivos metidos en el modelo principal

Que paso:

- La logica motivacional empezo a crecer demasiado dentro de `LeanUpModels.swift`.

Por que paso:

- Aunque el comportamiento funcionaba, dejar el catalogo de mensajes dentro del modelo hacia mas pesado el archivo y hacia mas dificil mantenerlo.

Como se soluciono:

- Se creo una libreria aparte (`LeanUpMotivationLibrary.swift`) para alojar el catalogo de mensajes.
- `LeanUpModels` quedo solo con la seleccion y el contexto dinamico.

Regla:

- Si un catalogo de strings crece de forma significativa, sacarlo del modelo principal a un archivo dedicado antes de que se vuelva deuda de mantenimiento.

### 23. `swipeActions` en el borde equivocado para "deslizar a la derecha"

Que paso:

- El gesto de marcar `En curso` seguia sin responder como esperaba el usuario.

Por que paso:

- La accion estaba puesta en `edge: .trailing`.
- El requerimiento real era deslizar a la derecha, que en interfaces LTR corresponde al borde `leading`.

Como se soluciono:

- Se movieron las acciones de `Malla` a `swipeActions(edge: .leading, ...)`.

Regla:

- Si el gesto pedido es "deslizar a la derecha" en iPhone con interfaz LTR, usar `leading`, no `trailing`.

### 24. Cierre visual brusco en la busqueda inline de Malla

Que paso:

- Al cerrar la barra de busqueda de `Malla`, la cabecera reaparecia de forma brusca y producia un artefacto visual.

Por que paso:

- El sistema limpiaba el query y el contenido principal reaparecia demasiado pronto, mientras la animacion de la barra aun seguia en curso.

Como se soluciono:

- Se introdujo un latch corto para mantener el modo de resultados unas decimas despues de vaciar el query.
- Tambien se desactivo la animacion implicita del cambio entre resultados y cabecera.

Regla:

- Cuando una vista intercambia bloques grandes durante el cierre de `searchable`, evitar que el cambio de layout compita con la animacion del sistema.

### 25. Resultados de electiva demasiado generales desde la busqueda principal

Que paso:

- La busqueda de `Malla` encontraba una electiva, pero al tocar el resultado solo abria el grupo general.
- Eso obligaba al usuario a volver a buscar manualmente la opcion dentro de la lista.

Por que paso:

- La ruta de detalle solo modelaba el grupo de electivas y no la opcion objetivo dentro de ese grupo.

Como se soluciono:

- La ruta de `Malla` ahora puede cargar un `targetOptionCode`.
- Los resultados de busqueda de electivas salen como opciones independientes.
- El detalle abre el grupo completo, ajusta la ruta interna si hace falta y hace scroll hasta la opcion encontrada.

Regla:

- Si un resultado de busqueda apunta a un elemento hijo dentro de un contenedor, la navegacion debe preservar tambien el objetivo interno y no quedarse solo en el contenedor padre.

### 26. Reaparecer la Malla reconstruyendo toda la jerarquia al limpiar la busqueda

Que paso:

- Al borrar el texto o cerrar la busqueda, `Malla` se veia como si recompusiera la pantalla en vivo.

Por que paso:

- Los resultados y la vista principal se estaban alternando con ramas distintas del layout.
- Aunque el sistema cerraba la busqueda bien, la pantalla principal se desmontaba y volvia a montarse justo en esa transicion.

Como se soluciono:

- La vista principal queda siempre montada.
- Los resultados de busqueda se renderizan por encima solo cuando el query tiene texto.

Regla:

- Si una pantalla densa usa `searchable`, preferir mantener el contenido base montado y superponer resultados antes que intercambiar arboles grandes durante el cierre.

### 27. Esperar que `swipeActions` funcione igual sobre cards dentro de `ScrollView`

Que paso:

- El gesto rapido de `En curso` no respondia en `Malla`.

Por que paso:

- La interaccion se implemento con `swipeActions`, pero Apple la muestra y documenta como patron de filas de `List`.
- `Malla` esta construida sobre `ScrollView` y cards personalizadas, no sobre una `List` tradicional.

Como se soluciono:

- Para conservar el diseno actual, se reemplazo por un gesto horizontal propio con feedback y umbral corto.

Regla:

- Si la vista no esta montada como `List`, no asumir que `swipeActions` va a resolver un gesto rapido de fila de forma fiable.

### 28. Resolver la busqueda solo con ocultar y mostrar resultados sin recordar posicion

Que paso:

- Al empezar a buscar, el usuario queria ver resultados desde arriba.
- Al cerrar la busqueda, tambien queria volver exactamente al punto donde venia leyendo.

Por que paso:

- Ocultar banners y mostrar resultados no basta cuando la pantalla ya venia con scroll intermedio.
- Sin recordar posicion, la experiencia se siente brusca o "teletransportada".

Como se soluciono:

- `Malla` ahora observa el `UIScrollView` real para recordar su offset antes de la busqueda.
- Cuando aparece texto, sube al inicio.
- Cuando la busqueda se limpia, restaura la posicion previa.

Regla:

- Si una pantalla larga mezcla `searchable` con contenido denso, tratar la posicion de scroll como parte del estado UX y no como detalle incidental.

### 29. Gesto horizontal demasiado sensible sobre filas largas

Que paso:

- El gesto rapido de `En curso` empezaba a pelear con el scroll vertical.

Por que paso:

- Cualquier arrastre ligeramente diagonal podia activar visualmente el gesto horizontal demasiado pronto.

Como se soluciono:

- El gesto ahora espera una dominancia horizontal clara antes de bloquearse como swipe.
- Tambien se reduce el desplazamiento visual de la card para no dar sensacion de que la lista se queda pegada.

Regla:

- En cards densas dentro de `ScrollView`, un gesto horizontal debe exigir umbral y dominancia clara antes de mover visualmente la fila.

### 30. Afinar `Malla` con construcciones Swift mas delicadas sin el error visible del compilador

Que paso:

- Tras el ultimo ajuste de `Malla`, el build volvio a caer pero el bloque pegado no mostraba la linea `error:` concreta.

Por que paso:

- En ese tipo de situacion, pequenas construcciones mas delicadas como wrappers observados con `init` manual o atajos de optional binding pueden volverse sospechosas aunque el log no ayude.

Como se soluciono:

- Se simplificaron esas piezas a formas mas conservadoras:
  - `LeanUpMallaMotivationCard` dejo de usar `@ObservedObject` con `init` manual
  - se reemplazaron atajos de binding opcional por sintaxis explicita
  - se hizo el recorrido de superviews con binding explicito

Regla:

- Si el compilador no esta mostrando la linea exacta, reducir primero el uso de azucar de lenguaje y wrappers complejos en la zona tocada antes de seguir agregando cambios.

### 31. Confundir el scroll principal con el scroll horizontal interno de la cabecera

Que paso:

- El doble toque en periodos y filtros ya devolvia el estado correcto, pero el usuario no veia el chip seleccionado porque el banner horizontal quedaba corrido.

Por que paso:

- Se corrigio el estado de seleccion, pero no se acompano con scroll horizontal del propio banner.

Como se soluciono:

- Cada banda horizontal (`periodos` y `filtros`) ahora usa `ScrollViewReader` y recentra el elemento activo cuando cambia.

Regla:

- Si un control horizontal cambia seleccion programaticamente, mover solo el scroll de ese control para mantener el foco visual.

### 32. Hacer el gesto rapido demasiado permisivo y con demasiada senal visual

Que paso:

- El swipe de `En curso` seguia peleandose con el scroll vertical y su affordance visual resultaba demasiado invasiva.

Por que paso:

- El umbral seguia siendo corto para una fila larga.
- Ademas, mostrar texto o iconos en el hueco del arrastre metia ruido innecesario.

Como se soluciono:

- El gesto ahora pide un desplazamiento bastante mas largo y una dominancia horizontal mucho mas clara.
- Tambien se limito a elementos realmente pendientes y el hueco del arrastre quedo limpio, sin texto ni iconos.

Regla:

- En una fila densa con scroll vertical alrededor, un gesto rapido debe ser intencional, largo y visualmente sobrio.

### 33. Mezclar el gesto rapido de la fila con la zona de tags horizontales

Que paso:

- Aunque el swipe ya era menos sensible, todavia podia interferir cuando el usuario arrastraba los tags de una materia.

Por que paso:

- La accion rapida seguia escuchando sobre toda la card, incluida la banda inferior donde viven los tags.

Como se soluciono:

- El gesto ahora ignora una franja inferior de la fila de materias.
- Asi la parte alta sigue sirviendo para el swipe rapido y la parte baja queda libre para el scroll horizontal de tags.

Regla:

- Si una fila mezcla accion horizontal propia y subcomponentes con scroll horizontal, separar explicitamente sus zonas interactivas.

### 34. Recentrar un banner horizontal antes de que su layout termine

Que paso:

- A veces el chip activo de `Periodos` o `Filtros` cambiaba, pero el scroll horizontal del banner quedaba apuntando a otra zona.

Por que paso:

- El recentrado podia dispararse demasiado pronto, antes de que SwiftUI terminara de recomponer el contenido y su ancho efectivo.

Como se soluciono:

- El `scrollTo` del banner se difirio al siguiente ciclo principal antes de aplicar la animacion.

Regla:

- Si un `ScrollViewReader` horizontal se desincroniza del estado visual, primero asegurar que el recentrado ocurra despues del layout y no en paralelo a la mutacion.

### 35. Tratar dos toques seguidos sobre chips distintos como si fuera "segundo toque"

Que paso:

- La UX esperada del usuario era: solo resetear cuando se repite el mismo chip activo.
- Pero la implementacion se estaba sintiendo como si cualquier toque posterior pudiera contar como "segundo toque".

Por que paso:

- Faltaba separar dos casos:
  - cambio normal a otro chip
  - repeticion intencional del mismo chip activo

Como se soluciono:

- El reset y el recentrado automatico ahora se disparan solo cuando se toca exactamente el mismo periodo o filtro que ya estaba activo.
- Cambiar de un chip a otro vuelve a ser una seleccion normal.

Regla:

- En chips con gesto de "segundo toque para reset", solo debe contar la repeticion exacta del elemento activo, nunca un toque posterior sobre otro distinto.

### 36. Regla operativa para requerimientos vagos de UX

Que paso:

- Varias iteraciones se desviaron porque el usuario tenia clara la idea visual, pero no siempre la podia describir con especificacion tecnica exacta.

Como se soluciono:

- A partir de ahora, antes de cambios de UX, se debe:
  - reformular la intencion en lenguaje mas logico
  - distinguir que debe pasar y que no debe pasar
  - pedir confirmacion breve antes de editar

Regla:

- Si el requerimiento viene expresado de forma vaga pero la intencion es detectable, ayudar a convertirlo en una regla de interaccion clara antes de implementar.

### 37. Tener la logica de reset correcta pero el recentrado en el momento equivocado

Que paso:

- El segundo toque ya reseteaba bien `Periodos` y `Filtros`, pero el banner horizontal seguia visualmente corrido.

Por que paso:

- El problema ya no estaba en la seleccion.
- El `scrollTo` podia dispararse antes de que el layout final del chip activo nuevo quedara estable.

Como se soluciono:

- El recentrado ahora hace una primera pasada inmediata y una segunda pasada corta diferida para asegurar el centrado final.

Regla:

- Si un reset de estado ya es correcto pero el banner no termina centrado, revisar el timing del `scrollTo` antes de volver a tocar la logica de seleccion.
