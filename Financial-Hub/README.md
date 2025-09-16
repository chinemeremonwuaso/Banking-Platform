# SecureStack Digital Banking Platform Smart Contract

## Overview

SecureStack is a comprehensive digital banking platform smart contract built on the Stacks blockchain. This contract provides a complete banking solution with account management, secure transactions, daily withdrawal limits, and robust security features.

## Features

### Account Management
- **Account Creation**: Users can establish banking accounts with automatic initialization
- **Security Protection**: Multi-level account security with encrypted hash protection
- **Account Locking/Unlocking**: Secure authentication system with configurable attempt limits
- **User Analytics**: Comprehensive tracking of user activity and transaction history

### Core Banking Operations
- **Deposits**: Secure fund deposits with validation and balance updates
- **Withdrawals**: Controlled withdrawals with fees, daily limits, and security checks
- **Peer-to-Peer Transfers**: Direct transfers between registered users
- **Transaction Logging**: Complete audit trail for all financial operations

### Security Features
- **Account Locking**: Automatic account protection after failed authentication attempts
- **Daily Withdrawal Limits**: Configurable daily withdrawal restrictions
- **Account Suspension**: Administrative control for account freezing
- **Emergency Controls**: System-wide emergency shutdown capabilities
- **Minimum Balance Requirements**: Configurable minimum account balance enforcement

### Administrative Controls
- **System Status Management**: Control over operational status and maintenance mode
- **Fee Configuration**: Adjustable withdrawal processing fees
- **Limit Management**: Configurable withdrawal thresholds and attempt limits
- **Emergency Fund Recovery**: Administrative fund extraction capabilities
- **User Account Management**: Administrative unlock and suspension controls

## Constants and Configuration

### System Configuration
- **Platform Administrator**: Contract deployer has full administrative privileges
- **Processing Fees**: 1 STX standard processing fee for withdrawals
- **Default Withdrawal Limit**: 1,000 STX per day
- **Transaction Limits**: Single transaction maximum of 100,000 STX
- **Security Attempts**: Default 3 attempts before account lockout

### Error Codes
- `u100`: Unauthorized access
- `u101`: Insufficient funds
- `u102`: Invalid transaction amount
- `u103`: Daily withdrawal limit exceeded
- `u104`: Banking system offline
- `u106`: Customer account does not exist
- `u107`: Customer account already exists
- `u108`: Self-transfer not allowed
- `u109`: Transaction fee too high
- `u110`: Limit below minimum threshold
- `u111`: Limit exceeds maximum threshold
- `u112`: Customer account is locked
- `u113`: Invalid security code
- `u114`: Maximum unlock attempts reached
- `u116`: Security attempt limit out of bounds
- `u118`: Account freeze active
- `u119`: Maintenance mode active
- `u120`: Invalid security level

## Public Functions

### User Functions

#### `establish-customer-banking-account`
Creates a new banking account for the caller.
- **Returns**: `(response bool uint)`
- **Requirements**: System must be operational, user must not already have an account

#### `configure-account-security-protection`
Sets up account security with encrypted hash and protection level.
- **Parameters**: 
  - `security-hash` (buff 32): Encrypted security credential
  - `protection-level` (uint): Security level (1-5)
- **Returns**: `(response bool uint)`

#### `authenticate-and-unlock-account`
Unlocks a locked account using the correct security credential.
- **Parameters**: 
  - `provided-security-credential` (buff 32): Security hash for authentication
- **Returns**: `(response bool uint)`

#### `process-account-deposit`
Deposits STX tokens into the user's account.
- **Parameters**: 
  - `deposit-amount` (uint): Amount to deposit in micro-STX
- **Returns**: `(response uint uint)`

#### `process-account-withdrawal`
Withdraws STX tokens from the user's account with fees.
- **Parameters**: 
  - `withdrawal-amount` (uint): Amount to withdraw in micro-STX
- **Returns**: `(response uint uint)`

#### `execute-peer-to-peer-transfer`
Transfers funds between two registered users.
- **Parameters**: 
  - `recipient-account` (principal): Recipient's account address
  - `transfer-amount` (uint): Amount to transfer in micro-STX
- **Returns**: `(response uint uint)`

### Administrative Functions

#### `modify-system-operational-state`
Controls the operational status of the banking system.
- **Parameters**: 
  - `new-operational-status` (bool): New operational state
- **Access**: Administrator only

#### `toggle-platform-maintenance-mode`
Enables or disables maintenance mode.
- **Parameters**: 
  - `maintenance-status` (bool): Maintenance mode state
- **Access**: Administrator only

#### `adjust-withdrawal-processing-fee`
Updates the withdrawal processing fee.
- **Parameters**: 
  - `updated-fee` (uint): New fee amount in micro-STX
- **Access**: Administrator only

#### `configure-daily-withdrawal-threshold`
Sets the daily withdrawal limit for all users.
- **Parameters**: 
  - `updated-threshold` (uint): New daily limit in micro-STX
- **Access**: Administrator only

#### `administrator-emergency-account-unlock`
Emergency unlock for any user account.
- **Parameters**: 
  - `locked-user-account` (principal): Account to unlock
- **Access**: Administrator only

#### `configure-security-attempt-threshold`
Sets the maximum security unlock attempts.
- **Parameters**: 
  - `updated-attempt-limit` (uint): New attempt limit (1-10)
- **Access**: Administrator only

#### `execute-emergency-fund-extraction`
Emergency fund recovery for the administrator.
- **Parameters**: 
  - `extraction-amount` (uint): Amount to extract in micro-STX
- **Access**: Administrator only

#### `administrator-account-suspension-control`
Controls user account suspension status.
- **Parameters**: 
  - `target-user-account` (principal): Account to modify
  - `suspension-status` (bool): Suspension state
- **Access**: Administrator only

#### `configure-minimum-balance-requirement`
Sets the minimum balance requirement for all accounts.
- **Parameters**: 
  - `updated-minimum-balance` (uint): New minimum balance in micro-STX
- **Access**: Administrator only

#### `activate-emergency-system-shutdown`
Emergency system shutdown control.
- **Parameters**: 
  - `shutdown-status` (bool): Shutdown state
- **Access**: Administrator only

## Data Storage

### Maps
- `user-account-balances`: User account balance tracking
- `user-daily-withdrawal-records`: Daily withdrawal amount tracking
- `platform-registered-users`: User registration status
- `user-security-configurations`: Account security settings and status
- `platform-transaction-ledger`: Complete transaction history
- `user-account-analytics`: User activity and statistics

### Global Variables
- System operational status and maintenance mode
- Platform-wide fee and limit configurations
- Transaction processing statistics
- User account counters and emergency controls

## Security Considerations

1. **Access Control**: All administrative functions are restricted to the platform administrator
2. **Input Validation**: All transaction amounts and parameters are validated
3. **Account Protection**: Multiple layers of account security including locking and suspension
4. **Daily Limits**: Withdrawal limits prevent excessive fund extraction
5. **Emergency Controls**: System-wide emergency shutdown capabilities
6. **Audit Trail**: Complete transaction logging for compliance and monitoring

## Usage Guidelines

1. **Account Setup**: Users must first establish an account before performing any banking operations
2. **Security Configuration**: Recommended to set up account security protection for enhanced safety
3. **Daily Limits**: Be aware of daily withdrawal limits when planning large withdrawals
4. **Minimum Balance**: Maintain required minimum balance to avoid transaction failures
5. **Emergency Situations**: Contact administrator for emergency account recovery

## Deployment Notes

- The contract deployer automatically becomes the platform administrator
- All monetary values are in micro-STX (1 STX = 1,000,000 micro-STX)
- The contract requires STX tokens for deposit and withdrawal operations
- Administrative privileges cannot be transferred or revoked