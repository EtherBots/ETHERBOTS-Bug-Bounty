pragma solidity ^0.4.18;

import "./AccessControl.sol";
import "./PerkTree.sol";
import "./GenericAuction.sol";

contract EtherbotsAuction is PerkTree {
    event PrintEvent(string, address, uint);

    // Auction auction;
    /// @dev Sets the reference to the sale auction.
    /// @param _address - Address of sale contract.
    function setAuctionAddress(address _address) external onlyOwner addressNotNil(_address) {
        require(_address != address(0));
        DutchAuction candidateContract = DutchAuction(_address);

        // require(candidateContract.isSaleClockAuction());
        // Set the new contract address
        auction = candidateContract;
    }

    // list a part for auction.

    function createAuction(
        uint256 _partId,
        uint256 _startPrice,
        uint256 _endPrice,
        uint256 _duration ) external whenNotPaused 
    {

        PrintEvent("createAuction", auction, 0);
        PrintEvent("this", this, 0);
        PrintEvent("sender", msg.sender, 0);
        PrintEvent("owner", partIndexToOwner[_partId], 0);

        // user must have current control of the part
        // will lose control if they delegate to the auction
        // therefore no duplicate auctions!
        require(owns(msg.sender, _partId));

        _approve(_partId, auction);

        // will throw if inputs are invalid
        // will clear transfer approval
        DutchAuction(auction).createAuction(_partId,_startPrice,_endPrice,_duration,msg.sender);
    }

    // transfer balance back to core contract
    function withdrawAuctionBalance() external onlyOwner {
        DutchAuction(auction).withdrawBalance();
    }
}
