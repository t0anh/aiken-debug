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

test should_return_debug_value() {
  let default = transaction.placeholder()
  let tx =
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
  debug.debug_tx(tx) == tx
}
