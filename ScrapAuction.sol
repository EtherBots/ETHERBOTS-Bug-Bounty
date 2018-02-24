pragma solidity ^0.4.18;

// import "./DutchAuction.sol";

// contract ScrapAuction is EtherbotsAuction {

//     uint256 public constant SCRAPYARD_START_PRICE = 1000 finney;
//     uint256 public auctionDuration = 1 day;

//     function setAuctionDuration(uint _duration) external onlyOwner {
//         auctionDuration = _duration;
//     }

//     function listScrapPart(uint partId) public {

//         _approve(partId, marketplace);
                
//         MarketplaceAuction(marketplace).createAuction(
//             partId,
//             _getNextAuctionPrice(),
//             0,
//             auctionDuration,
//             address(this)
//         );

//     }

//     function _getNextAuctionPrice() internal view returns (uint) {
//         uint avg = MarketplaceAuction(marketplace).averageScrapPrice();
//         // add 10% to the average
//         // prevent runaway pricing
//         uint next = avg + ((10 * avg) / 100);
//         if (next < SCRAPYARD_START_PRICE) {
//             next = SCRAPYARD_START_PRICE;
//         }
//         return next;
//     }

// }

// // The Scrapyard is a mechanism for reducing barriers to entry for the game
// // while preserving the value of 'regular parts'
// // What can scrap parts do?
// // Battle! (but only against other scrap bots)
// // be forged into better parts

// // Scrap parts can be combined together
// // So what can't scrap parts do?
// // Scrap bots can't battle
// // You can't mix scrap parts with non-scrap parts

// // contract ScrapyardAuction is DutchAuction {

// //     uint256 public constant SCRAPYARD_STARTING_PRICE = 10 finney;
// //     uint256 public constant SCRAPYARD_AUCTION_DURATION = 1 hours;

// //     function updatePrice() {

// //     }

// //     // should use market forces to update

// //     function setYardSize(uint8 size) external onlyOwner {
// //         yardSize = size;
// //     }

// //     function setLotTime(uint64 time) external onlyOwner {

// //     }

// //     uint8 public lastScrapSales;
// //     uint256[] public lastScrapPrices;

// //     function createAuction(
// //         uint256 _tokenId,
// //         uint256 _startingPrice,
// //         uint256 _endingPrice,
// //         uint256 _duration,
// //         address _seller
// //     )
// //         external
// //     {
// //         // Sanity check that no inputs overflow how many bits we've allocated
// //         // to store them in the auction struct.
// //         require(_startingPrice == uint256(uint128(_startingPrice)));
// //         require(_endingPrice == uint256(uint128(_endingPrice)));
// //         require(_duration == uint256(uint64(_duration)));

// //         require(msg.sender == address(baseNFTContract));
// //         _escrow(_seller, _tokenId);
// //         Auction memory auction = Auction(
// //             _seller,
// //             uint128(_startingPrice),
// //             uint128(_endingPrice),
// //             uint64(_duration),
// //             uint64(now)
// //         );
// //         _addAuction(_tokenId, auction);
// //     }

// //     // make this a constant to provide some certainty
// //     uint8 constant LAST_N_SALES = 5;

// //     function purchase(uint256 _tokenId) external payable {
// //         address seller = tokenIdToAuction[_tokenId].seller;
// //         uint256 price = _purchase(_tokenId, msg.value);
// //         _transfer(msg.sender, _token.Id);
// //         if (seller == address(baseNFTContract)) {
// //             // we sold it --> one of our scrap bots
// //             lastScrapPrices[lastScrapSales % LAST_N_SALES] = price;
// //             lastScrapSales++;
// //         }
// //     }


// //     function averageOfLastLot() external view returns (uint256) {
// //         uint256 sum = 0;
// //         for (uint256 i = 0; i < lastScrapPrices.length; i++) {
// //             sum += lastScrapPrices[i];
// //         }
// //         return sum / lastScrapPrices.length;
// //     }
// // }
