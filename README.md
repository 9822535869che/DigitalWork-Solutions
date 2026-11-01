# Freelance Escrow & Smart Payment Platform

ระบบจ้างงานฟรีแลนซ์และชำระเงินตามผลงานบน Ethereum ใช้ Smart Contract เป็นตัวกลางเก็บเงิน (Escrow) และจ่ายเงินให้ฟรีแลนซ์อัตโนมัติเมื่อผู้ว่าจ้างอนุมัติผลงาน

> โปรเจกต์ตัวอย่างเพื่อการศึกษา **ยังไม่ผ่านการ Audit** ใช้บนเครือข่ายทดสอบ (เช่น Sepolia) เท่านั้น ห้ามใช้เงินจริงหรือ Deploy บน Mainnet

---

## 1. ภาพรวม

บริษัท DigitalWork Solutions เป็นแพลตฟอร์มตัวกลางจับคู่ผู้ว่าจ้างกับฟรีแลนซ์ ปัญหาที่พบคือผู้ว่าจ้างบางรายไม่จ่ายเงินหลังได้รับงาน และฟรีแลนซ์บางรายไม่ส่งงานตามตกลง ระบบนี้แก้ปัญหาด้วย Smart Contract ที่ล็อกเงินค่าจ้างไว้จนกว่าเงื่อนไขจะครบ

**กฎทางธุรกิจสำคัญ**
- ห้ามจ่ายเงินซ้ำ (เมื่อจ่ายแล้ว ยอดใน Escrow ถูกตั้งเป็น 0 และสถานะเป็นสถานะสิ้นสุด)
- ห้ามเบิกเงินออกจาก Escrow หากยังไม่เข้าเงื่อนไขการอนุมัติหรือการตัดสินข้อพิพาท

## 2. ส่วนประกอบของโปรเจกต์

| ไฟล์ | หน้าที่ |
|---|---|
| `FreelanceEscrow.sol` | Smart Contract (Solidity ^0.8.24) |
| `freelance-escrow.html` | Frontend หน้าเดียว เชื่อมต่อ MetaMask ด้วย ethers.js v6 (โหลดจาก CDN) ไม่ต้องติดตั้งแพ็กเกจ |
| `README.md` | เอกสารนี้ |

## 3. ฟังก์ชันหลัก

| # | ฟังก์ชัน | ผู้ใช้ | รายละเอียด |
|---|---|---|---|
| 1 | Create Contract | Client | ระบุชื่อโครงการ รายละเอียด ค่าจ้าง กำหนดส่ง และ Wallet ของ Freelancer |
| 2 | Deposit Payment | Client | โอน ETH เข้า Contract ตามยอดที่ตกลงเป๊ะ ๆ |
| 3 | Submit Work | Freelancer | บันทึกหลักฐานส่งงาน (URL หรือ Hash) ต้องส่งก่อนกำหนด |
| 4 | Approve & Release | Client | ตรวจรับงานและอนุมัติ ระบบโอน ETH ให้ Freelancer อัตโนมัติ |
| 5 | Dispute Management | Client / Freelancer / Admin | คู่สัญญาแจ้งข้อพิพาท Admin ตัดสินคืนเงินหรือจ่ายเงิน |
| 6 | Transaction Tracking | ทุกบทบาท (ตามสิทธิ์) | ดูสถานะงาน ประวัติ และ Transaction Hash ผ่านหน้าเว็บ |
| + | Refund Expired Job | Client | ขอเงินคืนเมื่อเลยกำหนดและ Freelancer ไม่ส่งงาน (เพิ่มเติมจากโจทย์) |

### สถานะของงาน

```
Created ──ฝากเงิน──▶ Funded ──ส่งงาน──▶ Submitted ──อนุมัติ──▶ Completed
                       │                    │
                       │ เลยกำหนด+ไม่ส่งงาน │
                       ▼                    ▼
                    Refunded           Disputed ──Admin ตัดสิน──▶ Refunded / Completed
                       ▲
        (Funded ก็เปิดข้อพิพาทได้)
```

## 4. บทบาทและสิทธิ์ในหน้าเว็บ

บทบาทกำหนดจาก **Wallet ที่เชื่อมต่ออยู่** ไม่ใช่การกดสลับเอง

| บทบาท | วิธีระบุ | เมนูที่เห็น | ประวัติธุรกรรมที่ดูได้ |
|---|---|---|---|
| **Admin** | Wallet ที่ Deploy Contract (ค่า `admin()` ใน Contract) | ทุกหน้า | ทั้งหมด |
| **Client** | Admin ใส่ Address ในหน้า "เชื่อมต่อระบบ" | สร้างข้อตกลง, ฝากเงิน, อนุมัติ, คืนเงินหมดอายุ, เปิดข้อพิพาท, งานของฉัน, ตรวจสอบงาน, ประวัติ | สร้างงาน การจ่าย/คืนเงิน ข้อพิพาท ของงานที่ตัวเองว่าจ้าง |
| **Freelancer** | Admin ใส่ Address ในหน้า "เชื่อมต่อระบบ" | ส่งมอบงาน, เปิดข้อพิพาท, งานของฉัน, ตรวจสอบงาน, ประวัติ | เฉพาะรายการที่ได้รับเงิน |
| ผู้เยี่ยมชม | Wallet อื่น | เชื่อมต่อระบบ, ตรวจสอบงาน | ไม่มี |

> ข้อจำกัด: การซ่อนเมนูและการกรองประวัติทำเฉพาะในหน้าเว็บ รายการ Client/Freelancer เก็บใน `localStorage` ของเบราว์เซอร์ ส่วนสิทธิ์จริงบังคับโดย Smart Contract (เช่น เฉพาะ Client ของงานนั้นเท่านั้นที่อนุมัติได้) และข้อมูล Events บน Blockchain เป็นสาธารณะ ใครก็ดูผ่าน Etherscan ได้

## 5. สิ่งที่ต้องมี

- เบราว์เซอร์ที่ติดตั้ง **MetaMask** (เช่น Chrome)
- **SepoliaETH** สำหรับค่า Gas และค่าจ้างทดสอบ (ขอได้จาก Sepolia Faucet)
- Python (หรือ Node.js) สำหรับรันเซิร์ฟเวอร์ในเครื่อง
- MetaMask อย่างน้อย **3 Account** เพื่อทดสอบทั้ง 3 บทบาท

## 6. วิธีติดตั้งและใช้งาน

### 6.1 Deploy Smart Contract (Remix)

1. เปิด [Remix IDE](https://remix.ethereum.org) สร้างไฟล์ `FreelanceEscrow.sol` แล้ววางโค้ด
2. แท็บ **Solidity Compiler** เลือกเวอร์ชัน 0.8.24 ขึ้นไป แล้วกด Compile
3. แท็บ **Deploy & Run Transactions** ตั้ง Environment เป็น **Injected Provider – MetaMask** (ใช้ Remix VM ไม่ได้ เพราะหน้าเว็บเชื่อมไม่ถึง)
4. ตรวจว่า MetaMask อยู่บน **Sepolia** แล้วกด Deploy และ Confirm
5. คัดลอก **Contract Address** และจด **Block Number** จาก Etherscan ของ Transaction ที่ Deploy
6. Account ที่ Deploy จะเป็น **Admin** ของ Contract

### 6.2 รันหน้าเว็บ

อย่าดับเบิลคลิกเปิดไฟล์ (`file://`) เพราะ MetaMask มักไม่ทำงาน ให้รันเซิร์ฟเวอร์ในโฟลเดอร์ที่เก็บไฟล์:

```bash
python -m http.server 8000      # Windows ถ้าไม่ได้ผลให้ใช้: py -m http.server 8000
# หรือ
npx serve
```

จากนั้นเปิด `http://localhost:8000/freelance-escrow.html`

### 6.3 เชื่อมต่อระบบ

1. เมนู **เชื่อมต่อระบบ** วาง Contract Address
2. กด **เชื่อมต่อ MetaMask** แล้วกด Connect
3. ถ้าสำเร็จ แถบซ้ายจะแสดง Address, Chain ID และบทบาทของคุณ

### 6.4 ตั้งค่าบทบาท (ทำครั้งเดียว โดย Admin)

1. เชื่อมต่อด้วย Account ที่ Deploy (Admin)
2. ในหน้า **เชื่อมต่อระบบ** จะมีกล่อง "กำหนดบทบาทของ Wallet"
3. ใส่ Address ของ Client และ Freelancer (บรรทัดละ 1 Address) แล้วกด **บันทึกบทบาท**
4. สลับ Account ใน MetaMask แล้วกดเชื่อมต่อใหม่เพื่อใช้บทบาทนั้น

## 7. ขั้นตอนการทดสอบ (Test Flow)

### เส้นทางปกติ
1. **Client**: สร้างข้อตกลง (ใส่ Address ของ Freelancer) ได้ Job ID เช่น `#1`
2. **Client**: ฝากเงินตาม Job ID
3. **Freelancer**: ส่งมอบงาน (URL หรือ Hash)
4. **Client**: ตรวจรายละเอียดงาน แล้วอนุมัติและจ่ายเงิน → ETH ถูกโอนให้ Freelancer

### เส้นทางข้อพิพาท
สร้างงานใหม่ → ฝากเงิน → Client หรือ Freelancer เปิดข้อพิพาท → **Admin** ตัดสิน (คืนเงิน Client หรือจ่ายให้ Freelancer)

### เส้นทางหมดอายุ
สร้างงานที่ Deadline ใกล้ ๆ (เช่น 5 นาที) → ฝากเงิน → รอเลยกำหนด → Client กด "คืนเงินงานหมดอายุ"

### ข้อมูลทดสอบ

| ช่อง | ตัวอย่าง |
|---|---|
| ชื่อโครงการ | `ทดสอบเว็บไซต์ร้านกาแฟ` |
| รายละเอียด | `ออกแบบและพัฒนาเว็บไซต์ 3 หน้า` |
| ค่าจ้าง | `0.001` ETH |
| หลักฐานส่งงาน | `https://example.com/coffee-shop-demo` หรือ `URL \| sha256: <hash>` |

> หลักฐานส่งงานถูกบันทึกบน Blockchain สาธารณะและแก้ไขไม่ได้ ห้ามใส่ข้อมูลลับ

## 8. ประวัติธุรกรรมและ Deployment Block

หน้า **ประวัติธุรกรรม** อ่าน Events ของ Contract ย้อนหลังจาก **Deployment Block** (เลขบล็อกของเครือข่าย Sepolia ที่ Contract ถูกสร้าง ไม่ได้เริ่มจาก 0 เพราะเป็นเลขลำดับของบล็อกทั้งเครือข่าย)

- ใส่ Deployment Block ในหน้านี้แล้วกด **โหลดประวัติ** ระบบจำค่าไว้ให้
- ถ้าไม่ใส่ ระบบค้นย้อนหลังแค่ 20,000 บล็อกล่าสุดบนเครือข่ายจริง
- มีช่อง **ค้นหา Job ID** เพื่อกรองประวัติของงานเดียว
- การดึงข้อมูลแบ่งช่วงละ 3,000 บล็อกและลองซ้ำอัตโนมัติ เพื่อเลี่ยงข้อจำกัดของ RPC

## 9. สรุป Smart Contract

**ฟังก์ชันเขียน:** `createJob`, `depositPayment`, `submitWork`, `approveWork`, `openDispute`, `resolveDispute` (Admin), `refundExpiredJob`

**ฟังก์ชันอ่าน:** `getJob`, `getEscrowBalance`, `getJobStatus`, `getContractBalance`, `admin`, `nextJobId`

**Events:** `JobCreated`, `PaymentDeposited`, `WorkSubmitted`, `PaymentReleased`, `DisputeOpened`, `DisputeResolved`, `ClientRefunded`, `ExpiredJobRefunded`

**มาตรการความปลอดภัยที่มีในโค้ด**
- ป้องกัน Reentrancy ด้วย `nonReentrant`
- ใช้แนวทาง Checks-Effects-Interactions (ตั้งยอด Escrow เป็น 0 และเปลี่ยนสถานะก่อนโอน ETH)
- ฝากเงินได้ต้องตรงยอดเป๊ะและฝากได้ครั้งเดียวต่อหนึ่งงาน
- จ่ายเงินได้ครั้งเดียว (สถานะ Completed/Refunded เป็นสถานะสิ้นสุด)
- Client ห้ามจ้างตัวเอง
- เฉพาะ Admin เรียก `resolveDispute` ได้

**ข้อจำกัดที่ควรรู้**
- Admin คนเดียว (`immutable`) เปลี่ยนไม่ได้หลัง Deploy
- ข้อพิพาทเปิดได้เฉพาะสถานะ Funded หรือ Submitted
- `refundExpiredJob` เป็นกฎเพิ่มเติมจากโจทย์ ไม่ได้ระบุไว้โดยตรง
- ไม่รองรับการแก้ไขข้อตกลงหลังสร้าง ถ้าใส่ Address Freelancer ผิดต้องสร้างงานใหม่

## 10. แก้ปัญหาเบื้องต้น

| อาการ | สาเหตุ / วิธีแก้ |
|---|---|
| ไม่พบ MetaMask | เปิดผ่าน `http://localhost` ไม่ใช่ `file://` และเช็กว่าส่วนขยายเปิดอยู่ |
| `Only freelancer can submit` | Account ที่เชื่อมอยู่ไม่ตรงกับ Address Freelancer ของงานนั้น สลับ Account แล้วเชื่อมต่อใหม่ |
| `Incorrect ETH amount` | ยอดฝากต้องตรงค่าจ้างเป๊ะ ใช้ปุ่มฝากในเมนู ระบบใส่ยอดให้เอง |
| `Deadline must be in the future` | ตั้งกำหนดส่งเป็นเวลาในอนาคต |
| `could not coalesce error` | RPC ตอบผิดปกติ รอสักครู่แล้วลองใหม่ และเช็กว่า MetaMask อยู่บน Sepolia เดียวกับที่ Deploy |
| ประวัติธุรกรรมว่าง | ใส่ Deployment Block ให้น้อยกว่าหรือเท่ากับบล็อกที่ Deploy แล้วกด โหลดประวัติ |
| เมนูไม่ตรงบทบาท | Admin ต้องบันทึก Address ของ Client/Freelancer แล้วเชื่อมต่อใหม่ |
| อ่านข้อมูลจาก Contract ไม่ได้ | Contract Address ผิด หรือ MetaMask อยู่คนละเครือข่ายกับที่ Deploy |

## 11. เทคโนโลยีที่ใช้

- Solidity ^0.8.24
- ethers.js v6.13.5 (CDN)
- HTML / CSS / JavaScript (ไฟล์เดียว ไม่มี Build Step)
- MetaMask + Sepolia Testnet

## 12. ข้อควรระวัง

- เป็นโปรเจกต์เพื่อการเรียนรู้ ไม่ใช่โค้ดที่ผ่านการตรวจสอบความปลอดภัยสำหรับใช้งานจริง
- ห้ามใส่ Private Key ในโค้ดหรือหน้าเว็บ ระบบนี้ใช้การลงนามผ่าน MetaMask เท่านั้น
- ทดสอบบน Testnet ให้ครบทุกเส้นทางก่อนพิจารณานำไปใช้ต่อ
