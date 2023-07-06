#!/bin/bash
MNEMONIC_JUNK="test test test test test test test test test test test junk"
anvil --chain-id 31337 -f https://arb-goerli.g.alchemy.com/v2/$ALCHEMY_KEY  -m "${MNEMONIC:-$MNEMONIC_JUNK}" --fork-block-number 19474553