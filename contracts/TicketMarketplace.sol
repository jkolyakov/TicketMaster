// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ITicketNFT} from "./interfaces/ITicketNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TicketNFT} from "./TicketNFT.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol"; 
import {ITicketMarketplace} from "./interfaces/ITicketMarketplace.sol";
import "hardhat/console.sol";

contract TicketMarketplace is ITicketMarketplace {

    // Owner of the TicketMarketplace contract
    address public owner;

    // Modifier to restrict access to owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Unauthorized access");
        _;
    }

    // Address of the ERC20 token contract
    address public ERC20Address;

    // EventIds which are 0 indexed
    uint128 public currentEventId = 0;

    // TicketNFT contract which is responsible for managing the creation, ownership, and transfer of unique tickets.
    TicketNFT public nftContract;

    struct EventInfo {
        uint128 nextTicketToSell;
        uint128 maxTickets;
        uint256 pricePerTicket;
        uint256 pricePerTicketERC20;
    }

    mapping (uint128 => EventInfo) public events; // mapping of eventId => EventInfo

    /**
     * @notice Constructor for the TicketMarketplace contract
     * @param _ERC20Address The address of the ERC20 token contract
     */
    constructor (address _ERC20Address) {
        owner = msg.sender;
        ERC20Address = _ERC20Address;

        // Deploy the TicketNFT contract and set its owner as the TicketMarketplace contract
        nftContract = new TicketNFT();
        nftContract.setTicketMarketplace(address(this));
    }

    /**
     * @notice Create a new event with the specified details and increment the currentEventId for the next event
     * @param maxTickets The max number of tickets that can be sold at this event
     * @param pricePerTicket The price of each ticket in ETH
     * @param pricePerTicketERC20 The price of each ticket in ERC20
     */
    function createEvent(
        uint128 maxTickets,
        uint256 pricePerTicket,
        uint256 pricePerTicketERC20
    ) external override onlyOwner{
        uint128 eventId = currentEventId;
        events[eventId] = EventInfo(0, maxTickets, pricePerTicket, pricePerTicketERC20);
        currentEventId++;
        emit EventCreated(eventId, maxTickets, pricePerTicket, pricePerTicketERC20);
    }

    /**
     * @notice Updates the maximum tickets available for a specific event
     * Note that the new maxTickets should be greater than or equal to the current maxTickets
     * @param eventId The ID of the event
     * @param newMaxTickets The new maximum number of tickets available for the event
     */
    function setMaxTicketsForEvent(
        uint128 eventId,
        uint128 newMaxTickets
    ) external override onlyOwner{
        require(newMaxTickets >= events[eventId].maxTickets, "The new number of max tickets is too small!");
        events[eventId].maxTickets = newMaxTickets;
        emit MaxTicketsUpdate(eventId, newMaxTickets);
    }

    /**
     * @notice Updates the price of an event's ticket in ETH
     * @param eventId The ID of the event
     * @param price The new price of each ticket in ETH
     */
    function setPriceForTicketETH(
        uint128 eventId,
        uint256 price
    ) external override onlyOwner{
        events[eventId].pricePerTicket = price;
        emit PriceUpdate(eventId, price, "ETH");
    }

    /**
     * @notice Updates the price of an event's ticket in ECR20
     * @param eventId The ID of the event
     * @param price The new price of each ticket in ECR20
     */
    function setPriceForTicketERC20(
        uint128 eventId,
        uint256 price
    ) external override onlyOwner {
        events[eventId].pricePerTicketERC20 = price;
        emit PriceUpdate(eventId, price, "ERC20");
    }

    /**
     * @notice Allows the user to purchase tickets using ETH. The user must send enough ETH to cover the cost of the tickets. 
     * Upon successful purchase, the tickets are minted to the user's address.
     * @param eventId The ID of the event
     * @param ticketCount The number of tickets to buy
     */
    function buyTickets(
        uint128 eventId,
        uint128 ticketCount
    ) external payable override {
        EventInfo storage eventInfo = events[eventId];
        uint256 totalCost;
        unchecked {
            totalCost = eventInfo.pricePerTicket * ticketCount;
        }
        require(totalCost / ticketCount == eventInfo.pricePerTicket, "Overflow happened while calculating the total price of tickets. Try buying smaller number of tickets.");
        require(eventInfo.maxTickets >= eventInfo.nextTicketToSell + ticketCount, "We don't have that many tickets left to sell!");
        require(msg.value >= totalCost, "Not enough funds supplied to buy the specified number of tickets.");

        for (uint128 i = 0; i < ticketCount; i++) {
            uint256 ticketId = generateTicketId(eventId, eventInfo.nextTicketToSell + i);
            nftContract.mintFromMarketPlace(msg.sender, ticketId);
        }
        
        events[eventId].nextTicketToSell+= ticketCount;
        emit TicketsBought(eventId, ticketCount, "ETH");
    }

    /**
     * @notice Allows the user to purchase tickets using ERC20. The user must send enough ETH to cover the cost of the tickets. 
     * Upon successful purchase, the tickets are minted to the user's address and the ERC20 tokens are transferred to the TicketMarketplace contract.
     * @param eventId The ID of the event
     * @param ticketCount The number of tickets to buy
     */    function buyTicketsERC20(
        uint128 eventId,
        uint128 ticketCount
    ) external override {
        EventInfo storage eventInfo = events[eventId];
        uint256 totalCost;
        unchecked {
            totalCost = eventInfo.pricePerTicketERC20 * ticketCount;
        }
        require(totalCost / ticketCount == eventInfo.pricePerTicketERC20, "Overflow happened while calculating the total price of tickets. Try buying smaller number of tickets.");
        require(eventInfo.maxTickets >= eventInfo.nextTicketToSell + ticketCount, "We don't have that many tickets left to sell!");

        // Transfer the ERC20 tokens from the user to the TicketMarketplace contract
        IERC20 token = IERC20(ERC20Address);
        require(token.transferFrom(msg.sender, address(this), totalCost), "Token transfer failed");

        // Mint the tickets
        for (uint128 i = 0; i < ticketCount; i++) {
            uint256 ticketId = generateTicketId(eventId, eventInfo.nextTicketToSell + i); //Note that the seat number is 0 indexed
            nftContract.mintFromMarketPlace(msg.sender, ticketId);
        }

        events[eventId].nextTicketToSell+= ticketCount;
        emit TicketsBought(eventId, ticketCount, "ERC20");
    }

    /**
     * @notice Updates the ERC20 token address used for ticket purchases
     * @param newERC20Address The new address of the ERC20 token contract
     */
    function setERC20Address(address newERC20Address) external override onlyOwner{
        ERC20Address = newERC20Address;
        emit ERC20AddressUpdate(newERC20Address);
    }

    /**
     * @notice Generates a unique ticket ID based on the event ID and seat number
     * @param eventId The ID of the event
     * @param seatNumber The seat number of the ticket (0 indexed)
     */
    function generateTicketId(uint128 eventId, uint128 seatNumber) public pure returns (uint256) {
        return (uint256(eventId) << 128) + uint256(seatNumber);
    }
}