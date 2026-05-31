FOLDER chính cho bài test

1. contract -> chứa contract dự án
2. commons/ethereum.service.go -> service tương tác với smartcontract đã được deploy
3. modules ->folder chứa các handler, service xử lý api

FOLDER project
1. utils -> chứa các hàm cho các service 
2. commons chứa các core xử lý và shared như middlewares, error, models, repositories...
3. config -> setting và mapping env file vào biến toàn cục
4. docs ->swager tự tạo
5. servcer -> xử lý tạo server, tạo router

INSTALL

1. chạy lệnh build solcjs --bin --abi -o build ./contract/AttendanceTracker.sol 
-> folder sinh ra 2 file là .bin, .abi copy content vào .env CONTRACT_ABI hoặc tên SOL_BUILD_FILE
2. Cần cài và tạo ví metamask cần chuyển qua mạng test để deploy(cần phí gas).
- vào https://www.infura.io/faucet/sepolia để lấy eth test(do cơ chế chống spam của infura nên address phải có giao dịch)
- lấy privatekey(cần cực kỳ bảo mật không đưa và tiết lộ cho ai) của ví và cho vào PRIVATE_KEY của .env để deploy
3. tạo account trên các dịch vụ node cho deploy trên sepolia ví dụ alchemy.com hoặc các bên cung cấp

4. go run main.go để chạy project và chạy router get http://localhost:8080/api/v1/attendance/deploy
- nếu router trả về với ContractAddress thì copy bỏ vào CONTRACT_CREATION của .env

* https://sepolia.etherscan.io/address/0xf5Ef119E5558575666Ceb26159A353c3A01fe4a1
* address đã tạo và deploy trong 3 ngày qua với create, put cho checkin của nhân viên
* https://sepolia.etherscan.io/address/0x451b09094485588e877a9113d2256785c30fc381
* smartcontract cho checkin và checkout transaction

API: http://localhost:8080/api/v1/swagger/index.html

- POST http://localhost:8080/api/v1/attendance : create(checkin) record lên blockchain
- PUT http://localhost:8080/api/v1/attendance : update(checkout) record lên blockchain
- GET http://localhost:8080/api/v1/attendance?employeeId=1 -> cho lấy checkin theo employeeId
- GET http://localhost:8080/api/v1/attendance?startDate=timestamp&endDate=timestamp -> cho lấy checkin theo range date

Các chức năng còn thiếu: unitest cho smart contract và các function của api