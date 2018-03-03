pragma solidity ^0.4.11;

import {StandardToken as ERC20} from "./StandardToken.sol";

contract ERC20Exchange {

    mapping (bytes32 => bool) public fills;
    
    // Event to log filled orders
    event Filled(address indexed makerAddress, uint makerAmount, address indexed makerToken, address takerAddress, uint takerAmount, address indexed takerToken, uint256 expiration, uint256 nonce);
    // Even to log caneled orders
    event Canceled(address indexed makerAddress, uint makerAmount, address indexed makerToken, address takerAddress, uint takerAmount, address indexed takerToken, uint256 expiration, uint256 nonce);
    // Event to log failed orders
    event Failed(uint errorCode, address indexed makerAddress, uint makerAmount, address indexed makerToken, address takerAddress, uint takerAmount, address indexed takerToken, uint256 expiration, uint256 nonce);

    // Function to fill the order
    function fill(address makerAddress, uint makerAmount, address makerToken,
                  address takerAddress, uint takerAmount, address takerToken,
                  uint256 expiration, uint256 nonce, uint8 v, bytes32 r, bytes32 s) payable {
                      
        // The makeAddress and takerAddress must be different
        if (makerAddress == takerAddress) {
            msg.sender.transfer(msg.value);
            Failed(1, makerAddress, makerAmount, makerToken, takerAddress, takerAmount, takerToken, expiration, nonce);
            return;
        }
        // The order has expired
        if (expiration < now) {
            msg.sender.transfer(msg.value);
            Failed(2, makerAddress, makerAmount, makerToken, takerAddress, takerAmount, takerToken, expiration, nonce);
            return;
        }
        
        bytes32 hash = validate(makerAddress, makerAmount, makerToken, takerAddress, takerAmount, takerToken, expiration, nonce, v, r, s);
        
        // This order has already been filled
        if (fills[hash]) {
            msg.sender.transfer(msg.value);
            Failed(3, makerAddress, makerAmount, makerToken, takerAddress, takerAmount, takerToken, expiration, nonce);
            return;
        }
        
        if (takerToken == address(0x0)) {
            if (msg.value == takerAmount) {
                fills[hash] = true;
                assert(transfer(makerAddress, takerAddress, makerAmount, makerToken));
                makerAddress.transfer(msg.value);
                Filled(makerAddress, makerAmount, makerToken, takerAddress, takerAmount, takerToken, expiration, nonce);
            } 
            // The ether sent with this transaction does not match takerAmount
            else {
                msg.sender.transfer(msg.value);
                Failed(4, makerAddress, makerAmount, makerToken, takerAddress, takerAmount, takerToken, expiration, nonce);
            }

        } else {
            if (msg.value != 0) {
                msg.sender.transfer(msg.value);
                // No ether is required for a trade between tokens
                Failed(5, makerAddress, makerAmount, makerToken, takerAddress, takerAmount, takerToken, expiration, nonce);
                return;
            }
            
            if (takerAddress == msg.sender) {
                fills[hash] = true;
                assert(trade(makerAddress, makerAmount, makerToken, takerAddress, takerAmount, takerToken));
                Filled(makerAddress, makerAmount, makerToken, takerAddress, takerAmount, takerToken, expiration, nonce);
            } 
            else {
                // The sender of this transaction must match the takerAddress
                Failed(6, makerAddress, makerAmount, makerToken, takerAddress, takerAmount, takerToken, expiration, nonce);
            }
        }
    }

    function cancel(address makerAddress, uint makerAmount, address makerToken,
                    address takerAddress, uint takerAmount, address takerToken,
                    uint256 expiration, uint256 nonce, uint8 v, bytes32 r, bytes32 s) {
                        
        bytes32 hash = validate(makerAddress, makerAmount, makerToken, takerAddress, takerAmount, takerToken, expiration, nonce, v, r, s);
        
        if (msg.sender == makerAddress) {
            if (fills[hash] == false) {
                fills[hash] = true;
                Canceled(makerAddress, makerAmount, makerToken, takerAddress, takerAmount, takerToken, expiration, nonce);
            } 
            else {
                // Order has already been cancelled or filled
                Failed(7, makerAddress, makerAmount, makerToken, takerAddress, takerAmount, takerToken, expiration, nonce);
            }
        }
    }
    
    // Function to swap tokens between two parties
    function trade(address makerAddress, uint makerAmount, address makerToken,
                   address takerAddress, uint takerAmount, address takerToken) private returns (bool) {
        return (transfer(makerAddress, takerAddress, makerAmount, makerToken) && transfer(takerAddress, makerAddress, takerAmount, takerToken));
    }

    // Function to transfer tokens from one party to another
    function transfer(address from, address to, uint amount, address token) private returns (bool) {
        require(ERC20(token).transferFrom(from, to, amount));
        return true;
    }
    
    // Function to validate order arguments
    function validate(address makerAddress, uint makerAmount, address makerToken,
                      address takerAddress, uint takerAmount, address takerToken,
                      uint256 expiration, uint256 nonce, uint8 v, bytes32 r, bytes32 s) private returns (bytes32) {
        bytes32 hashV = keccak256(makerAddress, makerAmount, makerToken, takerAddress, takerAmount, takerToken, expiration, nonce);
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHash = sha3(prefix, hashV);
        require(ecrecover(prefixedHash, v, r, s) == makerAddress);
        return hashV;
    }
}
