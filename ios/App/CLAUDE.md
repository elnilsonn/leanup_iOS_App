# Claude Context

## Project Overview

* Platform: iOS 26+
* Language: Swift 6
* UI Framework: SwiftUI (primary), UIKit (only when necessary)
* Architecture: MVVM
* Minimum deployment target: iOS 26.0

---

## Development Rules

### General

* Always write Swift 6 compatible code (strict concurrency)
* Prefer SwiftUI over UIKit unless UIKit is strictly required
* Use `@Observable` macro instead of `ObservableObject` + `@Published`
* Use structured concurrency (`async/await`, `Task`, `TaskGroup`) — never use callbacks or completion handlers for new code
* Use Swift's native `Result` type or `throws` for error handling
* Keep views small and composable — extract subviews aggressively
* Never force unwrap optionals — use `guard let`, `if let`, or provide safe defaults

### Xcode Project Files

* **NEVER** modify `.pbxproj` files directly — this corrupts Xcode projects
* When creating new Swift files, create them and tell me to add them to Xcode manually
* When adding assets or resources, place them in the correct folder and instruct me to drag them into Xcode

### Testing

* Write unit tests with **Swift Testing** framework (not XCTest) for new code
* Use `#expect` and `#require` macros
* Test ViewModels, not Views directly

---

## iOS 26 — Liquid Glass

Liquid Glass is Apple's new dynamic material introduced in iOS 26. It creates translucent, physics-aware surfaces that refract and reflect light.

### Core Modifiers

```swift
// Basic usage — apply LAST in modifier chain
.glassEffect()

// With shape (default is capsule)
.glassEffect(in: .rect(cornerRadius: 16))
.glassEffect(in: .circle)
.glassEffect(in: .capsule)

// Glass variants
.glassEffect(.regular)                           // Standard glass
.glassEffect(.clear)                             // Subtle, minimal blur
.glassEffect(.regular.tint(.blue.opacity(0.3))) // Tinted

// Disable conditionally
.glassEffect(.regular, isEnabled: condition)
```

### GlassEffectContainer

Use when multiple glass elements are close together — they will morph and blend like liquid when they overlap:

```swift
GlassEffectContainer(spacing: 8) {
    HStack(spacing: 8) {
        Button("Action 1") { }
            .glassEffect()
        Button("Action 2") { }
            .glassEffect()
    }
}
```

### glassEffectID — Morphing Transitions

Animate between glass shapes using `matchedGeometryEffect`-style IDs:

```swift
GlassEffectContainer {
    if isExpanded {
        LargeView()
            .glassEffect(in: .rect(cornerRadius: 20))
            .glassEffectID("card", in: namespace)
    } else {
        SmallView()
            .glassEffect(in: .capsule)
            .glassEffectID("card", in: namespace)
    }
}
```

### Best Practices

1. Apply `.glassEffect()` as the **LAST** modifier on a view
2. Use `GlassEffectContainer` whenever two glass elements are within ~20pt of each other
3. Tint sparingly — only for primary call-to-action elements
4. Don't nest glass inside glass — glass cannot sample through other glass layers
5. Use `.clear` variant on content-heavy backgrounds where `.regular` would be too distracting
6. Avoid putting glass on top of other glass — use a dimming layer in between if needed
7. Interactive elements (buttons, toggles) automatically get scale/bounce/shimmer feedback when using glass

### Common Patterns

```swift
// Floating toolbar
HStack {
    ForEach(tools) { tool in
        Button { selectTool(tool) } label: {
            Image(systemName: tool.icon)
        }
    }
}
.padding(.horizontal, 16)
.padding(.vertical, 10)
.glassEffect(in: .capsule)

// Card with glass
VStack { ... }
    .padding()
    .glassEffect(in: .rect(cornerRadius: 20))

// Overlay sheet with glass background
ZStack {
    Color.black.opacity(0.2)  // dimming layer
    VStack { ... }
        .glassEffect(.clear, in: .rect(cornerRadius: 24))
}

// Tinted primary button (use sparingly)
Button("Get Started") { }
    .glassEffect(.regular.tint(.blue))
```

### UIKit Equivalent

```swift
// UIKit: use GlassEffectView
let glass = GlassEffectView(effect: UIGlassEffect())
glass.translatesAutoresizingMaskIntoConstraints = false
view.addSubview(glass)
// Then position with Auto Layout
```

---

## SwiftUI Patterns to Follow

```swift
// Prefer @Observable (iOS 17+, standard in iOS 26)
@Observable class MyViewModel {
    var items: [Item] = []
    var isLoading = false
}

// Environment injection
@Environment(MyViewModel.self) var viewModel

// Navigation
NavigationStack {
    ContentView()
        .navigationDestination(for: Destination.self) { dest in
            DestinationView(dest)
        }
}

// Animations — prefer spring
withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
    isExpanded.toggle()
}
```

---

## File Organization

```
MyApp/
├── App/
│   ├── MyApp.swift           # @main entry point
│   └── AppState.swift        # Global app state (@Observable)
├── Features/
│   ├── Home/
│   │   ├── HomeView.swift
│   │   └── HomeViewModel.swift
│   └── Detail/
│       ├── DetailView.swift
│       └── DetailViewModel.swift
├── Shared/
│   ├── Components/           # Reusable SwiftUI views
│   ├── Extensions/
│   └── Models/
└── Resources/
    └── Assets.xcassets
```

---

## Response Rules

When asked for something, always:

1. Write complete, compilable Swift code (no pseudocode, no `// TODO` unless asked)
2. Import only necessary frameworks
3. Include `// MARK: -` sections for code organization
4. Prefer composition over inheritance
5. If a native SwiftUI solution exists, use it — don't reach for UIKit or 3rd party libs first
