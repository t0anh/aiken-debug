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

fn back(self: ByteArray) {
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
    // pushing a dummy byte to get the last character 
    hex |> bytearray.concat("0"),
    ("", 0, 0),
    fn(byte, results) {
      let (acc, code, idx) = results
      let digit = get_digit(byte)
      if idx > 0 && idx % 2 == 0 {
        (acc |> bytearray.concat(from_byte(code)), digit, idx + 1)
      } else {
        (acc, code * 16 + digit, idx + 1)
      }
    },
  )
    |> first_of_triple
}

pub fn debug_cbor(cbr: String) {
  string.to_bytearray(cbr) |> do_debug_cbor |> string.from_bytearray
}

fn do_debug_cbor(bytes) {
  bytes
    |> bytearray.foldl(
         ("", 0, False, ""),
         fn(byte, results) {
           let (builder, level, has_token, token) = results
           let chr = from_byte(byte)
           //  trace string.from_bytearray("byte: ")
           //    |> string.concat(string.from_bytearray(chr))
           // trace string.from_bytearray("builder: ")
           //    |> string.concat(string.from_bytearray(builder))
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
                 |> newline(level - 1)
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

fn from_byte(byte: Int) {
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
    |> string.concat(@">> ")
}

fn with_single_quote_surrounded(builder: String) {
  [@"'", @"'"] |> string.join(builder)
}

fn with_tag(self: String, tag: String) {
  self |> string.concat(string.join([@"[", @"]"], tag))
}

fn with_multiline_result(builder: String) {
  @"\n>>\n"
    |> string.concat(builder)
}

fn get_credential(cred: Credential) {
  when cred is {
    VerificationKeyCredential(hash) ->
      string.concat(@"VerificationKeyCredential(", string.from_bytearray(hash))
        |> string.concat(@")")
    ScriptCredential(hash) ->
      string.concat(@"ScriptCredential(", string.from_bytearray(hash))
        |> string.concat(@")")
  }
}

pub fn debug_payment_credential(
  return_value: r,
  tag: String,
  cred: PaymentCredential,
) {
  trace tag |> with_inline_result |> string.concat(get_credential(cred))
  return_value
}

pub fn debug_stake_credential(
  return_value: r,
  tag: String,
  cred: Option<StakeCredential>,
) {
  trace tag
    |> with_inline_result
    |> string.concat(
         when cred is {
           None -> cbor.diagnostic(None)
           Some(Inline(cred)) -> get_credential(cred)
           _ -> fail
         },
       )

  return_value
}

pub fn debug_out_ref(self: OutputReference, tag: String) {
  let OutputReference(TransactionId(tx_hash), index) = self
  trace tag
    |> with_inline_result
    |> string.concat(
         string.from_bytearray(tx_hash)
           |> string.concat(@"#")
           |> string.concat(string.from_int(index)),
       )
  self
}

pub fn debug_address(return_value: r, tag: String, addr: Address) {
  return_value
    |> debug_stake_credential(
         string.concat(tag, @".stake_cred"),
         addr.stake_credential,
       )
    |> debug_payment_credential(
         string.concat(tag, @".payment_cred"),
         addr.payment_credential,
       )
}

pub fn debug_value(self: Value, tag: String) {
  trace tag
    |> string.concat(
         with_multiline_result(cbor.diagnostic(self |> flatten) |> debug_cbor),
       )
  self
}

pub fn debug_minted_value(self: MintedValue, name: String) {
  trace name
    |> string.concat(
         with_multiline_result(
           cbor.diagnostic(self |> value.from_minted_value |> flatten)
             |> debug_cbor,
         ),
       )
  self
}

pub fn debug_datum(return_value: r, tag: String, datum: Datum) {
  trace tag
    |> string.concat(with_multiline_result(cbor.diagnostic(datum) |> debug_cbor))
  return_value
}

pub fn debug_output(self: Output, tag: String) {
  Output {
    ..self,
    address: debug_address(
      self.address,
      string.concat(tag, @".address"),
      self.address,
    ),
    value: self.value |> debug_value(string.concat(tag, @".datum")),
    datum: debug_datum(self.datum, string.concat(tag, @".datum"), self.datum),
  }
}

pub fn debug_redeemer(entry: (ScriptPurpose, Redeemer)) {
  let (purpose, rdm) = entry
  trace string.from_bytearray("")
    |> with_inline_result
    |> string.concat(@".purpose")
    |> with_newline
    |> string.concat(
         when purpose is {
           Mint(pid) ->
             [@"Mint(policy_id=", @"]"]
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

pub fn debug_input(self: Input, tag: String) {
  Input {
    output_reference: self.output_reference
      |> debug_out_ref(string.concat(tag, @".out_ref")),
    output: self.output |> debug_output(string.concat(tag, @".output")),
  }
}

fn with_var(self: r, name: String) -> r {
  self
}

pub fn debug_redeemers(self: Dict<ScriptPurpose, Redeemer>) {
  self
    |> dict.to_list
    |> list.indexed_map(
         fn(idx, rdm) {
           rdm
             |> with_var(
                  @".redeemers"
                    |> with_tag(string.from_int(idx)),
                )
             |> debug_redeemer
         },
       )
    |> fn(_) { self }
}

pub fn debug_tx(tx: Transaction) {
  Transaction {
    ..tx,
    redeemers: tx.redeemers
      |> section(@"Redeemers")
      |> debug_redeemers()
      |> end_section,
    mint: tx.mint
      |> value.from_minted_value
      |> debug_value(@"mint")
      |> value.to_minted_value,
    inputs: list.indexed_map(
      tx.inputs,
      fn(idx, in) {
        debug_input(in, [@"input[", @"]"] |> string.join(string.from_int(idx)))
      },
    ),
    outputs: list.indexed_map(
      tx.outputs,
      fn(idx, out) {
        out
          |> debug_output(
               [@"output[", @"]"]
                 |> string.join(string.from_int(idx)),
             )
      },
    ),
  }
}

pub fn section(return_value: r, tag: String) -> r {
  trace list.repeat(@"========================", 2) |> string.join(tag)
  return_value
}

pub fn end_section(self: r) -> r {
  trace list.repeat(@"========================", 2) |> string.join(@"")
  self
}
