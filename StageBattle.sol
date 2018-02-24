pragma solidity ^0.4.17;

import "./EtherbotsBattle.sol";
import "./Battle.sol";
import "./Base.sol";
import "./AccessControl.sol";

contract TwoPlayerCommitRevealBattle is Battle, Pausable {

    EtherbotsBattle _base;

    function TwoPlayerCommitRevealBattle(EtherbotsBattle base) public {
        _base = base;
    }
    
    // Battle interface implementation.


    function name() external view returns (string) {
        return "2PCR";
    }

    function playerCount() external view returns (uint) {
        return duelingPlayers;
    }

    function battleCount() external view returns (uint) {
        return duels.length; 
    }

    function winnersOf(uint _duelId) external view returns (address[16] winnerAddresses) {
        // Duel memory _duel = duels[_duelId];
        // address[16] memory winnerAddresses;
        // winnerAddresses[0] = _duel.defenderAddress;
        // return winnerAddresses;
        uint8 max = 16;
        if (duelIdToAttackers[_duelId].length < max) {
            max = uint8(duelIdToAttackers[_duelId].length);
        }
        for (uint8 i = 0; i < max; i++) {
            if (duelIdToAttackers[_duelId][i].isWinner) {
                winnerAddresses[i]= duelIdToAttackers[_duelId][i].owner;
            } else {
                winnerAddresses[i] = duels[_duelId].defenderAddress;
            }
        }
    }

    function winnerOf(uint battleId, uint index) external view returns (address) {
        Attacker memory a = duelIdToAttackers[battleId][index];
        Duel memory d = duels[battleId];
        return a.isWinner ? a.owner : d.defenderAddress;
    }

    function loserOf(uint battleId, uint index) external view returns (address) {
        Attacker memory a = duelIdToAttackers[battleId][index];
        Duel memory d = duels[battleId];
        return a.isWinner ? d.defenderAddress : a.owner;
    }

    enum DuelStatus {
        Open, Exhausted, Completed, Cancelled
    }
    // mapping (uint => address) public battleIdToWinnerAddress;
    // TODO: packing?
    struct Duel {
        uint feeRemaining;
        uint[] defenderParts;
        bytes32 defenderCommit;
        uint64 maxAcceptTime;
        address defenderAddress;
        // Attacker[] attackers;
        DuelStatus status;
    }

    struct Attacker {
        address owner;
        uint[] parts;
        uint8[] moves;
        bool isWinner;
    }
    mapping (uint => Attacker[]) public duelIdToAttackers;
    // ID maps to index in battles array.
    // TODO: do we need this?
    // TODO: don't think we ever update it
    // if we want to find all the duels for a user, just use external view
    // mapping (address => uint[]) public addressToDuels;
    Duel[] public duels;
    uint public duelingPlayers;

    function getAttackersMoveFromDuelIdAndIndex(uint index, uint i, uint8 move) external view returns (uint8) {
        return duelIdToAttackers[index][i].moves[move];
    }
    
    function getAttackersPartsFromDuelIdAndIndex(uint index, uint i) external view returns (uint, uint, uint, uint) {
        return (duelIdToAttackers[index][i].parts[0],duelIdToAttackers[index][i].parts[1],duelIdToAttackers[index][i].parts[2],duelIdToAttackers[index][i].parts[3]);
    }

    function getAttackersLengthFromDuelId(uint index) external view returns (uint) {
        return duelIdToAttackers[index].length;
    }

    function getDefendersPartsFromDuelId(uint index) external view returns (uint, uint, uint, uint) {
        return (duels[index].defenderParts[0],duels[index].defenderParts[1],duels[index].defenderParts[2],duels[index].defenderParts[3]);
    }

    function getDuelFromId(uint index) external view returns (uint, uint, uint, uint, uint, bytes32, uint64, address, DuelStatus) {
        Duel memory _duel = duels[index];
        return (_duel.feeRemaining, _duel.defenderParts[0],_duel.defenderParts[1],_duel.defenderParts[2],_duel.defenderParts[3], _duel.defenderCommit, _duel.maxAcceptTime, _duel.defenderAddress, _duel.status);
    }

    /*
    =========================
     OWNER CONTROLLED FIELDS
    =========================
    */

    uint8 public maxAttackers = 5;

    function setMaxAttackers(uint8 _max) external onlyOwner {
        BattlePropertyChanged("Defender Fee", uint(maxAttackers), uint(_max));
        maxAttackers = _max;
    }

    // centrally controlled fields
    // CONSIDER: can users ever change these (e.g. different time per battle)
    // CONSIDER: how do we incentivize users to fight 'harder' bots
    uint public maxRevealTime;
    uint public attackerFee;
    uint public defenderFee;
    uint public attackerRefund;
    uint public defenderRefund;

    function setDefenderFee(uint _fee) external onlyOwner {
        BattlePropertyChanged("Defender Fee", defenderFee, _fee);
        defenderFee = _fee;
    }

    function setAttackerFee(uint _fee) external onlyOwner {
        BattlePropertyChanged("Attacker Fee", attackerFee, _fee);
        attackerFee = _fee;
    }

    function setAttackerRefund(uint _refund) external onlyOwner {
        BattlePropertyChanged("Attacker Refund", attackerRefund, _refund);
        attackerRefund = _refund;
    }

    function setDefenderRefund(uint _refund) external onlyOwner {
        BattlePropertyChanged("Defender Refund", defenderRefund, _refund);
        defenderRefund = _refund;
    }
    



    function _makePart(uint _id) internal view returns(EtherbotsBase.Part) {
        var (id, pt, pst, rarity, element, bld, exp, forgeTime, blr) = _base.getPartById(_id);
        return EtherbotsBase.Part({
            tokenId: id,
            partType: pt,
            partSubType: pst,
            rarity: rarity,
            element: element,
            battlesLastDay: bld,
            experience: exp,
            forgeTime: forgeTime,
            battlesLastReset: blr
        });
    }

    /*
    =========================
    EXTERNAL BATTLE FUNCTIONS
    =========================
    */

    // commit should be in the form of:
    // uint[8]|random string

    function createBattle(address _defender, uint[] partIds, bytes32 _movesCommit) external payable whenNotPaused {
        require(msg.sender == address(_base));

        // will fail if the base doesn't own all of the parts
        for (uint i=0; i<partIds.length; i++) {
            _base.takeOwnership(partIds[i]);
        }
        _defenderCommitMoves(_defender, partIds, _movesCommit);
    }

    function _defenderCommitMoves(address _defender, uint[] partIds, bytes32 _movesCommit) internal {
        require(_movesCommit != "");

        require(msg.value >= defenderFee);

        // check parts //defence1 melee2 body3 turret4
        uint8[4] memory types = [1, 2, 3, 4];
        require(_base.hasPartTypes(partIds, types));

        // is this the way of balancing the benefit of attacking?
        // should we have a max number of people who can attack one defender if we're going down this route?
        
        Duel memory _duel = Duel({
            defenderAddress: _defender,
            defenderParts: partIds,
            defenderCommit: _movesCommit,
            maxAcceptTime: uint64(now + maxRevealTime),
            status: DuelStatus.Open,
            // attackers: new Attacker[](0),
            feeRemaining: msg.value
        });
        // TODO: -1 here?
        uint256 newDuelId = duels.push(_duel) - 1;
        // duelIdToAttackers[newDuelId] = new Attacker[](16);
        duelingPlayers++; // doesn't matter if we overcount
        // addressToDuels[msg.sender].push(newDuelId);
        BattleCreated(newDuelId, _defender);
    }

    function attack(uint _duelId, uint[] parts, uint8[] _moves) external payable returns(bool) {

        // check that it's your robot
        require(_base.ownsAll(msg.sender, parts));

        // check that the moves are readable
        require(_isValidMoves(_moves));

        Duel storage duel = duels[_duelId];
        // the duel must be open
        require(duel.status == DuelStatus.Open);
        require(duelIdToAttackers[_duelId].length < maxAttackers);
        require(msg.value >= attackerFee);

        // checks part independence and timing
        require(_canAttack(_duelId, parts));

        if (duel.feeRemaining < defenderFee) {
            // just do a return - no need to punish the attacker
            // mark as exhaused
            duel.status = DuelStatus.Exhausted;
            return false;
        }

        duel.feeRemaining -= defenderFee;

        // already guaranteed
        Attacker memory _a = Attacker({
            owner: msg.sender,
            parts: parts,
            moves: _moves,
            isWinner: false
        });

        // duelIdToAttackers[_duelId].push(_a);
        duelIdToAttackers[_duelId].push(_a);
        // increment those battling - @rename
        duelingPlayers++;
        return true;
    }

    function _canAttack(uint _duelId, uint[] parts ) internal view returns(bool) {
        // short circuit if trying to attack yourself
        // obviously can easily get around this, but may as well check
        if (duels[_duelId].defenderAddress == msg.sender) {
            return false;
        }
        // the same part cannot attack the same bot at the same time
        for (uint i = 0; i < duelIdToAttackers[_duelId].length; i++) {
            for (uint j = 0; j < duelIdToAttackers[_duelId][i].parts.length; j++) {
                if (duelIdToAttackers[_duelId][i].parts[j] == parts[j]) {
                    return false;
                }
            }
        }
        return true;
    }

    uint8 constant MOVE_LENGTH = 8;

    function _isValidMoves(uint8[] _moves) internal pure returns(bool) {
        if (_moves.length != MOVE_LENGTH) {
            return false;
        }
        for (uint i = 0; i < MOVE_LENGTH; i++) {
            if (_moves[i] >= MOVE_TYPE_COUNT) {
                return false;
            }
        }
        return true;
    }

    event PrintMsg(string, address, address);

    function defenderRevealMoves(uint _duelId, uint8[] _moves, bytes32 _seed) external returns(bool) {
        require(duelIdToAttackers[_duelId].length != 0);

        Duel memory _duel = duels[_duelId];

        PrintMsg("reveal with defender", _duel.defenderAddress, msg.sender);

        require(_duel.defenderAddress == msg.sender);

        // require(bytes(_moves).length == 8);
        require(_duel.defenderCommit == keccak256(_moves, _seed));
        // if (_duel.defenderCommit != keccak256(_moves, _seed)) {
            // InvalidAction("Moves did not match move commit");
            // return false;
        // }
        // after the defender has revealed their moves, perform all the duels
        EtherbotsBase.Part[4] memory defenderParts = [
            _makePart(_duel.defenderParts[0]),
            _makePart(_duel.defenderParts[1]),
            _makePart(_duel.defenderParts[2]),
            _makePart(_duel.defenderParts[3])
        ];
        for (uint i = 0; i < duelIdToAttackers[_duelId].length; i++) {
            Attacker storage tempA = duelIdToAttackers[_duelId][i];
            _executeMoves(_duelId, tempA, defenderParts, _moves);
        }
        duelingPlayers -= (duelIdToAttackers[_duelId].length + 1);
        // give back an extra fees
        _refundDuelFee(_duel);
        // _refundDefenderFee(duelIdToAttackers[_duelId].length);
        // send back ownership of parts
        _base.transferAll(_duel.defenderAddress, _duel.defenderParts);
        duels[_duelId].status = DuelStatus.Completed;

        return true;
    }

    // should only be used where the defender has forgotten their moves
    // forfeits every battle
    function cancelBattle(uint _duelId) external {

        Duel memory _duel = duels[_duelId];
        require(_duel.status == DuelStatus.Open || _duel.status == DuelStatus.Exhausted);

        // can only be called by the defender
        require(msg.sender == _duel.defenderAddress);

        for (uint i = 0; i < duelIdToAttackers[_duelId].length; i++) {
            Attacker memory tempA = duelIdToAttackers[_duelId][i];
            duelIdToAttackers[_duelId][i].isWinner = true;
            _forfeitBattle(tempA.owner, tempA.moves, tempA.parts, _duel.defenderParts);
        }
        // no gas refund for cancelling
        // encourage people to battle rather than cancel
        _refundDuelFee(_duel);
        _base.transferAll(_duel.defenderAddress, _duel.defenderParts);
        duels[_duelId].status = DuelStatus.Cancelled;
    }

    // after the time limit has elapsed, anyone can claim victory for all the attackers
    // have to pay gas cost for all
    // todo: how much will this cost for 256 attackers?
    function claimTimeVictory(uint _duelId) external {
        Duel storage _duel = duels[_duelId];
        // let anyone claim it to stop boring iteration
        // @fixme CHANGED FROM MAX REVEAL TIME (doesn't exist) TO 
        // MAX ACCPEPT TIME + 1 DAY.
        require(now > (_duel.maxAcceptTime + 1 days));
        for (uint i = 0; i < duelIdToAttackers[_duelId].length; i++) {
            Attacker memory tempA = duelIdToAttackers[_duelId][i];
  
            duelIdToAttackers[_duelId][i].isWinner = true;            
            _forfeitBattle(tempA.owner, tempA.moves, tempA.parts, _duel.defenderParts);
        }
        _refundAttacker(duelIdToAttackers[_duelId].length);
        // refund the defender
        _refundDuelFee(_duel);
        _base.transferAll(_duel.defenderAddress, _duel.defenderParts);
        _duel.status = DuelStatus.Completed;
    }

    // compensation for gas costs
    // paid out of the battle fees
    function _refundDefender(uint _count) internal {
        uint refund = (_count * defenderFee);
        if (refund > 0) {
            msg.sender.transfer(refund);
        }
    }

    function _refundAttacker(uint _count) internal {
        // they have paid for everyone else to win
        // could be quite expensive
        uint refund = (_count * attackerFee);
        if (refund > 0) {
            msg.sender.transfer(refund);
        }
    }

    function _refundDuelFee(Duel _duel) internal {
        if (_duel.feeRemaining > 0) {
            uint a = _duel.feeRemaining;
            _duel.feeRemaining = 0;
            _duel.defenderAddress.transfer(a);
        }
    }

    uint16 constant EXP_BASE = 100;
    uint16 constant WINNER_EXP = 3;
    uint16 constant LOSER_EXP = 1;

    uint8 constant BONUS_PERCENT = 5;
    uint8 constant ALL_BONUS = 5;

    // Parts reminder: Blueprint represents details of the part:
    // [2] part level (experience),
    // [3] rarity status, (representing, i.e., "gold")
    // [4] elemental type, (i.e., "water")

    function getPartBonus(uint movingPart, EtherbotsBase.Part[4] parts) internal view returns (uint8) {
        uint8 typ = _makePart(movingPart).rarity;
        // apply bonuses
        uint8 matching = 0;
        for (uint8 i = 0; i < parts.length; i++) {
            if (parts[i].rarity == typ) {
                matching++;
            }
        }
        // matching will never be less than 1
        uint8 bonus = (matching - 1) * BONUS_PERCENT;
        return bonus;
    }

    uint8 constant PERK_BONUS = 5;
    uint8 constant PRESTIGE_INC = 1;
    // level 0
    uint8 constant PT_PRESTIGE_INDEX = 0;
    // level 1
    uint8 constant PT_OFFENSIVE = 1;
    uint8 constant PT_DEFENSIVE = 2;
    // level 2
    uint8 constant PT_MELEE = 3;
    uint8 constant PT_TURRET = 4;
    uint8 constant PT_DEFEND = 5;
    uint8 constant PT_BODY = 6;
    // level 3
    uint8 constant PT_MELEE_MECH = 7;
    uint8 constant PT_MELEE_ANDROID = 8;
    uint8 constant PT_TURRET_MECH = 9;
    uint8 constant PT_TURRET_ANDROID = 10;
    uint8 constant PT_DEFEND_MECH = 11;
    uint8 constant PT_DEFEND_ANDROID = 12;
    uint8 constant PT_BODY_MECH = 13;
    uint8 constant PT_BODY_ANDROID = 14;
    // level 4
    uint8 constant PT_MELEE_ELECTRIC = 15;
    uint8 constant PT_MELEE_STEEL = 16;
    uint8 constant PT_MELEE_FIRE = 17;
    uint8 constant PT_MELEE_WATER = 18;
    uint8 constant PT_TURRET_ELECTRIC = 19;
    uint8 constant PT_TURRET_STEEL = 20;
    uint8 constant PT_TURRET_FIRE = 21;
    uint8 constant PT_TURRET_WATER = 22;
    uint8 constant PT_DEFEND_ELECTRIC = 23;
    uint8 constant PT_DEFEND_STEEL = 24;
    uint8 constant PT_DEFEND_FIRE = 25;
    uint8 constant PT_DEFEND_WATER = 26;
    uint8 constant PT_BODY_ELECTRIC = 27;
    uint8 constant PT_BODY_STEEL = 28;
    uint8 constant PT_BODY_FIRE = 29;
    uint8 constant PT_BODY_WATER = 30;

    uint8 constant DODGE = 0;
    uint8 constant DEFEND = 1;
    uint8 constant MELEE = 2;
    uint8 constant TURRET = 3;

    uint8 constant FIRE = 0;
    uint8 constant WATER = 1;
    uint8 constant STEEL = 2;
    uint8 constant ELECTRIC = 3;

    // TODO: might be a more efficient way of doing this
    // read: almost definitely is
    // would destroy legibility tho?
    // will get back to it --> pretty gross rn
    function _applyBonusTree(uint8 move, EtherbotsBase.Part[4] parts, uint8[32] tree) internal pure returns (uint8 bonus) {
        uint8 prestige = tree[PT_PRESTIGE_INDEX];
        if (move == DEFEND || move == DODGE) {
            if (hasPerk(tree, PT_DEFENSIVE)) {
                bonus = _applyPerkBonus(bonus, prestige);
                if (move == DEFEND && hasPerk(tree, PT_DEFEND)) {
                    bonus = _applyPerkBonus(bonus, prestige);
                    if (hasPerk(tree, PT_DEFEND_MECH)) {
                        bonus = _applyPerkBonus(bonus, prestige);
                        if (getMoveType(parts, move) == ELECTRIC && hasPerk(tree, PT_DEFEND_ELECTRIC)) {
                            bonus = _applyPerkBonus(bonus, prestige);
                        } else if (getMoveType(parts, move) == STEEL && hasPerk(tree, PT_DEFEND_STEEL)) {
                            bonus = _applyPerkBonus(bonus, prestige);
                        }
                    } else if (hasPerk(tree, PT_DEFEND_ANDROID)) {
                        bonus = _applyPerkBonus(bonus, prestige);
                        if (getMoveType(parts, move) == FIRE && hasPerk(tree, PT_DEFEND_FIRE)) {
                            bonus = _applyPerkBonus(bonus, prestige);
                        } else if (getMoveType(parts, move) == WATER && hasPerk(tree, PT_DEFEND_WATER)) {
                            bonus = _applyPerkBonus(bonus, prestige);
                        }
                    }
                } else if (move == DODGE && hasPerk(tree, PT_BODY)) {
                    bonus = _applyPerkBonus(bonus, prestige);
                    bonus = _applyPerkBonus(bonus, prestige);
                    if (hasPerk(tree, PT_BODY_MECH)) {
                        bonus = _applyPerkBonus(bonus, prestige);
                        if (getMoveType(parts, move) == ELECTRIC && hasPerk(tree, PT_BODY_ELECTRIC)) {
                            bonus = _applyPerkBonus(bonus, prestige);
                        } else if (getMoveType(parts, move) == STEEL && hasPerk(tree, PT_BODY_STEEL)) {
                            bonus = _applyPerkBonus(bonus, prestige);
                        }
                    } else if (hasPerk(tree, PT_BODY_ANDROID)) {
                        bonus = _applyPerkBonus(bonus, prestige);
                        if (getMoveType(parts, move) == FIRE && hasPerk(tree, PT_BODY_FIRE)) {
                            bonus = _applyPerkBonus(bonus, prestige);
                        } else if (getMoveType(parts, move) == WATER && hasPerk(tree, PT_BODY_WATER)) {
                            bonus = _applyPerkBonus(bonus, prestige);
                        }
                    }
                }
            }
        } else {
            if (hasPerk(tree, PT_OFFENSIVE)) {
                bonus = _applyPerkBonus(bonus, prestige);
                if (move == MELEE && hasPerk(tree, PT_MELEE)) {
                    bonus = _applyPerkBonus(bonus, prestige);
                    if (hasPerk(tree, PT_MELEE_MECH)) {
                        bonus = _applyPerkBonus(bonus, prestige);
                        if (getMoveType(parts, move) == ELECTRIC && hasPerk(tree, PT_MELEE_ELECTRIC)) {
                            bonus = _applyPerkBonus(bonus, prestige);
                        } else if (getMoveType(parts, move) == STEEL && hasPerk(tree, PT_MELEE_STEEL)) {
                            bonus = _applyPerkBonus(bonus, prestige);
                        }
                    } else if (hasPerk(tree, PT_MELEE_ANDROID)) {
                        bonus = _applyPerkBonus(bonus, prestige);
                        if (getMoveType(parts, move) == FIRE && hasPerk(tree, PT_MELEE_FIRE)) {
                            bonus = _applyPerkBonus(bonus, prestige);
                        } else if (getMoveType(parts, move) == WATER && hasPerk(tree, PT_MELEE_WATER)) {
                            bonus = _applyPerkBonus(bonus, prestige);
                        }
                    }
                } else if (move == TURRET && hasPerk(tree, PT_TURRET)) {
                    bonus = _applyPerkBonus(bonus, prestige);
                    bonus = _applyPerkBonus(bonus, prestige);
                    if (hasPerk(tree, PT_TURRET_MECH)) {
                        bonus = _applyPerkBonus(bonus, prestige);
                        if (getMoveType(parts, move) == ELECTRIC && hasPerk(tree, PT_TURRET_ELECTRIC)) {
                            bonus = _applyPerkBonus(bonus, prestige);
                        } else if (getMoveType(parts, move) == STEEL && hasPerk(tree, PT_TURRET_STEEL)) {
                            bonus = _applyPerkBonus(bonus, prestige);
                        }
                    } else if (hasPerk(tree, PT_TURRET_ANDROID)) {
                        bonus = _applyPerkBonus(bonus, prestige);
                        if (getMoveType(parts, move) == FIRE && hasPerk(tree, PT_TURRET_FIRE)) {
                            bonus = _applyPerkBonus(bonus, prestige);
                        } else if (getMoveType(parts, move) == WATER && hasPerk(tree, PT_TURRET_WATER)) {
                            bonus = _applyPerkBonus(bonus, prestige);
                        }
                    }
                }
            }
        }
    }

    function getMoveType(EtherbotsBase.Part[4] parts, uint8 _move) internal pure returns(uint8) {
        return parts[_move].element;
    }

    function hasPerk(uint8[32] tree, uint8 perk) internal pure returns(bool) {
        return tree[perk] > 0;
    }

    uint8 constant PRESTIGE_BONUS = 1;

    function _applyPerkBonus(uint8 bonus, uint8 prestige) internal pure returns (uint8) {
        return bonus + (PERK_BONUS + (prestige * PRESTIGE_BONUS));
    }

   function getPerkBonus(uint8 move, EtherbotsBase.Part[4] parts) internal view returns (uint8) {
       var (, perks) = _base.getUserByAddress(msg.sender);
       return _applyBonusTree(move, parts, perks);
   }

   uint constant EXP_BONUS = 1;
   uint constant EVERY_X_LEVELS = 2;

   function getExpBonus(EtherbotsBase.Part[4] parts) internal view returns (uint8) {

       uint[] memory partIds = new uint[](4);
       partIds[0] = parts[0].tokenId;
       partIds[1] = parts[1].tokenId;
       partIds[2] = parts[2].tokenId;
       partIds[3] = parts[3].tokenId;
       

    //    [uint(,uint(parts[1].tokenId),
    //    uint(parts[2].tokenId),uint(parts[3].tokenId)];
       return uint8((_base._totalLevel(partIds) * EXP_BONUS) / EVERY_X_LEVELS);
   }

   uint8 constant SHADOW_BONUS = 5;
   uint8 constant GOLD_BONUS = 10;

    // allow for more rarities
    // might never implement: undroppable rarities
    // 5 gold parts can be forged into a diamond
    // assumes rarity as follows: standard = 0, shadow = 1, gold = 2
    // shadow gives base 5% boost, gold 10% ...
   function getRarityBonus(uint8 move, EtherbotsBase.Part[4] parts) internal pure returns (uint8) {
        // bonus applies per part (but only if you're using the rare part in this move)
        uint8 rarity = parts[move].rarity;
        uint8 count = 0;
        if (rarity == 0) {
            // standard rarity, no bonus
            return 0;
        }
        for (uint8 i = 0; i < parts.length; i++) {
            if (parts[i].rarity == rarity) {
                count++;
            }
        }
        uint8 bonus = count * BONUS_PERCENT;
        return bonus;
   }

   function _applyBonuses(uint8 move, EtherbotsBase.Part[4] parts, uint16 _dmg) internal view returns(uint16) {
       // perks only land if you won the move
       uint16 _bonus = getPerkBonus(move, parts);
       _bonus += getPartBonus(move, parts);
       _bonus += getExpBonus(parts);
       _bonus += getRarityBonus(move, parts);
       _dmg += (_dmg * _bonus) / 100;
       return _dmg;
   }
    
   // what about collusion - can try to time the block?
   // obviously if colluding could just pick exploitable moves
   // this is random enough for two non-colluding parties
   function randomSeed(uint8[] defenderMoves, uint8[] attackerMoves, uint8 rand) internal pure returns (uint) {
        return uint(keccak256(defenderMoves, attackerMoves, rand));
        // return random;
   }
    event attackerdamage(uint16 dam);
    event defenderdamage(uint16 dam);
       
   function _executeMoves(uint _duelId, Attacker storage attacker, EtherbotsBase.Part[4] defenderParts, uint8[] _defenderMoves) internal {
       // @fixme change usage of seed to make sure it's okay.
    //    uint seed = randomSeed(_defenderMoves, attacker.moves);
       uint16 totalAttackerDamage = 0;
       uint16 totalDefenderDamage = 0;

       EtherbotsBase.Part[4] memory attackerParts = [
            _makePart(attacker.parts[0]),
            _makePart(attacker.parts[1]),
            _makePart(attacker.parts[2]),
            _makePart(attacker.parts[3])
       ];

        uint16 attackerDamage;
        uint16 defenderDamage;
       // works just the same for draws
        for (uint8 i = 0; i < MOVE_LENGTH; i++) {
           // TODO: check move for validity?
            // var attackerMove = attacker.moves[i];
            // var defenderMove = _defenderMoves[i];
            (attackerDamage, defenderDamage) = _calculateBaseDamage(attacker.moves[i], _defenderMoves[i]);

            attackerDamage = _applyBonuses(attacker.moves[i], attackerParts, attackerDamage);
            defenderDamage = _applyBonuses(_defenderMoves[i], defenderParts, defenderDamage);
            attackerdamage(attackerDamage);
            defenderdamage(defenderDamage);
            attackerDamage = _applyRandomness(randomSeed(_defenderMoves, attacker.moves, i + 8), attackerDamage);
            defenderDamage = _applyRandomness(randomSeed(_defenderMoves, attacker.moves, i), defenderDamage);

            totalAttackerDamage += attackerDamage;
            totalDefenderDamage += defenderDamage;
            attackerdamage(attackerDamage);
            defenderdamage(defenderDamage);
            BattleStage(_duelId, i, [ attacker.moves[i], _defenderMoves[i] ], [attackerDamage, defenderDamage] );
            // BattleStage(_duelId, i, movesInMemory, damageInMemory );

        }

        if (totalAttackerDamage > totalDefenderDamage) {
            attacker.isWinner = true;
            // _winBattle(attacker.owner, duels[_duelId].defenderAddress, attacker.moves,
            //     _defenderMoves, attacker.parts, duels[_duelId].defenderParts);
        }
            _winBattle(duels[_duelId].defenderAddress, attacker.owner, _defenderMoves, 
            attacker.moves,duels[_duelId].defenderParts,attacker.parts, attacker.isWinner);
    }

    
   uint constant RANGE = 40;

   function _applyRandomness(uint rand, uint16 _dmg) internal pure returns (uint16) {
       // damage can be modified between 1 - (RANGE/2) and 1 + (RANGE/2)
       // keep things interesting!
       int16 damageNoise = 0;
       rand = rand % RANGE;
       if (rand > (RANGE / 2)) {
           damageNoise = int16(rand/2);
           // rand is 21 or above
       } else {
           // rand is 20 or below
           // this way makes 0 better than 20 --> who cares
           damageNoise = int16(-rand);
       }
       int16 toChange = int16(_dmg) * damageNoise/100;
       return uint16(int16(_dmg) + toChange);
   }

   // every move
   uint16 constant BASE_DAMAGE = 1000;
   uint8 constant WINNER_SPLIT = 3;
   uint8 constant LOSER_SPLIT = 1;

   function _calculateBaseDamage(uint8 a, uint8 d) internal pure returns(uint16, uint16) {
       if (a == d) {
           // even split
           return (BASE_DAMAGE / 2, BASE_DAMAGE / 2);
       }
       if (defeats(a, d)) {
           // 3 - 1 split
           return ((BASE_DAMAGE / (WINNER_SPLIT + LOSER_SPLIT)) * WINNER_SPLIT,
               (BASE_DAMAGE / (WINNER_SPLIT + LOSER_SPLIT)) * LOSER_SPLIT);
       } else if (defeats(d, a)) {
           // 3 - 1 split
           return ((BASE_DAMAGE / (WINNER_SPLIT + LOSER_SPLIT)) * LOSER_SPLIT,
               (BASE_DAMAGE / (WINNER_SPLIT + LOSER_SPLIT)) * WINNER_SPLIT);
       } else {
           return (BASE_DAMAGE / 2, BASE_DAMAGE / 2);
       }
   }
   // defence > attack
   // attack > body
   // body > turret
   // turret > defence

   /* move after it beats it
   uint8 constant DEFEND = 0;
   uint8 constant ATTACK = 1;
   uint8 constant BODY = 2;
   uint8 constant TURRET = 3;
   */

   uint8 constant MOVE_TYPE_COUNT = 4;

   // defence > attack
   // attack > body
   // body > turret
   // turret > defence

   // don't hardcode this
   function defeats(uint8 a, uint8 b) internal pure returns(bool) {
       return (a + 1) % MOVE_TYPE_COUNT == b;
   }

   // Experience-related functions/fields

   function _winBattle(address attackerAddress, address defenderAddress, 
   uint8[] attackerMoves, uint8[] defenderMoves, uint[] attackerPartIds, uint[] defenderPartIds, bool isAttackerWinner
   ) internal 
   {    
       if (isAttackerWinner) {
        var (winnerExpBase, loserExpBase) = _calculateExpSplit(attackerPartIds, defenderPartIds);
        _allocateExperience(attackerAddress, attackerMoves, winnerExpBase, attackerPartIds);
        _allocateExperience(defenderAddress, defenderMoves, loserExpBase, defenderPartIds);
       } else {
        (winnerExpBase, loserExpBase) = _calculateExpSplit(defenderPartIds, attackerPartIds);   
        _allocateExperience(defenderAddress, defenderMoves, winnerExpBase, defenderPartIds);
        _allocateExperience(attackerAddress, attackerMoves, loserExpBase, attackerPartIds);
       }

        
    }

    function _forfeitBattle( address winnerAddress,
        uint8[] winnerMoves, uint[] winnerPartIds, uint[] loserPartIds
   ) internal 
   {
        var (winnerExpBase, ) = _calculateExpSplit(winnerPartIds, loserPartIds);
        
        _allocateExperience(winnerAddress, winnerMoves, winnerExpBase, winnerPartIds);
    }

    uint16 constant BASE_EXP = 1000;
    uint16 constant EXP_MIN = 100;
    uint16 constant EXP_MAX = 1000;

    // this is a very important function in preventing collusion
    // works as a sort-of bell curve distribution
    // e.g. big bot attacks and defeats small bot (75exp, 25exp) = 100 total
    // e.g. big bot attacks and defeats big bot (750exp, 250exp) = 1000 total
    // e.g. small bot attacks and defeats big bot (1000exp, -900exp) = 100 total
    // huge incentive to play in the middle of the curve
    // makes collusion only slightly profitable (maybe -EV considering battle fees)

    function _calculateExpSplit(uint[] winnerParts,uint[] loserParts ) internal view returns (int32, int32) {
        uint32 totalWinnerLevel = _base._totalLevel(winnerParts) + 1;
        uint32 totalLoserLevel = _base._totalLevel(loserParts) + 1; // if no experience, don't divide by zero @@@@@@@@_@@@@@@@@
        // TODO: do we care about gold parts/combos etc
        // gold parts will naturally tend to higher levels anyway
        int32 total = _calculateTotalExperience(totalWinnerLevel, totalLoserLevel);
        return _calculateSplits(total, totalWinnerLevel, totalLoserLevel);
    }

    int32 constant WMAX = 1000;
    int32 constant WMIN = 75;
    int32 constant LMAX = 250;
    int32 constant LMIN = -900;

    uint8 constant WS = 3;
    uint8 constant LS = 1;
    function _calculateSplits(int32 total, uint32 wl, uint32 ll) internal pure returns (int32, int32) {
        
        int32 winnerSplit = max(WMIN, min(WMAX, ((total * WS) * (int32(ll) / int32(wl))) / (WS + LS)));
        int32 loserSplit = total - winnerSplit;
  
        return (winnerSplit, loserSplit);
    }

    int32 constant BMAX = 1000;
    int32 constant BMIN = 100;
    int32 constant RATIO = BMAX / BMIN;

    // total exp generated follows a weird curve
    // 100 plays 1, wins: 75/25      -> 100
    // 50 plays 50, wins: 750/250    -> 1000
    // 1 plays 1, wins: 750/250      -> 1000
    // 1 plays 100, wins: 1000, -900 -> 100
    function _calculateTotalExperience(uint32 wl, uint32 ll)  internal pure returns (int32) {
        int32 diff = (int32(wl) - int32(ll));
        return max(BMIN, BMAX - max(-RATIO * diff, RATIO * diff));
    }

    function max(int32 a, int32 b) pure internal returns (int32) {
        if (a > b) {
            return a;
        }
        return b;
    }

    function min(int32 a, int32 b) pure internal returns (int32) {
        if (a > b) {
            return b;
        }
        return a;
    }
    // allocates experience based on how many times a part was used in battle
    function _allocateExperience(address playerAddress, uint8[] moves, int32 exp, uint[] partIds) internal {
    
        int32[] memory exps = new int32[](partIds.length);
        int32 sum = 0;
        int32 each = exp / MOVE_LENGTH;
        for (uint i = 0; i < MOVE_LENGTH; i++) {
            exps[moves[i]] += each;
            sum += each;
        }
        _base.addExperience(playerAddress, partIds, exps);
    }


}
