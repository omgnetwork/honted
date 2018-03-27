#   Copyright 2018 OmiseGO Pte Ltd
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

extern crate tiny_keccak;
#[macro_use] extern crate rustler;

use rustler::{NifEnv, NifTerm, NifResult, NifEncoder};
use tiny_keccak::Keccak;

const HASH_SIZE_BYTES: usize = 64;
const HASH_SIZE_WORDS: usize = 16;
const KEC_256_HASH_SIZE_BYTES: usize = 32;
const CACHE_ROUNDS: u8 = 3;
const CACHE_BYTES_INIT: u64 = 16777216;
const CACHE_BYTES_GROWTH: u64 = 131072;
const EPOCH_LENGTH: u64 = 30000;

fn xor(v1: &[u32; HASH_SIZE_WORDS], v2: &[u32; HASH_SIZE_WORDS]) -> [u32; HASH_SIZE_WORDS] {
    let mut v3: [u32; HASH_SIZE_WORDS] = [0; HASH_SIZE_WORDS];
    for i in 0..HASH_SIZE_WORDS {
        v3[i] = v1[i] ^ v2[i];
    }
    v3
}

fn serialize_hash(v: &[u32; HASH_SIZE_WORDS]) -> [u8; HASH_SIZE_BYTES] {
    let mut serialized: [u8; HASH_SIZE_BYTES] = [0; HASH_SIZE_BYTES];
    for i in 0..v.len() {
        let item = v[i];
        let little_endian = int_to_little_endian(item);
        let serialized_idx = 4 * i;
        serialized[serialized_idx] = little_endian[0];
        serialized[serialized_idx + 1] = little_endian[1];
        serialized[serialized_idx + 2] = little_endian[2];
        serialized[serialized_idx + 3] = little_endian[3];
    }
    serialized
}

fn int_to_little_endian(int: u32) -> [u8; 4] {
    let b1: u8 = ((int >> 24) & 0xff) as u8;
    let b2: u8 = ((int >> 16) & 0xff) as u8;
    let b3: u8 = ((int >> 8) & 0xff) as u8;
    let b4: u8 = (int & 0xff) as u8;
    [b4, b3, b2, b1]
}

fn little_endian_to_int(le: &[u8]) -> u32 {
    le[0] as u32 + ((le[1] as u32) << 8) + ((le[2] as u32) << 16) + ((le[3] as u32) << 24)
}

fn deserialize_hash(v: &[u8; HASH_SIZE_BYTES]) -> [u32; HASH_SIZE_WORDS] {
    let mut v_idx = 0;
    let mut deserialized: [u32; HASH_SIZE_WORDS] = [0; HASH_SIZE_WORDS];
    let mut ds_idx = 0;
    while v_idx < v.len() {
        deserialized[ds_idx] = little_endian_to_int(&v[v_idx..(v_idx + 4)]);
        v_idx = v_idx + 4;
        ds_idx = ds_idx + 1;
    }
    deserialized
}

fn hash_array(v: &[u32; HASH_SIZE_WORDS]) -> [u32; HASH_SIZE_WORDS] {
    let serialized = serialize_hash(&v);
    let mut hasher = Keccak::new_keccak512();
    hasher.update(&serialized);
    let mut hash: [u8; HASH_SIZE_BYTES] = [0; HASH_SIZE_BYTES];
    hasher.finalize(&mut hash);
    deserialize_hash(&hash)
}

fn hash_bytes(v: &[u8; KEC_256_HASH_SIZE_BYTES]) -> [u32; HASH_SIZE_WORDS] {
    let mut hasher = Keccak::new_keccak512();
    hasher.update(v);
    let mut hash: [u8; HASH_SIZE_BYTES] = [0; HASH_SIZE_BYTES];
    hasher.finalize(&mut hash);
    deserialize_hash(&hash)
}

fn initial_cache(cache_size: u64, seed: &[u8; KEC_256_HASH_SIZE_BYTES]) -> Vec<[u32; HASH_SIZE_WORDS]> {
    let mut o: Vec<[u32; HASH_SIZE_WORDS]> = Vec::new();

    let mut e: [u32; HASH_SIZE_WORDS] = hash_bytes(&seed);
    o.push(e);

    for _i in 1..cache_size {
        e = hash_array(&e);
        o.push(e);
    }
    o
}

fn is_compose(candidate: u64) -> bool {
    let maximal_divisor = (candidate as f64).sqrt() as u64 + 1;
    for i in 2..maximal_divisor {
        if candidate % i == 0 {
            return true;
        }
    }
    false
}

fn get_cache_size(block_number: u64) -> u64 {
    let hash_size_bytes = HASH_SIZE_BYTES as u64;
    let mut size = CACHE_BYTES_INIT + CACHE_BYTES_GROWTH * (block_number / EPOCH_LENGTH) - hash_size_bytes;
    while is_compose(size / hash_size_bytes) {
        size -= hash_size_bytes;
    }
    size
}

fn keccak_256(v: &[u8; KEC_256_HASH_SIZE_BYTES]) -> [u8; KEC_256_HASH_SIZE_BYTES] {
    let mut hasher = Keccak::new_keccak256();
    hasher.update(v);
    let mut hash: [u8; KEC_256_HASH_SIZE_BYTES] = [0; KEC_256_HASH_SIZE_BYTES];
    hasher.finalize(&mut hash);
    hash
}

fn create_cache_seed(block_number: u64) -> [u8; KEC_256_HASH_SIZE_BYTES] {
    let num_hashes = block_number / EPOCH_LENGTH;
    let mut seed: [u8; KEC_256_HASH_SIZE_BYTES] = [0; KEC_256_HASH_SIZE_BYTES];
    for _i in 0..num_hashes {
        seed = keccak_256(&seed)
    }
    seed
}

rustler_export_nifs!(
    "Elixir.HonteD.ABCI.Ethereum.EthashCache",
    [("make_cache", 1, make_cache)],
    None
);

fn make_cache<'a>(env: NifEnv<'a>, args: &[NifTerm<'a>]) -> NifResult<NifTerm<'a>> {
    let block_number: u64 = try!(args[0].decode());
    Ok(make_cache_inner(block_number).encode(env))
}

fn make_cache_inner(block_number: u64) -> Vec<Vec<u32>> {
    let cache_size = get_cache_size(block_number);
    let seed = create_cache_seed(block_number);
    let n = cache_size / (HASH_SIZE_BYTES as u64);
    let mut o: Vec<[u32; HASH_SIZE_WORDS]> = initial_cache(n, &seed);
    for _round in 0..CACHE_ROUNDS {
        for i in 0..n {
            let index = i as usize;
            let v = ((o[index][0] as u64) % n) as usize;
            let xored = xor(&o[(((i as u64) + n - 1) % n) as usize], &o[v]);
            o[index] = hash_array(&xored);
        }
    }
    let v = o.iter().map(|&x| x.to_vec()).collect();
    v
}

#[cfg(test)]
mod tests {
    // not run in CI or mix test, tests implementation details
    use super::*;

    fn xor_test_case(v1: &[u32; HASH_SIZE_WORDS], v2: &[u32; HASH_SIZE_WORDS], expected: &[u32; HASH_SIZE_WORDS]) {
        let actual = xor(&v1, &v2);
        assert_eq!(&actual[..], &expected[..]);
    }

    #[test]
    fn xor_should_xor_arrays_content() {
        xor_test_case(&[10; HASH_SIZE_WORDS], &[1; HASH_SIZE_WORDS], &[11; HASH_SIZE_WORDS]);
        xor_test_case(&[1; HASH_SIZE_WORDS], &[10; HASH_SIZE_WORDS], &[11; HASH_SIZE_WORDS]);
        xor_test_case(&[9; HASH_SIZE_WORDS], &[9; HASH_SIZE_WORDS], &[0; HASH_SIZE_WORDS]);
        xor_test_case(&[16; HASH_SIZE_WORDS], &[256; HASH_SIZE_WORDS], &[272; HASH_SIZE_WORDS]);
    }

    #[test]
    fn int_to_little_endian_should_convert_int_to_little_endian_bytes() {
        assert_eq!(&(int_to_little_endian(10))[..], &[10, 0, 0, 0 as u8]);
        assert_eq!(&(int_to_little_endian(1025))[..], &[1, 4, 0, 0 as u8]);
    }

    #[test]
    fn little_endian_to_int_should_convert_little_endian_bytes_to_int() {
        assert_eq!(little_endian_to_int(&[10, 0, 0, 0 as u8]), 10);
        assert_eq!(little_endian_to_int(&[1, 4, 0, 0 as u8]), 1025);
    }

    #[test]
    fn serialize_hash_should_serialize_words_to_bytes() {
        let actual = serialize_hash(&[32000, 16, 970, 4123, 1, 0, 12351, 8, 15123, 256, 11, 98, 4231, 0, 0, 4]);
        let expected: [u8; HASH_SIZE_BYTES] = [
            0, 125, 0, 0, 16, 0, 0, 0, 202, 3, 0, 0, 27, 16, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 63, 48, 0, 0, 8, 0, 0, 0,
            19, 59, 0, 0, 0, 1, 0, 0, 11, 0, 0, 0, 98, 0, 0, 0, 135, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0];
        assert_eq!(&actual[..], &expected[..]);
    }

    #[test]
    fn hash_array_should_hash_array_of_words_with_keccak_512() {
        let actual = hash_array(&[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]);
        let expected: [u32; HASH_SIZE_WORDS] = [2172819737, 3621262696, 876910143, 3341827764, 459555228, 848032224, 3482054736, 2662156643,
            3923022282, 16975881, 736581666, 1618923586, 1654030958, 153632490, 3963076479, 1870909372];
        assert_eq!(&actual[..], &expected[..]);

        let actual = hash_array(&[1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31]);
        let expected: [u32; HASH_SIZE_WORDS] = [4095496674, 4219374178, 1753995958, 3571286059, 2344184721, 3017088741, 3150877954, 3514360654,
            662411939, 3778051935, 3105773609, 4233956302, 1405894646, 170908179, 222840554, 1359073150];
        assert_eq!(&actual[..], &expected[..]);
    }

    #[test]
    fn is_compose_should_return_true_for_compose_numbers() {
        assert!(is_compose(4));
        assert!(is_compose(9));
        assert!(is_compose(1234 * 4819));
        assert!(is_compose(171 * 173));
        assert!(is_compose(16777213 * 16777213));
    }

    #[test]
    fn is_compose_should_return_false_for_prime_numbers() {
        assert!(is_compose(5) == false);
        assert!(is_compose(2) == false);
        assert!(is_compose(173) == false);
    }

    #[test]
    fn make_cache_should_create_cache() {
        let actual = &make_cache_inner(10000)[100];
        let expected = [868643959, 3179556070, 1871292480, 2635187316, 2658670881, 3651954940, 864296532,
            4161655205, 1170742362, 1613380156, 3420562092, 2441378987, 2714353747, 536405404, 2918860778, 540860293].to_vec();
        assert_eq!(&actual[..], &expected[..]);
    }
}
