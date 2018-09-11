pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol";
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

    uint256 public startTimestamp;
    uint256 public icoDuration;

    uint256 public discountRate = 0;

    uint256 public totalRaised = 0;
    address public fundsWallet;
    
    uint256 public constant MAX_SUPPLY = 400 * (10**6) * (10**decimals);  
    uint256 public constant HARD_CAP = 150 * (10**6) * (10**decimals);
    uint256 public constant SOFT_CAP = 1 * (10**6) * (10**decimals);

    mapping (uint256 => address) private balancesId;
    uint256 private balancesIdIndex = 0;
    
    constructor(address _fundsWallet, uint256 _usdPrice, uint _icoDuration) public {
        
        balances[address(this)] = HARD_CAP;
        balances[_fundsWallet] = MAX_SUPPLY.sub(HARD_CAP);
        totalSupply_ = MAX_SUPPLY;

        fundsWallet = _fundsWallet;
        tokenPrice = _usdPrice;
        startTimestamp = now;
        icoDuration = _icoDuration;
    }
    
    function () isEthSend isIcoOpen public payable {
        calculateDiscount();
        uint256 tokenAmount = msg.value.mul(10**decimals).div(tokenPriceDiscount);
        if (balances[msg.sender] == 0) {
            balancesId[balancesIdIndex] = msg.sender;
            balancesIdIndex++;
        }
        _transfer(msg.sender, tokenAmount);
        totalRaised = totalRaised.add(tokenAmount);
        fundsWallet.transfer(msg.value);
    }

    modifier isEthSend() {
        require(msg.value > 0);
        _;
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

    function calculateDiscount() public {
        if (startTimestamp + 1 days > now) {
            if (discountRate != 20) {
                discountRate = 20;
                tokenPriceDiscount = tokenPrice.mul(100 - discountRate).div(uint256(100));
            }
        } else if (startTimestamp + 2 days > now) {
            if (discountRate != 15) {
                discountRate = 15;
                tokenPriceDiscount = tokenPrice.mul(100 - discountRate).div(uint256(100));
            }
        } else if (startTimestamp + 4 days > now) {
            if (discountRate != 10) {
                discountRate = 10;
                tokenPriceDiscount = tokenPrice.mul(100 - discountRate).div(uint256(100));
            }
        } else {
            if (discountRate != 0) {
                discountRate = 0;
                tokenPriceDiscount = tokenPrice;
            }
        }
    }

    function _transfer(address to, uint256 tokenAmount) private {
        require(tokenAmount <= balances[address(this)]);
        require(to != address(0));
        balances[address(this)] = balances[address(this)].sub(tokenAmount);
        balances[to] = balances[to].add(tokenAmount);
        emit Transfer(address(this), to, tokenAmount);
    }

    function distribute() isIcoFinished isTokenLeft public {
        uint256 tokenLeft = balances[address(this)];
        uint256 tokenSold = HARD_CAP.sub(tokenLeft);
        for (uint256 i = 0; i < balancesIdIndex && balances[address(this)] > 0; i++) {
            uint256 balance = balances[balancesId[i]];
            if (balance > 0 && balancesId[i] != address(this) && balancesId[i] != fundsWallet) {
                _transfer(balancesId[i], tokenLeft.mul(balance).div(tokenSold));
            }
        }
    }

    function setTokenPrice(uint256 _tokenPrice) onlyOwner public {
        tokenPrice = _tokenPrice;
        discountRate = 30; //for discount recalculate
    }
}
