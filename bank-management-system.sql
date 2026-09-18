CREATE DATABASE BANK_MANAGEMENT_SYSTEM

CREATE TABLE Users (
    user_id INT IDENTITY(1,1) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL,
    phone VARCHAR(15),
    address TEXT,
    kyc_status VARCHAR(20) DEFAULT 'Pending',
    created_at DATETIME DEFAULT GETDATE(),
    updated_at DATETIME DEFAULT GETDATE()
);


CREATE TABLE Accounts (
    account_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL,
    account_type VARCHAR(50) NOT NULL,
    balance DECIMAL(15, 2) DEFAULT 0.00,
    status VARCHAR(20) DEFAULT 'Active',
    created_at DATETIME DEFAULT GETDATE(),
    updated_at DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE
);


CREATE TABLE Transactions (
    transaction_id INT IDENTITY(1,1) PRIMARY KEY,
    account_id INT NOT NULL,
    transaction_type VARCHAR(50) NOT NULL,
    amount DECIMAL(15, 2) NOT NULL,
    timestamp DATETIME DEFAULT GETDATE(),
    status VARCHAR(20) DEFAULT 'Pending',
    reference_id INT NULL,
    FOREIGN KEY (account_id) REFERENCES Accounts(account_id) ON DELETE CASCADE
);


CREATE TABLE AuditLogs (
    log_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL,
    action TEXT NOT NULL,
    timestamp DATETIME DEFAULT GETDATE(),
    ip_address VARCHAR(45),
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE
);


CREATE TABLE Reports (
    report_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL,
    report_type VARCHAR(50) NOT NULL,
    generated_at DATETIME DEFAULT GETDATE(),
    file_path TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE
);


CREATE TABLE Notifications (
    notification_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL,
    message TEXT NOT NULL,
    timestamp DATETIME DEFAULT GETDATE(),
    status VARCHAR(20) DEFAULT 'Unread',
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE
);


CREATE TABLE SecuritySettings (
    setting_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL,
    two_factor_enabled BIT DEFAULT 0,
    last_password_change DATETIME NULL,
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE
);


--Not Implemented
ALTER TABLE Accounts
ADD CONSTRAINT FK_Accounts_User
FOREIGN KEY (user_id) REFERENCES Users(user_id)
ON DELETE CASCADE;

ALTER TABLE Transactions
ADD CONSTRAINT FK_Transactions_Account
FOREIGN KEY (account_id) REFERENCES Accounts(account_id)
ON DELETE CASCADE;

ALTER TABLE AuditLogs
ADD CONSTRAINT FK_AuditLogs_User
FOREIGN KEY (user_id) REFERENCES Users(user_id)
ON DELETE CASCADE;

ALTER TABLE Reports
ADD CONSTRAINT FK_Reports_User
FOREIGN KEY (user_id) REFERENCES Users(user_id)
ON DELETE CASCADE;

ALTER TABLE Notifications
ADD CONSTRAINT FK_Notifications_User
FOREIGN KEY (user_id) REFERENCES Users(user_id)
ON DELETE CASCADE;

ALTER TABLE SecuritySettings
ADD CONSTRAINT FK_SecuritySettings_User
FOREIGN KEY (user_id) REFERENCES Users(user_id)
ON DELETE CASCADE;

-- Calculate interest (e.g., 2% annual)
CREATE FUNCTION dbo.CalculateInterest(@account_id INT, @interest_rate DECIMAL(5,2))
RETURNS DECIMAL(15,2)
AS
BEGIN
    DECLARE @balance DECIMAL(15,2);
    SELECT @balance = balance FROM Accounts WHERE account_id = @account_id;
    RETURN @balance * (1 + @interest_rate/100);
END;
GO

-- Check KYC status for a user
CREATE FUNCTION dbo.CheckKYCStatus(@user_id INT)
RETURNS VARCHAR(20)
AS
BEGIN
    DECLARE @status VARCHAR(20);
    SELECT @status = kyc_status FROM Users WHERE user_id = @user_id;
    RETURN @status;
END;
GO

-- Create a new user
CREATE PROCEDURE dbo.CreateUser
    @name VARCHAR(100),
    @email VARCHAR(100),
    @password_hash VARCHAR(255),
    @role VARCHAR(50),
    @phone VARCHAR(15),
    @address VARCHAR(MAX)
AS
BEGIN
    INSERT INTO Users (name, email, password_hash, role, phone, address)
    VALUES (@name, @email, @password_hash, @role, @phone, @address);
END;
GO

-- Process transactions (deposit/withdrawal)
CREATE PROCEDURE dbo.ProcessTransaction
    @account_id INT,
    @transaction_type VARCHAR(50),
    @amount DECIMAL(15,2),
    @reference_id INT = NULL
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO Transactions (account_id, transaction_type, amount, reference_id)
        VALUES (@account_id, @transaction_type, @amount, @reference_id);
        
        IF @transaction_type = 'Deposit'
            UPDATE Accounts SET balance = balance + @amount WHERE account_id = @account_id;
        ELSE IF @transaction_type = 'Withdrawal'
            UPDATE Accounts SET balance = balance - @amount WHERE account_id = @account_id;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- Transfer funds between accounts
CREATE PROCEDURE dbo.ProcessTransfer
    @source_account_id INT,
    @target_account_id INT,
    @amount DECIMAL(15,2)
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC dbo.ProcessTransaction @source_account_id, 'Withdrawal', @amount;
        EXEC dbo.ProcessTransaction @target_account_id, 'Deposit', @amount;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


-- Auto-update 'updated_at' timestamp in Users
CREATE TRIGGER dbo.UpdateUserTimestamp
ON Users
AFTER UPDATE
AS
BEGIN
    UPDATE Users
    SET updated_at = GETDATE()
    WHERE user_id IN (SELECT user_id FROM inserted);
END;
GO

-- Prevent overdrafts (negative balance)
CREATE TRIGGER dbo.PreventOverdraft
ON Transactions
INSTEAD OF INSERT
AS
BEGIN
    DECLARE @account_id INT, @amount DECIMAL(15,2), @transaction_type VARCHAR(50);
    SELECT @account_id = account_id, @amount = amount, @transaction_type = transaction_type FROM inserted;
    
    IF @transaction_type = 'Withdrawal' AND 
       (SELECT balance FROM Accounts WHERE account_id = @account_id) < @amount
    BEGIN
        RAISERROR('Insufficient balance for withdrawal.', 16, 1);
        RETURN;
    END
    ELSE
    BEGIN
        INSERT INTO Transactions (account_id, transaction_type, amount, reference_id)
        SELECT account_id, transaction_type, amount, reference_id FROM inserted;
    END
END;
GO


CREATE INDEX idx_users_email ON Users(email);
CREATE INDEX idx_transactions_account ON Transactions(account_id);
CREATE INDEX idx_auditlogs_user ON AuditLogs(user_id);
GO

-- Customer account summary
CREATE VIEW dbo.CustomerAccountSummary
AS
SELECT 
    u.user_id,
    u.name,
    u.email,
    a.account_id,
    a.account_type,
    a.balance
FROM Users u
JOIN Accounts a ON u.user_id = a.user_id;
GO

-- Audit trail
CREATE VIEW dbo.AuditTrail
AS
SELECT 
    user_id,
    action,
    timestamp,
    ip_address
FROM AuditLogs;
GO

SELECT *
FROM dbo.AuditTrail
ORDER BY timestamp DESC;

-- Sample User
EXEC dbo.CreateUser 
    @name = 'John Doe',
    @email = 'john.doe@bank.com',
    @password_hash = 'hashed_pw_123',
    @role = 'Customer',
    @phone = '123-456-7890',
    @address = '123 Main Street';

-- Sample Account
INSERT INTO Accounts (user_id, account_type, balance)
VALUES (1, 'Savings', 1000.00);

-- Sample Transaction
EXEC dbo.ProcessTransaction 
    @account_id = 1,
    @transaction_type = 'Deposit',
    @amount = 500.00;


ALTER TABLE Users ALTER COLUMN address VARCHAR(MAX);
ALTER TABLE AuditLogs ALTER COLUMN action VARCHAR(MAX);
ALTER TABLE Reports ALTER COLUMN file_path VARCHAR(MAX);
ALTER TABLE Notifications ALTER COLUMN message VARCHAR(MAX);
GO

ALTER TABLE Users ADD CONSTRAINT CHK_Role CHECK (role IN ('Admin', 'Teller', 'Customer'));
ALTER TABLE Transactions ADD CONSTRAINT CHK_TransactionType CHECK (transaction_type IN ('Deposit', 'Withdrawal', 'Transfer'));
GO

SELECT * FROM CustomerAccountSummary;
SELECT * FROM AuditTrail;



-- Insert 20 Users
INSERT INTO Users (name, email, password_hash, role, phone, address, kyc_status)
VALUES
    ('Alice Johnson', 'alice.j@bank.com', 'hashed_pw_1', 'Admin', '111-222-3333', '123 Oak St', 'Verified'),
    ('Bob Smith', 'bob.s@bank.com', 'hashed_pw_2', 'Admin', '222-333-4444', '456 Pine St', 'Verified'),
    ('Charlie Brown', 'charlie.b@bank.com', 'hashed_pw_3', 'Teller', '333-444-5555', '789 Maple St', 'Verified'),
    ('Diana Prince', 'diana.p@bank.com', 'hashed_pw_4', 'Teller', '444-555-6666', '321 Elm St', 'Verified'),
    ('Evan Davis', 'evan.d@bank.com', 'hashed_pw_5', 'Teller', '555-666-7777', '654 Cedar St', 'Verified'),
    ('Fiona Clark', 'fiona.c@bank.com', 'hashed_pw_6', 'Customer', '666-777-8888', '987 Birch St', 'Verified'),
    ('George Wilson', 'george.w@bank.com', 'hashed_pw_7', 'Customer', '777-888-9999', '135 Walnut St', 'Pending'),
    ('Hannah Lee', 'hannah.l@bank.com', 'hashed_pw_8', 'Customer', '888-999-0000', '246 Spruce St', 'Verified'),
    ('Ian Moore', 'ian.m@bank.com', 'hashed_pw_9', 'Customer', '999-000-1111', '369 Willow St', 'Verified'),
    ('Julia Kim', 'julia.k@bank.com', 'hashed_pw_10', 'Customer', '000-111-2222', '159 Palm St', 'Pending'),
    ('Kevin Patel', 'kevin.p@bank.com', 'hashed_pw_11', 'Customer', '111-222-3334', '753 Redwood St', 'Verified'),
    ('Luna Garcia', 'luna.g@bank.com', 'hashed_pw_12', 'Customer', '222-333-4445', '357 Sequoia St', 'Verified'),
    ('Mike Ross', 'mike.r@bank.com', 'hashed_pw_13', 'Customer', '333-444-5556', '753 Magnolia St', 'Verified'),
    ('Nina Nguyen', 'nina.n@bank.com', 'hashed_pw_14', 'Customer', '444-555-6667', '159 Aspen St', 'Pending'),
    ('Oscar Martinez', 'oscar.m@bank.com', 'hashed_pw_15', 'Customer', '555-666-7778', '456 Fir St', 'Verified'),
    ('Paula Adams', 'paula.a@bank.com', 'hashed_pw_16', 'Customer', '666-777-8889', '852 Sycamore St', 'Verified'),
    ('Quinn Taylor', 'quinn.t@bank.com', 'hashed_pw_17', 'Customer', '777-888-9990', '258 Cherry St', 'Verified'),
    ('Rachel Green', 'rachel.g@bank.com', 'hashed_pw_18', 'Customer', '888-999-0001', '654 Poplar St', 'Verified'),
    ('Sam Wilson', 'sam.w@bank.com', 'hashed_pw_19', 'Customer', '999-000-1112', '753 Cedar St', 'Pending'),
    ('Tina Foster', 'tina.f@bank.com', 'hashed_pw_20', 'Customer', '000-111-2223', '357 Oak St', 'Verified');
GO

-- Insert Accounts (1-2 accounts per user)
INSERT INTO Accounts (user_id, account_type, balance)
VALUES
    (1, 'Savings', 25000.00), (1, 'Checking', 15000.00),
    (2, 'Savings', 30000.00),
    (3, 'Checking', 5000.00),
    (4, 'Savings', 10000.00), (4, 'Checking', 8000.00),
    (5, 'Savings', 12000.00),
    (6, 'Savings', 7000.00),
    (7, 'Checking', 3000.00),
    (8, 'Savings', 45000.00),
    (9, 'Checking', 2000.00),
    (10, 'Savings', 9000.00),
    (11, 'Checking', 6000.00), (11, 'Savings', 18000.00),
    (12, 'Savings', 22000.00),
    (13, 'Checking', 4000.00),
    (14, 'Savings', 15000.00),
    (15, 'Checking', 2500.00),
    (16, 'Savings', 35000.00),
    (17, 'Checking', 1200.00),
    (18, 'Savings', 28000.00),
    (19, 'Checking', 7500.00),
    (20, 'Savings', 50000.00);
GO

-- Insert Sample Transactions
INSERT INTO Transactions (account_id, transaction_type, amount, status)
VALUES
    (1, 'Deposit', 5000.00, 'Completed'),
    (1, 'Withdrawal', 2000.00, 'Completed'),
    (2, 'Deposit', 10000.00, 'Completed'),
    (3, 'Deposit', 3000.00, 'Completed'),
    (4, 'Withdrawal', 1500.00, 'Completed'),
    (5, 'Deposit', 2000.00, 'Completed'),
    (6, 'Transfer', 500.00, 'Pending'),
    (7, 'Deposit', 1000.00, 'Completed'),
    (8, 'Withdrawal', 5000.00, 'Completed'),
    (9, 'Deposit', 800.00, 'Completed'),
    (10, 'Withdrawal', 200.00, 'Completed'),
    (11, 'Deposit', 3000.00, 'Completed'),
    (12, 'Transfer', 1000.00, 'Pending'),
    (13, 'Deposit', 1500.00, 'Completed'),
    (14, 'Withdrawal', 500.00, 'Completed'),
    (15, 'Deposit', 200.00, 'Completed'),
    (16, 'Transfer', 2000.00, 'Completed'),
    (17, 'Deposit', 700.00, 'Completed'),
    (18, 'Withdrawal', 3000.00, 'Completed'),
    (19, 'Deposit', 2500.00, 'Completed'),
    (20, 'Withdrawal', 10000.00, 'Completed');
GO

SELECT * FROM Users;
SELECT * FROM Accounts;
SELECT * FROM Transactions;