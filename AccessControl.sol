pragma solidity ^0.4.18;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() public {
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}



 // Pause functionality taken from OpenZeppelin. License below.
 /* The MIT License (MIT)
 Copyright (c) 2016 Smart Contract Solutions, Inc.
 Permission is hereby granted, free of charge, to any person obtaining
 a copy of this software and associated documentation files (the
 "Software"), to deal in the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to
 permit persons to whom the Software is furnished to do so, subject to
 the following conditions: */

 /**
  * @title Pausable
  * @dev Base contract which allows children to implement an emergency stop mechanism.
  */
contract Pausable is Ownable {

  event SetPaused(bool paused);

  // starts unpaused
  bool public paused = false;

  /* @dev modifier to allow actions only when the contract IS paused */
  modifier whenNotPaused() {
    require(!paused);
    _;
  }

  /* @dev modifier to allow actions only when the contract IS NOT paused */
  modifier whenPaused() {
    require(paused);
    _;
  }

  function pause() public onlyOwner whenNotPaused returns (bool) {
    paused = true;
    SetPaused(paused);
    return true;
  }

  function unpause() public onlyOwner whenPaused returns (bool) {
    paused = false;
    SetPaused(paused);
    return true;
  }
}

contract EtherbotsPrivileges is Pausable {
  event ContractUpgrade(address newContract);

  modifier addressNotNil(address _address) {
    require(_address != 0x0);
    _;
  }

}
