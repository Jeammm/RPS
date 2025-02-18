// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract RPS {
    struct Player {
        uint choice; // 0 - Rock, 1 - Paper , 2 - Scissors, 3 - undefined
        address addr;
        uint joinTime;
        uint playTime;
    }

    uint waitingTime = 10;

    uint public numPlayer = 0;
    uint public reward = 0;
    mapping (uint => Player) public player;
    uint public numInput = 0;

    function addPlayer() public payable {
        require(numPlayer < 2);
        require(msg.value == 1 ether);
        reward += msg.value;
        player[numPlayer].addr = msg.sender;
        player[numPlayer].choice = 3;
        player[numPlayer].joinTime = block.timestamp;
        player[numPlayer].playTime = 0;
        numPlayer++;
    }

    function input(uint choice, uint idx) public  {
        require(numPlayer == 2);
        require(msg.sender == player[idx].addr);
        require(choice == 0 || choice == 1 || choice == 2);
        player[idx].choice = choice;
        player[idx].playTime = block.timestamp;
        numInput++;
        if (numInput == 2) {
            _checkWinnerAndPay();
        }
    }

    function _checkWinnerAndPay() private {
        uint p0Choice = player[0].choice;
        uint p1Choice = player[1].choice;
        address payable account0 = payable(player[0].addr);
        address payable account1 = payable(player[1].addr);
        if ((p0Choice + 1) % 3 == p1Choice) {
            // to pay player[1]
            account1.transfer(reward);
        }
        else if ((p1Choice + 1) % 3 == p0Choice) {
            // to pay player[0]
            account0.transfer(reward);    
        }
        else {
            // to split reward
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
        }
        reset();
    }

    function withdrawn(uint idx) public {
        require(msg.sender == player[idx].addr);

        if (numPlayer == 1) {
            require(block.timestamp - player[idx].joinTime > waitingTime);
            address payable account = payable(player[idx].addr);
            account.transfer(reward);
            reset();
        }

        uint opponent;
        if (idx == 0) {
            opponent = 1;
        } else {
            opponent = 0;
        }

        if (numPlayer == 2) {
            require(player[idx].playTime != 0);
            require(block.timestamp - player[idx].playTime > waitingTime);
            require(player[opponent].playTime == 0);
            address payable account = payable(player[idx].addr);
            account.transfer(reward);
            reset();
        }
    }

    function reset() private {
        numPlayer = 0;
        reward = 0;
        numInput = 0;
        delete player[0];
        delete player[1];
    }
}