# RWAPSSF.sol

จากปัญหาของเกม **RPS.sol** แบบเก่า เราจะเห็นได้ว่ามันมีข้อบกพร่องด้านความปลอดภัยและความไม่สะดวกในการใช้งานหลายอย่าง ซึ่งได้ถูกจัดการในเกม **RWAPSSF.sol แบบใหม่**

## Front-Running
ไม่มีใครอยากจะเลือกก่อน เพราะว่ากลัวถูกอีกคนทำ front-running (การได้ประโยชน์จากการรู้ล่วงหน้าว่าคนหนึ่งเลือกอะไร)

โดยการใช้การบวนการ **commit-reveal** เราสามารถแก้ปัญหาได้ดังนี้
 - ทำการ commit ผลลัพธ์การ hash ที่เกิดจากตัวเลือกของผู้เล่นรวมกับ salt ที่ผู้เล่นเลือก 
 ```solidity
 function input(uint choice, string memory salt) public {
	//hash input with salt and then commit
	require(numPlayer== 2);
	require(msg.sender == player[playerId[msg.sender]].addr);
	require(player[playerId[msg.sender]].playTime == 0);
	require(choice >= 0 && choice <= 6); // 0 <= choice <= 6
	bytes32 saltHash = keccak256(abi.encodePacked(salt));
	commit(getSaltedHash(bytes32(choice), saltHash));
	player[playerId[msg.sender]].playTime = block.timestamp;
	numInput++;
}
```
- ทำการ reveal คำตอบเมื่อผู้เล่นทั้งสองเลือกคำตอบแล้ว และประกาศผลเมื่อทั้งสอง reveal ครบ
```solidity
function revealMyChoice(uint choice, string memory salt)  public {
	//reveal the answer with the given salt
	require(numInput == 2);
	require(msg.sender == player[playerId[msg.sender]].addr);
	bytes32 saltHash = keccak256(abi.encodePacked(salt));
	revealAnswer(bytes32(choice), saltHash);
	player[playerId[msg.sender]].choice = choice;
	player[playerId[msg.sender]].revealTime = block.timestamp;
	numReveal++;
	if  (numReveal == 2)  {
		_checkWinnerAndPay();
	}
}
```

## Unknown Player ID
ผู้เล่นจะมี ID เป็นของตัวเองเมื่อทำการเข้าร่วมเกม แต่ผู้เล่นจะไม่สามารถรู้ ID ของตัวเองได้นอกจากจะใช้วิธีเดาสุ่ม 
 - mapping ระหว่าง account ของผู้เล่นกับ ID 
 ```solidity
 mapping (address => uint) public playerId;
 ```
 - ผู้เล่นไม่จำเป็นต้องรู้ ID ของตัวเองอีกต่อไป แต่สามารถเล่นได้โดยใช้ msg.sender 
```solidity
uint idx = playerId[msg.sender];
 ```

## One-Time Contract
จากเดิม Contract นี้จะไม่สามารถเล่นซ้ำได้ จะต้อง deploy ใหม่ จึงสร้างฟังก์ชั่นสำหรับ reset state ต่างๆที่เกิดขึ้น ใช้เตรียมพร้อมสำหรับเกมถัดไป
```solidity
function reset() private {
	//clean all the states
	numPlayer = 0;
	reward = 0;
	numInput = 0;
	numReveal = 0;
	delete player[0];
	delete player[1];
	delete playerId[player[0].addr];
	delete playerId[player[1].addr];
}
 ```
 
 ## RPS to RWAPSSF
 เพิ่มกติกาจากเดิม Rock Paper Scissors เป็น Rock Water Air Paper Sponge Scissors Fire โดยให้เทคนิค Modulation ดังนี้
 ```solidity
if ((p0Choice + 1) % 7 == p1Choice || (p0Choice +  2) % 7 == p1Choice || (p0Choice + 3) % 7 == p1Choice) {
	// to pay player[1]
	account1.transfer(reward);
}
else if ((p1Choice + 1) % 7 == p0Choice || (p1Choice + 2) % 7 == p0Choice || (p1Choice + 3) % 7 == p0Choice) {
	// to pay player[0]
	account0.transfer(reward);
}
else {
	// to split reward
	account0.transfer(reward / 2);
	account1.transfer(reward / 2);
}
 ```

## Money Locked
เนื่องจากเป็นเกมที่ต้องอาศัย 2 ผู้เล่น ทำให้อาจเกิดปัญหาเงินรางวัลติดอยู่ใน contract เมื่อมีผู้เล่นที่ไม่ดำเนินเกม ผู้เล่นจึงควรที่จะสามารถถอนเงินรางวัลออกมาได้เมื่อเวลาผ่านไปนานเกินไป แบ่งได้เป็น 3 กรณี

 - ไม่มีผู้เล่นที่สอง
 ```solidity
 if (numPlayer == 1) {
	//no one join the game
	require(block.timestamp - player[idx].joinTime > waitingTime);
	address payable account = payable(player[idx].addr);
	account.transfer(reward);
	reset();
}
 ```
 - ผู้เล่นอีกคนไม่ Reveal คำตอบ
```solidity
else {
	//opponent not pick a choice
	require(player[idx].playTime != 0);
	require(block.timestamp - player[idx].playTime > waitingTime);
	require(player[opponent].playTime == 0);
	address payable account = payable(player[idx].addr);
	account.transfer(reward);
	reset();
}
 ```
 - ผู้เล่นอีกคนไม่เลือกคำตอบ
 ```solidity
if (numInput ==  2) {
	//opponent not reveal his answer
	require(player[idx].revealTime > waitingTime);
	require(player[opponent].choice == 7);
	address payable account = payable(player[idx].addr);
	account.transfer(reward);
	reset();
}
 ```

## Screenshot
 - **มีผู้แพ้ชนะ** ให้ player 0 ออก Rock(0) และให้ player 1 ออก Sponge(4) ดังนั้น player 0 ชนะ player 1  
 ![ก่อนเล่น](https://i.ibb.co/6RYCfL0/Screenshot-2567-02-12-at-22-59-08.png)  
 ![Player 0 เลือก 0](https://i.ibb.co/2cv2j7q/Screenshot-2567-02-12-at-22-59-27.png)  
 ![Player 1 เลือก 4](https://i.ibb.co/gtwjqtp/Screenshot-2567-02-12-at-22-59-40.png)  
 ![ผลลัพธ์](https://i.ibb.co/BZzQnMS/Screenshot-2567-02-12-at-23-00-14.png)  
 - **เสมอ** ให้ player 0 และ player 1 ออก Scissors(5)  
 ![ก่อนเล่น](https://i.ibb.co/b1HDsnN/Screenshot-2567-02-12-at-23-01-55.png)  
![Player 1 เลือก 5](https://i.ibb.co/LdSqVG4/Screenshot-2567-02-12-at-23-02-03.png)  
![Player 0 เลือก 5](https://i.ibb.co/TrPt6MR/Screenshot-2567-02-12-at-23-02-15.png)  
![ผลลัพธ์](https://i.ibb.co/16DwQvk/Screenshot-2567-02-12-at-23-02-40.png)  