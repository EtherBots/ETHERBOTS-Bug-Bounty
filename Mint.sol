pragma solidity ^0.4.17;

import "./PerksRewards.sol";

contract Mint is PerksRewards {

    mapping (address => uint) doubleDropsClaimed;

    // this is the contract used for generating promo parts
    // very similar to the one used in cryptokitties

    uint8 constant MAX_DOUBLES = 2;
    uint8 public doubleDropCount;

    // can only be called twice
    // gives every part owner a part crate
    // this does not dilute anyone's value --> doubles supply
    // simply a way of introducing more players to the game
    function doubleDrop() external onlyOwner {
        require(doubleDropCount < MAX_DOUBLES);
        doubleDropCount++;
    }

    function claimDoubleDrop() external {
        require(doubleDropsClaimed[msg.sender] < doubleDropCount);
        doubleDropsClaimed[msg.sender]++;
        pendingPartCrates[msg.sender].push(block.number);
    }

    // prevents future double drops
    function removeDoubleDrops() external onlyOwner {
        doubleDropCount = MAX_DOUBLES;
    }

    // Owner only function to give an address new parts.
    // Strictly capped at 5000.
    // This will ONLY be used for promotional purposes (i.e. providing items for Wax/OPSkins partnership)
    // which we don't benefit financially from, or giving users who win the prize of designing a part 
    // for the game, a single copy of that part.
    
    uint16 constant MINT_LIMIT = 5000;
    uint16 public partsMinted = 0;

    function mintPart(address _owner) external onlyOwner {
        mintParts(1, _owner);
    }

    uint8 SINGLE_MINT_LIMIT = 100;

    function mintParts(uint16 _count, address _owner) public onlyOwner {
        require(_count > 0 && _count <= SINGLE_MINT_LIMIT);
        // check overflow
        require(partsMinted + _count > partsMinted);
        require(partsMinted + _count < MINT_LIMIT);
        
        for (uint i = 0; i < _count; i++) {
            addressToUser[_owner].numShards += SHARDS_TO_PART;
        }
        partsMinted += _count;
    }       

    function mintParticularPart(uint8[4] _partArray, address _owner) public onlyOwner {
        require(partsMinted < MINT_LIMIT);
        /* cannot create deprecated parts
        for (uint i = 0; i < deprecated.length; i++) {
            if (_partArray[2] == deprecated[i]) {
                revert();
            }
        } */
        _createPart(_partArray, _owner);
        partsMinted++;
    }

}