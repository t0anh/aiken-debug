use aiken/bytearray
use aiken/cbor
use aiken/dict
use aiken/string
use aiken/transaction.{
  InlineDatum, Mint, NoDatum, Output, ScriptPurpose, Transaction,
}
use aiken/transaction/credential.{Address, Inline, VerificationKeyCredential}
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
        |> value.add("minting_policy_1", "asset_name_2", -1)
        |> value.to_minted_value,
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
            |> value.add(ada_policy_id, ada_asset_name, 123_000_000),
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

test mint() {
  let val =
    value.zero()
      |> value.add("minting_policy_1", "asset_name_1", 1)
      |> value.add("minting_policy_1", "asset_name_2", -1)
      |> value.to_minted_value
  (
    val
      |> debug.debug_minted_value(@"mint_value")
  ) == val
}
