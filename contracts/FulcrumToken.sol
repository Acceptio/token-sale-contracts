pragma solidity ^0.4.24;

import 'openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol';
import "openzeppelin-solidity/contracts/token/ERC20/BurnableToken.sol";
import "openzeppelin-solidity/contracts/ownership/Claimable.sol";
import "openzeppelin-solidity/contracts/ownership/HasNoContracts.sol";
import "openzeppelin-solidity/contracts/ownership/HasNoTokens.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FulcrumToken is StandardToken, BurnableToken, Claimable, HasNoContracts, HasNoTokens {
    using SafeMath for uint256;

    string public name = "Fulcrum Token";
    string public symbol = "FULC";
    uint256 public constant decimals = 18;
    uint256 public tokenPrice;
    uint256 public tokenPriceDiscount;

    uint public startTimestamp;
    uint public icoDuration;

    uint256 public discountRate = 0;

    uint256 public totalRaised = 0;
    address public fundsWallet;
    
    uint256 public constant TOKEN_TOTAL_ALLOCATION = 400 * (10**6) * (10**decimals);  
    uint256 public constant HARD_CAP = 150 * (10**6) * (10**decimals);
    uint256 public constant SOFT_CAP = 1 * (10**6) * (10**decimals);

    mapping (uint256 => address) private balancesId;
    uint256 private balancesIdIndex = 0;
    mapping (address => uint256) public balances;
    mapping (address => mapping (address => uint256)) private allowed;
    
    constructor(address _fundsWallet, uint256 _usdPrice, uint _icoDuration) public {
        balances[address(this)] = HARD_CAP;
        balances[_fundsWallet] = TOKEN_TOTAL_ALLOCATION.sub(HARD_CAP);
        fundsWallet = _fundsWallet;
        tokenPrice = _usdPrice;
        startTimestamp = now;
        icoDuration = _icoDuration;
    }
    
    function () isIcoOpen public payable {
        calculateDiscount();
        uint256 tokenAmount = msg.value.mul(10**decimals).div(tokenPriceDiscount);
        if (balances[msg.sender] == 0) {
            balancesId[balancesIdIndex] = msg.sender;
            balancesIdIndex++;
        }
        transfer(msg.sender, tokenAmount);
        totalRaised = totalRaised.add(tokenAmount);
        fundsWallet.transfer(msg.value);
    }

    modifier isIcoOpen() {
        require((now <= (startTimestamp + icoDuration) && totalRaised < HARD_CAP) || totalRaised < SOFT_CAP);
        _;
    }

    modifier isIcoFinished() {
        require(totalRaised >= HARD_CAP || (now >= (startTimestamp + icoDuration) && totalRaised >= SOFT_CAP));
        _;
    }

    modifier isTokenLeft() {
        require(balances[address(this)] > 0);
        _;
    }

    function calculateDiscount() private {
        if (startTimestamp + 1 days > now) {
            if (discountRate != 20) {
                discountRate = 20;
                updateDiscountPrice();
            }
        } else if (startTimestamp + 2 days > now) {
            if (discountRate != 15) {
                discountRate = 15;
                updateDiscountPrice();
            }
        } else if (startTimestamp + 4 days > now) {
            if (discountRate != 10) {
                discountRate = 10;
                updateDiscountPrice();
            }
        } else {
            if (discountRate != 0) {
                discountRate = 0;
                updateDiscountPrice();
            }
        }
    }

    function updateDiscountPrice() private {
        if (discountRate > 0) {
            tokenPriceDiscount = tokenPrice.mul(100 - discountRate).div(uint256(100));
        } else {
            tokenPriceDiscount = tokenPrice;
        }
    }

    function distribute() isIcoFinished isTokenLeft public {
        uint256 tokenLeft = balances[address(this)];
        uint256 tokenSold = HARD_CAP.sub(tokenLeft);
        for (uint256 i = 0; i < balancesIdIndex && balances[address(this)] > 0; i++) {
            uint256 balance = balances[balancesId[i]];
            if (balance > 0 && balancesId[i] != address(this) && balancesId[i] != fundsWallet) {
                transfer(balancesId[i], tokenLeft.mul(balance).div(tokenSold));
            }
        }
    }

    function setTokenPrice(uint256 _tokenPrice) onlyOwner public {
        tokenPrice = _tokenPrice;
        discountRate = 30; //for discount recalculate
    }

    /**
    * @dev Total number of tokens in existence
    */
    function totalSupply() public view returns (uint256) {
        return TOKEN_TOTAL_ALLOCATION;
    }

    /**
    * @dev Gets the balance of the specified address.
    * @param _owner The address to query the the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function balanceOf(address _owner) public view returns (uint256) {
        return balances[_owner];
    }

    /**
    * @dev Function to check the amount of tokens that an owner allowed to a spender.
    * @param _owner address The address which owns the funds.
    * @param _spender address The address which will spend the funds.
    * @return A uint256 specifying the amount of tokens still available for the spender.
    */
    function allowance(
        address _owner,
        address _spender
    )
        public
        view
        returns (uint256)
    {
        return allowed[_owner][_spender];
    }

    /**
    * @dev Transfer token for a specified address
    * @param _to The address to transfer to.
    * @param _value The amount to be transferred.
    */
    function transfer(address _to, uint256 _value) public returns (bool) {
        require(_value <= balances[address(this)]);
        require(_to != address(0));

        balances[address(this)] = balances[address(this)].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(address(this), _to, _value);
        return true;
    }

    /**
    * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
    * Beware that changing an allowance with this method brings the risk that someone may use both the old
    * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
    * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
    * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    * @param _spender The address which will spend the funds.
    * @param _value The amount of tokens to be spent.
    */
    function approve(address _spender, uint256 _value) public returns (bool) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /**
    * @dev Transfer tokens from one address to another
    * @param _from address The address which you want to send tokens from
    * @param _to address The address which you want to transfer to
    * @param _value uint256 the amount of tokens to be transferred
    */
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    )
        public
        returns (bool)
    {
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);
        require(_to != address(0));

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        emit Transfer(_from, _to, _value);
        return true;
    }

    /**
    * @dev Increase the amount of tokens that an owner allowed to a spender.
    * approve should be called when allowed[_spender] == 0. To increment
    * allowed value is better to use this function to avoid 2 calls (and wait until
    * the first transaction is mined)
    * From MonolithDAO Token.sol
    * @param _spender The address which will spend the funds.
    * @param _addedValue The amount of tokens to increase the allowance by.
    */
    function increaseApproval(
        address _spender,
        uint256 _addedValue
    )
        public
        returns (bool)
    {
        allowed[msg.sender][_spender] = (
        allowed[msg.sender][_spender].add(_addedValue));
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    /**
    * @dev Decrease the amount of tokens that an owner allowed to a spender.
    * approve should be called when allowed[_spender] == 0. To decrement
    * allowed value is better to use this function to avoid 2 calls (and wait until
    * the first transaction is mined)
    * From MonolithDAO Token.sol
    * @param _spender The address which will spend the funds.
    * @param _subtractedValue The amount of tokens to decrease the allowance by.
    */
    function decreaseApproval(
        address _spender,
        uint256 _subtractedValue
    )
        public
        returns (bool)
    {
        uint256 oldValue = allowed[msg.sender][_spender];
        if (_subtractedValue >= oldValue) {
            allowed[msg.sender][_spender] = 0;
        } else {
            allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
        }
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }
}
