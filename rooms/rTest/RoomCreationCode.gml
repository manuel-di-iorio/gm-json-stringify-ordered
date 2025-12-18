show_debug_message("=== Test ===");
var st = {
    name: "Mario",
    score: 123,
    active: true,
    inv: [ "key", "coin" ],
    meta: { level: 5, boss: undefined }
};

var json = json_stringify_ordered(st);
show_debug_message(json);

var data = [ 
  "ciao", 
  5, 
  undefined, 
  {
    hello: "world",
    settings: 5,
    array: [
      10,
      { 
        "thisIsAStruct": undefined,
        a: "b",
        undefined,
        "10": 5,
        "multiline text": @"hey
how are you today?"
      }
    ]
  },
  [ "Test" ]
];

show_debug_message(json_stringify_ordered(data, true));
show_debug_message(json_parse(json_stringify_ordered(data, true)));

// Benchmark
show_debug_message("=== Benchmark ===");
var start, final;

// --- JSON native ---
start = get_timer();
for (var i=0; i<100000; i++) {
  json_stringify(data);
}
show_debug_message("json_stringify: " + string((get_timer() - start) / 1000000) + " s");

// --- JSON buffer ---
start = get_timer();

for (var i=0; i<100000; i++) {
  json_stringify_ordered(data);
}
show_debug_message("json_stringify_ordered: " + string((get_timer() - start) / 1000000) + " s");
