# 🏦 Bank Management System — SQL Server

A relational **Bank Management System database** built with **Microsoft SQL Server**, designed to demonstrate real-world banking data management and core database concepts.

## ✨ Overview

This project models the core operations of a banking system, including:

- 👤 User & role management
- 💳 Customer bank accounts
- 💰 Deposits & withdrawals
- 🔄 Account-to-account transfers
- 🪪 KYC status tracking
- 🔐 Security settings & 2FA
- 📋 Audit logging
- 🔔 Notifications
- 📊 Customer reports
- ⚡ Database triggers & automated validation

The database uses relationships between users, accounts, transactions, audit logs, reports, notifications, and security settings. :contentReference[oaicite:1]{index=1}

## 🛠️ Tech Stack

- **Database:** Microsoft SQL Server
- **Language:** T-SQL
- **Database Design:** Relational Database
- **Key Concepts:** Stored Procedures, Functions, Triggers, Views, Indexes, Constraints & Transactions

## 🗂️ Database Structure

| Table | Purpose |
|---|---|
| `Users` | Stores customer, teller, and admin information |
| `Accounts` | Manages customer bank accounts and balances |
| `Transactions` | Records deposits, withdrawals, and transfers |
| `AuditLogs` | Maintains an audit trail of user actions |
| `Reports` | Stores generated report information |
| `Notifications` | Manages user notifications |
| `SecuritySettings` | Stores security and 2FA settings |

## ⚙️ Core Database Features

### 💸 Transaction Processing

`ProcessTransaction` handles deposits and withdrawals using SQL transactions to maintain data consistency. :contentReference[oaicite:2]{index=2}

```sql
EXEC dbo.ProcessTransaction
    @account_id = 1,
    @transaction_type = 'Deposit',
    @amount = 500.00;
