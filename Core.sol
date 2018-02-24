pragma solidity ^0.4.18;

import "./EtherbotsBattle.sol";

contract EtherbotsCore is EtherbotsBattle {

    // The structure of Etherbots is modelled on CryptoKitties for obvious reasons:
    // ease of implementation, tried + tested etc.
    // it ellides some features and includes some others

    // The full system is implemented in the following manner:
    //
    // EtherbotsBase    | Storage and base types
    // EtherbotsAccess  | Access Control - who can change which state vars etc.
    // EtherbotsNFT     | ERC721 Implementation
    // EtherbotsBattle  | Battle interface contract: only one implementation, but could add later
    // EtherbotsAuction | Auction interface contract: only one at the moment, but could add later


    // Set in case the core contract is broken and an upgrade is required
    address public newContractAddress;

    function EtherbotsCore() public {
        // Starts paused.
        paused = true;
        owner = msg.sender;
    }

    // sets a new address for the contract
    // TODO: could implement a base contract which implements an interface
    // and then route all calls through that
    // pros: clients don't need to update
    // cons: could change the address and clients might be implementing a contract which does something different
    // centralisation issues
    // could use the same way as battles (store in array, can never remove)
    function setNewAddress(address _nextAddress) external onlyOwner whenPaused {
        // See README.md for upgrade plan
        newContractAddress = _nextAddress;
        ContractUpgrade(_nextAddress);
    }

    // only the auction contract can send ether to this contract
    /* function() external payable {
        require(msg.sender == address(saleAuction));
    } */

    // returns the part details
    // function getPart(uint256 _id) external view
    //     returns (uint256 forgeTime, uint32[8] blueprint) {
    //     Part storage part = parts[_id];
    //     forgeTime = uint256(part.forgeTime);
    //     blueprint = part.blueprint;
    //     // I do not like implicit returns
    // }

    /* // external contract addresses must be set before resumption
    function unpause() public onlyOwner whenPaused {
        require(newContractAddress != address(0));

        // Actually unpause the contract.
        super.unpause();
    } */

    // as users still lose their fees when cancelling battles
    // can withdraw everything
    function withdrawBalance() external onlyOwner {
        owner.transfer(this.balance);
    }
}
