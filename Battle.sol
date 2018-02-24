pragma solidity ^0.4.17;

contract Battle {
    // This struct does not exist outside the context of a battle

    // the name of the battle type
    function name() external view returns (string);
    // the number of robots currently battling
    function playerCount() external view returns (uint count);
    // creates a new battle, with a submitted user string for initial input/
    function createBattle(address defender, uint[] partIds, bytes32 commit) external payable;
    // cancels the battle at battleID
    function cancelBattle(uint battleID) external;
    
    function winnerOf(uint battleId, uint index) external view returns (address);
    function loserOf(uint battleId, uint index) external view returns (address);

    // TODO: parameters for these: as generic as possible
    // favour over-reporting/flexibility
    //_duelId, i, [attacker.moves[i], _defenderMoves[i]], [attackerDamage, defenderDamage]]
    event BattleCreated(uint indexed battleID, address indexed starter);
    event BattleStage(uint indexed battleID, uint8 moveNumber, uint8[2] attackerMovesDefenderMoves, uint16[2] attackerDamageDefenderDamage);
    event BattleEnded(uint indexed battleID, address indexed winner);
    event BattleConcluded(uint indexed battleID);
    event BattlePropertyChanged(string name, uint previous, uint value);
}