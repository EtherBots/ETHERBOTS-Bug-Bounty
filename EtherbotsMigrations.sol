pragma solidity ^0.4.17;

import "./Mint.sol";
import "./NewCratePreSale.sol";

contract EtherbotsMigrations is Mint {

    event CratesOpened(address indexed _from, uint8 _quantity);
    event OpenedOldCrates(address indexed _from);
    event MigratedCrates(address indexed _from, uint16 _quantity, bool isMigrationComplete);

    // address presale = 0xc23F76aEa00B775AADC8504CcB22468F4fD2261A;
    // address presale = 0x84dfd9f27bcb2c7f621f373e5215094c486c545b; // ropsten test
    // address presale = 0xf2a0b5dea1fdcb99d02a7e78aa3b96f388e18b74; //vmtest
    address presale = 0x84DFd9f27BcB2C7f621F373e5215094C486c545b; // RINKEBY TEST
    mapping(address => bool) public hasMigrated;
    mapping(address => bool) public hasOpenedOldCrates;
    mapping(address => uint[]) pendingCrates;
    mapping(address => uint16) public expiredCrates;
    mapping(address => uint16) public cratesMigrated;

  

   
    // Element: copy for MIGRATIONS ONLY.
    string constant private DEFENCE_ELEMENT_BY_ID = "12434133214";
    string constant private MELEE_ELEMENT_BY_ID = "31323422111144";
    string constant private BODY_ELEMENT_BY_ID = "212343114234111";
    string constant private TURRET_ELEMENT_BY_ID = "43212113434";

    // Once only function.
    // Transfers all pending and expired crates in the old contract
    // into pending crates in the current one.
    // Users can then open them on the new contract.
    // Should only rarely have to be called.
    // event oldpending(uint old);

    function openOldCrates() external {
        require(hasOpenedOldCrates[msg.sender] == false);
        // uint oldPendingCrates = NewCratePreSale(presale).getPendingCrateForUserByIndex(msg.sender,0); // getting unrecognised opcode here --!
        // oldpending(oldPendingCrates);
        // require(oldPendingCrates == 0);
        _migrateExpiredCrates();
        hasOpenedOldCrates[msg.sender] = true;
        OpenedOldCrates(msg.sender);
    }
    // event MigratedBot(string bot);
    // TODO: make sure this doesn't OOG on big migrates
    // event me(uint);
    function migrate() external whenNotPaused {
        
        // Can't migrate twice .
        require(hasMigrated[msg.sender] == false);
        
        // require(NewCratePreSale(presale).getPendingCrateForUserByIndex(msg.sender,0) == 0);
        // No pending crates in the new contract allowed. Make sure you open them first.
        require(pendingCrates[msg.sender].length == 0);
        
        // If the user has old expired crates, don't let them migrate until they've
        // converted them to pending crates in the new contract.
        if (NewCratePreSale(presale).getExpiredCratesForUser(msg.sender) > 0) {
            require(hasOpenedOldCrates[msg.sender]); 
        }

        // have to make a ton of calls unfortunately 
        uint16 length = uint16(NewCratePreSale(presale).getRobotCountForUser(msg.sender));

        // gas limit will be exceeded with *whale* etherbot players!
        // let's migrate their robots in batches of ten.
        // they can afford it
        bool isMigrationComplete = false;
        var max = length - cratesMigrated[msg.sender];
        if (max > 10) {
            max = 10;
        } else { // final call - all robots will be migrated
            isMigrationComplete = true;
            hasMigrated[msg.sender] = true;
        }
        for (uint i = cratesMigrated[msg.sender]; i < cratesMigrated[msg.sender] + max; i++) {
            var robot = NewCratePreSale(presale).getRobotForUserByIndex(msg.sender, i);
            var robotString = uintToString(robot);
            // MigratedBot(robotString);

            _migrateRobot(robotString);
            
        }
        cratesMigrated[msg.sender] += max;
        MigratedCrates(msg.sender, cratesMigrated[msg.sender], isMigrationComplete);
    }

    function _migrateRobot(string robot) private {
        var (melee, defence, body, turret) = _convertBlueprint(robot);
        // blueprints event
        // blueprints(body, turret, melee, defence);
        _createPart(melee, msg.sender);
        _createPart(defence, msg.sender);
        _createPart(turret, msg.sender);
        _createPart(body, msg.sender);
    }

    function _getRarity(string original, uint8 low, uint8 high) pure private returns (uint8) {
        uint32 rarity = stringToUint32(substring(original,low,high));
        if (rarity >= 950) {
          return GOLD; 
        } else if (rarity >= 850) {
          return SHADOW;
        } else {
          return STANDARD; 
        }
    }
   
    function _getElement(string elementString, uint partId) pure private returns(uint8) {
        return stringToUint8(substring(elementString, partId-1,partId));
    }

    function _getPartId(string original, uint8 start, uint8 end, uint8 partCount) pure private returns(uint8) {
        return (stringToUint8(substring(original,start,end)) % partCount) + 1;
    }

    function userPendingCrateNumber(address _user) external view returns (uint) {
        return pendingCrates[_user].length;
    }    
    
    // convert old string representation of robot into 4 new ERC721 parts
  
    function _convertBlueprint(string original) pure private returns(uint8[4] body,uint8[4] melee, uint8[4] turret, uint8[4] defence ) {

        /* ------ CONVERSION TIME ------ */
        

        body[0] = BODY; 
        body[1] = _getPartId(original, 3, 5, 15);
        body[2] = _getRarity(original, 0, 3);
        body[3] = _getElement(BODY_ELEMENT_BY_ID, body[1]);
        
        turret[0] = TURRET;
        turret[1] = _getPartId(original, 8, 10, 11);
        turret[2] = _getRarity(original, 5, 8);
        turret[3] = _getElement(TURRET_ELEMENT_BY_ID, turret[1]);

        melee[0] = MELEE;
        melee[1] = _getPartId(original, 13, 15, 14);
        melee[2] = _getRarity(original, 10, 13);
        melee[3] = _getElement(MELEE_ELEMENT_BY_ID, melee[1]);

        defence[0] = DEFENCE;
        var len = bytes(original).length;
        if (len == 19) {
            defence[1] = _getPartId(original, 18, 19, 11);
        } else if (len == 18) {
            defence[1] = uint8(1);
        } else if (len == 20) {
            defence[1] = _getPartId(original, 18, 20, 11);
        }
        defence[2] = _getRarity(original, 15, 18);
        defence[3] = _getElement(DEFENCE_ELEMENT_BY_ID, defence[1]);

        // implicit return
    }

    // give one more chance
    function _migrateExpiredCrates() private {
        // get the number of expired crates
        uint expired = NewCratePreSale(presale).getExpiredCratesForUser(msg.sender);
        for (uint i = 0; i < expired; i++) {
            pendingCrates[msg.sender].push(block.number);
        }
    }
    // Users can open pending crates on the new contract.
    function openCrates() public whenNotPaused {
        uint[] memory pc = pendingCrates[msg.sender];
        require(pc.length > 0);
        uint8 count = 0;
        for (uint i = 0; i < pc.length; i++) {
            uint crateBlock = pc[i];
            require(block.number > crateBlock);
            // can't open on the same timestamp
            var hash = block.blockhash(crateBlock);
            if (uint(hash) != 0) {
                // different results for all different crates, even on the same block/same user
                // randomness is already taken care of
                uint rand = uint(keccak256(hash, msg.sender, i)) % (10 ** 20);
                _migrateRobot(uintToString(rand));
                count++;
            } else {
                expiredCrates[msg.sender] += uint16(i + 1);
                break;
            }
        }
        CratesOpened(msg.sender, count);
        delete pendingCrates[msg.sender];
    }

    // The below are the dev backups for helping people open their crates
    // can only be used once, so we'd prefer not to use them.

    // commit to blockhashes for a number of expired crates
    // function forceExpiredCrates(address forced) external onlyOwner {
    //     uint expired = expiredCrates[forced];
    //     for (uint i = 0; i < expired; i++) {
    //         pendingCrates[forced].push(block.number);
    //     }
    //     // reset to 0 - last chance saloon
    //     expiredCrates[forced] = 0;
    //     OpenedOldCrates(forced);
    // }

    // // must be called before the hour is over
    // // otherwise the crates will be lost
    // // please do it yourselves --> we would like to never have to use this backup
    // // can't just allow looping or the owner could game the system
    // // we wouldn't :P --> but don't trust us!
    // function openExpiredCrates(address forced) external onlyOwner {
    //     // generate a fake robot
    //     // NOTE: these crates can 
    //     uint[] memory pc = pendingCrates[forced];
    //     require(pc.length > 0);
    //     for (uint i = 0; i < pc.length; i++) {
    //         uint crateBlock = pc[i];
    //         require(block.number > crateBlock);
    //         // can't open on the same timestamp
    //         var hash = block.blockhash(crateBlock);
    //         if (uint(hash) != 0) {
    //             // different results for all different crates, even on the same block/same user
    //             // randomness is already taken care of
    //             uint rand = uint(keccak256(hash, forced, i)) % (10 ** 20);
    //             _migrateRobot(uintToString(rand));
    //         }
    //         // all others are gooooooone 
    //     }
    //     CratesOpened(forced, uint8(pc.length));
    //     delete pendingCrates[forced];
    // }
    
}