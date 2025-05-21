// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.24;

import {ReentrancyGuard} from "openzeppelin/contracts/security/ReentrancyGuard.sol";

 contract MultiUserBank is ReentrancyGuard {
    bool public isPaused;
    uint256 public globalFee = 0.0001 ether;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    
    mapping(address => uint256) private balances;
    mapping(address => bool) private users;
    mapping(address => bool) private frozenAccounts;
    mapping(bytes32 => mapping(address => bool)) private roles;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event UserCreated(address indexed user, uint256 startingBalance, uint256 timestamp);

    error InsufficientBalance(uint256 available, uint256 required);
    error AccountNotExist(address user);
    error AccountAlreadyExists(address user);
    error UnauthorizedAccess();
    error InvalidAmount(uint256 amount);
    error ContractPaused();
    error PaymentFailed();
    error AccountIsFrozen(address user);

    modifier onlyAdmin () {
        if(roles[ADMIN_ROLE][msg.sender] == false) revert UnauthorizedAccess();
        _;
    }

    modifier onlyRole (bytes32 _role) {
        if(roles[_role][msg.sender] == false) revert UnauthorizedAccess();
        _;
    }

    modifier isValidAmount () {
        if(msg.value > globalFee) revert InvalidAmount(msg.value);
        _;
    }

    modifier whenNotPaused() {
        if(isPaused) revert ContractPaused();
        _;
    }

    modifier accountExists() {
        if(users[msg.sender] == false) revert AccountNotExist(msg.sender);
        _;
    }

    modifier accountNotFrozen(address _account) {
        if(frozenAccounts[_account] == true) revert AccountIsFrozen(_account);
        _;
    }

    constructor() {
        roles[ADMIN_ROLE][msg.sender] = true;
        isPaused = false;
    }

    function deposit (address _account) external payable whenNotPaused() isValidAmount() accountExists() {        
        balances[_account] += msg.value;
        
        emit Deposit(_account, msg.value);
    }

    function createAccount () external payable whenNotPaused() isValidAmount() {
        if(users[msg.sender] == true) revert AccountAlreadyExists(msg.sender);

        users[msg.sender] = true;
        balances[msg.sender] = msg.value;

        emit UserCreated(msg.sender, msg.value, block.timestamp);
    }

    function withdraw (uint256 _amount) external payable whenNotPaused() accountExists() nonReentrant() accountNotFrozen(msg.sender){
        if(balances[msg.sender] + globalFee < _amount) revert InsufficientBalance(balances[msg.sender], _amount + globalFee);

        balances[msg.sender] -= _amount;

        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if(!success) revert PaymentFailed();

        emit Withdraw(msg.sender, _amount);
    }

    function transfer (uint256 _amount, address _recipient) external payable whenNotPaused() accountExists() nonReentrant() isValidAmount() accountNotFrozen(msg.sender){
        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;

        emit Transfer(msg.sender, _recipient, _amount);
    }

    function pauseContract () external onlyRole(keccak256("ADMIN_ROLE")) whenNotPaused() {
        isPaused = true;
    }

    function unpauseContract () external onlyRole(keccak256("ADMIN_ROLE")) {
        isPaused = false;
    }

    function freezeAccount (address _account) external onlyRole(keccak256("MODERATOR_ROLE")) accountNotFrozen(_account){
        frozenAccounts[_account] = true;
    }

    function unfreezeAccount (address _account) external onlyRole(keccak256("MODERATOR_ROLE")) {
        frozenAccounts[_account] = false;
    }

    function setGlobalFee (uint256 _fee) external onlyRole(keccak256("ADMIN_ROLE")) {
        globalFee = _fee;
    }

    function getBalance (address _account) external view returns (uint256) {
        return balances[_account];
    }

    function getAccountStatus (address _account) external view returns (bool) {
        return users[_account];
    }
    
    function getFrozenStatus (address _account) external view returns (bool) {
        return frozenAccounts[_account];
    }
 }