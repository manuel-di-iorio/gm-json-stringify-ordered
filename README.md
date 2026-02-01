# json_stringify_ordered

**json_stringify_ordered** is a GML script for GameMaker that efficiently converts any value (struct, array, or primitive) into a formatted, human-readable JSON string.

---

## 🚀 Features

- Converts nested structs, arrays and primitives into formatted JSON (2-space indentation).
- Sorts struct keys alphabetically for deterministic output.
- **Compact mode**: keep small arrays or structs on a single line within pretty-printed output for better readability.
- Implemented using buffers for improved performance on large objects.

---

## 📋 Requirements

- GameMaker with support for structs (v2.3+)

---

## 💡 Usage

```gml
// json_stringify_ordered(value, prettify = false, compact = 0)
// value: the value to serialize
// prettify: optional boolean. If true, outputs formatted JSON with 2-space indentation.
//         If false, outputs compact JSON (no extra spaces or line breaks).
// compact: optional real. threshold (in characters) to keep small structs and arrays
//         on a single line when prettify is true. (0 = disabled).
// returns: JSON string
var s = json_stringify_ordered(value, true, 40);
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

### 📦 Compact Formatting Example

When using `prettify = true`, you can specify a `compact` threshold to keep short lists and objects on a single line:

```js
var st = {
  pos: { x: 10, y: 20 },
  tags: ["fire", "water", "earth"],
  active: true
};

var json = json_stringify_ordered(st, true, 40);
show_debug_message(json);
```

Output:

```json
{
  "active": true,
  "pos": { "x": 10, "y": 20 },
  "tags": [ "fire", "water", "earth" ]
}
```

> Note: struct keys are sorted alphabetically (`active`, `pos`, `tags`).

## 🤝 Contributing

If you'd like to improve the script or suggest changes, open an issue or a pull request in the repository.

---

## 📝 License

MIT
