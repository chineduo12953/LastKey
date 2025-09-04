# 🔐 LastKey - Dead Man's Switch Smart Contract

> **Secure document release system that automatically releases encrypted documents to beneficiaries after periods of inactivity** 💀⚡

## 🌟 Overview

LastKey is a Clarity smart contract that implements a "Dead Man's Switch" mechanism on the Stacks blockchain. It allows users to securely store document hashes that will be automatically released to designated beneficiaries if the owner fails to check in within a specified time period.

## ✨ Features

- 🔒 **Secure Document Storage** - Store encrypted document hashes on-chain
- ⏰ **Customizable Inactivity Periods** - Set your own timeout periods
- 👥 **Beneficiary Management** - Designate who receives access when triggered
- 🔄 **Regular Check-ins** - Reset the timer by checking in periodically
- 📊 **Status Monitoring** - Track switch status and time remaining
- 🗑️ **Switch Management** - Update or delete switches before release

## 🚀 Quick Start

### Creating a Dead Man's Switch

```clarity
(contract-call? .LastKey create-switch 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7  ;; beneficiary
  "a1b2c3d4e5f6..."                              ;; document hash
  u604800)                                        ;; 1 week in seconds
```

### Checking In (Reset Timer)

```clarity
(contract-call? .LastKey checkin)
```

### Releasing Documents (Anyone Can Call)

```clarity
(contract-call? .LastKey release-document 
  'SP1234567890ABCDEF...)  ;; owner's principal
```

## 📋 Core Functions

### 🔧 Management Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `create-switch` | Create a new dead man's switch | `beneficiary`, `document-hash`, `inactivity-period` |
| `checkin` | Reset the inactivity timer | None |
| `update-beneficiary` | Change the beneficiary | `new-beneficiary` |
| `update-document` | Update the document hash | `new-document-hash` |
| `update-inactivity-period` | Change the timeout period | `new-period` |
| `delete-switch` | Remove your switch | None |

### 🔍 Query Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `get-switch` | Get switch details | Switch data or none |
| `get-switch-status` | Get comprehensive status | Status object with timing info |
| `is-switch-expired` | Check if switch has expired | Boolean |
| `get-time-until-expiry` | Time remaining before expiry | Seconds remaining |
| `get-released-document` | Get released document info | Release data or none |

### ⚡ Action Functions

| Function | Description | Who Can Call |
|----------|-------------|--------------|
| `release-document` | Trigger document release | Anyone (if expired) |

## 🎯 Use Cases

- 📄 **Legal Documents** - Wills, trusts, and legal instructions
- 🔑 **Cryptocurrency Access** - Wallet recovery information
- 💼 **Business Continuity** - Critical business information and passwords
- 👨‍👩‍👧‍👦 **Family Emergency Plans** - Important family information and contacts
- 🏥 **Medical Information** - Health directives and medical history

## 🛡️ Security Features

- ✅ Only document owners can manage their switches
- ✅ Documents can only be released after the inactivity period expires
- ✅ Beneficiaries are cryptographically verified
- ✅ All actions are recorded on the immutable blockchain
- ✅ No central authority can interfere with the process

## ⚠️ Error Codes

| Code | Error | Description |
|------|-------|-------------|
| `u100` | `ERR_UNAUTHORIZED` | Caller not authorized |
| `u101` | `ERR_NOT_FOUND` | Switch not found |
| `u102` | `ERR_ALREADY_EXISTS` | Switch already exists |
| `u103` | `ERR_INVALID_PERIOD` | Invalid inactivity period |
| `u104` | `ERR_NOT_EXPIRED` | Switch hasn't expired yet |
| `u105` | `ERR_ALREADY_RELEASED` | Document already released |

## 🔄 Typical Workflow

1. **Setup** 🏗️ - Create switch with beneficiary and document hash
2. **Maintain** 🔄 - Regular check-ins to reset timer
3. **Monitor** 👀 - Track status and time remaining
4. **Release** 🚀 - Automatic release when timer expires
5. **Access** 📖 - Beneficiary retrieves document information

## 🧪 Testing

Use Clarinet to test the contract:

```bash
clarinet test
```

```bash
clarinet console
```

## 📝 Example Usage

```clarity
;; Create a switch for a 30-day period
(contract-call? .LastKey create-switch 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 
  "QmX1B2C3D4E5F6789ABCDEF..." 
  u2592000)

;; Check in weekly to reset timer
(contract-call? .LastKey checkin)

;; Check status
(contract-call? .LastKey get-switch-status tx-sender)

;; After 30 days of inactivity, anyone can release
(contract-call? .LastKey release-document 'SP1234...)
```

## 🤝 Contributing

Feel free to submit issues and enhancement requests! 

## 📄 License

This project is open source and available under the MIT License.

---

**⚠️ Important**: This contract handles sensitive information. Always test thoroughly and consider professional security audits before using in production environments.


