use aiken/builtin
use aiken/bytearray.{concat}
use aiken/cbor
use aiken/dict.{Dict}
use aiken/list
use aiken/string
use aiken/transaction.{
  Datum, Input, Mint, Output, OutputReference, Redeemer, ScriptPurpose, Spend,
  Transaction, TransactionId,
}
use aiken/transaction/credential.{
  Address, Credential, Inline, PaymentCredential, ScriptCredential,
  StakeCredential, VerificationKeyCredential,
}
use aiken/transaction/value.{MintedValue, Value, flatten}

fn first_of_quad(quad: (a, b, c, d)) {
  quad.1st
}

fn first_of_triple(tuple: (a, b, c)) {
  tuple.1st
}

fn pop_back(self: ByteArray, qty: Int) {
  bytearray.take(self, builtin.length_of_bytearray(self) - qty)
}

fn last_char(self: ByteArray) {
  bytearray.drop(self, builtin.length_of_bytearray(self) - 1)
}

fn is_open(chr: ByteArray) {
  or {
    chr == "[",
    chr == "{",
    chr == "(",
  }
}

fn is_close(chr: ByteArray) {
  or {
    chr == "]",
    chr == "}",
    chr == ")",
  }
}

fn newline(self: ByteArray, indent_lvl: Int) {
  self |> bytearray.concat("\n") |> indent(indent_lvl)
}

fn to_decimal(byte: Int) {
  if byte >= 97 && byte <= 102 {
    byte - 97 + 10
  } else if byte >= 65 && byte <= 70 {
    byte - 65 + 10
  } else if byte >= 48 && byte <= 57 {
    byte - 48
  } else {
    fail @"invalid digit"
  }
}

fn hex_to_string(hex: ByteArray) {
  bytearray.foldl(
    // pushing a dummy byte to flush the last character 
    hex |> bytearray.concat("0"),
    ("", 0, 0),
    fn(byte, results) {
      let (acc, code, idx) = results
      let dec = to_decimal(byte)
      if idx > 0 && idx % 2 == 0 {
        (
          acc
            |> bytearray.concat(code |> to_safe_code |> to_bytearray),
          dec,
          idx + 1,
        )
      } else {
        (acc, code * 16 + dec, idx + 1)
      }
    },
  )
    |> first_of_triple
}

pub fn format_cbor(cbr: String) {
  cbr |> bytearray.from_string |> do_format_cbor |> bytearray.to_string
}

pub fn to_safe_code(code: Int) {
  if code > 127 {
    // fallback to '?' when the code is a special character
    63
  } else {
    code
  }
}

fn do_format_cbor(bytes) {
  bytes
    |> bytearray.foldl(
         ("", 0, False, ""),
         fn(byte, results) {
           let (builder, level, has_token, token) = results
           let chr = to_bytearray(byte)
           if is_open(chr) {
             (
               builder
                 |> concat(chr)
                 |> newline(level + 1),
               level + 1,
               has_token,
               token,
             )
           } else if is_close(chr) {
             (
               builder
                 |> fn(builder) {
                      if !has_token && builtin.length_of_bytearray(token) > 0 {
                        builder
                          |> concat(", # ")
                          |> concat(
                               token
                                 |> hex_to_string,
                             )
                      } else {
                        builder
                      }
                    }
                 |> fn(builder) {
                      // pretty empty struct to be inline
                      let last_chr = builder |> pop_back(level + 1) |> last_char
                      if is_open(last_chr) {
                        builder |> pop_back(level + 1)
                      } else {
                        builder |> newline(level - 1)
                      }
                    }
                 |> concat(chr),
               level - 1,
               has_token,
               "",
             )
           } else if chr == "'" {
             (builder |> concat(chr), level, !has_token, token)
           } else if chr == "," {
             (
               builder
                 |> concat(chr)
                 |> fn(builder) {
                      if !has_token && builtin.length_of_bytearray(token) > 0 {
                        builder
                          |> concat(" # ")
                          |> concat(
                               token
                                 |> hex_to_string,
                             )
                      } else {
                        builder
                      }
                    }
                 |> newline(level),
               level,
               has_token,
               if !has_token {
                 ""
               } else {
                 token
               },
             )
           } else if chr == "_" {
             (
               builder
                 |> pop_back(level + 1)
                 |> newline(level),
               level,
               has_token,
               token,
             )
           } else if chr == " " {
             (builder, level, has_token, token)
           } else {
             (
               builder |> concat(chr),
               level,
               has_token,
               if has_token {
                 token |> concat(chr)
               } else {
                 token
               },
             )
           }
         },
       )
    |> first_of_quad
}

fn to_bytearray(byte: Int) {
  #"" |> bytearray.push(byte)
}

pub fn int(val: Int, name: String) {
  trace name |> with_newline |> string.concat(string.from_int(val))
  val
}

pub fn bytearray(self: ByteArray, name: String) {
  trace name |> with_newline |> string.concat(string.from_bytearray(self))
  self
}

fn indent(self: ByteArray, level: Int) {
  expect True == ( level >= 0 )
  self
    |> bytearray.concat(
         list.repeat("\t", level)
           |> list.reduce("", bytearray.concat),
       )
}

fn with_newline(builder: String) {
  builder
    |> string.concat(
         @"\n",
       )
}

fn with_single_quote_surrounded(builder: String) {
  [@"'", @"'"] |> string.join(builder)
}

fn with_tag(self: String, name: String) {
  self |> string.concat(string.join([@"[", @"]"], name))
}

fn get_credential(cred: Credential) {
  when cred is {
    VerificationKeyCredential(hash) ->
      string.concat(
        @"VerificationKeyCredential(",
        string.from_bytearray(hash) |> with_single_quote_surrounded,
      )
        |> string.concat(@")")
    ScriptCredential(hash) ->
      string.concat(
        @"ScriptCredential(",
        string.from_bytearray(hash) |> with_single_quote_surrounded,
      )
        |> string.concat(@")")
  }
}

pub fn payment_credential(self: PaymentCredential, name: String) {
  trace name |> with_newline |> string.concat(get_credential(self))
  self
}

pub fn stake_credential(self: Option<StakeCredential>, name: String) {
  trace name
    |> with_newline
    |> string.concat(
         when self is {
           None -> cbor.diagnostic(None)
           Some(Inline(cred)) -> get_credential(cred)
           _ -> fail
         },
       )
  self
}

pub fn out_ref(self: OutputReference, name: String) {
  let OutputReference(TransactionId(tx_hash), index) = self
  trace name
    |> with_newline
    |> string.concat(
         string.from_bytearray(tx_hash)
           |> string.concat(@"#")
           |> string.concat(string.from_int(index)),
       )
  self
}

pub fn address(self: Address, name: String) {
  Address {
    stake_credential: stake_credential(
      self.stake_credential,
      string.concat(name, @".stake_credential"),
    ),
    payment_credential: payment_credential(
      self.payment_credential,
      string.concat(name, @".payment_credential"),
    ),
  }
}

pub fn value(self: Value, name: String) {
  trace name
    |> with_newline
    |> string.concat(cbor.diagnostic(self |> flatten) |> format_cbor)
  self
}

pub fn minted_value(self: MintedValue, name: String) {
  trace name
    |> with_newline
    |> string.concat(
         cbor.diagnostic(self |> value.from_minted_value |> flatten)
           |> format_cbor,
       )
  self
}

pub fn data(self: Data, name: String) {
  trace name
    |> with_newline
    |> string.concat(cbor.diagnostic(self) |> format_cbor)
  self
}

pub fn datum(self: Datum, name: String) {
  trace name
    |> with_newline
    |> string.concat(cbor.diagnostic(self) |> format_cbor)
  self
}

pub fn output(self: Output, name: String) {
  Output {
    ..self,
    address: address(self.address, string.concat(name, @".address")),
    value: value(self.value, string.concat(name, @".value")),
    datum: datum(self.datum, string.concat(name, @".datum")),
  }
}

pub fn redeemer(entry: (ScriptPurpose, Redeemer), name: String) {
  let (purpose, rdm) = entry
  trace name
    |> with_newline
    |> string.concat(@".purpose")
    |> with_newline
    |> string.concat(
         when purpose is {
           Mint(pid) ->
             [@"Mint(policy_id=", @")"]
               |> string.join(
                    pid |> bytearray.to_string |> with_single_quote_surrounded,
                  )
           Spend(OutputReference(TransactionId(tx_hash), index)) ->
             [@"Spend(out_ref=", @")"]
               |> string.join(
                    string.from_bytearray(tx_hash)
                      |> string.concat(@"#")
                      |> string.concat(string.from_int(index))
                      |> with_single_quote_surrounded,
                  )
           _ -> cbor.diagnostic(purpose) |> format_cbor
         },
       )
    |> with_newline
    |> string.concat(@".redeemer")
    |> with_newline
    |> string.concat(
         cbor.diagnostic(rdm)
           |> format_cbor,
       )
  entry
}

pub fn input(self: Input, name: String) {
  Input {
    output_reference: self.output_reference
      |> out_ref(string.concat(name, @".out_ref")),
    output: self.output |> output(string.concat(name, @".output")),
  }
}

pub fn redeemers(self: Dict<ScriptPurpose, Redeemer>) {
  self
    |> dict.to_list
    |> list.indexed_map(
         fn(idx, rdm) {
           rdm
             |> redeemer(
                  @"redeemers"
                    |> with_tag(string.from_int(idx)),
                )
         },
       )
    |> fn(_) { self }
}

pub fn tx(tx: Transaction) {
  Transaction {
    ..tx,
    redeemers: tx.redeemers
      |> section(@"Redeemers")
      |> redeemers()
      |> section(@""),
    mint: tx.mint
      |> section(@"Mint")
      |> value.from_minted_value
      |> value(@"mint")
      |> value.to_minted_value,
    inputs: tx.inputs
      |> section(@"Inputs")
      |> list.indexed_map(
           fn(idx, in) {
             input(in, @"inputs" |> with_tag(string.from_int(idx)))
           },
         ),
    outputs: tx.outputs
      |> section(@"Outputs")
      |> list.indexed_map(
           fn(idx, out) {
             output(out, @"outputs" |> with_tag(string.from_int(idx)))
           },
         ),
  }
}

pub fn section(return_value: r, name: String) -> r {
  let len = string.to_bytearray(name) |> builtin.length_of_bytearray
  let width = 80
  let left = ( width - len ) / 2
  let right = width - len - left
  trace [
    @"=" |> list.repeat(left) |> string.join(@""),
    @"=" |> list.repeat(right) |> string.join(@""),
  ]
    |> string.join(name)
  return_value
}

pub fn token_dict(self: Dict<ByteArray, Int>, name: String) {
  trace name
    |> list.foldl(
         dict.to_list(self),
         _,
         fn(entry, builder) {
           builder
             |> with_newline
             |> string.concat(cbor.diagnostic(entry) |> format_cbor)
         },
       )
  self
}

pub fn bytearray_list(self: List<ByteArray>, name: String) {
  trace name
    |> with_newline
    |> string.concat(cbor.diagnostic(self))
    |> format_cbor
  self
}
