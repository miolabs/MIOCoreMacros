# MIOCoreMacros

## @Export: Swift functions for WebAssembly and JavaScript

Write the API of a wasm module as plain Swift functions and mark them with `@Export`. The macro writes the `@_expose(wasm)` / `@_cdecl` wrapper next to each function, and `mio-wasm-bindings` writes the JavaScript class (and its `.d.ts`) that calls them. Both follow MIOCoreWasm's convention (MIOCore), so the module loads with `miowasm.js`.

```swift
import MIOCoreMacros
#if os(WASI)
import MIOCoreWasm          // the generated wrappers use MCWasm
#endif

/// Sorts by a column; a null / empty key clears the sort.
@Export( "dlr_sort" )
func sort ( _ table: Int, key: String? = nil, ascending: Bool = true ) throws { … }
```

The wrapper exists only when building for WASI (`#if os(WASI)`), so the functions build and test on every platform. Rules:

- **Global functions only**, not generic, async, variadic or `inout`.
- **Names:** `@Export( "symbol" )` sets the wasm export name; without it the Swift name is used. The JavaScript method always takes the Swift name.

| Swift | wasm | JavaScript |
|---|---|---|
| `Int`, `Int32` | i32 | number |
| `Double`, `Float` | f64 / f32 | number |
| `Bool` | i32 | boolean |
| `String`, `String?` | (pointer, length) | string, `null` → nil |
| `Data`, `[UInt8]` (optional too) | (pointer, length) | Uint8Array, or a string as UTF-8 |
| any Codable type (optional too) | JSON (pointer, length) | any value (JSON) |

- **Results:** the same types. `String`, `Data` and Codable results come back as an MCWasm buffer, and an optional `String` / `Data` result of nil becomes `null`.
- **Optional numbers and Bool** aren't supported; use a Codable type.
- **Errors:** a function that throws, or that decodes a JSON argument, records the error with `MCWasm.fail`. The generated JavaScript rethrows it as an `Error` with the same message.
- **Defaults:** literal default values (`true`, `3`, `"es_ES"`, `nil`) become JavaScript defaults.
- **Documentation:** `///` comments become JSDoc.

### JavaScript bindings
From the package that has the `@Export` functions:

```bash
swift package --allow-writing-to-package-directory wasm-bindings \
    --target DLReportKitWasm --class DLReportKitWasm --output js/DLReportKitWasm.js
```

The command writes `js/DLReportKitWasm.js` and `js/DLReportKitWasm.d.ts`. `--miowasm <path>` changes how the class imports `miowasm.js` (default `./miowasm.js`). Extend the class for JS-only helpers:

```js
import { DLReportKitWasm } from "./DLReportKitWasm.js";
export class DLReportKit extends DLReportKitWasm { tables() { … } }
const kit = await DLReportKit.instantiate( fetch( "DLReportKitWasm.wasm" ) );
```

`MIOExportCore` holds the model both sides share, so the Swift wrapper and the JavaScript class can't disagree.
