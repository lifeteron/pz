#!/bin/bash

# 파란색 굵은 텍스트를 출력하는 함수 정의
function echo_blue_bold {
    echo -e "\033[1;34m$1\033[0m"
}
echo

# 컬러 정의
export RED='\033[0;31m'
export YELLOW='\033[1;33m'
export GREEN='\033[0;32m'
export NC='\033[0m'  # No Color

# 사용자로부터 여러 프라이빗 키 입력받기
read -p "메타마스크 프라이빗 키를 콤마로 구분하여 입력하세요.버너지갑을 사용하세요. (예: key1,key2,...): " user_private_keys

# 프라이빗 키 입력 검증
if [ -z "$user_private_keys" ]; then
  echo_blue_bold "${RED}오류: 프라이빗 키를 입력하지 않았습니다.${NC}"
  exit 1
fi

# 프라이빗 키를 배열로 변환
IFS=',' read -r -a private_keys_array <<< "$user_private_keys"

# 프라이빗 키가 유효한지 확인
for key in "${private_keys_array[@]}"; do
  if [ ${#key} -ne 64 ]; then
    echo_blue_bold "${RED}오류: 프라이빗 키는 64자리 16진수 문자열이어야 합니다.${NC}"
    exit 1
  fi
done

# 기존 privatekeys.txt 파일이 있으면 삭제
if [ -f privatekeys.txt ]; then
  rm privatekeys.txt
  echo_blue_bold "기존 privatekeys.txt 파일을 삭제했습니다."
fi

# 새로운 privatekeys.txt 파일 생성 및 프라이빗 키 추가
for key in "${private_keys_array[@]}"; do
  echo "$key" >> privatekeys.txt
done
echo_blue_bold "새로운 privatekeys.txt 파일이 생성되고 프라이빗 키가 추가되었습니다."
echo

# ethers 패키지가 설치되어 있지 않으면 설치, 이미 설치되어 있으면 메시지 출력
if ! npm list ethers@5.5.4 >/dev/null 2>&1; then
  echo_blue_bold "ethers 패키지를 설치 중..."
  npm install ethers@5.5.4
  echo
else
  echo_blue_bold "ethers 패키지가 이미 설치되어 있습니다."
fi
echo

# 임시 Node.js 스크립트 파일 생성
temp_node_file=$(mktemp /tmp/node_script.XXXXXX.js)

# Node.js 스크립트 내용을 임시 파일에 작성
cat << EOF > $temp_node_file
const fs = require("fs");
const ethers = require("ethers");

// privatekeys.txt 파일에서 개인 키를 읽어와 줄바꿈을 기준으로 배열로 저장
const privateKeys = fs.readFileSync("privatekeys.txt", "utf8").trim().split("\\n").filter(key => key.trim() !== "");

// 이더리움 공급자 URL 설정
const providerURL = "https://testnet-rpc.plumenetwork.xyz/http";
const provider = new ethers.providers.JsonRpcProvider(providerURL);

// 스마트 계약 주소 및 트랜잭션 데이터 설정
const contractAddress = "0x8Dc5b3f1CcC75604710d9F464e3C5D2dfCAb60d8";
const transactionData = "0x183ff085";
const numberOfTransactions = 1;  // 보낼 트랜잭션 수 설정

// 트랜잭션을 보내는 비동기 함수 정의
async function sendTransaction(wallet) {
    // 현재 블록의 기본 수수료를 가져오기
    const block = await provider.getBlock("latest");
    const baseFee = block.baseFeePerGas;  // 블록 기본 수수료

    // 적절한 maxPriorityFeePerGas와 maxFeePerGas 설정
    const maxPriorityFeePerGas = ethers.utils.parseUnits("1.0", "gwei");  // 우선 수수료 1 Gwei
    const maxFeePerGas = baseFee.add(ethers.utils.parseUnits("0.5", "gwei"));  // 기본 수수료 + 0.5 Gwei 우선 수수료

    const tx = {
        to: contractAddress,  // 스마트 계약 주소로 트랜잭션 전송
        value: 0,             // 전송할 이더리움 값 (0으로 설정)
        gasLimit: ethers.BigNumber.from(600000),  // 가스 리미트 설정
        maxPriorityFeePerGas: maxPriorityFeePerGas,  // 우선 수수료 설정
        maxFeePerGas: maxFeePerGas,  // 최대 수수료 설정
        data: transactionData,  // 트랜잭션 데이터 설정
    };

    try {
        // 트랜잭션 전송 및 결과 대기
        const transactionResponse = await wallet.sendTransaction(tx);
        console.log("\033[1;35m트랜잭션 해시:\033[0m", transactionResponse.hash);
        const receipt = await transactionResponse.wait();  // 트랜잭션 확인 대기
        console.log("");
    } catch (error) {
        console.error("트랜잭션 전송 중 오류 발생:", error);
    }
}

// 메인 비동기 함수 정의
async function main() {
    // 각 개인 키에 대해 트랜잭션을 전송
    for (const key of privateKeys) {
        // 프라이빗 키가 올바른 형식인지 확인
        if (key.length !== 64) {
            console.error("유효하지 않은 프라이빗 키:", key);
            continue;
        }

        try {
            const wallet = new ethers.Wallet(key, provider);
            for (let i = 0; i < numberOfTransactions; i++) {
                console.log("지갑에서 체크인 중:", wallet.address);
                await sendTransaction(wallet);  // 트랜잭션 전송
            }
        } catch (error) {
            console.error("유효하지 않은 프라이빗 키:", key, error);
        }
    }
}

// 메인 함수 실행 및 오류 출력
main().catch(console.error);
EOF

# Node.js 스크립트 실행
NODE_PATH=$(npm root -g):$(pwd)/node_modules node $temp_node_file

# 임시 Node.js 스크립트 파일 삭제
rm $temp_node_file
echo

# 안내 메시지 출력
echo -e "${GREEN}모든 작업이 완료되었습니다.${NC}"
echo -e "${GREEN}ㅇㅇ${NC}"
