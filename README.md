# Description

Adding sugar to Aiken debugging flow

## How to use

You wouldn't install me as a dependency, since traces will be ignored when living inside the `build` folder (at least for now). Instead, using me as a snippet for debugging purpose


## API Documentation

Pipe a debugger without changing your logic. For example:

```diff
validator {
     when ctx.purpose is {
       Spend(_) -> or {
-          must_be_signed_by(ctx.transaction, datum.owner),
+          must_be_signed_by(ctx.transaction |> debug.tx, datum.owner),
           and {
             must_be_signed_by(ctx.transaction, datum.beneficiary),
             must_start_after(ctx.transaction.validity_range, datum.lock_until),
```

And see results:

```bash
# aiken check
# ..
 ↳ =====================================Inputs=====================================
 ↳ inputs[0].out_ref
 tx_0#1
 ↳ inputs[0].output.address.payment_credential
 VerificationKeyCredential('payment')
 ↳ inputs[0].output.address.stake_credential
 VerificationKeyCredential('stake')
 ↳ inputs[0].output.value
 [
 	[
 		h'',
 		h'',
 		123999999
 	]
 ]
 ↳ inputs[0].output.datum
 121([])
 ↳ inputs[1].out_ref
 tx_0#0
 ↳ inputs[1].output.address.payment_credential
 ScriptCredential('script_key_hash_1')
 ↳ inputs[1].output.address.stake_credential
 ScriptCredential('script_key_hash_0')
 ↳ inputs[1].output.value
 [
 	[
 		h'',
 		h'',
 		99999
 	]
 ]
 ↳ inputs[1].output.datum
 121([])
 ↳ ====================================Outputs=====================================
 ↳ outputs[0].address.payment_credential
 VerificationKeyCredential('payment')
 ↳ outputs[0].address.stake_credential
 VerificationKeyCredential('stake')
 ↳ outputs[0].value
 []
 ↳ outputs[0].datum
 121([])
 ↳ outputs[1].address.payment_credential
 VerificationKeyCredential('payment')
 ↳ outputs[1].address.stake_credential
 VerificationKeyCredential('stake')
 ↳ outputs[1].value
 [
 	[
 		h'',
 		h'',
 		123000000
 	],
 	[
 		h'6E66745F706F6C6963795F6964', # nft_policy_id
 		h'6E66745F6E616D65', # nft_name
 		1
 	]
 ]
 ↳ outputs[1].datum
 123([
 	121([
 		h'646174756D5F6F776E6572', # datum_owner
 	])
 ])
 ↳ ======================================Mint======================================
 ↳ mint
 [
 	[
 		h'6D696E74696E675F706F6C6963795F31', # minting_policy_1
 		h'61737365745F6E616D655F31', # asset_name_1
 		1
 	],
 	[
 		h'6D696E74696E675F706F6C6963795F32', # minting_policy_2
 		h'61737365745F6E616D655F32', # asset_name_2
 		-1
 	]
 ]
 ↳ ===================================Redeemers====================================
 ↳ redeemers[0]
 .purpose
 Mint(policy_id='minting_policy_id')
 .redeemer
 121([
 	1,
 	h'32', # 2
 ])
 ↳ ================================================================================

```

List of debuggers:

- `debug_int`
- `debug_bytearray`
- `debug_out_ref`
- `debug_input`
- `debug_output`
- `debug_redeemers`
- `debug_datum`
- `debug_value`
- `debug_minted_value`
- ...
