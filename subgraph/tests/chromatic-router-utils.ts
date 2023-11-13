import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt } from "@graphprotocol/graph-ts"
import {
  AccountCreated,
  OpenPosition
} from "../generated/ChromaticRouter/ChromaticRouter"

export function createAccountCreatedEvent(
  account: Address,
  owner: Address
): AccountCreated {
  let accountCreatedEvent = changetype<AccountCreated>(newMockEvent())

  accountCreatedEvent.parameters = new Array()

  accountCreatedEvent.parameters.push(
    new ethereum.EventParam("account", ethereum.Value.fromAddress(account))
  )
  accountCreatedEvent.parameters.push(
    new ethereum.EventParam("owner", ethereum.Value.fromAddress(owner))
  )

  return accountCreatedEvent
}

export function createOpenPositionEvent(
  marketAddress: Address,
  trader: Address,
  account: Address,
  tradingFee: BigInt,
  tradingFeeUSD: BigInt
): OpenPosition {
  let openPositionEvent = changetype<OpenPosition>(newMockEvent())

  openPositionEvent.parameters = new Array()

  openPositionEvent.parameters.push(
    new ethereum.EventParam(
      "marketAddress",
      ethereum.Value.fromAddress(marketAddress)
    )
  )
  openPositionEvent.parameters.push(
    new ethereum.EventParam("trader", ethereum.Value.fromAddress(trader))
  )
  openPositionEvent.parameters.push(
    new ethereum.EventParam("account", ethereum.Value.fromAddress(account))
  )
  openPositionEvent.parameters.push(
    new ethereum.EventParam(
      "tradingFee",
      ethereum.Value.fromUnsignedBigInt(tradingFee)
    )
  )
  openPositionEvent.parameters.push(
    new ethereum.EventParam(
      "tradingFeeUSD",
      ethereum.Value.fromUnsignedBigInt(tradingFeeUSD)
    )
  )

  return openPositionEvent
}
