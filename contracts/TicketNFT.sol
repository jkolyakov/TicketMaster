// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ITicketNFT} from "./interfaces/ITicketNFT.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Uncomment this line to use console.log
import "hardhat/console.sol";

contract TicketNFT is ERC1155, ITicketNFT, Ownable {

    // Address of the TicketMarketplace contract
    address public ticketMarketplace;

    // Event to log the minting of a ticket
    event TicketMinted(address indexed to, uint256 indexed nftId);

    // Constructor for the TicketNFT contract
    constructor() ERC1155("") Ownable(msg.sender) {}

    /// @notice Sets the TicketMarketplace contract address (only callable by owner)
    /**
     * @notice Sets the TicketMarketplace contract address
     * @param _marketplace The address of the TicketMarketplace contract
     */
    function setTicketMarketplace(address _marketplace) external onlyOwner{
        require(ticketMarketplace == address(0), "Marketplace already set");
        ticketMarketplace = _marketplace;
    }

    /**
     * @notice Allows the marketplace to mint tickets
     * @param to Address to mint the ticket to
     * @param nftId The NFT ID of the ticket 
     */
    function mintFromMarketPlace(address to, uint256 nftId) external override {
        require(msg.sender == ticketMarketplace, "Unauthorized: Issuer is not the marketplace");

        _mint(to, nftId, 1, "");
        emit TicketMinted(to, nftId);
    }
}