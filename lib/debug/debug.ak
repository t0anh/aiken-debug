use aiken/builtin
use aiken/bytearray.{concat}
use aiken/cbor
use aiken/dict
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
use aiken/transaction/value.{Value, flatten}

fn first_of_quad(tuple: (a, b, c, d)) {
  tuple.1st
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

pub fn beautify(cbr: String) {
  string.to_bytearray(cbr) |> do_beautify |> string.from_bytearray
}

fn do_beautify(bytes) {
  bytes
    |> bytearray.foldl(
         ("", 0, False, ""),
         fn(byte, results) {
           let (builder, level, is_token, token) = results
           let chr = from_byte(byte)
           if is_open(chr) {
             (
               builder
                 |> concat(chr)
                 |> concat("\n")
                 |> concat(indent(level + 1)),
               level + 1,
               is_token,
               token,
             )
           } else if is_close(chr) {
             (
               if back(builder) == "\t" {
                 builder |> pop_back(level + 1) |> concat(chr)
               } else {
                 builder
                   |> fn(builder) {
                        if !is_token && builtin.length_of_bytearray(token) > 0 {
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
                   |> concat("\n")
                   |> concat(indent(level - 1))
                   |> concat(chr)
               },
               level - 1,
               is_token,
               "",
             )
           } else if chr == "'" {
             (builder |> concat(chr), level, !is_token, token)
           } else if chr == "," {
             (
               builder
                 |> concat(chr)
                 |> fn(builder) {
                      if !is_token && builtin.length_of_bytearray(token) > 0 {
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
                 |> concat("\n")
                 |> concat(indent(level)),
               level,
               is_token,
               if !is_token {
                 ""
               } else {
                 token
               },
             )
           } else if chr == "_" {
             (
               builder
                 |> pop_back(level + 1)
                 |> concat("\n")
                 |> concat(indent(level)),
               level,
               is_token,
               token,
             )
           } else if chr == " " {
             (builder, level, is_token, token)
           } else {
             (
               builder |> concat(chr),
               level,
               is_token,
               if is_token {
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

fn indent(level: Int) {
  list.repeat("\t", level)
    |> list.reduce("", bytearray.concat)
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

pub fn payment_credential(return_value: r, tag: String, cred: PaymentCredential) {
  trace tag |> with_inline_result |> string.concat(get_credential(cred))
  return_value
}

pub fn stake_credential(
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

pub fn out_ref(return_value: r, tag: String, out_ref: OutputReference) {
  let OutputReference(TransactionId(tx_hash), index) = out_ref
  trace tag
    |> with_inline_result
    |> string.concat(
         string.from_bytearray(tx_hash)
           |> string.concat(@"#")
           |> string.concat(string.from_int(index)),
       )
  return_value
}

pub fn address(return_value: r, tag: String, addr: Address) {
  return_value
    |> stake_credential(string.concat(tag, @".stake_cred"), addr.stake_credential)
    |> payment_credential(
         string.concat(tag, @".payment_cred"),
         addr.payment_credential,
       )
}

pub fn debug_value(return_value: r, tag: String, val: Value) {
  trace tag
    |> string.concat(
         with_multiline_result(cbor.diagnostic(val |> flatten) |> beautify),
       )
  return_value
}

pub fn datum(return_value: r, tag: String, datum: Datum) {
  trace tag
    |> string.concat(with_multiline_result(cbor.diagnostic(datum) |> beautify))
  return_value
}

pub fn output(return_value: r, tag: String, output: Output) {
  return_value
    |> address(string.concat(tag, @".address"), output.address)
    |> debug_value(string.concat(tag, @".value"), output.value)
    |> datum(string.concat(tag, @".datum"), output.datum)
}

pub fn redeemer(return_value: r, tag: String, entry: (ScriptPurpose, Redeemer)) {
  let (purpose, rdm) = entry
  trace tag
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
           _ -> cbor.diagnostic(purpose) |> beautify
         },
       )
    |> with_inline_result
    |> string.concat(@".redeemer")
    |> with_newline
    |> string.concat(
         cbor.diagnostic(rdm)
           |> beautify,
       )
  return_value
}

pub fn input(return_value: r, tag: String, input: Input) {
  return_value
    |> out_ref(string.concat(tag, @".out_ref"), input.output_reference)
    |> output(string.concat(tag, @".output"), input.output)
}

pub fn tx(return_value: r, tx: Transaction) {
  return_value
    |> fn(r) {
         list.indexed_foldr(
           tx.redeemers |> dict.to_list,
           r,
           fn(idx, rdm, res) {
             redeemer(
               res,
               [@"redeemers[", @"]"] |> string.join(string.from_int(idx)),
               rdm,
             )
           },
         )
       }
    |> fn(r) {
         list.indexed_foldr(
           tx.inputs,
           r,
           fn(idx, in, res) {
             input(
               res,
               [@"input[", @"]"] |> string.join(string.from_int(idx)),
               in,
             )
           },
         )
       }
    |> fn(r) {
         list.indexed_foldr(
           tx.outputs,
           r,
           fn(idx, out, res) {
             output(
               res,
               [@"output[", @"]"] |> string.join(string.from_int(idx)),
               out,
             )
           },
         )
       }
}

pub fn section(return_value: r, tag: String) {
  trace list.repeat(@"========================", 2) |> string.join(tag)
  return_value
}
