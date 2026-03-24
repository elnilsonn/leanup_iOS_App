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

### 38. Recentrar usando solo estado derivado cuando el reset necesita un destino explicito

Que paso:

- El segundo toque ya cambiaba bien al periodo o filtro correcto, pero el banner horizontal seguia sin recentrarse al destino final.

Por que paso:

- El recentrado seguia leyendo el estado derivado del momento, en lugar de recibir un objetivo explicito del reset.

Como se soluciono:

- El reset ahora manda un target concreto al banner.
- El banner recentra contra ese target y repite el ajuste en varias pasadas cortas.

Regla:

- Si un reset visual debe aterrizar en un chip especifico, pasar ese chip como objetivo explicito en vez de confiar solo en el estado recomputado.

### 39. Primer recentrado de Periodos mas debil que los siguientes

Que paso:

- El reset de `Periodos` ya recentraba bien, pero la primera vez podia quedarse corto y solo a partir de la segunda quedaba perfecto.

Por que paso:

- El banner de `Periodos` necesitaba un poco mas de margen temporal en ese primer flujo para asentarse por completo antes del centrado final.

Como se soluciono:

- Se agrego una pasada diferida extra solo para `Periodos`.
- `Filtros` se dejaron intactos porque no presentaban ese problema.

Regla:

- Si un banner horizontal falla solo la primera vez pero luego funciona, reforzar el timing inicial del recentrado en esa banda concreta, no en todas.

### 40. Seguir parchando delays cuando la instancia del banner ya quedo desfasada

Que paso:

- Aunque se reforzaron delays, `Periodos` seguia fallando en el primer reset.

Por que paso:

- El problema ya no era solo el tiempo.
- La primera instancia del banner podia quedarse desfasada respecto al target final del reset.

Como se soluciono:

- En el reset de `Periodos`, la banda horizontal se recrea y se centra desde cero con el target explicito.

Regla:

- Si un `ScrollViewReader` sigue fallando solo en un primer flujo especifico, considerar recrear esa banda puntual antes de seguir agregando retardos.

### 41. Recentrar una banda recien reconstruida demasiado pronto para que se vea la animacion

Que paso:

- La banda de `Periodos` ya recentraba bien tras el rebuild, pero el movimiento podia sentirse seco, sin la animacion horizontal visible.

Por que paso:

- El `scrollTo` se estaba disparando demasiado pegado al `onAppear` de la banda nueva.

Como se soluciono:

- El recentrado del reset se difirio al siguiente ciclo principal, manteniendo la animacion.

Regla:

- Si una banda reconstruida ya centra bien pero pierde la sensacion de animacion, retrasar el disparo del `scrollTo` un ciclo principal antes de volver a tocar su logica.

### 42. No cerrar un ajuste sin verificar si realmente corrigio el sintoma exacto

Que paso:

- Hubo varias iteraciones donde la direccion del arreglo parecia razonable, pero el sintoma exacto que el usuario seguia viendo no desaparecia del todo.

Como se corrige de ahora en adelante:

- Antes de dar por cerrada una correccion, revisar otra vez:
  - que el cambio apunte al sintoma exacto reportado
  - que no se haya corregido solo una parte parecida
  - que el comportamiento final esperado quede cubierto por la logica nueva

Regla:

- No marcar una correccion como lista sin una verificacion adicional centrada en el sintoma exacto que sigue describiendo el usuario.

### 43. Intentar animar un reset reconstruyendo la banda en vez de animar la banda viva

Que paso:

- `Periodos` llegaba al destino correcto, pero seguia sin sentirse como una animacion horizontal igual a `Filtros`.

Por que paso:

- `Filtros` animaba sobre la misma banda viva.
- `Periodos` estaba reconstruyendo la banda y luego recentrando, lo que favorece el aterrizaje correcto pero no una transicion equivalente.

Como se soluciono:

- `Periodos` vuelve a animar sobre la misma banda viva.
- Se mantiene el target explicito del reset y el token se dispara en el siguiente ciclo principal para no perder el destino correcto.

Regla:

- Si una banda debe animarse como otra que ya funciona, primero alinear su estructura de vida antes de seguir ajustando tiempos o retardos.

### 44. Duplicar la misma senal de progreso en la cabecera del periodo

Que paso:

- El resumen del periodo mostraba el progreso `5/8` dos veces.

Por que paso:

- La cabecera tenia un badge extra arriba a la derecha aunque el mismo valor ya se mostraba junto a `Cierre del periodo`.

Como se soluciono:

- Se elimino el badge superior duplicado y se dejo una sola referencia visible al progreso.

Regla:

- Si una metrica ya aparece de forma clara dentro del bloque principal, no repetirla en un badge adicional sin aportar una funcion nueva.

### 45. Perder el tap del detalle por priorizar demasiado la capa del gesto rapido

Que paso:

- Al tocar una materia o electiva, a veces no se abria el panel de detalle.

Por que paso:

- La capa usada para escuchar el gesto rapido de `En curso` podia quedarse con la interaccion de la fila antes que el tap normal.

Como se soluciono:

- El tap para abrir detalle paso a tener prioridad alta sobre la fila.

Regla:

- En una fila con gesto secundario y navegacion primaria, el tap de apertura debe tener prioridad clara sobre la capa auxiliar del gesto.

### 46. Hacer que la capa de busqueda se comporte como una pantalla distinta a la Malla base

Que paso:

- La `Malla` normal se integraba bien con el comportamiento visual tipo iOS 26, pero la capa de busqueda no.

Por que paso:

- La capa de resultados tenia una estructura mas pelada que la pantalla base:
  - otro `ScrollView`
  - sin la misma respiracion de contenido
  - sin colchón inferior suficiente frente a la tab bar flotante

Como se soluciono:

- La capa de busqueda se alineo con la estructura de la `Malla` base.
- Se le dio el mismo tratamiento de fondo y de scroll friendly, y se añadió espacio inferior de seguridad dentro del contenido.

Regla:

- Si una vista de busqueda vive dentro de una pantalla base que ya se comporta bien, su capa de resultados debe heredar la misma estructura visual antes de inventar soluciones nuevas.

### 47. Cortar la capa de resultados apenas el query queda vacio aunque la barra del sistema siga cerrandose

Que paso:

- Al cerrar la lupa/barra de busqueda en `Malla`, aparecia una franja visual fea arriba antes de que todo quedara normal.

Por que paso:

- La vista estaba atando el cierre solo a `query.isEmpty`.
- En cuanto el texto desaparecia, la capa de resultados y el contexto visual de busqueda se desmontaban de inmediato.
- Pero la barra `searchable` del sistema seguia cerrandose unos instantes mas, asi que el titulo grande y el contenido base reaparecian demasiado pronto.

Como se soluciono:

- `Malla` ahora observa tambien si la barra sigue presentada.
- Durante el cierre se conserva un estado transitorio corto:
  - el titulo sigue en modo inline
  - la capa de resultados sigue viva con el ultimo query util
  - y solo cuando la animacion del sistema termina vuelve la `Malla` grande normal

Regla:

- Si una animacion de `searchable` falla solo al cerrar, no desmontar la UI de busqueda solo porque el texto ya esta vacio; primero esperar a que el sistema termine de cerrar la barra.

### 48. Forzar el titulo inline durante el cierre aunque el problema solo existiera en el estado de titulo grande

Que paso:

- Despues del arreglo anterior, seguia apareciendo un `Malla` pequeno fantasma durante el cierre de la busqueda cuando la pantalla estaba arriba del todo.

Por que paso:

- El cierre seguia forzando `navigationBarTitleDisplayMode(.inline)` mientras la barra del sistema terminaba de animarse.
- Eso ayudaba al handoff visual general, pero introducia justo el titulo pequeno que no debia verse en el estado de `large title`.

Como se soluciono:

- Se mantuvo el latch visual del cierre de busqueda.
- Pero se retiro el forzado de `.inline` en `Malla`.
- El titulo vuelve a depender de `.large`, dejando que el sistema maneje la transicion del encabezado sin ese fantasma intermedio.

Regla:

- Si un bug de cierre aparece solo en la variante de `large title`, no forzar `.inline` como parche global; primero conservar el comportamiento nativo del titulo y aislar solo el handoff del `searchable`.

### 49. Tratar igual el cierre de busqueda en top y fuera del top aunque la navegacion este en estados distintos

Que paso:

- Al dejar el titulo siempre en `.large`, se quitaba el `Malla` pequeno fantasma en el top, pero se dañaba otra vez parte de la animacion que ya estaba bien en otros desplazamientos.

Por que paso:

- El cierre no ocurre siempre desde el mismo contexto visual.
- Cuando `Malla` esta arriba del todo, la navegacion esta en estado de `large title`.
- Cuando el usuario esta mas abajo, la misma pantalla ya esta en una logica visual equivalente a titulo reducido.
- Aplicar el mismo parche a ambos casos vuelve a romper uno de los dos.

Como se soluciono:

- `Malla` ahora guarda si la busqueda se abrio desde el top o no.
- El cierre usa esa referencia para decidir si debe mantener el contexto de `large title` o el contexto inline.

Regla:

- Si una animacion de navegacion falla solo en una posicion concreta del scroll, no asumir un unico estado global; primero distinguir desde que contexto visual real entro el usuario a la transicion.

### 50. Seguir forzando inline mientras la busqueda esta presentada aunque se hubiera abierto desde large title

Que paso:

- Incluso despues de distinguir entre top y no-top para el cierre, seguia apareciendo el `Malla` pequeno en medio de la animacion si la busqueda habia nacido arriba del todo.

Por que paso:

- La condicion anterior aun forzaba el estado inline durante la presentacion de la busqueda, aunque el flujo hubiera empezado desde `large title`.
- Eso dejaba preparado el titulo pequeno que luego se colaba en el cierre.

Como se soluciono:

- El estado inline ahora solo se usa si la busqueda se abrio estando fuera del top.
- Si la busqueda nacio arriba del todo, todo ese flujo conserva el contexto de `large title`.

Regla:

- Si una transicion nace desde `large title`, no introducir `inline` ni siquiera durante la fase presentada salvo que sea estrictamente necesario; de lo contrario el titulo reducido termina filtrandose en el cierre.

### 51. Sobreajustar el cierre de busqueda separando top y no-top cuando el arreglo global ya era mejor

Que paso:

- Se intento separar el cierre de busqueda de `Malla` entre el caso que nace desde el top y el caso que nace mas abajo.
- Aunque la hipotesis era razonable, en la practica se daño otra vez la animacion general y el usuario prefirio volver al estado anterior.

Por que paso:

- El refinamiento atacaba un frame concreto del `large title`, pero introducia demasiada logica condicional sobre la navegacion.
- El costo visual total del experimento fue peor que el beneficio puntual.

Como se soluciono:

- Se revirtio todo el refinamiento top/no-top.
- Se recupero el comportamiento anterior, que mantenia mejor la transicion global del cierre.

Regla:

- Si un refinamiento muy especifico corrige un detalle pero empeora la animacion general percibida, revertirlo y volver al ultimo estado estable en vez de insistir sobre una rama que ya se demostro peor.

### 52. Tomar decisiones de busqueda futuras sin partir del patron ya validado en Malla

Que paso:

- El flujo de busqueda de `Malla` ya paso por varias iteraciones hasta encontrar una base que se siente bien para el usuario.

Como se corrige de ahora en adelante:

- El comportamiento actual de `Malla` queda como patron por defecto para futuras busquedas similares en la app.

Regla:

- Antes de inventar otra interaccion de lupa o barra, reutilizar como referencia el patron ya validado en `Malla` y desviarse solo si la nueva pantalla realmente lo exige.

### 53. Reutilizar `lastNonEmptySearchQuery` para cerrar la busqueda aunque el usuario ya no quisiera ver resultados

Que paso:

- Despues de escribir en la busqueda de `Malla`, cerrar la barra seguia dando problemas.
- Tambien fallaba el caso de escribir, borrar el texto y luego cerrar.

Por que paso:

- El cierre estaba resucitando el ultimo query no vacio mediante `lastNonEmptySearchQuery`.
- Eso hacia que toda sesion de busqueda que hubiera tenido texto se siguiera tratando como si todavia hubiera una busqueda activa, incluso cuando el usuario ya habia borrado todo.

Como se soluciono:

- Se retiro la dependencia del ultimo query escrito para el cierre.
- Si hubo texto en la sesion, el sistema usa solo una capa transitoria vacia mientras termina la animacion.
- Los resultados solo se muestran cuando el query actual sigue siendo no vacio.

Regla:

- Si el usuario ya vacio una busqueda, no revivir el ultimo query como parche visual de cierre; mantener una transicion limpia es mejor que reinyectar resultados viejos.

### 54. Mantener la lista de resultados visible durante el cierre aunque la barra ya se estuviera cerrando

Que paso:

- Despues del ajuste anterior, seguia fallando el caso de abrir, escribir y cerrar directamente con los resultados aun visibles.

Por que paso:

- Aunque el latch ya no revivia el ultimo query, la vista seguia pintando la lista de resultados mientras `hasActiveSearch` fuera verdadero.
- Eso permitia que el cierre siguiera conviviendo con resultados vivos en pantalla justo durante la minimizacion del sistema.

Como se soluciono:

- En cuanto empieza `isSearchClosing`, la lista de resultados deja de renderizarse.
- La capa transitoria del cierre se mantiene, pero ya limpia.

Regla:

- Si el cierre de una busqueda sigue fallando cuando hay resultados visibles, separar la capa de transicion de la capa de resultados; no mantener ambas al mismo tiempo.

### 55. Dejar cierres diferidos vivos aunque la app cambie de estado o vuelva de background

Que paso:

- Ademas de los cierres manuales, quedaban comportamientos raros al bloquear el movil o salir de la app y volver dentro de `Malla`.

Por que paso:

- La busqueda estaba usando cierres diferidos con `DispatchQueue.main.asyncAfter`, pero sin invalidar formalmente transiciones viejas al cambiar de escena.
- Eso puede dejar estados de cierre colgando aunque el contexto visual ya haya cambiado.

Como se soluciono:

- Se anadio una generacion interna para invalidar cierres viejos.
- Tambien se limpian estados transitorios de busqueda cuando la app deja de estar activa y al volver, si ya no hay una busqueda real abierta.

Regla:

- Si una UI usa cierres diferidos y la app puede ir a background durante esa ventana, invalidar siempre las transiciones viejas al cambiar de escena.

### 56. Hacer reaparecer la Malla apenas el query se vacia aunque la barra siga presentada

Que paso:

- A veces, despues de escribir y cerrar, la animacion se quedaba un instante en un estado intermedio poco fluido.

Por que paso:

- El `query` ya se habia vaciado, pero la barra `searchable` del sistema seguia presentada.
- Como la vista estaba usando el query vacio para decidir el overlay, `Malla` reaparecia demasiado pronto debajo de una barra que todavia no habia terminado su propio cierre.

Como se soluciono:

- La capa de transicion ahora tambien se mantiene mientras la barra siga presentada, siempre que esa sesion ya hubiera tenido texto.
- La vista principal ya no reaparece en esa ventana intermedia.

Regla:

- Si una busqueda se siente retenida entre dos estados, revisar no solo el cierre final sino tambien el tramo donde el query ya esta vacio pero la barra del sistema sigue presentada.

### 57. Dejar que `query` vacio y `isPresented` intenten cerrar la misma sesion al mismo tiempo

Que paso:

- Aun quedaban cierres de busqueda poco fluidos o con un frame retenido en algunas variantes.

Por que paso:

- `searchSessionHadContent` todavia podia resetearse desde `query` vacio antes de que el cierre real del `searchable` terminara.
- Eso dejaba una carrera entre dos fuentes de verdad:
  - el texto actual
  - la presentacion real de la barra del sistema

Como se soluciono:

- Se retiro ese reset prematuro desde `query`.
- Ahora la sesion de busqueda se cierra desde la logica del search chrome y no desde dos caminos simultaneos.

Regla:

- Si una animacion depende de `query` e `isPresented`, no dejar que ambos cierren por separado el mismo estado transitorio; elegir una sola autoridad para terminar la sesion.

### 58. Seguir asumiendo que todo el glitch de `searchable` viene de la app sin validar primero limitaciones del framework

Que paso:

- La busqueda de `Malla` en iOS 26 siguio mostrando glitches al cerrar despues de escribir, incluso despues de varios ajustes razonables en el estado local.

Por que paso:

- La combinacion usada es especialmente sensible:
  - `searchable`
  - `searchToolbarBehavior(.minimize)`
  - `NavigationStack`
  - `TabView`
  - y titulo grande
- Apple Developer Forums ya muestra reportes recientes de comportamiento incorrecto de `searchable` y de transiciones/navigation chrome en SwiftUI sobre iOS 26.

Como se corrige de ahora en adelante:

- Tratar este tipo de bug primero como posible problema mixto: framework + implementacion local.
- Antes de seguir sumando latches y delays, validar documentacion, foros y repros de terceros.
- Si el search chrome del sistema sigue siendo inestable en este contexto, preferir un search chrome propio en SwiftUI antes que seguir acumulando parches sobre `.searchable`.

Regla:

- Si una animacion de barra nativa en SwiftUI sigue fallando tras varios ajustes coherentes, detener la iteracion reactiva y verificar si el framework tiene regresiones conocidas en esa combinacion de APIs.

### 59. No dejar registrado con claridad cuando el usuario hace rollback manual a un estado anterior

Que paso:

- Despues de varias iteraciones sobre la busqueda de `Malla`, el usuario restauró manualmente una version anterior que volvio a comportarse como queria.
- Los logs todavia dejaban mezcladas muchas entradas experimentales sin una nota final clara sobre cual era el estado vigente.

Por que paso:

- Se fue documentando cada intento tecnico, pero falto una entrada de cierre que distinguiera entre:
  - historial de experimentos
  - y estado final realmente adoptado por el usuario

Como se corrige de ahora en adelante:

- Cuando el usuario haga un rollback manual o restaure una version previa, registrar de inmediato una nota final indicando que esa version pasa a ser la referencia vigente.
- No asumir que la ultima iteracion documentada coincide con el estado actual del codigo si el usuario ya la revirtio por su cuenta.

Regla:

- Si el usuario restaura manualmente una version anterior, los logs deben dejar explicito el nuevo punto de verdad para no confundir intentos historicos con estado actual.

### 60. Asumir que las electivas traen las mismas familias de tipo que las materias

Que paso:

- Al redisenar `Perfil`, el mapa de tipos pedia contar `Teorica`, `Practica`, `Lectura` y `Numeros` tanto en materias como en electivas.

Por que paso:

- Las materias del JSON si traen `types`.
- Las electivas no traen esas familias; traen `disciplinaryTracks`, que es una clasificacion distinta.

Como se resolvio:

- El mapa de tipos de `Perfil` se calcula solo con materias que traen tipologia explicita.
- No se invento una conversion artificial de `disciplinaryTracks` a `types`.

Regla:

- Si una lectura visual depende de una taxonomia concreta, confirmar primero que esa taxonomia exista realmente en los datos antes de extrapolar desde otro campo parecido.

### 61. Borrar un helper compartido al rehacer una pantalla

Que paso:

- El build cayo con `cannot find 'LeanUpSurfaceInsetCard' in scope` dentro de `LeanUpMallaScreen.swift`.

Por que paso:

- `LeanUpSurfaceInsetCard` vivia dentro de la version vieja de `LeanUpProfileScreen.swift`.
- Al rehacer `Perfil`, el helper desaparecio, pero `Malla` todavia lo usaba en varias cards internas.

Como se soluciono:

- El helper se restauro en `LeanUpSharedUI.swift`.
- Asi vuelve a ser visible para todas las pantallas y deja de depender de una pantalla concreta.

Regla:

- Si un componente ya es usado por mas de una pantalla, moverlo a `SharedUI` antes de eliminar o reemplazar la pantalla donde nacio.

### 62. Repetir en `Configuracion` informacion que ya es protagonista en otras pantallas

Que paso:

- Al replantear `Configuracion`, aparecia la tentacion de sumar tambien reminders u otros bloques informativos que ya viven mejor en `Malla`.

Por que pasa:

- Cuando una pantalla de ajustes queda muy vacia, es facil llenarla con datos reales de otras secciones aunque no sean settings de verdad.

Como se corrige:

- `Configuracion` se queda solo con controles y lecturas que si pertenecen a un centro de control:
  - nombre
  - apariencia
  - estado local
  - datos guardados
  - informacion de la app
- No se meten reminders ni otros modulos que repitan protagonismo funcional de otra pantalla.

Regla:

- Si un dato ya tiene su pantalla natural, no usar `Configuracion` como contenedor comodin solo para llenar espacio.

## Actualizacion 2026-03-24 - El copy no debe hablar como si explicara la arquitectura de la app

Problema:

- En `Perfil` y `Configuracion` aparecieron textos como "esta pantalla", "otra seccion" o frases similares que suenan a explicacion interna del producto en vez de ayuda real para la persona.

Por que pasa:

- Al diferenciar pantallas entre si, es facil que el copy termine justificando la estructura de la app en lugar de describir el beneficio directo para quien la usa.

Como se corrige:

- Reescribir los textos desde la experiencia humana:
  - que hace esa informacion
  - como ayuda
  - por que importa
- Evitar mencionar la existencia de otras pantallas o secciones salvo que sea estrictamente necesario para navegacion.

Regla:

- El copy visible no debe sonar a comentario de disenio o arquitectura; debe sonar a producto terminado.

## Actualizacion 2026-03-24 - El dark mode no puede depender de opacidades pensadas para modo claro

Problema:

- Varias superficies compartidas seguian usando blancos transluidos o `Color.primary.opacity(...)` pensados desde modo claro.
- En dark eso hacia que partes de la app se vieran lavadas, azuladas de mas o directamente claras cuando la intencion era un tono casi negro.

Por que pasa:

- Si el sistema oscuro se resuelve solo con invertir texto y fondo, pero sin una paleta semantica propia, las cards y controles heredan opacidades que no expresan profundidad real.

Como se corrige:

- Definir una paleta dark especifica:
  - fondo casi negro
  - surfaces grafito
  - stroke tenue
  - acentos solo para estados y acciones
- Rehacer primero los componentes compartidos y luego corregir residuos blancos en las pantallas mas visibles.

Regla:

- El dark mode de LeanUp debe sentirse intencional y profundo; no como una inversion automatica del modo claro.

## Actualizacion 2026-03-24 - Un modelo observable con demasiadas computadas puede sentirse lento aunque la UI sea simple

Problema:

- `LeanUpAppModel` acumulaba muchas propiedades computadas que volvían a recorrer cursos, electivas, notas, periodos y senales cada vez que SwiftUI releia los cuerpos de las vistas.

Por que pasa:

- En SwiftUI, segun Apple, el rendimiento depende mucho de las dependencias y del costo de cada update.
- Si un `ObservableObject` grande expone demasiadas computadas caras, un cambio pequeno puede disparar bastante trabajo repetido en main thread.

Como se corrige:

- Precalcular una base derivada cuando cambia el `snapshot`.
- Hacer que las propiedades mas consultadas lean de esa base en vez de repetir filtros, sorts y recorridos completos.
- Si aun persisten hitches, el siguiente paso debe ser perfilar con Instruments y no seguir adivinando.

Regla:

- Para datos que muchas pantallas leen todo el tiempo, preferir cache derivada sincronizada con el estado fuente antes que recomputacion libre en cada acceso.

## Actualizacion 2026-03-24 - Un dark mode premium no debe apoyarse en demasiadas capas caras

Problema:

- Parte del lag empezaba a sentirse mas desde que se introdujo el dark mode profundo.
- Las superficies compartidas mezclaban sombra, overlay, gradientes y blur en zonas muy repetidas de la interfaz.

Por que pasa:

- Apple insiste en mantener la ruta de actualizacion barata y libre de trabajo innecesario en main thread, y visualmente esto tambien aplica a composicion y render.
- En listas largas o pantallas densas, sombras y blur repetidos suelen sentirse antes que en una maqueta corta.

Como se corrige:

- Preferir superficies oscuras limpias antes que muchas capas apiladas.
- Usar blur solo si aporta de verdad y no en contenedores persistentes donde una base solida funciona igual.
- Reducir sombras en dark mode y dejar que la separacion venga mas por tono y borde que por elevacion artificial.

Regla:

- Si el dark mode ya se ve premium por contraste y jerarquia, no seguir agregando blur o sombras por decoracion.

## Actualizacion 2026-03-24 - Un `ObservableObject` gigante no debe viajar hasta cada card

Problema:

- Varias pantallas estaban pasando `LeanUpAppModel` completo a muchas subviews internas.
- Eso ampliaba la zona de invalidacion de SwiftUI y hacia que una mutacion pequena pudiera volver a evaluar demasiadas cards.

Por que pasa:

- Es muy comodo conectar cada subview al modelo global, pero a escala eso convierte un solo cambio de estado en demasiados renders potenciales.

Como se corrige:

- Dejar `@ObservedObject` en el root de pantalla.
- Construir `ViewData` livianos con solo lo que cada modulo necesita.
- Pasar valores, bindings y closures en vez del modelo entero cuando no hace falta mutar directamente desde la subview.

Regla:

- Si una card solo necesita datos ya resueltos, no debe observar el `AppModel` completo.

## Actualizacion 2026-03-24 - Guardar en `UserDefaults` dentro del hot path hace sentir la app mas pesada

Problema:

- Cada mutacion del snapshot hacia reconstruccion derivada y guardado inmediato del backup.
- Eso empujaba trabajo sincronico al main thread justo despues de acciones pequenas.

Por que pasa:

- Persistir siempre “ya mismo” parece seguro, pero en una app muy interactiva mete serializacion repetida donde mas se siente.

Como se corrige:

- Coalescer el guardado con un pequeno delay.
- Reutilizar el snapshot ya normalizado en vez de volver a normalizarlo antes de serializar.

Regla:

- Persistencia frecuente si, pero no cada pulsacion o mutacion como trabajo sincronico inmediato.

## Actualizacion 2026-03-24 - El polish visual compartido pesa mas que una sola pantalla

Problema:

- El lag no venia solo de `Malla`.
- La sensacion de pesadez se estaba propagando desde `SharedUI`, `Dashboard` y la configuracion global del chrome.

Por que pasa:

- Cuando sombras, strokes, gradientes y fondos completos viven en la base compartida, el costo no se reparte: se multiplica en toda la app.

Como se corrige:

- Recortar primero el sistema compartido y luego afinar pantallas concretas.
- Priorizar separacion por tono y jerarquia antes que elevacion artificial o blur.

Regla:

- Si el lag se siente global, mirar primero `SharedUI` y la raiz nativa antes de culpar a una sola pantalla.

## Actualizacion 2026-03-24 - Las closures con `nil` en estado derivado necesitan tipo explicito

Problema:

- En `LeanUpModels`, una closure que calculaba `estimatedRemainingPeriods` devolvia `nil` sin tener un tipo opcional explicito.
- Swift perdio el contexto y rompio la compilacion con `'nil' requires a contextual type`.

Por que pasa:

- Cuando una closure local mezcla `nil` y un `Double` sin anotacion de tipo, la inferencia no siempre basta dentro de una construccion grande.

Como se corrige:

- Declarar el valor como `Double?` desde la asignacion de la closure.

Regla:

- Si una closure local puede devolver `nil`, tiparla de forma explicita antes de confiar en la inferencia del compilador.

- La misma regla aplica a `compactMap`: si la closure devuelve `nil` y un modelo concreto, conviene anotar `Element?` en la closure o tipar el resultado explicitamente.

## Actualizacion 2026-03-24 - Si el dark mode mejora el rendimiento, el light mode no debe seguir caro

Problema:

- El dark mode se habia aligerado visualmente, pero el light mode seguia usando mas brillo, mas contraste aparente y superficies mas "flotantes".
- Eso dejaba una diferencia rara: la app se sentia mas liviana en oscuro que en claro.

Por que pasa:

- Aunque la estructura sea la misma, el modo claro puede seguir costando mas si conserva fondos decorativos fuertes, cards muy luminosas y sombras mas largas.

Como se corrige:

- Aplicar al light mode la misma filosofia del dark:
  - fondo mas plano
  - surfaces por tono, no por brillo
  - menos sombra
  - menos bloom decorativo

Regla:

- Si una simplificacion visual ayuda en dark, revisar si el light aun esta pagando una version mas cara del mismo sistema.

## Actualizacion 2026-03-24 - El verdadero costo pendiente estaba en las superficies claras translucidas

Problema:

- Aunque el fondo claro ya se habia simplificado, muchas pantallas seguian usando tarjetas internas con `Color.primary.opacity(...)`.
- Eso dejaba al light mode con demasiadas capas suaves mezclandose sobre un fondo ya decorado.

Por que pasa:

- En SwiftUI, una app puede verse ligera pero seguir siendo cara si hay muchas superficies translucidas neutrales repetidas en listas, grids y banners.

Como se corrige:

- Sustituir esas superficies por colores claros semanticos mas solidos.
- Mantener el diseno y los acentos, pero bajar la dependencia de alpha en bloques grandes o repetidos.

Regla:

- En `light mode`, los contenedores neutros repetidos deben usar surfaces claras solidas antes que `Color.primary.opacity(...)`.
