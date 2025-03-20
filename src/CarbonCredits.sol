// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract CarbonCredits is ERC1155, Ownable {
    error CarbonCredits__InvalidCreditType();

    struct CreditType {
        uint256 vintage; // year of the credits
        string projectType; // type of project - wind/solar
        string region; // region of the project
        string standard; // gold standard
        bool isActive;
    }

    uint256 private _nextCreditId = 1;

    mapping(uint256 => CreditType) public creditTypes;

    constructor() ERC1155("CarbonCredits") Ownable(msg.sender) {}

    function createCreditType(uint256 vintage, string memory projectType, string memory region, string memory standard)
        external
        onlyOwner
        returns (uint256)
    {
        uint256 creditId = _nextCreditId++;
        creditTypes[creditId] =
            CreditType({vintage: vintage, projectType: projectType, region: region, standard: standard, isActive: true});
        return creditId;
    }

    function mint(address account, uint256 creditId, uint256 amount, bytes memory data) external onlyOwner {
        if (!creditTypes[creditId].isActive) revert CarbonCredits__InvalidCreditType();
        _mint(account, creditId, amount, data);
    }

    function getCreditTypes(uint256 creditId) external view returns (CreditType memory) {
        return creditTypes[creditId];
    }
}
