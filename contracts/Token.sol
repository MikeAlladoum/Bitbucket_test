pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
  // ------------------------------------------ //
  // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
  // ------------------------------------------ //
  using SafeMath for uint256;
  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  mapping (address => uint256) public balanceOf;
  // ------------------------------------------ //
  // ----- END: DO NOT EDIT THIS SECTION ------ //
  // ------------------------------------------ //

  address[] private holders;
  mapping (address => bool) private isHolder;
  mapping (address => uint256) private dividends;
  mapping (address => mapping (address => uint256)) private allowances;

  // IERC20

  function allowance(address owner, address spender) external view override returns (uint256) {
    return allowances[owner][spender];
  }

  function transfer(address to, uint256 value) external override returns (bool) {
    require(balanceOf[msg.sender] >= value, "Insufficient balance");
    
    // Remove sender from holders if they will have 0 balance
    if (balanceOf[msg.sender].sub(value) == 0 && isHolder[msg.sender]) {
      _removeHolder(msg.sender);
    }
    
    balanceOf[msg.sender] = balanceOf[msg.sender].sub(value);
    balanceOf[to] = balanceOf[to].add(value);
    
    // Track new holder if recipient is gaining tokens
    if (value > 0 && !isHolder[to]) {
      holders.push(to);
      isHolder[to] = true;
    }
    
    return true;
  }

  function approve(address spender, uint256 value) external override returns (bool) {
    allowances[msg.sender][spender] = value;
    return true;
  }

  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    require(balanceOf[from] >= value, "Insufficient balance");
    require(allowances[from][msg.sender] >= value, "Allowance exceeded");
    
    // Update allowance
    allowances[from][msg.sender] = allowances[from][msg.sender].sub(value);
    
    // Remove from from holders if they will have 0 balance
    if (balanceOf[from].sub(value) == 0 && isHolder[from]) {
      _removeHolder(from);
    }
    
    balanceOf[from] = balanceOf[from].sub(value);
    balanceOf[to] = balanceOf[to].add(value);
    
    // Track new holder if recipient is gaining tokens
    if (value > 0 && !isHolder[to]) {
      holders.push(to);
      isHolder[to] = true;
    }
    
    return true;
  }

  // IMintableToken

  function mint() external payable override {
    require(msg.value > 0, "Must send Ether to mint");
    
    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
    totalSupply = totalSupply.add(msg.value);
    
    // Track holder
    if (!isHolder[msg.sender]) {
      holders.push(msg.sender);
      isHolder[msg.sender] = true;
    }
  }

  function burn(address payable dest) external override {
    uint256 amount = balanceOf[msg.sender];
    require(amount > 0, "No tokens to burn");
    
    balanceOf[msg.sender] = 0;
    totalSupply = totalSupply.sub(amount);
    
    // Remove from holders
    _removeHolder(msg.sender);
    
    dest.transfer(amount);
  }

  // IDividends

  function getNumTokenHolders() external view override returns (uint256) {
    return holders.length;
  }

  function getTokenHolder(uint256 index) external view override returns (address) {
    require(index > 0 && index <= holders.length, "Invalid index");
    return holders[index - 1];
  }

  function recordDividend() external payable override {
    require(msg.value > 0, "Must send Ether");
    require(totalSupply > 0, "No token holders");
    
    for (uint256 i = 0; i < holders.length; i++) {
      if (balanceOf[holders[i]] > 0) {
        uint256 holderDividend = msg.value.mul(balanceOf[holders[i]]).div(totalSupply);
        dividends[holders[i]] = dividends[holders[i]].add(holderDividend);
      }
    }
  }

  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    return dividends[payee];
  }

  function withdrawDividend(address payable dest) external override {
    uint256 amount = dividends[msg.sender];
    require(amount > 0, "No dividends to withdraw");
    
    dividends[msg.sender] = 0;
    dest.transfer(amount);
  }

  // Helper function to remove a holder from the list
  function _removeHolder(address holder) internal {
    if (!isHolder[holder]) return;
    
    isHolder[holder] = false;
    
    // Find and remove from holders array
    for (uint256 i = 0; i < holders.length; i++) {
      if (holders[i] == holder) {
        // Replace with last element and pop
        if (i < holders.length - 1) {
          holders[i] = holders[holders.length - 1];
        }
        holders.pop();
        break;
      }
    }
  }
}