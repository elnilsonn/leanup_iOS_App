# LeanUp Migration Log

Actualizado: 2026-03-21
Estado: log vivo de la migracion nativa

## Como usar este archivo

- Este documento resume, en orden, lo que ya hicimos.
- Se debe consultar antes de seguir con cambios grandes.
- Cada iteracion nueva debe quedar registrada aqui para no perder contexto.

## Objetivo general

Migrar LeanUp desde una base hibrida/web hacia una app nativa de iPhone con `SwiftUI-first`, manteniendo la informacion importante del proyecto original y alineando la experiencia con la guia de Apple para iOS 26 y Liquid Glass.

## Principios que estamos siguiendo

- Migracion por fases, no reescritura brusca.
- Priorizar componentes nativos reales.
- Mantener persistencia local nativa como fuente de verdad.
- Aprovechar la informacion existente de `www/index.html` mientras termina la migracion.
- Profesionalizar estructura sin arriesgar compilaciones innecesariamente.

## Bitacora paso a paso

### 1. Investigacion base

- Se leyeron `CLAUDE.md`, `CONTEXT.md` y el contexto del repo.
- Se investigaron fuentes oficiales de Apple sobre iOS 26, Liquid Glass y SwiftUI.
- Se creo la guia principal en `docs/apple-ios26-guide.md`.

### 2. Contrato de datos nativo

- Se definio un contrato de datos para no migrar a ciegas.
- Se documento en `docs/leanup-data-contract.md`.
- Se prepararon tipos nativos para snapshot, temas, notas y electivas.

### 3. Shell nativa inicial

- La app dejo de arrancar como experiencia principal en WebView.
- `Main.storyboard` paso a usar `NativeRootViewController`.
- Se monto una shell nativa con tabs en SwiftUI.

### 4. Dashboard, Configuracion y base visual nativa

- Se construyo una primera version nativa de `Inicio`.
- Se creo una `Configuracion` nativa inicial.
- Se establecio fondo, tarjetas, metricas y componentes reutilizables.

### 5. Malla nativa funcional

- `Malla` dejo de ser placeholder.
- Se conecto carga de base academica desde `native-academics.json`.
- Se anadio fallback derivando datos desde `www/index.html` con `JavaScriptCore`.
- La malla ya muestra periodos, materias, electivas y editor de notas nativo.

### 6. Correcciones de estabilidad

- Se corrigio un fallo de compilacion del dashboard separando vistas grandes en componentes pequenos.
- Se mejoro la carga de datos y se redujo el riesgo de scroll horizontal en malla.

### 7. Dashboard mas real

- `Inicio` dejo de ser mensaje de transicion.
- Ahora muestra pulso academico, prioridades, creditos, avance y direccion profesional.

### 8. Configuracion profesional

- Se migraron y conservaron piezas de la web original:
  - nombre de usuario
  - tema claro/oscuro/sistema
  - acerca de LeanUp
  - contacto
- Se anadieron:
  - datos guardados
  - limpieza de progreso academico con confirmacion
  - restauracion de nombre

### 9. Fix de tema nativo

- El selector de tema no estaba aplicando cambios visuales reales.
- Se conecto `themeMode` con `UIKit` mediante `overrideUserInterfaceStyle`.
- Desde ese punto `Claro`, `Oscuro` y `Sistema` ya funcionan en iPhone.

### 10. Perfil profesional mas rico

- Se rescato del `index.html` informacion de:
  - textos de LinkedIn
  - salida laboral
  - skills
  - proyectos de portafolio
- Se extendio el modelo nativo para soportar esos campos.
- `Perfil` ya muestra:
  - roles sugeridos
  - habilidades visibles
  - textos listos para LinkedIn
  - ideas de portafolio

### 11. Feedback de copiar

- Se creo feedback visual en el boton `Copiar`.
- El boton cambia de estado y ahora se ajusta hacia color verde al copiar.

### 12. Limpieza interna en curso

- Se empezo a ordenar la base nativa sin tocar todavia el proyecto Xcode de forma riesgosa.
- Estrategia actual:
  - limpiar vistas muertas o de transicion
  - consolidar componentes reutilizables
  - mantener cambios dentro de `AppDelegate.swift` mientras no hagamos una separacion segura por target

### 13. Regla de contexto operativo

- A partir de este punto, antes de seguir con cambios grandes, hay que consultar:
  - `docs/apple-ios26-guide.md`
  - `docs/migration-log.md`
- Este log se seguira actualizando en cada iteracion importante.

### 14. Ajuste visual y limpieza segura

- El boton `Copiar` del bloque de LinkedIn pasa a verde al completar la accion.
- Se continua la limpieza interna de forma segura:
  - marcando vistas legacy para no confundirlas con las activas
  - evitando por ahora refactors agresivos que puedan romper el target de Xcode

### 15. Orden interno del archivo nativo

- Se audito `ios/App/App/AppDelegate.swift` y se confirmo que sigue siendo el mayor foco de deuda tecnica.
- Se delimitaron mejor las zonas activas del archivo:
  - `Dashboard Experience`
  - `Settings Experience`
  - `Malla Experience`
  - `Profile Experience`
- La eliminacion fisica de bloques legacy sigue pendiente, pero se hara solo con una pasada controlada para no volver a comprometer la compilacion.

### 16. Separacion real de la capa nativa

- Se cumplio la separacion formal del codigo nativo en archivos nuevos registrados en `App.xcodeproj`.
- Se movieron fuera de `AppDelegate.swift`:
  - la fundacion de datos y modelos
  - la raiz nativa SwiftUI
  - `Dashboard`
  - `Configuracion`
  - `Malla`
  - `Perfil`
  - componentes compartidos de UI
- Nuevas rutas principales:
  - `ios/App/App/NativeFoundation/LeanUpModels.swift`
  - `ios/App/App/NativeFoundation/NativeRoot.swift`
  - `ios/App/App/NativeScreens/*.swift`
  - `ios/App/App/NativeUI/LeanUpSharedUI.swift`

### 17. AppDelegate reducido y bridge modular

- `ios/App/App/AppDelegate.swift` dejo de concentrar toda la app nativa y ahora queda reducido a arranque y estado base.
- La logica hibrida restante se repartio por responsabilidad en:
  - `ios/App/App/NativeBridge/HybridOverlayUI.swift`
  - `ios/App/App/NativeBridge/AppDelegate+Mounting.swift`
  - `ios/App/App/NativeBridge/AppDelegate+Injection.swift`
  - `ios/App/App/NativeBridge/AppDelegate+Bridge.swift`
  - `ios/App/App/NativeBridge/AppDelegate+Gestures.swift`
  - `ios/App/App/NativeBridge/AppDelegate+Capacitor.swift`
- Se eliminaron piezas legacy sin uso dentro de la capa nativa.
- El archivo central bajo de un monolito de miles de lineas a una base corta y entendible.

### 18. Ajuste de compilacion tras el split

- Al validar el split, aparecio un fallo de compilacion en `swift-frontend`.
- Causa mas probable confirmada por estructura:
  - varios metodos del `AppDelegate` quedaron con `private` despues de moverlos a extensiones en archivos distintos
  - en Swift, ese nivel de acceso ya no permite llamadas entre extensiones separadas por archivo
- Se corrigio cambiando esos metodos del bridge a visibilidad de modulo.
- Tambien se quitaron conformancias `Sendable` innecesarias en la fundacion nativa para evitar choques con las comprobaciones mas estrictas de Xcode 26.

### 19. Error exacto del frontend resuelto en la base

- El log exacto mostro dos causas concretas:
  - una propiedad almacenada (`backButtonAnimWorkItem`) habia quedado dentro de `AppDelegate+Mounting.swift`
  - varias propiedades del `AppDelegate` seguian en `private` aunque ahora las usan extensiones en archivos distintos
- Ajuste aplicado:
  - `backButtonAnimWorkItem` vuelve a vivir en `ios/App/App/AppDelegate.swift`
  - las propiedades compartidas del bridge pasaron a visibilidad de modulo
- Este era un error estructural de Swift, no de `Info.plist` ni de assets.

### 20. Malla nativa mas util y menos dependiente de la capa web

- `ios/App/App/NativeScreens/LeanUpMallaScreen.swift` dejo de ser una lista nativa basica y paso a una experiencia mas guiada:
  - resumen academico superior
  - bloque de decisiones inmediatas
  - busqueda nativa por materia, codigo, descripcion y electivas
  - detalles enriquecidos con skills, texto profesional y portafolio cuando existen
- La edicion de notas se mantiene totalmente nativa y sigue siendo compatible con las calificaciones finales que el usuario registre manualmente.
- `Malla` ya no depende de paneles HTML ni de bridge JS para mostrarse ni para editar el progreso.

### 21. Perfil profesional mas estrategico

- `ios/App/App/NativeScreens/LeanUpProfileScreen.swift` se reordeno para que `Perfil` se lea como una pantalla profesional real:
  - encabezado con narrativa y nivel de preparacion
  - senales de preparacion
  - direccion profesional
  - evidencia concreta de materias y electivas aprobadas
  - bloques de LinkedIn y portafolio conservados
- El objetivo de esta iteracion fue que `Perfil` ya no se sienta como un prototipo de resumen, sino como una lectura clara de posicionamiento profesional.

### 22. Menor dependencia de bridge en Malla y Perfil

- `ios/App/App/NativeFoundation/LeanUpModels.swift` ahora cachea la base academica nativa en `UserDefaults`.
- Orden nuevo de carga:
  1. `native-academics.json`
  2. cache nativa propia
  3. derivacion desde `index.html` como ultimo respaldo de migracion
- Esto reduce la dependencia operacional de `Malla` y `Perfil` respecto al HTML heredado:
  - la experiencia visible ya es nativa
  - y ahora tambien conservan una fuente nativa cacheada aunque el fallback web siga existiendo como red de seguridad

### 23. Limpieza de UX y tono en pantallas nativas

- Se revisaron `Dashboard`, `Malla`, `Perfil` y `Configuracion` para eliminar:
  - banners redundantes entre secciones
  - textos que sonaban a migracion o a explicacion interna de desarrollo
  - frases que no aportaban valor directo al usuario final
- Ajustes principales:
  - `Dashboard` fusiona lectura general y prioridades en un solo bloque mas util
  - `Malla` elimina la tarjeta redundante de decisiones y deja un resumen mas directo
  - `Perfil` fusiona lectura de preparacion y direccion en un panorama profesional mas compacto
  - `Configuracion` deja de hablar de la arquitectura interna y usa textos mas de producto

### 24. Recorte real de deuda en AppDelegate+Injection.swift

- `ios/App/App/NativeBridge/AppDelegate+Injection.swift` dejo de cargar parches heredados que ya no aportaban valor claro a la experiencia principal.
- Se eliminaron o simplificaron piezas legacy como:
  - hacks visuales de gradientes fijos
  - parches vacios o sin efecto real
  - bloques comentados enormes de transiciones antiguas
- La inyeccion quedo reorganizada por responsabilidad:
  - estilos minimos para fallback hibrido
  - backup / autosave
  - confirmacion de notas
  - panel de detalle
  - haptics
  - scroll sync
  - sincronizacion de tema
- Esto no elimina todavia toda la capa hibrida, pero si baja la complejidad del bridge y lo deja mas alineado con la guia:
  - menos hacks visuales
  - menos comportamiento duplicado
  - mas enfoque en lo que aun sirve como respaldo temporal

### 25. Decision de fallback web: solo conservar rescate de datos

- Se reviso el estado real de la app frente a la guia y al codigo:
  - `Main.storyboard` ya arranca en `NativeRootViewController`
  - `Dashboard`, `Malla`, `Perfil` y `Configuracion` ya viven en SwiftUI
  - la ruta hibrida con `WKWebView` ya no era la experiencia principal
- Decision tomada:
  - conservar solo fallback web orientado a datos
  - retirar el fallback web orientado a interfaz
- FallBacks que SI se conservan:
  - `leanup_v4_backup` como compatibilidad de datos guardados de etapas anteriores
  - `native-academics.json` como fuente academica nativa principal
  - derivacion desde `www/index.html` solo como ultimo rescate de contenido academico
- Fallbacks que se retiran de la ruta principal:
  - montaje de `WKWebView` como experiencia alternativa
  - overlays nativos del modo hibrido antiguo
  - inyeccion JS de runtime para sostener una interfaz web principal
- Ajustes aplicados:
  - `ios/App/App/AppDelegate.swift` queda reducido al ciclo base de arranque
  - `ios/App/App/NativeBridge/AppDelegate+Mounting.swift` deja de montar la ruta hibrida
  - `ios/App/App/NativeBridge/AppDelegate+Bridge.swift` deja de sostener el puente de UI web
  - `ios/App/App/NativeBridge/AppDelegate+Gestures.swift` retira gestos del panel web heredado
  - `ios/App/App/NativeBridge/HybridOverlayUI.swift` queda como placeholder temporal, ya no como pieza activa de runtime
- Esto alinea mejor la arquitectura con la guia:
  - SwiftUI-first real
  - persistencia nativa como fuente de verdad
  - web solo como respaldo de datos, no como interfaz viva

### 26. Fuente academica nativa definitiva

- `ios/App/App/NativeFoundation/LeanUpModels.swift` deja de derivar la base academica desde `index.html`.
- La carga academica queda reducida a:
  1. `native-academics.json`
  2. cache nativa propia en `UserDefaults`
- Se elimina la dependencia de `JavaScriptCore` para reconstruir materias y electivas desde el HTML heredado.
- A partir de este punto, el respaldo web deja de ser necesario incluso para reconstruir la malla academica en runtime.

### 27. Limpieza final del target iOS respecto al bridge retirado

- `ios/App/App.xcodeproj/project.pbxproj` deja de compilar las piezas retiradas del bridge hibrido:
  - `AppDelegate+Mounting.swift`
  - `AppDelegate+Injection.swift`
  - `AppDelegate+Bridge.swift`
  - `AppDelegate+Gestures.swift`
  - `HybridOverlayUI.swift`
- `ios/App/App/NativeBridge` queda reducido a `AppDelegate+Capacitor.swift`, que es la unica pieza de integracion nativa que sigue viva dentro de esa carpeta.
- `ios/App/App/AppDelegate.swift` queda como un `UIApplicationDelegate` simple y coherente con una app que ya no arranca sobre `WKWebView`.
- Con esto, el legado web deja de influir en:
  - arranque
  - interfaz
  - navegacion
  - inyeccion JS
  - recuperacion de base academica
- El legado web solo sobrevive como artefacto empaquetado temporal dentro de `public`, no como dependencia activa de la app nativa.

### 28. Eliminacion del paquete web del bundle iOS

- `ios/App/App/public/index.html` y los artefactos heredados de Cordova dejaron de formar parte del bundle iOS.
- `ios/App/App/native-academics.json` pasa a ser el unico recurso de datos empaquetado que la app iPhone necesita para la base academica.
- `ios/App/App/NativeFoundation/LeanUpModels.swift` simplifica su busqueda:
  1. recurso `native-academics.json`
  2. cache nativa local
- Se elimina la exploracion amplia del bundle buscando restos de la capa web.

### 29. Build del IPA desacoplado de Capacitor

- `.github/workflows/build.yml` deja de ejecutar:
  - `npm install`
  - `npx cap sync ios`
- El IPA se construye directamente desde el proyecto Xcode nativo.
- `ios/App/App.xcodeproj/project.pbxproj` deja de referenciar:
  - `CapApp-SPM`
  - `AppDelegate+Capacitor.swift`
  - `config.xml`
  - `capacitor.config.json`
- Tambien se retiran del repo iOS los restos de:
  - `CapApp-SPM`
  - configuraciones generadas de Capacitor
  - artefactos Cordova iOS heredados

### 30. Cierre tecnico de la guia para iPhone

- LeanUp iPhone ya cumple la arquitectura objetivo definida en la guia:
  - shell `SwiftUI-first`
  - estado y modelos en Swift
  - persistencia local nativa como fuente de verdad
  - sin `WKWebView` activo en runtime
  - sin `Capacitor` dentro del flujo de build del IPA
- `www/index.html` puede seguir existiendo como referencia historica del proyecto, pero ya no condiciona el producto iOS ni su compilacion.
- A partir de este punto, la deuda principal restante ya no es estructural sino visual y de producto.

### 31. Validacion real del cierre tecnico

- El proyecto volvio a compilar bien en GitHub Actions.
- La app abrio bien en iPhone.
- La `Malla` cargo correctamente las materias y la base academica nativa.
- Con esto queda confirmado no solo el cierre teorico de la guia, sino tambien su validacion practica en dispositivo real.

### 32. Limpieza de contexto y documentos heredados

- Se retiraron o actualizaron documentos viejos que seguian describiendo LeanUp como app hibrida cuando ya no lo es en iPhone.
- `AGENTS.md` se reescribio con el estado operativo real del proyecto.
- `CONTEXT.md` se reescribio como contexto actual y no como fotografia de la etapa Capacitor.
- `CLAUDE.md` se elimino porque ya no aportaba nada distinto y solo duplicaba contexto heredado.
- `www/index.html` se conserva por decision del usuario como referencia temporal, pero ya no debe tratarse como arquitectura activa.

### 33. Dashboard como pantalla guia del nuevo lenguaje visual

- `ios/App/App/NativeScreens/LeanUpDashboardScreen.swift` se rediseño como primera pantalla de referencia para el polish visual:
  - hero mas fuerte y mas editorial
  - banda de metricas con jerarquia mas clara
  - bloque de momento academico
  - bloque de siguiente movimiento
  - bloque de direccion profesional con senales compactas
- Se fijan decisiones visuales para repetir luego en `Malla`, `Perfil` y `Configuracion`:
  - gradientes UNAD mas intencionales
  - tarjetas mas limpias con relieve suave
  - titulos de seccion con `eyebrow` + titulo + detalle
  - barras de progreso mas claras
  - lenguaje de producto menos plano y mas orientado a lectura de avance
- `ios/App/App/NativeUI/LeanUpSharedUI.swift` tambien se elevo para que toda la app herede una base mas consistente:
  - fondo general mas trabajado con capas y acentos UNAD
  - `LeanUpSurfaceCard` mas pulida
  - nuevos componentes compartidos como `LeanUpSectionHeader` y `LeanUpProgressTrack`
  - eliminacion de piezas viejas del dashboard que ya no se usan

### 34. Bitacora de errores y ajuste de fluidez

- Se creo `docs/error-log.md` como registro vivo de errores importantes, causas y soluciones para no repetir fallos ya vistos.
- `AGENTS.md` se actualizo para recordar que este archivo debe consultarse antes de cambios grandes.
- Tras detectar lag al hacer scroll en iPhone, se priorizo rendimiento sobre decoracion:
  - `LeanUpPageBackground` se simplifico
  - se retiraron blurs grandes
  - se redujeron sombras pesadas
  - se suavizo el costo visual del hero del `Dashboard`
- Este ajuste se hizo porque la fluidez del usuario tiene prioridad sobre efectos visuales costosos.

### 35. Reorganizacion estructural de Malla

- `ios/App/App/NativeScreens/LeanUpMallaScreen.swift` se reordeno para que `Malla` se lea mas como control academico que como mezcla plana de bloques.
- Cambios principales:
  - overview centrado en promedio, creditos, materias por recuperar y materias sin nota
  - nueva tarjeta de `Siguiente paso` para decirle al usuario donde mirar primero
  - cada periodo separa claramente `Materias` de `Electivas complementarias`
  - las electivas bajan de protagonismo visual y narrativo
  - las materias reprobadas o sin nota ahora se leen mas facil dentro de la lista
- Con esto, `Malla` se acerca mas al rol real que tiene en LeanUp:
  - registrar notas
  - entender estado academico
  - decidir prioridades
- Durante esta iteracion aparecio un fallo de compilacion por logica imperativa dentro de `LeanUpCourseRow`.
- Se corrigio moviendo esa logica a propiedades calculadas privadas para mantener el `body` limpio y compatible con `ViewBuilder`.

### 36. Malla recupera traductor de LinkedIn y prompts de portafolio

- Se rescataron desde `www/index.html` los campos exactos de:
  - `skills`
  - texto de LinkedIn (`li`)
  - proyecto de portafolio (`po`)
  - prompt para IA (`prompt`)
- Esa informacion se migro a `ios/App/App/native-academics.json` para que la app nativa no dependa del HTML en runtime.
- `ios/App/App/NativeFoundation/LeanUpModels.swift` se amplio con `portfolioPrompt` tanto para materias como para opciones de electiva.
- `ios/App/App/NativeScreens/LeanUpMallaScreen.swift` ahora muestra dentro del detalle de cada materia y electiva:
  - bloque `Traductor de LinkedIn` con boton `Copiar texto`
  - bloque `Portafolio`
  - boton `🤖 Copiar prompt para IA` cuando la materia si tiene prompt asociado
- La intencion fue conservar el wording exacto del HTML original, pero ya dentro de la experiencia nativa.

### 37. Malla pasa a navegacion por periodo y filtros rapidos

- `ios/App/App/NativeScreens/LeanUpMallaScreen.swift` se reorganizo para reducir scroll largo y ruido visual.
- Cambios principales:
  - barra sticky horizontal de periodos
  - un solo periodo visible a la vez
  - filtros rapidos: `Todas`, `Pendientes`, `En curso`, `Aprobadas`, `Reprobadas`, `Electivas`
  - boton flotante de busqueda con hoja propia, en lugar de la barra fija de `searchable`
  - electivas con lectura dorada para recuperar mejor la referencia visual del HTML
  - chips de tipo y dificultad con color propio, en vez de tags neutras
  - boton flotante de volver dentro del detalle de materias y electivas
- El objetivo de esta iteracion fue que `Malla` se sienta mas rapida y mas facil de recorrer en iPhone, sin depender de mostrar toda la carrera de una sola vez.

### 38. Ajuste hacia controles mas nativos del sistema en Malla

- Se corrigio la implementacion para acercarla mas al patron nativo de Apple:
  - la barra de periodos deja de pinnearse dentro del scroll y queda fija fuera del contenido desplazable
  - la busqueda sale del boton flotante custom y pasa a abrir una vista con `searchable` del sistema
  - el detalle de materias y electivas deja el boton flotante custom y vuelve a usar barra de navegacion nativa con accion de regreso/cierre
- Regla reafirmada para siguientes iteraciones:
  - primero intentar control nativo de `SwiftUI`/sistema
  - solo caer en soluciones custom si el sistema no cubre bien la necesidad

### 39. Barra de periodos vuelve a bloque normal dentro del scroll

- La barra de periodos se habia dejado fija fuera del `ScrollView`.
- Se ajusto para volver a comportarse como un bloque normal de `Malla`:
  - aparece como una tarjeta/banner mas
  - se mueve con el scroll
  - el usuario debe subir para volver a verla, igual que con el resto del contenido
- Esto se hizo por preferencia de uso real del proyecto, no por limitacion tecnica.

### 40. Cierre de teclado mas natural en entradas de texto

- Se agrego soporte general para cerrar teclado en pantallas con input:
  - tocar fuera del campo
  - desplazar el contenido
- Esto se aplico sobre todo en:
  - `Malla`
  - detalle de materias
  - detalle de electivas
  - buscador de malla
  - `Configuracion`

### 41. Dashboard reorganizado alrededor del avance real

- Se elimino por completo el bloque de `Direccion profesional` del dashboard.
- La pantalla ahora queda organizada en 6 bloques claros:
  - hero
  - resumen rapido
  - ritmo de avance
  - GPA tracker
  - lectura de rendimiento
  - logros desbloqueados
- Tambien se movio mas logica al modelo nativo para que el dashboard no sea solo acomodo visual:
  - proyeccion estimada de grado basada en velocidad real
  - promedio por periodo para mini grafico
  - materias con mejor y peor desempeno segun notas reales
  - sistema de badges/logros desbloqueables
- Con esto `Dashboard` deja de repetir ideas sueltas y pasa a leer de verdad la carrera desde datos concretos.

## Estado actual

### Ya funcional

- Shell nativa
- Dashboard nativo
- Malla nativa
- Configuracion nativa
- Perfil nativo enriquecido
- Persistencia local nativa
- Tema claro/oscuro/sistema
- Estructura nativa modular registrada en el target iOS
- Malla con busqueda y foco academico nativo
- Perfil con lectura profesional mas estrategica
- Cache academica nativa para reducir dependencia del HTML heredado
- Pantallas nativas con tono mas de producto y menos de prototipo
- Bridge hibrido mas acotado y mas mantenible
- Fallback web reducido a compatibilidad y rescate de datos
- Base academica cargada solo desde fuente nativa y cache local
- Target iOS limpio de bridge de interfaz retirado
- Bundle iOS reducido a recursos nativos reales
- Build del IPA desacoplado de Capacitor
- Guia tecnica cerrada en su parte arquitectonica para iPhone
- Validacion real completada en GitHub Actions e iPhone
- Contexto documental alineado con la app nativa actual
- Dashboard convertido en pantalla guia del nuevo lenguaje visual
- Error log operativo creado y criterio de fluidez reforzado
- Malla reordenada para priorizar materias y utilidad academica real
- Malla vuelve a incluir textos exactos de LinkedIn y prompts de portafolio del HTML original
- Malla ahora funciona por periodo visible con filtros rapidos y busqueda flotante
- Malla ahora deja fija la barra de periodos fuera del scroll y vuelve a patrones mas nativos del sistema para buscar y volver
- Dashboard reorganizado con enfoque en ritmo, promedio, rendimiento y logros

### Riesgos actuales

- `www/index.html` sigue existiendo en el repo como archivo historico monolitico, aunque ya no afecta la app iPhone.
- Todavia faltan pasadas de polish visual y de consistencia total.
- Puede quedar algun documento historico menor con referencias antiguas, pero el contexto operativo principal ya quedo corregido.
- El nuevo lenguaje visual ya empezo en `Dashboard`, pero todavia no se ha propagado al resto de pantallas.

## Siguiente foco recomendado

1. Ajustar fino el nuevo dashboard segun uso real en iPhone.
2. Llevar la misma claridad estructural a `Perfil` y `Configuracion`.
3. Luego entrar a la pasada grande de polish visual y consistencia total.
