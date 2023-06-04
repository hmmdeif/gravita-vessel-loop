# Gravita Loop Contract

Mimics InstaDapp/DefiSaver type looping for Gravita Vessels.

## Build

`forge build`

## Test

As this is an integration, fork tests are the only tests that are important.

`forge test`

## Deploy

Uses env vars from a file `.env`. Copy and rename `.env.sample` and fill in the required variables.

```
source .env
forge script script/FlashVessel.mainnet.s.sol:FlashVesselMainnetScript --rpc-url $MAINNET_RPC_URL --broadcast --verify -vvvv
```