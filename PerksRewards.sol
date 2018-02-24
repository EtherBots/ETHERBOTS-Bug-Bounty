pragma solidity ^0.4.17;

import "./EtherbotsAuction.sol";

contract PerksRewards is EtherbotsAuction {
    ///  An internal method that creates a new part and stores it. This
    ///  method doesn't do any checking and should only be called when the
    ///  input data is known to be valid. Will generate both a Forge event
    ///  and a Transfer event.
   function _createPart(uint8[4] _partArray, address _owner) internal returns (uint) {
        uint32 newPartId = uint32(parts.length);
        assert(newPartId == parts.length);

        Part memory _part = Part({
            tokenId: newPartId,
            partType: _partArray[0],
            partSubType: _partArray[1],
            rarity: _partArray[2],
            element: _partArray[3],
            battlesLastDay: 0,
            experience: 0,
            forgeTime: uint32(now),
            battlesLastReset: uint32(now)
        });
        assert(newPartId == parts.push(_part) - 1);

        // emit the FORGING!!!
        Forge(_owner, newPartId, _part);

        // This will assign ownership, and also emit the Transfer event as
        // per ERC721 draft
        _transfer(0, _owner, newPartId);

        return newPartId;
    }

    uint32 constant shardsPerCrate = 500;
    uint public PART_REWARD_CHANCE = 995;
    // Deprecated subtypes contain the subtype IDs of legacy items
    // which are no longer available to be redeemed in game.
    // i.e. subtype ID 14 represents lambo body, presale exclusive.
    // a value of 0 represents that subtype (id within range)
    // as being deprecated for that part type (body, turret, etc)
    uint8[] public defenceElementBySubtypeIndex;
    uint8[] public meleeElementBySubtypeIndex;
    uint8[] public bodyElementBySubtypeIndex;
    uint8[] public turretElementBySubtypeIndex;
    // uint8[] public defenceElementBySubtypeIndex = [1,2,4,3,4,1,3,3,2,1,4];
    // uint8[] public meleeElementBySubtypeIndex = [3,1,3,2,3,4,2,2,1,1,1,1,4,4];
    // uint8[] public bodyElementBySubtypeIndex = [2,1,2,3,4,3,1,1,4,2,3,4,1,1,0]; // no more lambos :'(
    // uint8[] public turretElementBySubtypeIndex = [4,3,2,1,2,1,1,3,4,3,4];

    function setRewardChance(uint _newChance) external onlyOwner {
        require(_newChance > 980); // not too hot
        require(_newChance <= 1000); // not too cold
        PART_REWARD_CHANCE = _newChance; // just right
        // come at me goldilocks
    }
    // The following functions DON'T create parts, they add new parts
    // as possible rewards from the reward pool.


    function addDefenceParts(uint8[] _newElement) external onlyOwner {
        for (uint8 i = 0; i < _newElement.length; i++) {
            defenceElementBySubtypeIndex.push(_newElement[i]);
        }
        // require(defenceElementBySubtypeIndex.length < uint(uint8(-1)));
    }
    function addMeleeParts(uint8[] _newElement) external onlyOwner {
        for (uint8 i = 0; i < _newElement.length; i++) {
            meleeElementBySubtypeIndex.push(_newElement[i]);
        }
        // require(meleeElementBySubtypeIndex.length < uint(uint8(-1)));
    }
    function addBodyParts(uint8[] _newElement) external onlyOwner {
        for (uint8 i = 0; i < _newElement.length; i++) {
            bodyElementBySubtypeIndex.push(_newElement[i]);
        }
        // require(bodyElementBySubtypeIndex.length < uint(uint8(-1)));
    }
    function addTurretParts(uint8[] _newElement) external onlyOwner {
        for (uint8 i = 0; i < _newElement.length; i++) {
            turretElementBySubtypeIndex.push(_newElement[i]);
        }
        // require(turretElementBySubtypeIndex.length < uint(uint8(-1)));
    }
    // Deprecate subtypes. Once a subtype has been deprecated it can never be
    // undeprecated. Starting with lambo!
    function deprecateDefenceSubtype(uint8 _subtypeIndexToDeprecate) external onlyOwner {
        defenceElementBySubtypeIndex[_subtypeIndexToDeprecate] = 0;
    }

    function deprecateMeleeSubtype(uint8 _subtypeIndexToDeprecate) external onlyOwner {
        meleeElementBySubtypeIndex[_subtypeIndexToDeprecate] = 0;
    }

    function deprecateBodySubtype(uint8 _subtypeIndexToDeprecate) external onlyOwner {
        bodyElementBySubtypeIndex[_subtypeIndexToDeprecate] = 0;
    }

    function deprecateTurretSubtype(uint8 _subtypeIndexToDeprecate) external onlyOwner {
        turretElementBySubtypeIndex[_subtypeIndexToDeprecate] = 0;
    }

    // function _randomIndex(uint _rand, uint8 _startIx, uint8 _endIx, uint8 _modulo) internal pure returns (uint8) {
    //     require(_startIx < _endIx);
    //     bytes32 randBytes = bytes32(_rand);
    //     uint result = 0;
    //     for (uint8 i=_startIx; i<_endIx; i++) {
    //         result = result | uint8(randBytes[i]);
    //         result << 8;
    //     }
    //     uint8 resultInt = uint8(uint(result) % _modulo);
    //     return resultInt;
    // }


    // This function takes a random uint, an owner and randomly generates a valid part.
    // It then transfers that part to the owner.
    function _generateRandomPart(uint _rand, address _owner) internal {
        // random uint 20 in length - MAYBE 20.
        // first randomly gen a part type
        _rand = uint(keccak256(_rand));
        uint8[4] memory randomPart;
        randomPart[0] = uint8(_rand % 4) + 1;
        _rand = uint(keccak256(_rand));
        
        // randomPart[0] = _randomIndex(_rand,0,4,4) + 1; // 1, 2, 3, 4, => defence, melee, body, turret

        if (randomPart[0] == DEFENCE) {
            randomPart[1] = getPartSubtype(_rand,defenceElementBySubtypeIndex);
            randomPart[3] = _getElement(defenceElementBySubtypeIndex, randomPart[1]);

        } else if (randomPart[0] == MELEE) {
            randomPart[1] = getPartSubtype(_rand,meleeElementBySubtypeIndex);
            randomPart[3] = _getElement(meleeElementBySubtypeIndex, randomPart[1]);

        } else if (randomPart[0] == BODY) {
            randomPart[1] = getPartSubtype(_rand,bodyElementBySubtypeIndex);
            randomPart[3] = _getElement(bodyElementBySubtypeIndex, randomPart[1]);

        } else if (randomPart[0] == TURRET) {
            randomPart[1] = getPartSubtype(_rand,turretElementBySubtypeIndex);
            randomPart[3] = _getElement(turretElementBySubtypeIndex, randomPart[1]);

        }
        _rand = uint(keccak256(_rand));
        randomPart[2] = _getRarity(_rand);
        // randomPart[2] = _getRarity(_randomIndex(_rand,8,12,3)); // rarity
        _createPart(randomPart, _owner);
    }

    function getPartSubtype(uint _rand, uint8[] elementBySubtypeIndex) internal pure returns (uint8) {
        require(elementBySubtypeIndex.length < uint(uint8(-1)));
        uint8 subtypeLength = uint8(elementBySubtypeIndex.length);
        uint8 subtypeIndex = uint8(_rand % subtypeLength);
        // uint8 subtypeIndex = _randomIndex(_rand,4,8,subtypeLength);
        uint8 count = 0;
        while (elementBySubtypeIndex[subtypeIndex] == 0) {
            subtypeIndex++;
            count++;
            if (subtypeIndex == subtypeLength) {
                subtypeIndex = 0;
            }
            if (count > subtypeLength) {
                break;
            }
        }
        require(elementBySubtypeIndex[subtypeIndex] != 0);
        return subtypeIndex + 1;
    }


    function _getRarity(uint rand) pure internal returns (uint8) {
        uint16 rarity = uint16(rand % 1000);
        if (rarity >= 990) {  // 1% chance of gold
          return GOLD;
        } else if (rarity >= 970) { // 2% chance of shadow
          return SHADOW;
        } else {
          return STANDARD;
        }
    }

    function _getElement(uint8[] elementBySubtypeIndex, uint8 subtype) internal pure returns (uint8) {
        uint8 subtypeIndex = subtype - 1;
        return elementBySubtypeIndex[subtypeIndex];
    }

    mapping(address => uint[]) pendingPartCrates ;

    function getPendingPartCrateLength() external view returns (uint) {
        return pendingPartCrates[msg.sender].length;
    }

    /// Put shards together into a new part-crate
    function redeemShardsIntoPending() external {
        User storage user = addressToUser[msg.sender];
         while (user.numShards >= shardsPerCrate) {
             user.numShards -= shardsPerCrate;
             pendingPartCrates[msg.sender].push(block.number);
             // 256 blocks to redeem
         }
    }

    function openPendingPartCrates() external {
        for (uint i = 0; i < pendingPartCrates[msg.sender].length; i++) {
            uint pendingBlockNumber = pendingPartCrates[msg.sender][i];
            // can't open on the same timestamp
            require(block.number > pendingBlockNumber);

            var hash = block.blockhash(pendingBlockNumber);

            if (uint(hash) != 0) {
                // different results for all different crates, even on the same block/same user
                // randomness is already taken care of
                uint rand = uint(keccak256(hash, msg.sender, i)) % (10 ** 20);
                _generateRandomPart(rand,msg.sender);
            } else {
                // Do nothing, no second chances to secure integrity of randomness.
            }
        }
        delete pendingPartCrates[msg.sender];
    }

    uint32 constant SHARDS_MAX = 10000;

    function _addShardsToUser(User storage _user, uint32 _shards) internal {
        uint32 updatedShards = _user.numShards + _shards;
        if (updatedShards > SHARDS_MAX) {
            updatedShards = SHARDS_MAX;
        }
        _user.numShards = updatedShards;
        ShardsAdded(msg.sender,_shards);
    }

    // FORGING / SCRAPPING
    event ShardsAdded(address caller, uint32 shards);
    event Scrap(address user, uint partId);

    uint32 constant SHARDS_TO_PART = 500;
    uint8 constant SCRAP_PERCENT = 70;

    address RESELLER = address(0);

    // scraps a part for shards
    function scrap(uint partId) external {
        require(owns(msg.sender, partId));
        User storage u = addressToUser[msg.sender];
        _addShardsToUser(u, (SHARDS_TO_PART * SCRAP_PERCENT) / 100);
        Scrap(msg.sender, partId);
        transfer(scrapyard, partId);
    }

}
