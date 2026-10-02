///|
/// Compare decimal values without rounding large integers through Double.
/// Exponents are bounded to keep normalization arithmetic safe.
fn canonical_number(value : Json, repr : String?) -> String raise ConfigError {
  let text = match repr {
    Some(s) => s
    None => value.stringify()
  }
  let parsed = @json.parse(text) catch {
    _ => raise InvalidPatch("invalid JSON number")
  }
  if !(parsed is Number(_, ..)) {
    raise InvalidPatch("non-finite JSON number")
  }
  let lower = text.replace_all(old="E", new="e")
  let parts = lower.split("e").to_array()
  let exp = if parts.length() == 2 {
    @string.parse_int(parts[1]) catch {
      _ => raise LimitExceeded("number exponent out of range")
    }
  } else {
    0
  }
  if exp < -1000000 || exp > 1000000 {
    raise LimitExceeded("number exponent exceeds +/-1000000")
  }
  let mantissa = parts[0].to_owned()
  let negative = mantissa.strip_prefix("-") is Some(_)
  let unsigned = if negative {
    mantissa.strip_prefix("-").unwrap().to_owned()
  } else {
    mantissa
  }
  let decimal = unsigned.split(".").to_array()
  let digits = unsigned.replace_all(old=".", new="").to_array()
  let fraction = if decimal.length() == 2 { decimal[1].length() } else { 0 }
  let mut start = 0
  let mut end = digits.length()
  while start < end && digits[start] == '0' {
    start = start + 1
  }
  if start == end {
    return "0"
  }
  while end > start && digits[end - 1] == '0' {
    end = end - 1
  }
  let exponent = exp - fraction + digits.length() - end
  (if negative { "-" } else { "" }) +
  String::from_array(digits.exact_view(start~, end~)) +
  "e" +
  exponent.to_string()
}

///|
/// Semantic equality ignores object member order and numeric spelling.
/// Public traversal functions validate first; recursive calls cannot fail.
fn same(a : Json, b : Json) -> Bool {
  match (a, b) {
    (Number(_, repr=ar), Number(_, repr=br)) => {
      // Numbers have already been validated by each public operation.
      let x = canonical_number(a, ar) catch { _ => return false }
      let y = canonical_number(b, br) catch { _ => return false }
      x == y
    }
    (Array(x), Array(y)) => {
      if x.length() != y.length() {
        return false
      }
      for i = 0; i < x.length(); i = i + 1 {
        if !same(x[i], y[i]) {
          return false
        }
      }
      true
    }
    (Object(x), Object(y)) => {
      if x.length() != y.length() {
        return false
      }
      for k, v in x {
        guard y.get(k) is Some(w) else { return false }
        if !same(v, w) {
          return false
        }
      }
      true
    }
    _ => a == b
  }
}

///|
fn same_slot(a : Json?, b : Json?) -> Bool {
  match (a, b) {
    (Some(x), Some(y)) => same(x, y)
    (None, None) => true
    _ => false
  }
}
