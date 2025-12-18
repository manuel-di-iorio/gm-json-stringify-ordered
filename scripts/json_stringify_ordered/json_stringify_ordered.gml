/// @function json_stringify_ordered(value)
/// @description Converts any value (struct, array, or primitive) to a formatted JSON string using buffers for better performance
/// @param {any} value The value to convert to JSON
/// @param {bool} prettify Whether to include pretty formatting
/// @return {string} A properly formatted and indented JSON string
function json_stringify_ordered(value, prettify = false) {
  var buf = buffer_create(1024, buffer_grow, 1);
  __json_stringify_buffer(value, buf, 0, prettify);
  var result = buffer_peek(buf, 0, buffer_text);
  buffer_delete(buf);
  return result;
}

/// @function __json_stringify_buffer(v, buf, indent, prettify)
/// @description Serializes a value into a buffer with JSON formatting.
/// @param {any} v The value to serialize (struct, array, or primitive)
/// @param {id.buffer} buf The target buffer where the serialized data will be written
/// @param {real} [indent=0] The current indentation level for prettify-printing
/// @param {bool} [pretty=true] Whether to include pretty formatting
/// @return {undefined}
function __json_stringify_buffer(v, buf, indent = 0, prettify) {
  if (is_struct(v)) __json_stringify_struct(v, buf, indent, prettify);
  else if (is_array(v)) __json_stringify_array(v, buf, indent, prettify);
  else __json_stringify_primitive(v, buf);
}

/// @function __json_stringify_primitive(v, buf)
/// @description Writes a primitive value to buffer in JSON format. Handles strings, numbers, booleans, and null values
/// @param {any} v The primitive value to convert
/// @param {id.buffer} buf The buffer to write to
/// @private
function __json_stringify_primitive(v, buf) {
  if (is_string(v)) {
    buffer_write(buf, buffer_u8, ord("\""));
    var escaped = string_replace_all(v, "\"", "\\\"");
    buffer_write(buf, buffer_text, escaped);
    buffer_write(buf, buffer_u8, ord("\""));
  }
  else if (is_real(v)) {
    buffer_write(buf, buffer_text, string(v));
  }
  else if (is_bool(v)) {
    buffer_write(buf, buffer_text, v ? "true" : "false");
  }
  else if (is_undefined(v) || is_nan(v)) {
    buffer_write(buf, buffer_text, "null");
  }
}

/// @function __json_stringify_array(arr, buf, indent, prettify)
/// @description Writes an array to buffer in JSON format with proper indentation
/// @param {array} arr The array to convert
/// @param {id.buffer} buf The buffer to write to
/// @param {real} indent The current indentation level
/// @param {bool} prettify Whether to include pretty formatting
/// @private
function __json_stringify_array(arr, buf, indent, prettify) {
  buffer_write(buf, buffer_u8, ord("["));
  if (prettify) buffer_write(buf, buffer_u8, 10); // newline
  
  var pad = string_repeat("  ", indent + 1);
  var pad_close = string_repeat("  ", indent);

  for (var i = 0, il = array_length(arr); i < il; i++) {
      if (prettify) buffer_write(buf, buffer_text, pad);
      __json_stringify_buffer(arr[i], buf, indent + 1, prettify);

      if (i < il - 1) buffer_write(buf, buffer_u8, ord(","));
      if (prettify) buffer_write(buf, buffer_u8, 10); // newline
  }

  if (prettify) buffer_write(buf, buffer_text, pad_close);
  buffer_write(buf, buffer_u8, ord("]"));
}

/// @function __json_stringify_struct(st, indent, buf, pretty)
/// @description Writes a struct to buffer in JSON format with proper indentation. Keys are sorted alphabetically
/// @param {struct} st The struct to convert
/// @param {id.buffer} buf The buffer to write to
/// @param {real} indent The current indentation level
/// @param {bool} prettify Whether to include pretty formatting
/// @private
function __json_stringify_struct(st, buf, indent, prettify) {
  var keys = variable_struct_get_names(st);
  array_sort(keys, true);

  buffer_write(buf, buffer_u8, ord("{"));
  if (prettify) buffer_write(buf, buffer_u8, 10); // newline
  
  var pad = string_repeat("  ", indent + 1);
  var pad_close = string_repeat("  ", indent);

  for (var i = 0, il = array_length(keys); i < il; i++) {
      var k = keys[i];
      
      if (prettify) buffer_write(buf, buffer_text, pad);
      buffer_write(buf, buffer_u8, ord("\""));
      buffer_write(buf, buffer_text, k);
      buffer_write(buf, buffer_text, prettify ? "\": " : "\":");
      
      __json_stringify_buffer(st[$ k], buf, indent + 1, prettify);

      if (i < il - 1) buffer_write(buf, buffer_u8, ord(","));
      if (prettify) buffer_write(buf, buffer_u8, 10); // newline
  }

  if (prettify) buffer_write(buf, buffer_text, pad_close);
  buffer_write(buf, buffer_u8, ord("}"));
}
