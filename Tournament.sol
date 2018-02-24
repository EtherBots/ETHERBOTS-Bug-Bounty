pragma solidity ^0.4.17;

import "./Battle.sol";

contract Tournament {

    function name() external view returns(string); 
    function playerCount(uint id) external view returns(uint);
    function playerAt(uint id, uint index) external view returns (address);

    event TournamentOpen(uint id, address creator, uint16 players);
    event TournamentBracket(uint id, address creator, address[] bracket);
    event TournamentMatch(uint id, uint battleId, address winner);
    event TournamentResult(uint id, address[] results);
}

// bracket, battles
// [a, b, c, d, 0, 0, 0]
// [0, 0, 0]
// [a, b, c, d, a, c, 0]
// [1, 2, 0]
// [a, b, c, d, a, c, a]
// [1, 2, 3]
contract SingleEliminationTournament is Tournament {

    function name() external view returns(string) {
        return "Single Elim";
    }

    function playerCount(uint /*id*/) external view returns(uint) {
        return tournaments.length;
    }

    function playerAt(uint id, uint index) external view returns (address) {
        return tournaments[id].bracket[index];
    }

    TournamentBattle[] tournaments;

    struct TournamentBattle {
        Battle battle;
        uint8 requiredParticipants;
        uint entryFee;
        address[] participants;
        address[] bracket;
        uint[] battleIds;
        uint64 bracketCreationBlock;
    }

    function SingleEliminationTournament() public {

    }

    // Tournaments should be inherently deflationary
    // can have up to 256 participants
    function createTournament(Battle _battle, uint8 _count, uint _fee) external {
        tournaments.push(TournamentBattle({
            entryFee: _fee,
            requiredParticipants: _count,
            bracket: new address[](_count),
            participants: new address[](_count),
            battleIds: new uint[](_count / 2),
            battle: _battle,
            bracketCreationBlock: 0
        }));
    }

    // must be called once
    // need to stop this being manipulated by one player
    // should resist collusion s.t. if one player is not co-operating
    // it is infeasible to create predictably stacked tournaments
    function createBracket(uint256 _tournamentId) external {
        TournamentBattle storage tournament = tournaments[_tournamentId];
        // tournament must be full
        require(tournament.participants.length == tournament.requiredParticipants);
        require(tournament.bracketCreationBlock == 0);
        tournament.bracketCreationBlock = uint64(block.number);

    }

    // call to reveal the bracket
    // can be called by anyone
    function revealBracket(uint256 _tournamentId) external {
        TournamentBattle storage tournament = tournaments[_tournamentId];
        // tournament must be full
        require(tournament.participants.length == tournament.requiredParticipants);
        require(tournament.bracketCreationBlock != 0);
        require(tournament.bracketCreationBlock < now);
        // if the bracket was created more than 256 blocks ago
        // just reset the process
        // don't have to worry about gaming when any player can call it 
        if (tournament.bracketCreationBlock + 255 < now) {
            tournament.bracketCreationBlock = 0;
            return;
        }
        bytes32 rand = block.blockhash(tournament.bracketCreationBlock + 1);
        // pick someone at random
        tournament.bracket = _shuffle(tournament.participants, rand);

        TournamentBracket(_tournamentId, msg.sender, tournament.bracket);
    }

    function winnerOf(uint _tId) external view returns (address) {
        TournamentBattle memory tournament = tournaments[_tId];
        return tournament.bracket[tournament.bracket.length-1];
    }

    function _shuffle(address[] participants, bytes32 rand) pure internal returns (address[]) {
        address[] memory shuffled = new address[](participants.length);
        for (uint i = 0; i < participants.length; i++) {
            uint pos = uint(keccak256(rand, participants[i], i)) % participants.length;
            // will always find an open spot eventually
            for (uint j = pos; j < participants.length;) {
                if (shuffled[j] != address(0)) {
                    shuffled[j] = participants[i];
                    break;
                }
                // wrap around
                j = j < participants.length - 1 ? (j + 1) : 0;
            }
        }
    }

    function joinTournament(uint256 _tId) external payable {
        TournamentBattle storage tournament = tournaments[_tId];
        require(msg.value >= tournament.entryFee);
        // give refunds if over-spent
        if (msg.value > tournament.entryFee) {
            msg.sender.transfer(msg.value-tournament.entryFee);
        }
        // can't join a full tournament
        require(tournament.participants.length < tournament.requiredParticipants);
        // can't join a tournament twice
        for (uint i = 0; i < tournament.participants.length; i++) {
            address p = tournament.participants[i];
            require(msg.sender != p);
        }
        tournament.participants.push(msg.sender);
    }

    // defender must call create battle 
    // [a, b, c, d, e, f, g, h, a, c, e, g, a, e, a]
    // [0, 0, 0, 0, 0, 0, 0]
    // 0 --> 0
    // 2 --> 1
    // 4 --> 2
    // 6 --> 3
    // 8 --> 4
    // 10 --> 5
    // etc

    // when you win
    // [a, b, c, d, e, f, g, h, a, c, e, g, a, e, a]
    // [0, 0, 0, 0, 0, 0, 0]
    // win 0 --> current + length of level = 8
    // win 1 --> 9
    // win 2 --> 10
    // win 3 --> 11
    // win 4 --> 4 + (4 * 2) = 12
    // win 5 --> 5 + (4 * 2) = 13
    // win 6 --> 6 + (4 * 2) = 14
    function setBattle(uint _tId, uint8 _pos, uint _bId) external {
        TournamentBattle storage tournament = tournaments[_tId];

        // must be in the correct position in the bracket
        // only evens can set battle
        require(_pos % 2 == 0 && msg.sender == tournament.bracket[(_pos / 2)]);

        // can't supersede an existing tournament
        require(tournament.battleIds[_pos] == 0);

        tournament.battleIds[_pos] = _bId;
    }

    // returns where the bracket position should be updated after
    function _nextPosition(uint /*count*/, uint /*_pos*/) internal pure returns (uint) {
        return 0;
    }
                        
    function reportResult(uint _tId, uint _pos, uint _bId) external {
        // anyone can report the result of a match
        TournamentBattle storage tournament = tournaments[_tId];

        // must be the correct battle
        require(tournament.battleIds[_pos] == _bId);

        // winner progresses - no draws!!
        // can only be one battler here
        address win = tournament.battle.winnerOf(_bId, 0);

        // must be a winner
        require(win != address(0));
        // progress to the next round

        tournament.bracket[_nextPosition(tournament.participants.length, _pos)] = win;

        // if opponent is decided:

        TournamentMatch(_tId, _pos, win);

        // check for tournament end

        if (_pos == tournament.bracket.length) {
            TournamentResult(_tId, tournament.bracket);
        }

    }

}
