// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

library Errors {
    string constant ONLY_DAO_CAN_ACCESS = "DAO";
    string constant ONLY_VAULT_CAN_ACCESS = "VLT";
    string constant ONLY_DEDICATED_MSG_SENDER_CAN_ACCESS = "DMS";
    string constant ONLY_LIQUIDATOR_CAN_ACCESS = "LIQ";
    string constant ONLY_FUNDS_OWNER_CAN_WITHDRAW_FUNDS = "FOW";
    string constant ETH_TRANSFER_FAILED = "ETF";
    string constant INVALID_SWAP_VALUE = "ISV";
    string constant NOT_ENOUGH_SLOT_FREE_LIQUIDITY = "NESL";
    string constant TOO_SMALL_AMOUNT = "TSA";
    string constant INVALID_ORACLE_VERSION = "IOV";
    string constant EXCEED_MARGIN_RANGE = "IOV";
    string constant UNSUPPORTED_TRADING_FEE_RATE = "UTFR";
    string constant ALREADY_REGISTERED_ORACLE_PROVIDER = "ARO";
    string constant ALREADY_REGISTERED_TOKEN = "ART";
    string constant UNREGISTERED_TOKEN = "URT";
    string constant INTEREST_RATE_NOT_INITIALIZED = "IRNI";
    string constant INTEREST_RATE_OVERFLOW = "IROF";
    string constant INTEREST_RATE_PAST_TIMESTAMP = "IRPT";
    string constant INTEREST_RATE_NOT_APPENDABLE = "IRNA";
    string constant INTEREST_RATE_ALREADY_APPLIED = "IRAA";
    string constant UNSETTLED_POSITION = "USP";
    string constant INVALID_POSITION_QTY = "IPQ";
}
