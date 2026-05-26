pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

/**
 * @title Token
 * @notice A fully-featured ERC20-compliant token with minting, burning, and dividend distribution capabilities.
 * @dev Implements IERC20, IMintableToken, and IDividends interfaces with comprehensive holder tracking.
 */
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

  /// @dev Internal array tracking all token holders
  address[] private holders;
  
  /// @dev Mapping to efficiently check if address is a holder
  mapping (address => bool) private isHolder;
  
  /// @dev Accumulated dividends per holder
  mapping (address => uint256) private dividends;
  
  /// @dev Allowances for transfers on behalf of token owners
  mapping (address => mapping (address => uint256)) private allowances;

  /// @notice Emitted when tokens are transferred
  event Transfer(address indexed from, address indexed to, uint256 value);
  
  /// @notice Emitted when allowance is granted
  event Approval(address indexed owner, address indexed spender, uint256 value);
  
  /// @notice Emitted when tokens are minted
  event Mint(address indexed to, uint256 value);
  
  /// @notice Emitted when tokens are burned
  event Burn(address indexed from, uint256 value);
  
  /// @notice Emitted when dividends are recorded
  event DividendRecorded(uint256 totalAmount, uint256 tokenHolders);
  
  /// @notice Emitted when dividends are withdrawn
  event DividendWithdrawn(address indexed to, uint256 amount);

  // ========== IERC20 Functions ==========

  /**
   * @notice Returns the amount of tokens that the spender is allowed to transfer on behalf of the owner
   * @param owner The token owner address
   * @param spender The address allowed to spend tokens
   * @return The allowance amount
   */
  function allowance(address owner, address spender) external view override returns (uint256) {
    return allowances[owner][spender];
  }

  /**
   * @notice Transfers tokens from the caller to the recipient
   * @param to The recipient address
   * @param value The amount of tokens to transfer
   * @return true on successful transfer
   */
  function transfer(address to, uint256 value) external override returns (bool) {
    require(to != address(0), "Invalid recipient address");
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
    
    emit Transfer(msg.sender, to, value);
    return true;
  }

  /**
   * @notice Approves the spender to transfer tokens on behalf of the caller
   * @param spender The address authorized to spend tokens
   * @param value The amount of tokens to approve for spending
   * @return true on successful approval
   */
  function approve(address spender, uint256 value) external override returns (bool) {
    require(spender != address(0), "Invalid spender address");
    allowances[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
  }

  /**
   * @notice Transfers tokens from one address to another on behalf of the owner
   * @param from The sender address
   * @param to The recipient address
   * @param value The amount of tokens to transfer
   * @return true on successful transfer
   */
  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    require(from != address(0), "Invalid source address");
    require(to != address(0), "Invalid recipient address");
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
    
    emit Transfer(from, to, value);
    return true;
  }

  // ========== IMintableToken Functions ==========

  /**
   * @notice Mints new tokens by accepting Ether payment
   * @dev Token amount minted equals the Ether value sent (1:1 ratio)
   * The sender is automatically tracked as a token holder
   */
  function mint() external payable override {
    require(msg.value > 0, "Must send Ether to mint");
    
    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
    totalSupply = totalSupply.add(msg.value);
    
    // Track holder
    if (!isHolder[msg.sender]) {
      holders.push(msg.sender);
      isHolder[msg.sender] = true;
    }
    
    emit Mint(msg.sender, msg.value);
  }

  /**
   * @notice Burns tokens from the caller and sends the corresponding Ether to the destination
   * @param dest The address to receive the burned token value in Ether
   * @dev Burns all tokens held by the caller
   */
  function burn(address payable dest) external override {
    require(dest != address(0), "Invalid destination address");
    uint256 amount = balanceOf[msg.sender];
    require(amount > 0, "No tokens to burn");
    
    balanceOf[msg.sender] = 0;
    totalSupply = totalSupply.sub(amount);
    
    // Remove from holders
    _removeHolder(msg.sender);
    
    emit Burn(msg.sender, amount);
    dest.transfer(amount);
  }

  // ========== IDividends Functions ==========

  /**
   * @notice Returns the total number of token holders
   * @return The count of active token holders
   */
  function getNumTokenHolders() external view override returns (uint256) {
    return holders.length;
  }

  /**
   * @notice Returns the address of a token holder at the given index
   * @param index The index of the holder (1-based indexing)
   * @return The address of the holder at the specified index
   */
  function getTokenHolder(uint256 index) external view override returns (address) {
    require(index > 0 && index <= holders.length, "Invalid holder index");
    return holders[index - 1];
  }

  /**
   * @notice Records dividend distribution to all current token holders
   * @dev Dividends are distributed proportionally based on token balance
   * The Ether sent is distributed among holders holding tokens at call time
   */
  function recordDividend() external payable override {
    require(msg.value > 0, "Must send Ether for dividend");
    require(totalSupply > 0, "No token holders for dividend distribution");
    
    for (uint256 i = 0; i < holders.length; i++) {
      if (balanceOf[holders[i]] > 0) {
        uint256 holderDividend = msg.value.mul(balanceOf[holders[i]]).div(totalSupply);
        dividends[holders[i]] = dividends[holders[i]].add(holderDividend);
      }
    }
    
    emit DividendRecorded(msg.value, holders.length);
  }

  /**
   * @notice Returns the withdrawable dividend amount for a given address
   * @param payee The address to check dividend for
   * @return The amount of dividends available for withdrawal
   */
  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    return dividends[payee];
  }

  /**
   * @notice Withdraws accumulated dividends for the caller
   * @param dest The address to receive the dividend Ether
   * @dev Resets the dividend balance to 0 after withdrawal
   */
  function withdrawDividend(address payable dest) external override {
    require(dest != address(0), "Invalid destination address");
    uint256 amount = dividends[msg.sender];
    require(amount > 0, "No dividends to withdraw");
    
    dividends[msg.sender] = 0;
    emit DividendWithdrawn(msg.sender, amount);
    dest.transfer(amount);
  }

  // ========== Internal Helper Functions ==========

  /**
   * @notice Removes a holder from the active holders list
   * @param holder The address of the holder to remove
   * @dev Uses an efficient O(1) removal strategy by swapping with the last element
   * This function is called when a holder's balance reaches 0
   */
  function _removeHolder(address holder) internal {
    if (!isHolder[holder]) return;
    
    isHolder[holder] = false;
    
    // Find and remove from holders array using swap-with-last strategy
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