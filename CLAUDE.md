# CLAUDE.md — LeanUp iOS App

Contexto completo para Claude Code. Leer esto **antes** de modificar cualquier archivo.

---

## ¿Qué es LeanUp?

App universitaria para estudiantes de **Marketing y Negocios Digitales en la UNAD Colombia** (SNIES 116376), modalidad 100% virtual. Gestión de malla curricular, notas, perfil profesional, salidas laborales, portafolio y LinkedIn.

**Repositorio:** https://github.com/elnilsonn/leanup-app
**Contacto:** elnilsonn / nsolisasprilla@icloud.com

---

## Arquitectura

LeanUp es una **Capacitor hybrid app**: contenido web en `WKWebView` + overlays nativos Swift añadidos sobre el WebView.

```
┌─────────────────────────────────────┐
│  UIWindow                           │
│  ├── CAPWebView (WKWebView)         │  ← www/index.html (toda la app)
│  ├── LiquidGlassTabBar (SwiftUI)    │  ← bottom pill nativo
│  └── GlassBackButton (SwiftUI)      │  ← botón volver nativo
└─────────────────────────────────────┘
```

### Archivos críticos

| Archivo | Qué hace |
|---------|----------|
| `www/index.html` | La app completa (HTML + CSS + JS vanilla, un solo archivo) |
| `ios/App/App/AppDelegate.swift` | Todo el código nativo iOS: overlays, JS injection, bridge |
| `capacitor.config.json` | Config de Capacitor |
| `ios/App/App/CLAUDE.md` | Reglas de iOS 26 / Liquid Glass SwiftUI |
| `CONTEXT.md` | Contexto original del proyecto (datos académicos, estructura) |

### Stack
- **Web:** HTML + CSS + JS vanilla (sin frameworks), un solo `index.html`
- **iOS:** Capacitor + Swift/SwiftUI, distribuido via SideStore
- **Storage:** `localStorage` clave `leanup_v4` + backup en `UserDefaults` clave `leanup_v4_backup`
- **Build:** GitHub Actions → IPA sin firma → SideStore

---

## Colores UNAD

```css
--unad-navy: #001B50
--unad-blue: #0046AD
--unad-cyan: #009DC4
--unad-gold: #FFB81C
```

---

## Puente JS ↔ Swift (WKScriptMessageHandler)

**Todos los mensajes van a través de `webkit.messageHandlers.nativeUI.postMessage({event, ...})`**

Desde JS hacia Swift:
```javascript
// Guardar datos (dispara backup en UserDefaults)
webkit.messageHandlers.nativeUI.postMessage({ event: 'save', data: JSON.stringify({...}) });

// Haptics
webkit.messageHandlers.nativeUI.postMessage({ event: 'haptic', style: 'medium' });
// Estilos: 'light' | 'medium' | 'heavy' | 'rigid' | 'soft' | 'selection' | 'success' | 'warning' | 'error'

// Panel abierto/cerrado
webkit.messageHandlers.nativeUI.postMessage({ event: 'panelOpen' });
webkit.messageHandlers.nativeUI.postMessage({ event: 'panelClose' });

// Dark mode
webkit.messageHandlers.nativeUI.postMessage({ event: 'darkMode', on: true });

// Scroll (para ocultar/mostrar UI nativa)
webkit.messageHandlers.nativeUI.postMessage({ event: 'scroll', dir: 'down' });
```

Swift escucha en `userContentController(_:didReceive:)` dentro del AppDelegate.

---

## JS Injection (`injectEnhancements(into:)`)

El AppDelegate inyecta JavaScript al cargar el WebView que hace:

1. **`floatButtons`** — Mueve el `#saveBtn` nativo y añade botones flotantes de guardar/reiniciar
2. **`patchSaveReset`** — Wrappea `window.saveData` para enviar backup nativo después de guardar
3. **`patchMarkUnsaved`** — Wrappea `window.markUnsaved` (⚠️ NO es `markDirty`, ver Errores Pasados)
4. **`autoSave`** — Triple estrategia: `visibilitychange` + `pagehide` + `setInterval(30000)`
5. **`patchPanel`** — Wrappea `mobileOpenPanel`/`mobileClosePanelOrBack` con animación slide iOS
6. **`addWebHaptics`** — Añade `haptic` listeners a acordeones, mat-rows, botones de copiar, dark toggle, social buttons
7. **`setupScroll`** — Fix de scroll: `-webkit-tap-highlight-color`, `touch-action`, `user-select`
8. **`patchDark`** — Wrappea `toggleDark` para sincronizar el color scheme nativo

---

## Persistencia de datos

### Problema
`WKWebView` puede perder `localStorage` cuando iOS cierra la app con force-quit o bajo presión de memoria.

### Solución — 3 capas
1. **Guardar explícito:** `saveData()` en JS → `{event:'save', data:json}` → `UserDefaults.standard.set(b64, forKey:"leanup_v4_backup")`
2. **Auto-save:** `visibilitychange` + `pagehide` también disparan backup nativo
3. **Intervalo:** `setInterval(autoSave, 30000)` cada 30 segundos

### Restore al iniciar
`restoreFromUserDefaults(in:)` se llama en `webView(_:didFinish:)`:
```swift
let b64 = UserDefaults.standard.string(forKey: "leanup_v4_backup")
// Decodifica base64 → JSON → evalúa JS para setItem en localStorage → llama loadData()+renderAll()
```

---

## Gestos en el Tab Bar (LiquidGlassTabBar)

**Arquitectura unificada:** Un solo `DragGesture(minimumDistance:0)` con `.highPriorityGesture` cubre toda la barra.

```
Touch → onChanged:
  - Primer evento: guarda gestureStartX
  - Si |dx| > dragThreshold(8pt) → isDragging = true → preview silencioso
  - Si isDragging: mueve draggedIndex para preview visual

Touch → onEnded:
  - Si !isDragging (o dx < 8pt) → Es TAP → usa gestureStartX para calcular tab → haptic .medium → selecciona tab
  - Si isDragging → Es SWIPE → usa endX para calcular tab final → selecciona tab
  - Reset: gestureStartX=nil, isDragging=false, draggedIndex=nil
```

⚠️ **Nunca añadir un segundo `DragGesture` a los items individuales** — causará conflicto de gestos (ver Errores Pasados).

---

## Funciones clave en index.html

```javascript
saveData()              // Guarda en localStorage, feedback verde en #saveBtn
resetChanges()          // Llama confirm(), recarga desde localStorage
markUnsaved()           // Activa punto dorado en #saveBtn (⚠️ NO es markDirty)
loadData()              // Lee leanup_v4 de localStorage, restaura estado
renderMalla()           // Renderiza acordeones. NEVER llamar desde JS injection
toggleMalla(id)         // Abre/cierra acordeón — manipula DOM directo
mobileOpenPanel()       // Abre #detailPanel en móvil (agrega clase mobile-open)
mobileClosePanelOrBack()// Cierra panel y limpia selección
toggleDark(on)          // Activa/desactiva body.dark
setBottomNav(id)        // Activa tab del bottom nav web (oculto cuando usa nav nativa)
selMat(id)              // Abre detalle de materia normal
selElec(grupo, cod)     // Selecciona electiva y muestra detalle
copyPrompt(txt, btn)    // Copia prompt al portapapeles con feedback visual
```

### IDs y clases importantes

```html
#saveBtn         <!-- Botón guardar (puede estar oculto) -->
#resetBtn        <!-- Botón reiniciar -->
#glassSaveBtn    <!-- Versión glass del save -->
#glassResetBtn   <!-- Versión glass del reset -->
#darkToggle      <!-- Toggle modo oscuro -->
#mainContent     <!-- Contenedor principal (touch-action: pan-y) -->
#detailPanel     <!-- Panel de detalle (fixed en móvil) -->
.mat-row         <!-- Fila de materia -->
.per-header      <!-- Header de periodo (accordion) -->
.malla-acc-header<!-- Header de grupo acordeón de malla -->
.bottom-nav      <!-- Nav inferior web (glass) -->
.elec-opt        <!-- Opción de electiva -->
.nota-btn        <!-- Botones +/- de nota -->
```

---

## Gestos nativos iOS

### Edge Swipe (volver del panel de detalle)
- `UIScreenEdgePanGestureRecognizer` en `.leftEdge` añadido al WKWebView
- `handleEdgeSwipe(_:)`: en `.began` → `panelOpen`, en `.changed` → translateX en tiempo real, en `.ended` → si velocidad/progreso suficiente cierra panel, sino `snapPanelBack`
- El panel web sigue el dedo con `transform: translateX(Xpx)` via `evaluateJavaScript`

### Haptics
`triggerHaptic(style:)` mapea strings a UIKit:
```swift
"light"     → UIImpactFeedbackGenerator(.light)
"medium"    → UIImpactFeedbackGenerator(.medium)
"heavy"     → UIImpactFeedbackGenerator(.heavy)
"rigid"     → UIImpactFeedbackGenerator(.rigid)
"soft"      → UIImpactFeedbackGenerator(.soft)
"selection" → UISelectionFeedbackGenerator
"success"   → UINotificationFeedbackGenerator(.success)
"warning"   → UINotificationFeedbackGenerator(.warning)
"error"     → UINotificationFeedbackGenerator(.error)
```

---

## iOS 26 Liquid Glass — Reglas

Ver `ios/App/App/CLAUDE.md` para referencia completa. Resumen de reglas críticas:

1. **`.glassEffect()` va SIEMPRE ÚLTIMO** en la cadena de modificadores
2. **Nunca anidar glass dentro de glass** — glass no puede samplear a través de otras capas de glass
3. **`GlassEffectContainer`** solo cuando hay MÚLTIPLES elementos glass hermanos que deben morphear juntos — no usar para un solo elemento
4. Para el **bubble activo** dentro de una barra glass: usar `Capsule().fill(.primary.opacity(...))` — NO `.glassEffect()` (sería glass dentro de glass)
5. Para **GlassBackButton**: aplicar `.glassEffect()` como `ViewModifier` externo, no dentro de `.background{}`

```swift
// ✅ CORRECTO — glass como último modificador via ViewModifier
struct GlassCircleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.glassEffect(in: Circle())
    }
}
myButton.modifier(GlassCircleModifier())

// ❌ MAL — glass dentro de background
myButton.background { Circle().glassEffect(in: Circle()) }
```

---

## Animaciones iOS (parámetros Apple)

```swift
// Estándar — la mayoría de transiciones
.spring(response: 0.3, dampingFraction: 0.82)

// Press / feedback táctil
.spring(response: 0.15, dampingFraction: 0.65)

// Expansión / accordion
.spring(response: 0.4, dampingFraction: 0.75)
```

CSS equivalente para JS injection (panel slide):
```javascript
// Abrir panel (slide in from right)
cubic-bezier(0.25, 0.46, 0.45, 0.94)  // 280ms

// Cerrar panel (slide out to right)
cubic-bezier(0.4, 0, 1, 1)             // 280ms
```

---

## ⛔ Errores Pasados — No Repetir

### 1. Glass anidado (violación crítica de Liquid Glass)
**Error:** El bubble activo del tab bar usaba `.glassEffect(in: Capsule())` DENTRO de la barra que ya tenía `.glassEffect()`.
**Por qué falla:** Apple dice explícitamente que glass no puede samplear a través de otras capas de glass — el resultado es un artefacto visual negro/opaco.
**Fix:** El bubble activo usa `Capsule().fill(.primary.opacity(0.18))` — highlight sólido semitransparente, no glass.

### 2. `GlassEffectContainer` mal usado
**Error:** `GlassEffectContainer` envolvía un único elemento glass (la barra de tabs).
**Por qué falla:** `GlassEffectContainer` solo tiene efecto cuando hay MÚLTIPLES elementos glass hermanos que deben morphear/fusionarse. Con uno solo es inútil e introduce un wrapper innecesario.
**Fix:** Eliminar el container cuando solo hay un elemento glass.

### 3. `.glassEffect()` no aplicado como último modificador
**Error:** `.glassEffect()` usado dentro de un closure `.background { }` en el botón back.
**Por qué falla:** Los modificadores dentro de `.background` se aplican antes que los del exterior — el glass queda "enterrado" y no captura la capa visual correcta.
**Fix:** Crear `GlassCircleModifier: ViewModifier` que aplica `.glassEffect(in: Circle())` como modificador exterior con `.modifier(GlassCircleModifier())`.

### 4. `markDirty` vs `markUnsaved` (bug crítico)
**Error:** El JS injection intentaba wrappear `window.markDirty` para habilitar el botón de reset.
**Por qué falla:** La app usa `markUnsaved()` — `markDirty` NO EXISTE en `index.html`. El wrapper se ejecutaba silenciosamente sin efecto.
**Fix:** Siempre wrappear `window.markUnsaved`. Verificar nombres de funciones en el HTML antes de wrappear.

### 5. `strong self` en closure de SwiftUI
**Error:** `mountBackButton` tenía `GlassBackButton { self.capacitorWebView?... }` capturando AppDelegate fuertemente.
**Por qué falla:** Ciclo de retención — AppDelegate retiene el view controller que retiene el closure que retiene AppDelegate.
**Fix:** `GlassBackButton { [weak self] in self?.capacitorWebView?... }`

### 6. Datos no persisten al force-quit
**Error:** Solo se guardaba en `localStorage`. Al force-quit iOS puede purgar el storage del WKWebView.
**Por qué falla:** `WKWebView` almacena localStorage en una ubicación que iOS puede limpiar bajo presión de memoria o al matar la app.
**Fix:** Triple backup: (1) `UserDefaults` via message handler al guardar, (2) mismo backup en `visibilitychange`/`pagehide`, (3) `setInterval(autoSave, 30000)`. Al iniciar, `restoreFromUserDefaults()` recupera el backup.

### 7. Conflicto de dos DragGesture en el tab bar
**Error:** `DragGesture(minimumDistance:8)` en el `GeometryReader` exterior + `DragGesture(minimumDistance:0)` en cada `Button` individual.
**Por qué falla:** SwiftUI no puede resolver qué gesture tiene prioridad cuando ambos intentan procesar el mismo toque — comportamiento errático, swipes que no registran o que saltan al tab equivocado.
**Fix:** Un único `DragGesture(minimumDistance:0)` con `.highPriorityGesture` en toda la barra. `gestureStartX` + `isDragging` + `dragThreshold=8pt` diferencian tap de swipe internamente.

### 8. Haptics en cada step del drag (intrusivo)
**Error:** `UIImpactFeedbackGenerator(.light).impactOccurred()` se llamaba en `onDragChanged` en cada evento de movimiento.
**Por qué falla:** Con un dedo deslizándose a 60fps, el haptic se dispara ~60 veces/segundo — vibración constante e intrusiva que se siente como bug.
**Fix:** Eliminar haptic de `onDragChanged` completamente. Solo disparar `.medium` en `onDragEnded` cuando es un tap (selección de tab).

### 9. Items "seleccionados" al hacer scroll
**Error:** Al hacer scroll en cualquier tab, los `.mat-row` y otros elementos interactivos aparecían con estado `:active`/seleccionado mientras el dedo pasaba sobre ellos.
**Por qué falla:** iOS dispara `:active` y `tap-highlight-color` en cualquier elemento que el dedo toque durante el scroll.
**Fix (CSS injection):**
```css
* { -webkit-tap-highlight-color: transparent; }
.mat-row, .per-header, .elec-opt { -webkit-user-select: none; }
#mainContent { touch-action: pan-y; }
.mat-row, .elec-opt, .nota-btn { touch-action: manipulation; }
```

### 10. Retain cycle en WKScriptMessageHandler
**Error:** Registrar `AppDelegate` directamente como `WKScriptMessageHandler`.
**Por qué falla:** `WKUserContentController` retiene fuertemente al handler — ciclo de retención que impide que el WKWebView se libere.
**Fix:** Usar proxy `WeakMsgHandler: NSObject, WKScriptMessageHandler` que guarda `weak var target` y delega los mensajes.

---

## Proceso de actualización

1. Editar `www/index.html` y/o `ios/App/App/AppDelegate.swift`
2. `git add . && git commit -m "descripción" && git push`
3. GitHub Actions compila el IPA (10-20 min en Mac virtual)
4. Descargar artifact → extraer `LeanUp.ipa` → comprimir a `LeanUp-IPA.zip`
5. Crear release en GitHub con nuevo tag, subir zip
6. Actualizar `source.json` con nueva versión y URL
7. Push final

---

## Bugs del HTML resueltos (no reabrir)

- Panel desaparecía al editar nota → `saveNota/editNota` actualizan DOM inline sin rerenderizar
- Panel desaparecía al abrir/cerrar acordeón → `.malla-acc-header` en excepciones de click-outside
- `selElec` no llamaba `renderMalla()` → ahora actualiza DOM directamente
- Scroll loco en panel móvil → panel vive en `body`, no en el grid
- Doble tap zoom → `user-scalable=no` + `touch-action:manipulation`
- Zoom en inputs → `font-size:16px !important` en todos los inputs
- Botón atrás no aparecía → eliminado `style="display:none"` inline del HTML

---

## Mejoras pendientes

- [ ] Notificaciones de recordatorio de notas
- [ ] Compartir progreso como imagen
- [ ] Modo estudio con temporizador Pomodoro
- [ ] Calculadora de promedio ponderado
- [ ] Exportar malla a PDF
- [ ] Liquid Glass CSS real en toda la interfaz web (gradiente animado UNAD de fondo)
