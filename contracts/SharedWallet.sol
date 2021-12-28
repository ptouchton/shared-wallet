// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.1;

import "@openzeppelin/contracts/access/Ownable.sol";

contract SharedWallet is Ownable {
    struct Payment {
        uint256 payment;
        uint256 timestamp;
    }

    struct Balance {
        uint256 totalBalance;
        uint256 numPayments;
        mapping(uint256 => Payment) payments;
    }

    mapping(address => Balance) public balanceReceived;

    uint256 public lockedUntil;

    /// The amount of Ether sent was not higher than
    /// the currently highest amount.
    error NotEnoughEther();

    modifier ownerOrAllowed(uint256 _amount) {
        require(
            owner() == msg.sender ||
                balanceReceived[msg.sender].totalBalance >= _amount,
            "You are not allowed"
        );
        _;
    }

    event AllowanceChanged(
        address indexed _forWho,
        address indexed _fromWhom,
        uint256 _oldAmount,
        uint256 _newAmount
    );

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getMyBalance(address _me) public view returns (uint256) {
        return balanceReceived[_me].totalBalance;
    }

    function receiveMoney() public payable {
        require(
            balanceReceived[msg.sender].totalBalance + msg.value >
                balanceReceived[msg.sender].totalBalance,
            "Amount should be greater than zero"
        );
        balanceReceived[msg.sender].totalBalance += msg.value;

        Payment memory payment = Payment(msg.value, block.timestamp);
        balanceReceived[msg.sender].payments[
            balanceReceived[msg.sender].numPayments
        ] = payment;
        balanceReceived[msg.sender].numPayments++;
        lockedUntil = block.timestamp + 1 minutes;
    }

    function addAllowance(address payable _to, uint256 _amt) public payable {
        require(
            _amt < balanceReceived[msg.sender].totalBalance,
            "Not enough ether"
        );
        assert(
            balanceReceived[msg.sender].totalBalance >=
                balanceReceived[msg.sender].totalBalance - _amt
        );

        emit AllowanceChanged(
            _to,
            msg.sender,
            balanceReceived[_to].totalBalance,
            balanceReceived[_to].totalBalance += _amt
        );

        balanceReceived[msg.sender].totalBalance -= _amt;

        Payment memory payment = Payment(_amt, block.timestamp);
        balanceReceived[_to].totalBalance += _amt;
        balanceReceived[_to].payments[
            balanceReceived[msg.sender].numPayments
        ] = payment;
        balanceReceived[_to].numPayments++;

        lockedUntil = block.timestamp + 1 minutes;
    }

    function withdrawMoney(address payable _to, uint256 _amt)
        public
        ownerOrAllowed(_amt)
    {
        require(
            _amt <= address(this).balance,
            "There are not enough funds in the smart contract"
        );
        if (lockedUntil < block.timestamp) {
            emit AllowanceChanged(
                _to,
                msg.sender,
                balanceReceived[msg.sender].totalBalance,
                balanceReceived[msg.sender].totalBalance -= _amt
            );
            balanceReceived[msg.sender].totalBalance -= _amt;

            _to.transfer(_amt);
        }
    }

    function convertWeiToEth(uint256 _amount) public pure returns (uint256) {
        return _amount / 1 ether;
    }

    receive() external payable {
        receiveMoney();
    }
}
