#!/bin/bash

# 컬러 및 출력 함수 정의
echo_blue_bold() { echo -e "\033[1;34m$1\033[0m"; }
export RED='\033[0;31m' YELLOW='\033[1;33m' GREEN='\033[0;32m' NC='\033[0m'

# 사용자로부터 프라이빗 키 입력받기
read -p "메타마스크 프라이빗 키를 콤마로 구분하여 입력하세요. 버너지갑을 사용하세요. (예: key1,key2,...): " user_private_keys
[ -z "$user_private_keys" ] && echo_blue_bold "${RED}오류: 프라이빗 키를 입력하지 않았습니다.${NC}" && exit 1

# 프라이빗 키 배열로 변환 및 검증
IFS=',' read -r -a private_keys_array <<< "$user_private_keys"
for key in "${private_keys_array[@]}"; do
  [ ${#key} -ne 64 ] && echo_blue_bold "${RED}오류: 프라이빗 키는 64자리 16진수 문자열이어야 합니다.${NC}" && exit 1
done

# ethers 패키지 설치 확인
if ! npm list ethers@5.5.4 >/dev/null 2>&1; then
  echo_blue_bold "ethers 패키지를 설치 중..." && npm install ethers@5.5.4
else
  echo_blue_bold "ethers 패키지가 이미 설치되어 있습니다."
fi

# Node.js 스크립트 실행
NODE_PATH=$(npm root -g):$(pwd)/node_modules node - << 'EOF'
const ethers = require("ethers");

// 사용자로부터 프라이빗 키를 받음
const privateKeys = process.env.PRIVATE_KEYS.split(',');
const provider = new ethers.providers.JsonRpcProvider("https://testnet-rpc.plumenetwork.xyz/http");
const contractAddress = "0x8Dc5b3f1CcC75604710d9F464e3C5D2dfCAb60d8";
const transactionData = "0x183ff085";
const numberOfTransactions = 1;

async function sendTransaction(wallet) {
    const block = await provider.getBlock("latest");
    const maxFeePerGas = block.baseFeePerGas.add(ethers.utils.parseUnits("0.5", "gwei"));
    const tx = {
        to: contractAddress,
        value: 0,
        gasLimit: 600000,
        maxPriorityFeePerGas: ethers.utils.parseUnits("1.0", "gwei"),
        maxFeePerGas,
        data: transactionData,
    };
    try {
        const txResponse = await wallet.sendTransaction(tx);
        console.log("\033[1;35m트랜잭션 해시:\033[0m", txResponse.hash);
        await txResponse.wait();
    } catch (error) {
        console.error("트랜잭션 전송 중 오류 발생:", error);
    }
}

async function main() {
    for (const key of privateKeys) {
        if (key.length !== 64) {
            console.error("유효하지 않은 프라이빗 키:", key);
            continue;
        }
        try {
            const wallet = new ethers.Wallet(key, provider);
            for (let i = 0; i < numberOfTransactions; i++) {
                console.log("지갑에서 체크인 중:", wallet.address);
                await sendTransaction(wallet);
            }
        } catch (error) {
            console.error("유효하지 않은 프라이빗 키:", key, error);
        }
    }
}

main().catch(console.error);
EOF

# 메모리에서 프라이빗 키 삭제
unset user_private_keys private_keys_array
echo -e "${GREEN}모든 작업이 완료되었습니다.${NC}"
echo -e "${GREEN}FIN AND DEL ${NC}"
