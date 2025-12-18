# json_stringify_ordered

**json_stringify_ordered** is a GML script for GameMaker that efficiently converts any value (struct, array, or primitive) into a formatted, human-readable JSON string.

---

## 🚀 Features

- Converts nested structs, arrays and primitives into formatted JSON (2-space indentation).
- Sorts struct keys alphabetically for deterministic output.
- Implemented using buffers for improved performance on large objects.

---

## 📋 Requirements

- GameMaker with support for structs (v2.3+)

---

## 💡 Usage

```gml
// json_stringify_ordered(value, prettify = false)
// value: the value to serialize
// prettify: optional boolean. If true, outputs formatted JSON with 2-space indentation.
//         If false, outputs compact JSON (no extra spaces or line breaks).
// returns: JSON string
var s = json_stringify_ordered(value, true);
show_debug_message(s);
```

Example:

```gml
var st = {
    name: "Mario",
    score: 123,
    active: true,
    inv: [ "key", "coin" ],
    meta: { level: 5, boss: undefined }
};

var json = json_stringify_ordered(st);
show_debug_message(json);
```

Output:

```json
{
  "active": true,
  "inv": [
    "key",
    "coin"
  ],
  "meta": {
    "boss": null,
    "level": 5
  },
  "name": "Mario",
  "score": 123
}
```

> Note: struct keys are sorted alphabetically (`active`, `inv`, `meta`, ...).

---

## 🔧 Technical details

- Serialization uses the `buffer_` functions to write directly to a buffer, reducing temporary allocations — this is significantly faster than concatenating strings.
- Strings are escaped, numbers keep their numeric form, and `undefined`/`NaN` become `null`.

---

## 🤝 Contributing

If you'd like to improve the script or suggest changes, open an issue or a pull request in the repository.

---

## 📝 License

MIT
