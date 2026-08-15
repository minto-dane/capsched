//! Strict decoder for the dependency-free canonical differential wire format.

const MAX_DEPTH: usize = 16;
const MAX_TUPLE_ITEMS: usize = 4_096;

#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) enum Value {
    None,
    Bool(bool),
    Integer(u64),
    String(String),
    Tuple(Vec<Value>),
}

impl Value {
    pub(crate) fn into_tuple(self, context: &str) -> Result<Vec<Value>, String> {
        match self {
            Self::Tuple(values) => Ok(values),
            _ => Err(format!("{context}: expected tuple")),
        }
    }

    pub(crate) fn into_string(self, context: &str) -> Result<String, String> {
        match self {
            Self::String(value) => Ok(value),
            _ => Err(format!("{context}: expected string")),
        }
    }

    pub(crate) fn into_integer(self, context: &str) -> Result<u64, String> {
        match self {
            Self::Integer(value) => Ok(value),
            _ => Err(format!("{context}: expected nonnegative integer")),
        }
    }
}

pub(crate) fn exact(input: &[u8]) -> Result<Value, String> {
    decode(input, 0)
}

fn decode(input: &[u8], depth: usize) -> Result<Value, String> {
    if depth > MAX_DEPTH {
        return Err("canonical value nesting exceeds limit".to_owned());
    }
    let (&tag, body) = input
        .split_first()
        .ok_or_else(|| "empty canonical value".to_owned())?;
    match tag {
        b'N' if body.is_empty() => Ok(Value::None),
        b'B' if body == b"0" => Ok(Value::Bool(false)),
        b'B' if body == b"1" => Ok(Value::Bool(true)),
        b'I' => decode_integer(body),
        b'S' => String::from_utf8(body.to_vec())
            .map(Value::String)
            .map_err(|_| "canonical string is not UTF-8".to_owned()),
        b'T' => decode_tuple(body, depth + 1),
        _ => Err("unknown or non-canonical value tag".to_owned()),
    }
}

fn decode_integer(body: &[u8]) -> Result<Value, String> {
    if body.is_empty()
        || body.iter().any(|value| !value.is_ascii_digit())
        || (body.len() > 1 && body[0] == b'0')
    {
        return Err("non-canonical integer".to_owned());
    }
    let text = std::str::from_utf8(body).map_err(|_| "integer is not ASCII".to_owned())?;
    text.parse::<u64>()
        .map(Value::Integer)
        .map_err(|_| "integer exceeds u64".to_owned())
}

fn decode_tuple(mut body: &[u8], depth: usize) -> Result<Value, String> {
    let mut values = Vec::new();
    while !body.is_empty() {
        if values.len() == MAX_TUPLE_ITEMS {
            return Err("canonical tuple exceeds item limit".to_owned());
        }
        let colon = body
            .iter()
            .position(|value| *value == b':')
            .ok_or_else(|| "tuple frame lacks colon".to_owned())?;
        let length_text = &body[..colon];
        if length_text.is_empty()
            || length_text.iter().any(|value| !value.is_ascii_digit())
            || (length_text.len() > 1 && length_text[0] == b'0')
        {
            return Err("tuple frame length is not canonical".to_owned());
        }
        let length = std::str::from_utf8(length_text)
            .map_err(|_| "tuple frame length is not ASCII".to_owned())?
            .parse::<usize>()
            .map_err(|_| "tuple frame length exceeds usize".to_owned())?;
        body = &body[colon + 1..];
        if length > body.len() {
            return Err("tuple frame is truncated".to_owned());
        }
        let (framed, remainder) = body.split_at(length);
        values.push(decode(framed, depth)?);
        body = remainder;
    }
    Ok(Value::Tuple(values))
}

#[cfg(test)]
mod tests {
    use super::{exact, Value};

    #[test]
    fn canonical_values_decode_exactly() {
        assert_eq!(exact(b"N"), Ok(Value::None));
        assert_eq!(exact(b"B1"), Ok(Value::Bool(true)));
        assert_eq!(exact(b"I0"), Ok(Value::Integer(0)));
        assert_eq!(exact(b"Svalue"), Ok(Value::String("value".to_owned())));
        assert_eq!(
            exact(b"T2:I15:Stext"),
            Ok(Value::Tuple(vec![
                Value::Integer(1),
                Value::String("text".to_owned()),
            ]))
        );
    }

    #[test]
    fn malformed_values_fail_closed() {
        for value in [
            b"".as_slice(),
            b"B2",
            b"I",
            b"I01",
            b"I18446744073709551616",
            b"T01:N",
            b"T2:N",
            b"T1:X",
        ] {
            assert!(exact(value).is_err(), "accepted malformed value: {value:?}");
        }
    }
}
