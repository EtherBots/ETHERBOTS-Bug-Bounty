pragma solidity ^0.4.17;

import "./EtherbotsMigrations.sol";
import "./Battle.sol";
import "./Tournament.sol";

contract EtherbotsBattle is EtherbotsMigrations {

    // can never remove any of these contracts, can only add
    // once we publish a contract, you'll always be able to play by that ruleset
    // good for two player games which are non-susceptible to collusion
    // people can be trusted to choose the most beneficial outcome, which in this case
    // is the fairest form of gameplay.
    // fields which are vulnerable to collusion still have to be centrally controlled :(

    Tournament[] approvedTournaments;

    function addApprovedBattle(Battle _battle) external onlyOwner {
        approvedBattles.push(_battle);
    }

    function addApprovedTournament(Tournament _tournament) external onlyOwner {
        approvedTournaments.push(_tournament);
    }

    function _isApprovedTournament() internal view returns (bool) {
        for (uint8 i = 0; i < approvedTournaments.length; i++) {
            if (msg.sender == address(approvedTournaments[i])) {
                return true;
            }
        }
        return false;
    }

    function _isApprovedBattle() internal view returns (bool) {
        for (uint8 i = 0; i < approvedBattles.length; i++) {
            if (msg.sender == address(approvedBattles[i])) {
                return true;
            }
        }
        return false;
    }

    modifier onlyApprovedTournaments(){
        require(_isApprovedTournament());
        _;
    }

    modifier onlyApprovedBattles(){
        require(_isApprovedBattle());
        _;
    }

    function createBattle(uint _battleId, uint[] partIds, bytes32 commit) external payable {
        // sanity check to make sure _battleId is a valid battle
        require(_battleId >= 0);
        require(_battleId < approvedBattles.length);
        require(ownsAll(msg.sender, partIds));
        Battle battle = Battle(approvedBattles[_battleId]);
        // Transfer all to selected battle contract.
        for (uint i=0; i<partIds.length; i++) {
            _approve(partIds[i], address(battle));
        }
        battle.createBattle.value(msg.value)(msg.sender, partIds, commit);

    }

    mapping(address => Reward[]) public pendingRewards;
    // actually probably just want a length getter here as default public mapping getters
    // are pretty expensive

    struct Reward {
        uint blocknumber;
        int32 exp;
    }

    function addExperience(address _user, uint[] _partIds, int32[] _exps) external onlyApprovedBattles {
        address user = _user;
        require(_partIds.length == _exps.length);
        int32 sum = 0;
        for (uint i = 0; i < _exps.length; i++) {
            sum += _addPartExperience(_partIds[i], _exps[i]);
        }
        _addUserExperience(user, sum);
        _storeReward(user, sum);
    }

    // store sum.
    function _storeReward(address _user, int32 _battleExp) internal {
        pendingRewards[_user].push(Reward({
            blocknumber: 0,
            exp: _battleExp
        }));
    }

    /* function _getExpProportion(int _exp) returns(int) {
        // assume max/min of 1k, -1k
        return 1000 + _exp + 1; // makes it between (1, 2001)
    } */
    uint8 bestMultiple = 3;
    uint8 mediumMultiple = 2;
    uint8 worstMultiple = 1;
    uint8 minShards = 1;
    function _getExpMultiple(int _exp) internal view returns (uint8, uint8) {
        if (_exp > 500) {
            return (bestMultiple,mediumMultiple);
        } else if (_exp > 0) {
            return (mediumMultiple,mediumMultiple);
        } else {
            return (worstMultiple,mediumMultiple);
        }
    }

    function setBest(uint8 _newBestMultiple) external onlyOwner {
        bestMultiple = _newBestMultiple;
    }
    function setMedium(uint8 _newMediumMultiple) external onlyOwner {
        mediumMultiple = _newMediumMultiple;
    }
    function setWorst(uint8 _newWorstMultiple) external onlyOwner {
        worstMultiple = _newWorstMultiple;
    }
    function setMinShards(uint8 _newMin) external onlyOwner {
        minShards = _newMin;
    }

    function _calculateShards(int _exp, uint rand) internal view returns (uint16) {
        var (a, b) = _getExpMultiple(_exp);
        uint16 shards;
        if (rand % 100 > 97) {
            shards = uint16(a * ((rand % 20) + 12) / b); // max 96, avg 33
        } else if (rand % 100 > 85) {
            shards = uint16(a * ((rand % 10) + 6) / b);  // max 24, avg 16
        } else {
            shards = uint16((a * (rand % 5)) / b);          // avg 3
        }

        if (shards < minShards) {
            shards = minShards;
        }

        return shards;
    }

    // convert wins into pending battle crates
    // Not to pending old crates (migration), nor pending part crates (redeemShards)
    function convertReward() external {

        Reward[] storage rewards = pendingRewards[msg.sender];

        for (uint i = 0; i < rewards.length; i++) {
            if (rewards[i].blocknumber == 0) {
                rewards[i].blocknumber = block.number;
            }
        }

    }

    // in PerksRewards
    function redeemBattleCrates() external {
        uint8 count = 0;
        for (uint i = 0; i < pendingRewards[msg.sender].length; i++) {
            Reward memory rewardStruct = pendingRewards[msg.sender][i];
            // can't open on the same timestamp
            require(block.number > rewardStruct.blocknumber);

            var hash = block.blockhash(rewardStruct.blocknumber);

            if (uint(hash) != 0) {
                // different results for all different crates, even on the same block/same user
                // randomness is already taken care of
                uint rand = uint(keccak256(hash, msg.sender, i)) % (10 ** 20);
                _generateBattleReward(rand,rewardStruct.exp);
                count++;
            } else {
                // Do nothing, no second chances to secure integrity of randomness.
            }
        }
        CratesOpened(msg.sender, count);
        delete pendingRewards[msg.sender];
    }

    function _generateBattleReward(uint rand, int32 exp) internal {
        if ((rand % 1000) > PART_REWARD_CHANCE && exp > 0) {
            _generateRandomPart(rand, msg.sender);
        } else {
            _addShardsToUser(addressToUser[msg.sender], _calculateShards(exp, rand));
        }
    }

    // don't need to do any scaling
    // should already have been done by previous stages
    function _addUserExperience(address user, int32 exp) internal {
        // never allow exp to drop below 0
        User memory u = addressToUser[user];
        if (exp < 0 && uint32(int32(u.experience) + exp) > u.experience) {
            u.experience = 0;
            return;
        } else if (exp > 0) {
            // check for overflow
            require(uint32(int32(u.experience) + exp) > u.experience);
        }
        addressToUser[user].experience = uint32(int32(u.experience) + exp);
        //_addUserReward(user, exp);
    }

    function setMinScaled(int8 _min) external onlyOwner {
        minScaled = _min;
    }

    int8 minScaled = 25;

    function _scaleExp(uint32 _battleCount, int32 _exp) internal view returns (int32) {
        if (_battleCount <= 10) {
            return _exp; // no drop off
        }
        int32 exp =  (_exp * 10)/int32(_battleCount);

        if (exp < minScaled) {
            return minScaled;
        }
        return exp;
    }

    function _addPartExperience(uint _id, int32 _baseExp) internal returns (int32) {
        // never allow exp to drop below 0
        Part storage p = parts[_id];
        if (now - p.battlesLastReset > 24 hours) {
            p.battlesLastReset = uint32(now);
            p.battlesLastDay = 0;
        }
        p.battlesLastDay++;
        int32 exp = _baseExp;
        if (exp > 0) {
            exp = _scaleExp(p.battlesLastDay, _baseExp);
        }

        if (exp < 0 && uint32(int32(p.experience) + exp) > p.experience) {
            // check for wrap-around
            p.experience = 0;
            return;
        } else if (exp > 0) {
            // check for overflow
            require(uint32(int32(p.experience) + exp) > p.experience);
        }

        parts[_id].experience = uint32(int32(parts[_id].experience) + exp);
        return exp;
    }

    function _totalLevel(uint[] partIds) public view returns (uint32) {
        uint32 total = 0;
        for (uint i = 0; i < partIds.length; i++) {
            total += _getLevel(parts[partIds[i]].experience);
        }
        return total;
    }



    function hasPartTypes(uint[] partIds, uint8[4] types) external view returns(bool) {
        if (partIds.length != types.length) {
            return false;
        }
        for (uint i = 0; i < partIds.length; i++) {
            if (parts[partIds[i]].partType != types[i]) {
                return false;
            }
        }
        return true;
    }

}
