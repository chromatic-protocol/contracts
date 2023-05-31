// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";
import {IERC1155MetadataURI} from "@openzeppelin/contracts/interfaces/IERC1155MetadataURI.sol";

interface IUSUMLpToken is IERC1155, IERC1155MetadataURI {
    function totalSupply(uint256 id) external view returns (uint256);

    function mint(address to, uint256 id, uint256 amount, bytes calldata data) external;

    function burn(address from, uint256 id, uint256 amount) external;

    function decimals() external view returns (uint8);
}
