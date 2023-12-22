use aiken/bytearray
use aiken/cbor
use aiken/dict
use aiken/transaction.{
  InlineDatum, Input, Mint, NoDatum, Output, OutputReference, ScriptPurpose,
  Transaction, TransactionId,
}
use aiken/transaction/credential.{
  Address, Inline, ScriptCredential, VerificationKeyCredential,
}
use aiken/transaction/value.{ada_asset_name, ada_policy_id}
use debug/debug

type DatumType {
  owner: ByteArray,
}

type MintingRedeemer {
  first: Int,
  second: ByteArray,
}

fn compare(first: ScriptPurpose, second: ScriptPurpose) {
  bytearray.compare(
    cbor.diagnostic(first) |> bytearray.from_string,
    cbor.diagnostic(second) |> bytearray.from_string,
  )
}

fn get_tx() {
  let default = transaction.placeholder()
  Transaction {
    ..default,
    redeemers: default.redeemers
      |> dict.insert(Mint("minting_policy_id"), MintingRedeemer(1, "2"), compare),
    mint: value.zero()
      |> value.add("minting_policy_1", "asset_name_1", 1)
      |> value.add("minting_policy_2", "asset_name_2", -1)
      |> value.to_minted_value,
    inputs: [
      Input {
        output_reference: OutputReference(TransactionId("tx_0"), 1),
        output: Output {
          value: value.from_lovelace(123_999_999),
          address: Address {
            stake_credential: Some(Inline(VerificationKeyCredential("stake"))),
            payment_credential: VerificationKeyCredential("payment"),
          },
          datum: NoDatum,
          reference_script: None,
        },
      },
      Input {
        output_reference: OutputReference(TransactionId("tx_0"), 0),
        output: Output {
          value: value.from_lovelace(99_999),
          address: Address {
            stake_credential: Some(
              Inline(ScriptCredential("script_key_hash_0")),
            ),
            payment_credential: ScriptCredential("script_key_hash_1"),
          },
          datum: NoDatum,
          reference_script: None,
        },
      },
    ],
    outputs: [
      Output {
        value: value.zero(),
        address: Address {
          stake_credential: Some(Inline(VerificationKeyCredential("stake"))),
          payment_credential: VerificationKeyCredential("payment"),
        },
        datum: NoDatum,
        reference_script: None,
      },
      Output {
        value: value.zero()
          |> value.add(ada_policy_id, ada_asset_name, 123_000_000)
          |> value.add("nft_policy_id", "nft_name", 1),
        address: Address {
          stake_credential: Some(Inline(VerificationKeyCredential("stake"))),
          payment_credential: VerificationKeyCredential("payment"),
        },
        datum: InlineDatum(DatumType { owner: "datum_owner" }),
        reference_script: None,
      },
    ],
  }
}

test works_with_bytearray() {
  let my_bytearray = "my_bytearray"
  ( my_bytearray |> debug.bytearray(@"my_bytearray") ) == my_bytearray
}

test works_with_int() {
  let my_int = 100
  ( my_int |> debug.int(@"my_int") ) == my_int
}

test works_with_non_zero_value() {
  let my_value =
    value.zero()
      |> value.add(ada_policy_id, ada_asset_name, 123_000_000)
      |> value.add("nft_policy_id", "nft_name", 1)
  ( my_value |> debug.value(@"my_value") ) == my_value
}

test works_with_zero_value() {
  let my_value = value.zero()
  ( my_value |> debug.value(@"my_value") ) == my_value
}

test works_with_inline_datum() {
  let my_value = InlineDatum(DatumType("decoded_from_hex"))
  ( my_value |> debug.datum(@"my_datum") ) == my_value
}

test works_with_no_datum() {
  let my_value = NoDatum
  ( my_value |> debug.datum(@"my_datum") ) == my_value
}

test works_with_input() {
  let my_value =
    Input {
      output_reference: OutputReference(TransactionId("tx_0"), 1),
      output: Output {
        value: value.from_lovelace(123_999_999),
        address: Address {
          stake_credential: Some(Inline(VerificationKeyCredential("stake"))),
          payment_credential: VerificationKeyCredential("payment"),
        },
        datum: NoDatum,
        reference_script: None,
      },
    }
  ( my_value |> debug.input(@"my_input") ) == my_value
}

test works_with_out_ref() {
  let my_value = OutputReference(TransactionId("tx_0"), 1)
  ( my_value |> debug.out_ref(@"my_output_reference") ) == my_value
}

test works_with_output() {
  let my_value =
    Output {
      value: value.from_lovelace(123_999_999),
      address: Address {
        stake_credential: Some(Inline(VerificationKeyCredential("stake"))),
        payment_credential: VerificationKeyCredential("payment"),
      },
      datum: NoDatum,
      reference_script: None,
    }
  ( my_value |> debug.output(@"my_output") ) == my_value
}

test works_with_script_output() {
  let my_value =
    Output {
      value: value.from_lovelace(99_999),
      address: Address {
        stake_credential: Some(Inline(ScriptCredential("script_key_hash_0"))),
        payment_credential: ScriptCredential("script_key_hash_1"),
      },
      datum: NoDatum,
      reference_script: None,
    }
  ( my_value |> debug.output(@"my_output") ) == my_value
}

test works_with_redeemers() {
  let tx = get_tx()
  let my_value = tx.redeemers
  ( my_value |> debug.section(@"My Redeemers") |> debug.redeemers ) == my_value
}

test works_with_minted_value() {
  let tx = get_tx()
  let my_value = tx.mint
  ( my_value |> debug.minted_value(@"my_minted_value") ) == my_value
}

test works_with_transaction() {
  let tx = get_tx()
  debug.tx(tx) == tx
}

test works_with_cbor() {
  let cbr =
    @"[_ [_ h'', h'', 8731820539], [_ h'626F6E645F6E66745F706F6C6963795F6964', h'843C7CBAD2622B3013FABBE327FEBEF1DB5FEC4F20D0D706171DE24028C998E3', 1]]"

  trace debug.format_cbor(cbr)
  debug.format_cbor(cbr) != @""
}

test works_with_cbor_2() {
  let cbr =
    @" 123([_ 121([_ {_ h'': {_ h'': 2383561 }, h'626F6E642D6E66742D706F6C6963792D6964': {_ h'5E72B098375D3959535E2717A1E87BB45F5864CFC279197C7984524C6EF4D783': 1 } }, 130, h'626F6E642D706F6C6963792D6964', h'5E72B098375D3959535E2717A1E87BB45F5864CFC279197C7984524C6EF4D783', 87, 10, 500, h'6861736865642D61737365742D6E616D65', 126])])"
  trace debug.format_cbor(cbr)
  debug.format_cbor(cbr) != @""
}
