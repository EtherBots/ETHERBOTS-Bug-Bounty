pragma solidity ^0.4.18;

import "./AccessControl.sol";
import "./Base.sol";

// This contract implements both the original ERC-721 standard and
// the proposed 'deed' standard of 841
// I don't know which standard will eventually be adopted - support both for now
// TODO: there must be a better way of expressing all this
// TODO: add proper ERC165 or ERC820 support (won't take long)

/// @title Interface for contracts conforming to ERC-721: Deed Standard
/// @author William Entriken (https://phor.net), et. al.
/// @dev Specification at https://github.com/ethereum/eips/841
/// can read the comments there
contract ERC721 {

    // COMPLIANCE WITH ERC-165 (DRAFT)

    /// @dev ERC-165 (draft) interface signature for itself
    bytes4 internal constant INTERFACE_SIGNATURE_ERC165 =
        bytes4(keccak256("supportsInterface(bytes4)"));

    /// @dev ERC-165 (draft) interface signature for ERC721
    bytes4 internal constant INTERFACE_SIGNATURE_ERC721 =
         bytes4(keccak256("ownerOf(uint256)")) ^
         bytes4(keccak256("countOfDeeds()")) ^
         bytes4(keccak256("countOfDeedsByOwner(address)")) ^
         bytes4(keccak256("deedOfOwnerByIndex(address,uint256)")) ^
         bytes4(keccak256("approve(address,uint256)")) ^
         bytes4(keccak256("takeOwnership(uint256)"));

    function supportsInterface(bytes4 _interfaceID) external pure returns (bool);

    // PUBLIC QUERY FUNCTIONS //////////////////////////////////////////////////

    function ownerOf(uint256 _deedId) public view returns (address _owner);
    function countOfDeeds() external view returns (uint256 _count);
    function countOfDeedsByOwner(address _owner) external view returns (uint256 _count);
    function deedOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256 _deedId);

    // TRANSFER MECHANISM //////////////////////////////////////////////////////

    event Transfer(address indexed from, address indexed to, uint256 indexed deedId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed deedId);

    function approve(address _to, uint256 _deedId) external payable;
    function takeOwnership(uint256 _deedId) external payable;
}

/// @title Metadata extension to ERC-721 interface
/// @author William Entriken (https://phor.net)
/// @dev Specification at https://github.com/ethereum/eips/issues/XXXX
contract ERC721Metadata is ERC721 {

    bytes4 internal constant INTERFACE_SIGNATURE_ERC721Metadata =
        bytes4(keccak256("name()")) ^
        bytes4(keccak256("symbol()")) ^
        bytes4(keccak256("deedUri(uint256)"));

    function name() public pure returns (string n);
    function symbol() public pure returns (string s);

    /// @notice A distinct URI (RFC 3986) for a given token.
    /// @dev If:
    ///  * The URI is a URL
    ///  * The URL is accessible
    ///  * The URL points to a valid JSON file format (ECMA-404 2nd ed.)
    ///  * The JSON base element is an object
    ///  then these names of the base element SHALL have special meaning:
    ///  * "name": A string identifying the item to which `_deedId` grants
    ///    ownership
    ///  * "description": A string detailing the item to which `_deedId` grants
    ///    ownership
    ///  * "image": A URI pointing to a file of image/* mime type representing
    ///    the item to which `_deedId` grants ownership
    ///  Wallets and exchanges MAY display this to the end user.
    ///  Consider making any images at a width between 320 and 1080 pixels and
    ///  aspect ratio between 1.91:1 and 4:5 inclusive.
    function deedUri(uint256 _deedId) external view returns (string _uri);
}

/// @title Enumeration extension to ERC-721 interface
/// @author William Entriken (https://phor.net)
/// @dev Specification at https://github.com/ethereum/eips/issues/XXXX
contract ERC721Enumerable is ERC721Metadata {

    /// @dev ERC-165 (draft) interface signature for ERC721
    bytes4 internal constant INTERFACE_SIGNATURE_ERC721Enumerable =
        bytes4(keccak256("deedByIndex()")) ^
        bytes4(keccak256("countOfOwners()")) ^
        bytes4(keccak256("ownerByIndex(uint256)"));

    function deedByIndex(uint256 _index) external view returns (uint256 _deedId);
    function countOfOwners() external view returns (uint256 _count);
    function ownerByIndex(uint256 _index) external view returns (address _owner);
}

contract ERC721Original {

    bytes4 constant INTERFACE_SIGNATURE_ERC721Original =
        bytes4(keccak256("totalSupply()")) ^
        bytes4(keccak256("balanceOf(address)")) ^
        bytes4(keccak256("ownerOf(uint256)")) ^
        bytes4(keccak256("approve(address,uint256)")) ^
        bytes4(keccak256("takeOwnership(uint256)")) ^
        bytes4(keccak256("transfer(address,uint256)"));

    // Core functions
    function implementsERC721() public pure returns (bool);
    function totalSupply() public view returns (uint256 _totalSupply);
    function balanceOf(address _owner) public view returns (uint256 _balance);
    function ownerOf(uint _tokenId) public view returns (address _owner);
    function approve(address _to, uint _tokenId) external payable;
    function transferFrom(address _from, address _to, uint _tokenId) public;
    function transfer(address _to, uint _tokenId) public payable;

    // Optional functions
    function name() public pure returns (string _name);
    function symbol() public pure returns (string _symbol);
    function tokenOfOwnerByIndex(address _owner, uint _index) external view returns (uint _tokenId);
    function tokenMetadata(uint _tokenId) public view returns (string _infoUrl);

    // Events
    // event Transfer(address indexed _from, address indexed _to, uint256 _tokenId);
    // event Approval(address indexed _owner, address indexed _approved, uint256 _tokenId);
}

contract ERC721AllImplementations is ERC721Original, ERC721Enumerable {

}


contract EtherbotsNFT is EtherbotsBase, ERC721Enumerable, ERC721Original {
    function supportsInterface(bytes4 _interfaceID) external pure returns (bool) {
        return (_interfaceID == ERC721Original.INTERFACE_SIGNATURE_ERC721Original) ||
            (_interfaceID == ERC721.INTERFACE_SIGNATURE_ERC721) ||
            (_interfaceID == ERC721Metadata.INTERFACE_SIGNATURE_ERC721Metadata) ||
            (_interfaceID == ERC721Enumerable.INTERFACE_SIGNATURE_ERC721Enumerable);
    }
    function implementsERC721() public pure returns (bool) {
        return true;
    }

    function name() public pure returns (string _name) {
      return "Etherbots";
    }

    function symbol() public pure returns (string _smbol) {
      return "ETHBOT";
    }

    // total supply of parts --> as no parts are ever deleted, this is simply
    // the total supply of parts ever created
    function totalSupply() public view returns (uint) {
        return parts.length;
    }

    /// @notice Returns the total number of deeds currently in existence.
    /// @dev Required for ERC-721 compliance.
    function countOfDeeds() external view returns (uint256) {
        return parts.length;
    }

    //--/ internal function    which checks whether the token with id (_tokenId)
    /// is owned by the (_claimant) address
    function owns(address _owner, uint256 _tokenId) public view returns (bool) {
        return (partIndexToOwner[_tokenId] == _owner);
    }

    /// internal function    which checks whether the token with id (_tokenId)
    /// is owned by the (_claimant) address
    function ownsAll(address _owner, uint256[] _tokenIds) public view returns (bool) {
        for (uint i = 0; i < _tokenIds.length; i++) {
            if (partIndexToOwner[_tokenIds[i]] != _owner) {
                return false;
            }
        }
        return true;
    }

    function _approve(uint256 _tokenId, address _approved) internal {
        partIndexToApproved[_tokenId] = _approved;
    }

    function _approvedFor(address _newOwner, uint256 _tokenId) internal view returns (bool) {
        return (partIndexToApproved[_tokenId] == _newOwner);
    }

    function ownerByIndex(uint256 _index) external view returns (address _owner){
        return partIndexToOwner[_index];
    }

    // returns the NUMBER of tokens owned by (_owner)
    function balanceOf(address _owner) public view returns (uint256 count) {
        return addressToTokensOwned[_owner];
    }

    function countOfDeedsByOwner(address _owner) external view returns (uint256) {
        return balanceOf(_owner);
    }

    // transfers a part to another account
    function transfer(address _to, uint256 _tokenId) public whenNotPaused payable {
        // payable for ERC721 --> don't actually send eth @_@
        require(msg.value == 0);

        // Safety checks to prevent accidental transfers to common accounts
        require(_to != address(0));
        require(_to != address(this));
        // can't transfer parts to the auction contract directly
        require(_to != address(auction));
        // can't transfer parts to any of the battle contracts directly
        for (uint j = 0; j < approvedBattles.length; j++) {
            require(_to != approvedBattles[j]);
        }

        // Cannot send tokens you don't own
        require(owns(msg.sender, _tokenId));

        // perform state changes necessary for transfer
        _transfer(msg.sender, _to, _tokenId);
    }
    // transfers a part to another account

    function transferAll(address _to, uint256[] _tokenIds) public whenNotPaused {

        // Safety checks to prevent accidental transfers to common accounts
        require(_to != address(0));
        require(_to != address(this));
        // can't transfer parts to the auction contract directly
        require(_to != address(auction));
        // can't transfer parts to any of the battle contracts directly
        for (uint j = 0; j < approvedBattles.length; j++) {
            require(_to != approvedBattles[j]);
        }

        // Cannot send tokens you don't own
        require(ownsAll(msg.sender, _tokenIds));

        for (uint k = 0; k < _tokenIds.length; k++) {
            // perform state changes necessary for transfer
            _transfer(msg.sender, _to, _tokenIds[k]);
        }


    }


    // approves the (_to) address to use the transferFrom function on the token with id (_tokenId)
    // if you want to clear all approvals, simply pass the zero address
    function approve(address _to, uint256 _deedId) external whenNotPaused payable {
        // payable for ERC721 --> don't actually send eth @_@
        require(msg.value == 0);
// use internal function?
        // Cannot approve the transfer of tokens you don't own
        require(owns(msg.sender, _deedId));

        // Store the approval (can only approve one at a time)
        partIndexToApproved[_deedId] = _to;

        Approval(msg.sender, _to, _deedId);
    }

    // approves many token ids
    function approveMany(address _to, uint256[] _tokenIds) external whenNotPaused {

        for (uint i = 0; i < _tokenIds.length; i++) {
            uint _tokenId = _tokenIds[i];

            // Cannot approve the transfer of tokens you don't own
            require(owns(msg.sender, _tokenId));

            // Store the approval (can only approve one at a time)
            partIndexToApproved[_tokenId] = _to;
            //create event for each approval? _tokenId guaranteed to hold correct value?
            Approval(msg.sender, _to, _tokenId);
        }
    }

    // transfer the part with id (_tokenId) from (_from) to (_to)
    // (_to) must already be approved for this (_tokenId)
    function transferFrom(address _from, address _to, uint256 _tokenId) public whenNotPaused {

        // Safety checks to prevent accidents
        require(_to != address(0));
        require(_to != address(this));

        // sender must be approved
        require(partIndexToApproved[_tokenId] == msg.sender);
        // from must currently own the token
        require(owns(_from, _tokenId));

        // Reassign ownership (also clears pending approvals and emits Transfer event).
        _transfer(_from, _to, _tokenId);
    }

    // returns the current owner of the token with id = _tokenId
    function ownerOf(uint256 _deedId) public view returns (address _owner) {
        _owner = partIndexToOwner[_deedId];
        // must result false if index key not found
        require(_owner != address(0));
    }

    // returns a dynamic array of the ids of all tokens which are owned by (_owner)
    // Looping through every possible part and checking it against the owner is
    // actually much more efficient than storing a mapping or something, because
    // it won't be executed as a transaction
    function tokensOfOwner(address _owner) external view returns(uint256[] ownerTokens) {
        uint256 tokenCount = balanceOf(_owner);

        //what if tokensCount == 0? return empty array
        uint256[] memory result = new uint256[](tokenCount);

        uint256 totalParts = totalSupply();
        uint256 resultIndex = 0;

//thirsty function? Doesn't exit if tokenCount found. (writes past end of array)
        for (uint partId = 0; partId < totalParts; partId++) {
            if (partIndexToOwner[partId] == _owner) {
                result[resultIndex] = partId;
                resultIndex++;
            }
        }
        return result; // will have 0 elements if tokenCount == 0
    }

    //same issues as above
    // Returns an array of all part structs owned by the user. Free to call.
    function getPartsOfOwner(address _owner) external view returns(bytes24[]) {
        uint256 tokenCount = balanceOf(_owner);
        uint256 totalParts = totalSupply();

        uint resultIndex = 0;
        bytes24[] memory result = new bytes24[](tokenCount);
        for (uint partId = 0; partId < totalParts; partId++) {
            if (partIndexToOwner[partId] == _owner) {
                Part storage p = parts[partId];

                bytes24 b;
                b = bytes24(p.tokenId);

                b = b << 8;
                b = b | bytes24(p.partType);

                b = b << 8;
                b = b | bytes24(p.partSubType);

                b = b << 8;
                b = b | bytes24(p.rarity);

                b = b << 8;
                b = b | bytes24(p.element);

                b = b << 32;
                b = b | bytes24(p.battlesLastDay);

                b = b << 32;
                b = b | bytes24(p.experience);

                b = b << 32;
                b = b | bytes24(p.forgeTime);

                b = b << 32;
                b = b | bytes24(p.battlesLastReset);

                result[resultIndex] = b;
                resultIndex++;
            }
        }

        return result; // will have 0 elements if tokenCount == 0
    }

    uint32 constant FIRST_LEVEL = 1000;
    uint32 constant INCREMENT = 1000;

    // every level, you need 1000 more exp to go up a level
    function _getLevel(uint32 _exp) public pure returns(uint32) {
        uint32 c = 0;
        for (uint32 i = FIRST_LEVEL; i <= _exp; i += c * INCREMENT) {
            c++;
        }
        return c;
    }

    string metadataBase = "https://api.etherbots.io/api/";


    function setMetadataBase(string _base) external onlyOwner {
        metadataBase = _base;
    }

    // part type, subtype,
    // have one internal function which lets us implement the divergent interfaces
    function _metadata(uint256 _id) internal view returns(string) {
        Part memory p = parts[_id];
        return strConcat(strConcat(
            metadataBase,
            uintToString(uint(p.partType)),
            "/",
            uintToString(uint(p.partSubType)),
            "/"
        ), uintToString(uint(p.rarity)), "", "", "");
    }

    function strConcat(string _a, string _b, string _c, string _d, string _e) internal pure returns (string){
        bytes memory _ba = bytes(_a);
        bytes memory _bb = bytes(_b);
        bytes memory _bc = bytes(_c);
        bytes memory _bd = bytes(_d);
        bytes memory _be = bytes(_e);
        string memory abcde = new string(_ba.length + _bb.length + _bc.length + _bd.length + _be.length);
        bytes memory babcde = bytes(abcde);
        uint k = 0;
        for (uint i = 0; i < _ba.length; i++) babcde[k++] = _ba[i];
        for (i = 0; i < _bb.length; i++) babcde[k++] = _bb[i];
        for (i = 0; i < _bc.length; i++) babcde[k++] = _bc[i];
        for (i = 0; i < _bd.length; i++) babcde[k++] = _bd[i];
        for (i = 0; i < _be.length; i++) babcde[k++] = _be[i];
        return string(babcde);
    }

    /// @notice A distinct URI (RFC 3986) for a given token.
    /// @dev If:
    ///  * The URI is a URL
    ///  * The URL is accessible
    ///  * The URL points to a valid JSON file format (ECMA-404 2nd ed.)
    ///  * The JSON base element is an object
    ///  then these names of the base element SHALL have special meaning:
    ///  * "name": A string identifying the item to which `_deedId` grants
    ///    ownership
    ///  * "description": A string detailing the item to which `_deedId` grants
    ///    ownership
    ///  * "image": A URI pointing to a file of image/* mime type representing
    ///    the item to which `_deedId` grants ownership
    ///  Wallets and exchanges MAY display this to the end user.
    ///  Consider making any images at a width between 320 and 1080 pixels and
    ///  aspect ratio between 1.91:1 and 4:5 inclusive.
    function deedUri(uint256 _deedId) external view returns (string _uri){
        return _metadata(_deedId);
    }

    /// returns a metadata URI
    // TODO: implement this.
    function tokenMetadata(uint256 _tokenId) public view returns (string infoUrl) {
        return _metadata(_tokenId);
    }

    function takeOwnership(uint256 _deedId) external payable {
        // payable for ERC721 --> don't actually send eth @_@
        require(msg.value == 0);

        address _from = partIndexToOwner[_deedId];

        require(_approvedFor(msg.sender, _deedId));

        _transfer(_from, msg.sender, _deedId);
    }

    // parts are stored sequentially
    function deedByIndex(uint256 _index) external view returns (uint256 _deedId){
        return _index;
    }

    function countOfOwners() external view returns (uint256 _count){
        // TODO: implement this
        return 0;
    }

// thirsty function
    function tokenOfOwnerByIndex(address _owner, uint _index) external view returns (uint _tokenId){
        return _tokenOfOwnerByIndex(_owner, _index);
    }

// code duplicated
    function _tokenOfOwnerByIndex(address _owner, uint _index) private view returns (uint _tokenId){
        // The index should be valid.
        require(_index < balanceOf(_owner));

        // can loop through all without
        uint256 seen = 0;
        uint256 totalTokens = totalSupply();

        for (uint i = 0; i < totalTokens; i++) {
            if (partIndexToOwner[i] == _owner) {
                if (seen == _index) {
                    return i;
                }
                seen++;
            }
        }
    }

    function deedOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256 _deedId){
        return _tokenOfOwnerByIndex(_owner, _index);
    }
}
