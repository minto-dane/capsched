pub const WIRE_SCHEMA: &str = "F0-C4-RUST-DIFFERENTIAL-V1";

fn frame(value: &[u8], output: &mut Vec<u8>) {
    output.extend_from_slice(value.len().to_string().as_bytes());
    output.push(b':');
    output.extend_from_slice(value);
}

pub fn string(value: &str) -> Vec<u8> {
    let mut output = Vec::with_capacity(value.len() + 1);
    output.push(b'S');
    output.extend_from_slice(value.as_bytes());
    output
}

pub fn integer(value: u64) -> Vec<u8> {
    let mut output = Vec::new();
    output.push(b'I');
    output.extend_from_slice(value.to_string().as_bytes());
    output
}

pub fn none() -> Vec<u8> {
    vec![b'N']
}

pub fn tuple(values: impl IntoIterator<Item = Vec<u8>>) -> Vec<u8> {
    let mut output = vec![b'T'];
    for value in values {
        frame(&value, &mut output);
    }
    output
}

pub fn strings<'a>(values: impl IntoIterator<Item = &'a str>) -> Vec<u8> {
    tuple(values.into_iter().map(string))
}

pub fn hex(input: &[u8]) -> String {
    crate::sha256::hex(input)
}
