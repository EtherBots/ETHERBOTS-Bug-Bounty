pragma solidity ^0.4.18;

import "./ERC721.sol";
import "./Base.sol";
import "./AccessControl.sol";

// Auction contract, facilitating statically priced sales, as well as 
// inflationary and deflationary pricing for items.
// Relies heavily on the ERC721 interface and so most of the methods
// are tightly bound to that implementation
contract NFTAuctionBase is Pausable {

    ERC721AllImplementations public nftContract;
    uint256 public ownerCut;
    uint public minDuration;
    uint public maxDuration;

    // Represents an auction on an NFT (in this case, Robot part)
    struct Auction {
        // address of part owner
        address seller;
        // wei price of listing
        uint256 startPrice;
        // wei price of floor
        uint256 endPrice;
        // duration of sale in seconds.
        uint64 duration;
        // Time when sale started
        // Reset to 0 after sale concluded
        uint64 start;
    }

    function NFTAuctionBase() public {
        minDuration = 1 minutes;
        maxDuration = 30 days; // arbitrary
    }

    // map of all tokens and their auctions
    mapping (uint256 => Auction) tokenIdToAuction;

    event AuctionCreated(uint256 tokenId, uint256 startPrice, uint256 endPrice, uint64 duration, uint64 start);
    event AuctionSuccessful(uint256 tokenId, uint256 totalPrice, address winner);
    event AuctionCancelled(uint256 tokenId);

    // returns true if the token with id _partId is owned by the _claimant address
    function _owns(address _claimant, uint256 _partId) internal view returns (bool) {
        return nftContract.ownerOf(_partId) == _claimant;
    }

   // returns false if start == 0
    function _isActiveAuction(Auction _auction) internal pure returns (bool) {
        return _auction.start > 0;
    }
    
    // assigns ownership of the token with id = _partId to this contract
    // must have already been approved
    function _escrow(address, uint _partId) internal {
        // throws on transfer fail
        nftContract.takeOwnership(_partId);
    }

    // transfer the token with id = _partId to buying address
    function _transfer(address _purchasor, uint256 _partId) internal {
        // successful purchaseder must takeOwnership of _partId
        // nftContract.approve(_purchasor, _partId); 
               // actual transfer
                nftContract.transfer(_purchasor, _partId);

    }

    // creates
    function _newAuction(uint256 _partId, Auction _auction) internal {

        require(_auction.duration >= minDuration);

        tokenIdToAuction[_partId] = _auction;

        AuctionCreated(uint256(_partId),
            uint256(_auction.startPrice),
            uint256(_auction.endPrice),
            uint64(_auction.duration),
            uint64(_auction.start)
        );
    }

    function setMinDuration(uint _duration) external onlyOwner {
        minDuration = _duration;
    }

    function setMaxDuration(uint _duration) external onlyOwner {
        maxDuration = _duration;
    }

    /// Removes auction from public view, returns token to the seller
    function _cancelAuction(uint256 _partId, address _seller) internal {
        _removeAuction(_partId);
        _transfer(_seller, _partId);
        AuctionCancelled(_partId);
    }

    event PrintEvent(string, address, uint);

    // Calculates price and transfers purchase to owner. Part is NOT transferred to buyer.
    function _purchase(uint256 _partId, uint256 _purchaseAmount) internal returns (uint256) {

        Auction storage auction = tokenIdToAuction[_partId];

        // check that this token is being auctioned
        require(_isActiveAuction(auction));

        // enforce purchase >= the current price
        uint256 price = _currentPrice(auction);
        require(_purchaseAmount >= price);

        // Store seller before we delete auction.
        address seller = auction.seller;

        // Valid purchase. Remove auction to prevent reentrancy.
        _removeAuction(_partId);

        // Transfer proceeds to seller (if there are any!)
        if (price > 0) {
            
            // Calculate and take fee from purchase

            uint256 auctioneerCut = _computeFee(price);
            uint256 sellerProceeds = price - auctioneerCut;

            PrintEvent("Seller, proceeds", seller, sellerProceeds);

            // Pay the seller
            seller.transfer(sellerProceeds);
        }

        // Calculate excess funds and return to buyer.
        uint256 purchaseExcess = _purchaseAmount - price;

        PrintEvent("Sender, excess", msg.sender, purchaseExcess);
        // Return any excess funds. Reentrancy again prevented by deleting auction.
        msg.sender.transfer(purchaseExcess);

        AuctionSuccessful(_partId, price, msg.sender);

        return price;
    }

    // returns the current price of the token being auctioned in _auction
    function _currentPrice(Auction storage _auction) internal view returns (uint256) {
        uint256 secsElapsed = now - _auction.start;
        return _computeCurrentPrice(
            _auction.startPrice,
            _auction.endPrice,
            _auction.duration,
            secsElapsed
        );
    }

    // Checks if NFTPart is currently being auctioned.
    function _isBeingAuctioned(Auction storage _auction) internal view returns (bool) {
        return (_auction.start > 0);
    }

    // removes the auction of the part with id _partId
    function _removeAuction(uint256 _partId) internal {
        delete tokenIdToAuction[_partId];
    }

    // computes the current price of an deflating-price auction 
    function _computeCurrentPrice( uint256 _startPrice, uint256 _endPrice, uint256 _duration, uint256 _secondsPassed ) internal pure returns (uint256 _price) {
        _price = _startPrice;
        if (_secondsPassed >= _duration) {
            // Has been up long enough to hit endPrice.
            // Return this price floor.
            _price = _endPrice;
            // this is a statically price sale. Just return the price.
        }
        else if (_duration > 0) {
            // This auction contract supports auctioning from any valid price to any other valid price.
            // This means the price can dynamically increase upward, or downard.
            int256 priceDifference = int256(_endPrice) - int256(_startPrice);
            int256 currentPriceDifference = priceDifference * int256(_secondsPassed) / int256(_duration);
            int256 currentPrice = int256(_startPrice) + currentPriceDifference;

            _price = uint256(currentPrice);
        }
        return _price;
    }

    // Compute percentage fee of transaction

    function _computeFee (uint256 _price) internal view returns (uint256) {
        return _price * ownerCut / 10000; 
    }

}

// Clock auction for NFTParts.
// Only timed when pricing is dynamic (i.e. startPrice != endPrice).
// Else, this becomes an infinite duration statically priced sale,
// resolving when succesfully purchase for or cancelled.

contract DutchAuction is NFTAuctionBase, EtherbotsPrivileges {

    // The ERC-165 interface signature for ERC-721.
    bytes4 constant InterfaceSignature_ERC721 = bytes4(0xda671b9b);
 
    function DutchAuction(address _nftAddress, uint256 _fee) public {
        require(_fee <= 10000);
        ownerCut = _fee;

        ERC721AllImplementations candidateContract = ERC721AllImplementations(_nftAddress);
        require(candidateContract.supportsInterface(InterfaceSignature_ERC721));
        nftContract = candidateContract;
    }

    // Remove all ether from the contract. This will be marketplace fees.
    // Transfers to the NFT contract. 
    // Can be called by owner or NFT contract.

    function withdrawBalance() external {
        address nftAddress = address(nftContract);

        require(msg.sender == owner || msg.sender == nftAddress);

        nftAddress.transfer(this.balance);
    }

    event PrintEvent(string, address, uint);

    // Creates an auction and lists it.
    function createAuction( uint256 _partId, uint256 _startPrice, uint256 _endPrice, uint256 _duration, address _seller ) external whenNotPaused {
        // Sanity check that no inputs overflow how many bits we've allocated
        // to store them in the auction struct.
        require(_startPrice == uint256(uint128(_startPrice)));
        require(_endPrice == uint256(uint128(_endPrice)));
        require(_duration == uint256(uint64(_duration)));

        require(msg.sender == address(nftContract));
        _escrow(_seller, _partId);
        Auction memory auction = Auction(
            _seller,
            uint128(_startPrice),
            uint128(_endPrice),
            uint64(_duration),
            uint64(now) //seconds uint 
        );
        PrintEvent("Auction Start", 0x0, auction.start);
        _newAuction(_partId, auction);
    }

    // purchases on open auction
    // will transfer ownership is successful
    
    function purchase(uint256 _partId) external payable whenNotPaused {
        // _purchase will throw if the purchase or funds transfer fails
        _purchase(_partId, msg.value);
        _transfer(msg.sender, _partId);
    }

    // Allows a user to cancel an auction before it's resolved.
    // Returns the part to the seller.

    function cancelAuction(uint256 _partId) external {
        Auction storage auction = tokenIdToAuction[_partId];
        require(_isBeingAuctioned(auction));
        address seller = auction.seller;
        require(msg.sender == seller);
        _cancelAuction(_partId, seller);
    }

    // returns the current price of the auction of a token with id _partId
    function getCurrentPrice(uint256 _partId) external view returns (uint256) {
        Auction storage auction = tokenIdToAuction[_partId];
        require(_isActiveAuction(auction));
        return _currentPrice(auction);
    }

    //  Returns the details of an auction from its _partId.
    function getAuction(uint256 _partId) external view returns ( address seller, uint256 startPrice, uint256 endPrice, uint256 duration, uint256 startedAt ) {
        Auction storage auction = tokenIdToAuction[_partId];
        require(_isBeingAuctioned(auction));
        return ( auction.seller, auction.startPrice, auction.endPrice, auction.duration, auction.start);
    }

    // Allows owner to cancel an auction.
    // ONLY able to be used when contract is paused,
    // in the case of emergencies.
    // Parts returned to seller as it's equivalent to them 
    // calling cancel.
    function cancelAuctionWhenPaused(uint256 _partId) whenPaused onlyOwner external {
        Auction storage auction = tokenIdToAuction[_partId];
        require(_isBeingAuctioned(auction));
        _cancelAuction(_partId, auction.seller);
    }

}
