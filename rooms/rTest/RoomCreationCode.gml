/// rTest — test suite + benchmarks for json_stringify_ordered
/// Run the room and read the output in Output > Debug.
///
/// Test philosophy: expected values come from the native json_stringify
/// (oracle) or from json_parse roundtrips, never from hardcoded guesses.
/// Hardcoded full-output strings are avoided on purpose: key ordering is
/// checked via key positions, pretty/compact via structural properties.

global.__t_total = 0;
global.__t_passed = 0;
global.__t_failed = 0;

function __t_eq(_name, _got, _exp) {
    global.__t_total++;
    if (_got == _exp) {
        global.__t_passed++;
    } else {
        global.__t_failed++;
        show_debug_message("FAIL " + _name + "\n  exp: " + string(_exp) + "\n  got: " + string(_got));
    }
}

function __t_true(_name, _cond, _extra = "") {
    global.__t_total++;
    if (_cond) {
        global.__t_passed++;
    } else {
        global.__t_failed++;
        show_debug_message("FAIL " + _name + " " + string(_extra));
    }
}

function __t_summary() {
    show_debug_message("=== Test summary: " + string(global.__t_passed) + "/" + string(global.__t_total)
        + " passed, " + string(global.__t_failed) + " failed ===");
}

/// Deep equality for structs/arrays/primitives (NaN-aware).
function __deep_eq(_a, _b) {
    if (is_struct(_a) || is_struct(_b)) {
        if (!is_struct(_a) || !is_struct(_b)) return false;
        var _na = variable_struct_get_names(_a);
        var _nb = variable_struct_get_names(_b);
        if (array_length(_na) != array_length(_nb)) return false;
        for (var _i = 0; _i < array_length(_na); _i++) {
            var _k = _na[_i];
            if (!variable_struct_exists(_b, _k)) return false;
            if (!__deep_eq(_a[$ _k], _b[$ _k])) return false;
        }
        return true;
    }
    if (is_array(_a) || is_array(_b)) {
        if (!is_array(_a) || !is_array(_b)) return false;
        if (array_length(_a) != array_length(_b)) return false;
        for (var _j = 0; _j < array_length(_a); _j++) {
            if (!__deep_eq(_a[_j], _b[_j])) return false;
        }
        return true;
    }
    if (is_nan(_a) || is_nan(_b)) return (is_nan(_a) && is_nan(_b));
    return (_a == _b);
}

/// Core oracle: ordered output must match native output exactly, and parsing
/// our output must give back the value (every oracle case gets a json_parse).
/// Only valid for JSON-safe values with keys already in sorted order
/// (native preserves insertion order, ordered sorts), or key-free values.
function __t_native_eq(_name, _v) {
    __t_eq(_name + " (vs native)", json_stringify_ordered(_v), json_stringify(_v));
    __t_true(_name + " (roundtrip)", __deep_eq(json_parse(json_stringify_ordered(_v)), _v));
}

/// Roundtrip: parsing our output must give back an equal value.
/// Only valid for JSON-safe values (no NaN/Infinity/int64/method/handle).
function __t_roundtrip(_name, _v) {
    __t_true(_name + " (roundtrip)", __deep_eq(json_parse(json_stringify_ordered(_v)), _v));
}

/// Info-only comparison with native: prints when different, never fails.
/// Used where native conventions legitimately differ (float formatting,
/// handle stringification, unicode escapes).
function __t_info_native(_name, _v) {
    var _o = json_stringify_ordered(_v);
    var _n = json_stringify(_v);
    if (_o != _n) {
        show_debug_message("INFO " + _name + " differs from native\n  native:  " + string(_n) + "\n  ordered: " + string(_o));
    }
}

/// Numbers: native always formats floats (42.0, 3.1400000000000001) while
/// ordered uses string() (42, 3.14). Both are valid JSON for the same value,
/// so the assertion is parse-based, with native comparison info-only.
function __t_num(_name, _v) {
    __t_true(_name + " (parses back)", json_parse(json_stringify_ordered(_v)) == _v);
    __t_info_native(_name, _v);
}

/// Independent hex -> int64 conversion (shifts, not multiply-add: int64
/// arithmetic overflow does not wrap, but bitwise ops keep the 64-bit pattern).
function __hex_to_int64(_hex) {
    var _v = int64("0");
    var _len = string_length(_hex);
    for (var _h = 1; _h <= _len; _h++) {
        var _c = ord(string_char_at(_hex, _h));
        var _d = -1;
        if (_c >= 48 && _c <= 57) _d = _c - 48;
        else if (_c >= 97 && _c <= 102) _d = _c - 97 + 10;
        else if (_c >= 65 && _c <= 70) _d = _c - 65 + 10;
        else return undefined;
        _v = (_v << 4) | int64(_d);
    }
    return _v;
}

/// Checks one int64 value against the documented "@i64@hex$i64$" convention:
/// shape is verified on the raw output string, the hex is decoded with
/// independent string math, and the engine must decode it back natively.
function __t_int64(_name, _v64) {
    var _out = json_stringify_ordered(_v64); // raw, e.g. "\"@i64@ff$i64$\""
    var _ok_shape = (string_pos("\"@i64@", _out) == 1)
        && (string_pos("$i64$\"", _out) == string_length(_out) - 5);
    __t_true(_name + " (sentinel shape)", _ok_shape, _out);
    if (!_ok_shape) return;
    var _hex = string_copy(_out, 7, string_length(_out) - 12);
    __t_true(_name + " (lowercase hex)", _hex == string_lower(_hex), _hex);
    __t_true(_name + " (hex decodes back)", __hex_to_int64(_hex) == _v64, _hex);
    __t_true(_name + " (native decodes back)", json_parse(_out) == _v64, _out);
}

/// Measures fn() called _iters times, repeated _trials times.
/// Returns the average time per call in microseconds (best trial).
function __b_measure(_mfn, _iters, _trials) {
    // Warmup: stabilizes key/pad cache and branch predictor.
    var _w = max(10, _iters div 10);
    for (var _wi = 0; _wi < _w; _wi++) _mfn();
    var _best = undefined;
    var _s = 0;
    var _e = 0;
    for (var _t = 0; _t < _trials; _t++) {
        _s = get_timer();
        for (var _k = 0; _k < _iters; _k++) _mfn();
        _e = (get_timer() - _s) / max(1, _iters); // us/call
        if (is_undefined(_best) || _e < _best) _best = _e;
    }
    return _best;
}

function __b_report(_label, _us_per_call, _baseline = undefined) {
    var _ops = (_us_per_call > 0) ? (1000000.0 / _us_per_call) : 0;
    var _msg = _label + ": " + string(_us_per_call) + " us/call (" + string(_ops) + " ops/s)";
    if (_baseline != undefined && _baseline > 0 && _us_per_call > 0) {
        var _pct = 100.0 * _us_per_call / _baseline;
        _msg += " — " + string(_pct) + "% of baseline (" + string(_baseline / _us_per_call) + "x)";
    }
    show_debug_message(_msg);
}

// ============================================================
// 1. Key ordering (the feature native does NOT provide).
// Native preserves insertion order, so ordering is checked via
// key positions in the output + parse roundtrip, not full strings.
// ============================================================
show_debug_message("=== Test: ordering ===");

var _o1 = json_stringify_ordered({ z: 1, a: 2, m: 3 });
__t_true("order base a<m<z", string_pos("\"a\"", _o1) < string_pos("\"m\"", _o1) && string_pos("\"m\"", _o1) < string_pos("\"z\"", _o1), _o1);
__t_true("order base roundtrip", __deep_eq(json_parse(_o1), { z: 1, a: 2, m: 3 }));

var _o2 = json_stringify_ordered({ b: 1, A: 2 });
__t_true("order case-sensitive A<b", string_pos("\"A\"", _o2) < string_pos("\"b\"", _o2), _o2);
__t_true("order case-sensitive roundtrip", __deep_eq(json_parse(_o2), { b: 1, A: 2 }));

var _o3 = json_stringify_ordered({ "2": 6, "10": 5 });
__t_true("order numeric-like 10<2", string_pos("\"10\"", _o3) < string_pos("\"2\"", _o3), _o3);
__t_true("order numeric-like roundtrip", __deep_eq(json_parse(_o3), { "2": 6, "10": 5 }));

var _o4 = json_stringify_ordered({ z: { d: 1, b: 2 }, a: 1 });
__t_true("order nested outer a<z", string_pos("\"a\"", _o4) < string_pos("\"z\"", _o4), _o4);
__t_true("order nested inner b<d", string_pos("\"b\"", _o4) < string_pos("\"d\"", _o4), _o4);
__t_true("order nested roundtrip", __deep_eq(json_parse(_o4), { z: { d: 1, b: 2 }, a: 1 }));

// Arrays keep their order (native preserves it too — verified in output),
// so an exact oracle works with string elements (avoids float formatting).
__t_native_eq("array order kept", ["c", "a", "b"]);

var _nomut = { b: 1, a: 2 };
json_stringify_ordered(_nomut);
__t_true("input not mutated", variable_struct_names_count(_nomut) == 2 && variable_struct_exists(_nomut, "a") && variable_struct_exists(_nomut, "b"));

// ============================================================
// 2. Empty containers (minified via native oracle, pretty structural)
// ============================================================
show_debug_message("=== Test: empty containers ===");

__t_native_eq("empty struct min", {});
__t_native_eq("empty array min", []);

var _pe = json_stringify_ordered({}, true);
__t_true("empty struct pretty roundtrip", __deep_eq(json_parse(_pe), {}));
__t_true("empty struct pretty has newline", string_pos("\n", _pe) > 0, _pe);
var _pa = json_stringify_ordered([], true);
__t_true("empty array pretty roundtrip", __deep_eq(json_parse(_pa), []));
__t_true("empty array pretty has newline", string_pos("\n", _pa) > 0, _pa);

var _pn = json_stringify_ordered({ a: {}, l: [] }, true);
__t_true("empty nested pretty roundtrip", __deep_eq(json_parse(_pn), { a: {}, l: [] }));

// pretty+compact on empties must collapse to native min output
__t_eq("empty struct pretty+compact = native", json_stringify_ordered({}, true, 10), json_stringify({}));
__t_eq("empty array pretty+compact = native", json_stringify_ordered([], true, 10), json_stringify([]));

// ============================================================
// 3. Primitives (native oracle + roundtrip)
// ============================================================
show_debug_message("=== Test: primitives ===");

__t_native_eq("string", "hello");
__t_native_eq("empty string", "");
__t_num("int", 42);
__t_num("negative int", -7);
__t_num("zero", 0);
__t_num("float", 1.5);
__t_num("float pi", 3.14);
__t_native_eq("true", true);
__t_native_eq("false", false);
__t_native_eq("bool array", [true, false]);
// Struct/array with undefined: numbers inside make exact match impossible
// (native float formatting), so roundtrip + info-only native comparison.
__t_roundtrip("undefined in struct", { boss: undefined, level: 5 });
__t_info_native("undefined in struct", { boss: undefined, level: 5 });
__t_roundtrip("undefined in array", [undefined, 1]);
__t_info_native("undefined in array", [undefined, 1]);
__t_roundtrip("struct with undefined", { boss: undefined, level: 5 });

// top-level undefined: native oracle avoided, parse must yield null/undefined
__t_true("undefined top-level parses to null", is_undefined(json_parse(json_stringify_ordered(undefined))));
// pointer_null writes as JSON null, like undefined (per engine docs)
__t_true("pointer_null writes null", json_stringify_ordered(pointer_null) == "null");
__t_true("pointer_null parses to null", is_undefined(json_parse(json_stringify_ordered(pointer_null))));

// ============================================================
// 4. String and key escaping (native oracle + parse-back)
// ============================================================
show_debug_message("=== Test: escaping ===");

var _esc_cases = ["a\"b", "a\\b", "a\nb", "a\rb", "a\tb", "line1\nline2\ttab"];
for (var _ei = 0; _ei < array_length(_esc_cases); _ei++) {
    var _es = _esc_cases[_ei];
    __t_native_eq("escape case " + string(_ei), _es);
    __t_true("escape case " + string(_ei) + " parses back", json_parse(json_stringify_ordered(_es)) == _es);
}
// Control chars where native conventions may differ: parse-back must hold,
// native comparison is info-only.
var _esc_exotic = ["a\bb", "a\fb", "\\\"\n\r\t", "hey\nhow are you?"];
for (var _ej = 0; _ej < array_length(_esc_exotic); _ej++) {
    var _ex = _esc_exotic[_ej];
    __t_true("exotic escape " + string(_ej) + " parses back", json_parse(json_stringify_ordered(_ex)) == _ex);
    __t_info_native("exotic escape " + string(_ej), _ex);
}
// Unicode: must survive the roundtrip; native comparison info-only
// (native may emit \uXXXX while we pass raw UTF-8 through — both valid).
var _eu = "caffè € 日本語";
__t_true("unicode parses back", json_parse(json_stringify_ordered(_eu)) == _eu);
__t_info_native("unicode", _eu);

// Keys with special chars: single-key structs so native order is irrelevant,
// string values so native float formatting cannot interfere.
var _ek = {};
_ek[$ "a\"b"] = "v";
__t_native_eq("key with double quote", _ek);
__t_true("key with double quote parses back", __deep_eq(json_parse(json_stringify_ordered(_ek)), _ek));
var _ek2 = {};
_ek2[$ "x\ny"] = "v";
__t_native_eq("key with newline", _ek2);
var _ek3 = {};
_ek3[$ "a\\b"] = "v";
__t_native_eq("key with backslash", _ek3);

// ============================================================
// 5. Special values: NaN / Infinity / int64 / handle / method.
// Native has no defined behavior here, so checks are structural
// (documented sentinel conventions + parse), not hardcoded strings.
// ============================================================
show_debug_message("=== Test: special values ===");

// The engine natively decodes these sentinels, so assertions check the
// decoded value (not the literal marker string).
__t_true("NaN decodes back to NaN", is_nan(json_parse(json_stringify_ordered(NaN))));
__t_true("infinity decodes back", json_parse(json_stringify_ordered(infinity)) == infinity);
__t_true("-infinity decodes back", json_parse(json_stringify_ordered(-infinity)) == -infinity);
__t_true("NaN in array roundtrip", __deep_eq(json_parse(json_stringify_ordered([NaN, 1])), [NaN, 1]));

__t_int64("int64 zero", int64("0"));
__t_int64("int64 42", int64("42"));
__t_int64("int64 255", int64("255"));
__t_int64("int64 16", int64("16"));
__t_int64("int64 max", int64("9223372036854775807"));
__t_int64("int64 min", int64("-9223372036854775808"));
__t_int64("int64 -1", int64("-1"));

// method values report is_struct with zero visible keys, so ordered writes
// {} while native exposes internals ({"toString":{"length":...}}). The checks
// below pin the actual behavior (valid struct, stable) without guessing.
var _mfn = function() { return 1; };
var _mout = json_stringify_ordered(_mfn);
__t_true("method output parses to struct", is_struct(json_parse(_mout)), _mout);
__t_true("method output is stable", json_stringify_ordered(json_parse(_mout)) == _mout, _mout);
var _marr = json_parse(json_stringify_ordered([_mfn]));
__t_true("method in array parses to struct", is_struct(_marr[0]), _mout);
__t_info_native("method", _mfn);

// handles keep the engine string() form (e.g. "ref ds_map 0", while native
// uses "@ref ds_map(0)"): both are valid JSON strings, so the checks pin
// that our output parses back to string(v), with the native diff as info.
var _map = ds_map_create();
__t_true("ds_map parses to string(ref)", json_parse(json_stringify_ordered(_map)) == string(_map), string(_map));
var _lst = ds_list_create();
__t_true("ds_list parses to string(ref)", json_parse(json_stringify_ordered(_lst)) == string(_lst), string(_lst));
__t_info_native("ds_map handle", _map);
__t_info_native("ds_list handle", _lst);
ds_list_destroy(_lst);
ds_map_destroy(_map);

// ============================================================
// 6. Pretty printing (native has no pretty mode: structural checks)
// ============================================================
show_debug_message("=== Test: pretty ===");

var _pretty_st = { name: "Mario", score: 123, active: true, inv: ["key", "coin"], meta: { level: 5, boss: undefined } };
var _pretty_out = json_stringify_ordered(_pretty_st, true);
__t_true("pretty roundtrip", __deep_eq(json_parse(_pretty_out), _pretty_st));
__t_true("pretty starts indented", string_pos("{\n  \"active\"", _pretty_out) == 1, string_copy(_pretty_out, 1, 20));
__t_true("pretty keys ordered", string_pos("\"active\"", _pretty_out) < string_pos("\"inv\"", _pretty_out)
    && string_pos("\"inv\"", _pretty_out) < string_pos("\"meta\"", _pretty_out)
    && string_pos("\"meta\"", _pretty_out) < string_pos("\"name\"", _pretty_out)
    && string_pos("\"name\"", _pretty_out) < string_pos("\"score\"", _pretty_out));
__t_true("pretty ends with newline+brace", string_copy(_pretty_out, string_length(_pretty_out) - 1, 2) == "\n}");

var _parr = json_stringify_ordered([1, 2], true);
__t_true("pretty array roundtrip", __deep_eq(json_parse(_parr), [1, 2]));
__t_true("pretty array shape", string_pos("[\n  1", _parr) == 1 && string_copy(_parr, string_length(_parr) - 1, 2) == "\n]", _parr);

var _pnest = json_stringify_ordered({ a: { b: { c: 1 } } }, true);
__t_true("pretty nested roundtrip", __deep_eq(json_parse(_pnest), { a: { b: { c: 1 } } }));
__t_true("pretty nested 6-space indent", string_pos("\n      \"c\"", _pnest) > 0, _pnest);

// Struct member order in memory is not source order (native emitted b,a for
// an {a,b} literal), so multi-key structs can only match native at parse level.
__t_true("minified matches native after parse",
    __deep_eq(json_parse(json_stringify_ordered({ a: "x", b: "y" })), json_parse(json_stringify({ a: "x", b: "y" }))));
__t_eq("compact flag has no effect when minified",
    json_stringify_ordered({ b: "y", a: "x" }, false, 1000),
    json_stringify_ordered({ b: "y", a: "x" }, false));
__t_true("compact flag minified parses", __deep_eq(json_parse(json_stringify_ordered({ b: "y", a: "x" }, false, 1000)), { b: "y", a: "x" }));

// ============================================================
// 7. Compact mode (behavioral: inline vs expanded + roundtrip)
// ============================================================
show_debug_message("=== Test: compact ===");

var _cmed = { pos: { x: 10, y: 20 }, tags: ["fire", "water"], active: true };
var _cmed_out = json_stringify_ordered(_cmed, true, 40);
__t_true("compact medium roundtrip", __deep_eq(json_parse(_cmed_out), _cmed));
__t_true("compact medium root expands", string_pos("{\n", _cmed_out) == 1, string_copy(_cmed_out, 1, 30));
__t_true("compact medium child struct inline", string_pos("{ \"x\": 10, \"y\": 20 }", _cmed_out) > 0, _cmed_out);
__t_true("compact medium child array inline", string_pos("[ \"fire\", \"water\" ]", _cmed_out) > 0, _cmed_out);

var _c0 = json_stringify_ordered({ x: 10, y: 20 }, true, 0);
__t_true("compact 0 expands", string_pos("\n", _c0) > 0, _c0);
__t_true("compact 0 roundtrip", __deep_eq(json_parse(_c0), { x: 10, y: 20 }));

var _chuge = json_stringify_ordered({ x: 10, y: 20 }, true, 100000);
__t_true("compact huge all inline", string_count("\n", _chuge) == 0, _chuge);
__t_true("compact huge roundtrip", __deep_eq(json_parse(_chuge), { x: 10, y: 20 }));

var _carr0 = json_stringify_ordered(["fire", "water"], true, 0);
__t_true("compact array 0 expands", string_pos("\n", _carr0) > 0, _carr0);
__t_true("compact array 0 roundtrip", __deep_eq(json_parse(_carr0), ["fire", "water"]));
var _carrh = json_stringify_ordered(["fire", "water"], true, 100000);
__t_true("compact array huge inline", string_count("\n", _carrh) == 0, _carrh);
__t_true("compact array huge roundtrip", __deep_eq(json_parse(_carrh), ["fire", "water"]));

// Tight threshold: inline length must be < compact; equal length expands.
// The reference length is measured, not assumed.
var _probe = { a: 1 };
var _inline_len = string_byte_length(json_stringify_ordered(_probe, true, 100000));
var _at_exact = json_stringify_ordered(_probe, true, _inline_len);
__t_true("compact exact threshold expands", string_pos("\n", _at_exact) > 0, "len=" + string(_inline_len));
__t_true("compact exact threshold still parses", __deep_eq(json_parse(_at_exact), _probe));
var _at_plus = json_stringify_ordered(_probe, true, _inline_len + 1);
__t_true("compact threshold+1 stays inline", string_pos("\n", _at_plus) == 0, _at_plus);

// Nested compact: huge threshold => all inline (0 newlines); small threshold => expands
var _nested = { big: { a: 1, b: 2, c: 3, d: 4, e: 5 }, tiny: { x: 1 } };
var _nested_big = json_stringify_ordered(_nested, true, 100000);
__t_true("nested compact huge all inline", string_count("\n", _nested_big) == 0, _nested_big);
__t_true("nested compact huge roundtrip", __deep_eq(json_parse(_nested_big), _nested));
var _nested_small = json_stringify_ordered(_nested, true, 12);
__t_true("nested compact small expands", string_count("\n", _nested_small) > string_count("\n", _nested_big), _nested_small);
__t_true("nested compact small roundtrip", __deep_eq(json_parse(_nested_small), _nested));

// UTF-8: threshold is in bytes, not chars — reference length measured in bytes
var _uni = { s: "è" };
var _uni_inline = json_stringify_ordered(_uni, true, 100000);
var _uni_len = string_byte_length(_uni_inline);
__t_true("unicode exact byte threshold expands", string_pos("\n", json_stringify_ordered(_uni, true, _uni_len)) > 0, _uni_inline);
__t_true("unicode exact byte threshold parses", __deep_eq(json_parse(json_stringify_ordered(_uni, true, _uni_len)), _uni));
__t_true("unicode byte threshold+1 stays inline", string_pos("\n", json_stringify_ordered(_uni, true, _uni_len + 1)) == 0, _uni_inline);
__t_true("unicode byte threshold+1 parses", __deep_eq(json_parse(json_stringify_ordered(_uni, true, _uni_len + 1)), _uni));

// ============================================================
// 8. Parity with native on JSON-safe payloads (parse-level,
// since native preserves insertion order and ordered sorts)
// ============================================================
show_debug_message("=== Test: parity with native ===");

var _safe = { hello: "world", settings: 5, arr: [10, { a: "b", n: 10 }], flag: false, nothing: undefined };
__t_true("parity parses equal", __deep_eq(json_parse(json_stringify_ordered(_safe)), json_parse(json_stringify(_safe))));
__t_true("roundtrip idempotent", json_stringify_ordered(json_parse(json_stringify_ordered(_safe))) == json_stringify_ordered(_safe));

var _safe2 = { z: 3, a: [1, 2, { m: "x", b: 1 }], m: "test" };
__t_true("parity unsorted keys parses equal", __deep_eq(json_parse(json_stringify_ordered(_safe2)), json_parse(json_stringify(_safe2))));

// ============================================================
// 9. Robustness: depth, large payloads, buffer reuse
// ============================================================
show_debug_message("=== Test: robustness ===");

// deep nesting (15 levels): key count derived from input, not assumed output
var _deep = 1;
for (var _d = 0; _d < 15; _d++) _deep = { v: _deep };
var _deep_json = json_stringify_ordered(_deep);
__t_true("deep nesting 15 keys", string_count("\"v\"", _deep_json) == 15, string_length(_deep_json));
__t_true("deep nesting roundtrip", __deep_eq(json_parse(_deep_json), _deep));

// large array
var _big_arr = [];
for (var _bi = 0; _bi < 500; _bi++) array_push(_big_arr, _bi);
var _big_json = json_stringify_ordered(_big_arr);
__t_true("big array brackets", string_char_at(_big_json, 1) == "[" && string_char_at(_big_json, string_length(_big_json)) == "]");
__t_true("big array roundtrip length", array_length(json_parse(_big_json)) == 500);
__t_true("big array roundtrip values", __deep_eq(json_parse(_big_json), _big_arr));

// buffer reuse: repeated calls are identical (self-consistency, not a guess)
var _r1 = json_stringify_ordered({ b: 2, a: 1 });
var _r2 = json_stringify_ordered({ b: 2, a: 1 });
__t_eq("buffer reuse is idempotent", _r1, _r2);
__t_true("buffer reuse value parses", __deep_eq(json_parse(_r1), { b: 2, a: 1 }));

// large then small: small output must still match native on sorted input
var _huge_str = string_repeat("x", 200000);
var _huge_json = json_stringify_ordered({ data: _huge_str });
__t_true("huge payload ok", string_length(_huge_json) > 200000);
__t_true("huge payload roundtrip", __deep_eq(json_parse(_huge_json), { data: _huge_str }));
__t_true("small still correct after huge",
    __deep_eq(json_parse(json_stringify_ordered({ a: "x", b: "y" })), json_parse(json_stringify({ a: "x", b: "y" }))));

// input array not mutated
var _am = [3, 2, 1];
json_stringify_ordered(_am);
__t_true("input array not mutated", array_length(_am) == 3 && _am[0] == 3);

__t_summary();

// ============================================================
// 10. Benchmark
// ============================================================
show_debug_message("=== Benchmark (best of N trials, with warmup) ===");

var _small = { name: "Mario", score: 123, active: true, hp: 99.5, world: "1-1", boss: undefined };

// JSON-safe payload for a fair comparison with native (no NaN/Infinity/int64/handle).
var _mixed_safe = [
    "hello", 5, undefined,
    { hello: "world", settings: 5, array: [10, { a: "b", n: 5, deep: [1, 2, 3] }] },
    ["Test", "other"], true, false, 3.14
];

// Full payload with specials (ordered only; native does not support them the same way).
var _ds = ds_map_create();
var _mixed_full = [
    "hello", 5, undefined,
    { hello: "world", settings: 5, array: [10, { a: "b", n: 5 }] },
    ["Test"], NaN, infinity, -infinity, int64("9223372036854775807"), _ds
];

// Large payload: 150 structs with nested array
var _large = [];
for (var _li = 0; _li < 150; _li++) {
    array_push(_large, { id: _li, name: "enemy_" + string(_li), x: _li * 1.5, y: -_li, tags: ["fire", "water", "earth"], alive: (_li mod 2 == 0) });
}

// Payload with many strings needing escapes
var _stringy = { text: "quote:\" backslash:\\ newline:\n tab:\t Cherry pie €", arr: ["a\"b", "c\nd", "e\\f", "geh"] };

function __bench_case(_label, _data_safe, _iters) {
    var _trials = 3;
    show_debug_message("--- " + _label + " (iters=" + string(_iters) + ", trials=" + string(_trials) + ") ---");
    global.__b_data = _data_safe; // via global: GML closures do not always capture locals
    var _t_native = __b_measure(function() { json_stringify(global.__b_data); }, _iters, _trials);
    __b_report("native json_stringify", _t_native);
    var _t_min = __b_measure(function() { json_stringify_ordered(global.__b_data); }, _iters, _trials);
    __b_report("ordered min", _t_min, _t_native);
    var _t_pretty = __b_measure(function() { json_stringify_ordered(global.__b_data, true); }, _iters, _trials);
    __b_report("ordered pretty", _t_pretty, _t_native);
    var _t_compact = __b_measure(function() { json_stringify_ordered(global.__b_data, true, 64); }, _iters, _trials);
    __b_report("ordered pretty+compact64", _t_compact, _t_native);
}

__bench_case("small struct", _small, 8000);
__bench_case("mixed safe", _mixed_safe, 3000);
__bench_case("large 150 objects", _large, 100);
__bench_case("stringy escape", _stringy, 2000);

// Specials: ordered only (native excluded from comparison)
show_debug_message("--- mixed full specials (ordered only, iters=3000) ---");
global.__b_data = _mixed_full;
var _t_full_min = __b_measure(function() { json_stringify_ordered(global.__b_data); }, 3000, 3);
__b_report("ordered min full-specials", _t_full_min);
var _t_full_pretty = __b_measure(function() { json_stringify_ordered(global.__b_data, true, 64); }, 3000, 3);
__b_report("ordered pretty+compact64 full-specials", _t_full_pretty);

ds_map_destroy(_ds);

show_debug_message("=== Done ===");


show_debug_message("=== Example ===")

var st = {
    name: "Mario",
    score: 123,
    active: true,
    inv: [ "key", "coin" ],
    meta: { level: 5, boss: undefined }
};

var json = json_stringify_ordered(st);
show_debug_message(json);


var st = {
  pos: { x: 10, y: 20 },
  tags: ["fire", "water", "earth"],
  active: true
};

var json = json_stringify_ordered(st, true, 40);
show_debug_message(json);