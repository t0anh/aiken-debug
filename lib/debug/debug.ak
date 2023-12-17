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
  }
}

fn is_close(chr: ByteArray) {
  or {
    chr == "]",
    chr == "}",
  }
}

fn newline(self: ByteArray, indent_lvl: Int) {
  self |> bytearray.concat("\n") |> indent(indent_lvl)
}

fn get_digit(byte: Int) {
  if byte >= 65 {
    byte - 65 + 10
  } else if byte >= 48 {
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
      let digit = get_digit(byte)
      if idx > 0 && idx % 2 == 0 {
        (acc |> bytearray.concat(to_bytearray(code)), digit, idx + 1)
      } else {
        (acc, code * 16 + digit, idx + 1)
      }
    },
  )
    |> first_of_triple
}

pub fn debug_cbor(cbr: String) {
  string.to_bytearray(cbr) |> format_cbor |> string.from_bytearray
}

fn format_cbor(bytes) {
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

pub fn debug_int(val: Int, name: String) {
  trace name |> string.concat(string.from_int(val))
  val
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

fn with_inline_result(builder: String) {
  builder
    |> with_newline
}

fn with_single_quote_surrounded(builder: String) {
  [@"'", @"'"] |> string.join(builder)
}

fn with_tag(self: String, name: String) {
  self |> string.concat(string.join([@"[", @"]"], name))
}

fn with_multiline_result(builder: String) {
  @"\n"
    |> string.concat(builder)
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

pub fn debug_payment_credential(self: PaymentCredential, name: String) {
  trace name |> with_inline_result |> string.concat(get_credential(self))
  self
}

pub fn debug_stake_credential(self: Option<StakeCredential>, name: String) {
  trace name
    |> with_inline_result
    |> string.concat(
         when self is {
           None -> cbor.diagnostic(None)
           Some(Inline(cred)) -> get_credential(cred)
           _ -> fail
         },
       )
  self
}

pub fn debug_out_ref(self: OutputReference, name: String) {
  let OutputReference(TransactionId(tx_hash), index) = self
  trace name
    |> with_inline_result
    |> string.concat(
         string.from_bytearray(tx_hash)
           |> string.concat(@"#")
           |> string.concat(string.from_int(index)),
       )
  self
}

pub fn debug_address(self: Address, name: String) {
  Address {
    stake_credential: debug_stake_credential(
      self.stake_credential,
      string.concat(name, @".stake_credential"),
    ),
    payment_credential: debug_payment_credential(
      self.payment_credential,
      string.concat(name, @".payment_credential"),
    ),
  }
}

pub fn debug_value(self: Value, name: String) {
  trace name
    |> string.concat(
         with_multiline_result(cbor.diagnostic(self |> flatten) |> debug_cbor),
       )
  self
}

pub fn debug_minted_value(self: MintedValue, name: String) {
  trace name
    |> with_newline
    |> string.concat(
         cbor.diagnostic(self |> value.from_minted_value |> flatten)
           |> debug_cbor,
       )
  self
}

pub fn debug_datum(self: Datum, name: String) {
  trace name
    |> string.concat(with_multiline_result(cbor.diagnostic(self) |> debug_cbor))
  self
}

pub fn debug_output(self: Output, name: String) {
  Output {
    ..self,
    address: debug_address(self.address, string.concat(name, @".address")),
    value: debug_value(self.value, string.concat(name, @".value")),
    datum: debug_datum(self.datum, string.concat(name, @".datum")),
  }
}

pub fn debug_redeemer(entry: (ScriptPurpose, Redeemer), name: String) {
  let (purpose, rdm) = entry
  trace name
    |> with_inline_result
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
           _ -> cbor.diagnostic(purpose) |> debug_cbor
         },
       )
    |> with_inline_result
    |> string.concat(@".redeemer")
    |> with_newline
    |> string.concat(
         cbor.diagnostic(rdm)
           |> debug_cbor,
       )
  entry
}

pub fn debug_input(self: Input, name: String) {
  Input {
    output_reference: self.output_reference
      |> debug_out_ref(string.concat(name, @".out_ref")),
    output: self.output |> debug_output(string.concat(name, @".output")),
  }
}

pub fn debug_redeemers(self: Dict<ScriptPurpose, Redeemer>) {
  self
    |> dict.to_list
    |> list.indexed_map(
         fn(idx, rdm) {
           rdm
             |> debug_redeemer(
                  @"redeemers"
                    |> with_tag(string.from_int(idx)),
                )
         },
       )
    |> fn(_) { self }
}

pub fn debug_tx(tx: Transaction) {
  Transaction {
    ..tx,
    redeemers: tx.redeemers
      |> debug_section(@"Redeemers")
      |> debug_redeemers()
      |> debug_section(@""),
    mint: tx.mint
      |> debug_section(@"Mint")
      |> value.from_minted_value
      |> debug_value(@"mint")
      |> value.to_minted_value,
    inputs: tx.inputs
      |> debug_section(@"Inputs")
      |> list.indexed_map(
           fn(idx, in) {
             debug_input(in, @"inputs" |> with_tag(string.from_int(idx)))
           },
         ),
    outputs: tx.outputs
      |> debug_section(@"Outputs")
      |> list.indexed_map(
           fn(idx, out) {
             debug_output(out, @"outputs" |> with_tag(string.from_int(idx)))
           },
         ),
  }
}

pub fn debug_section(return_value: r, name: String) -> r {
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
