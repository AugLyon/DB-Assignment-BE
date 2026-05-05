-- ==============================================================================
-- NHÓM 1: QUẢN LÝ TÀI KHOẢN
-- ==============================================================================

CREATE TABLE USER_ACCOUNT (
    User_ID SERIAL PRIMARY KEY,
    Email VARCHAR(255) UNIQUE NOT NULL,
    Password VARCHAR(255) NOT NULL
);

CREATE TABLE USER_POWER_UP (
    User_ID INT NOT NULL,
    Power_Up_Name VARCHAR(100) NOT NULL,
    PRIMARY KEY (User_ID, Power_Up_Name),
    FOREIGN KEY (User_ID) REFERENCES USER_ACCOUNT(User_ID) ON DELETE CASCADE
);

CREATE TABLE USER_PREFERENCE (
    User_ID INT PRIMARY KEY,
    Theme_Mode VARCHAR(50),
    Language VARCHAR(50),
    Notification_Setting VARCHAR(50),
    FOREIGN KEY (User_ID) REFERENCES USER_ACCOUNT(User_ID) ON DELETE CASCADE
);

CREATE TABLE USER_PROFILE (
    Profile_ID SERIAL PRIMARY KEY,
    User_ID INT UNIQUE NOT NULL,
    First_Name VARCHAR(100),
    Last_Name VARCHAR(100),
    Time_zone VARCHAR(100),
    Contact VARCHAR(255),
    Avatar_Url TEXT,
    FOREIGN KEY (User_ID) REFERENCES USER_ACCOUNT(User_ID) ON DELETE CASCADE
);

CREATE TABLE FREE_USER (
    User_ID INT PRIMARY KEY,
    Ad_Tracking_ID VARCHAR(255),
    Storage_Limit INT,
    FOREIGN KEY (User_ID) REFERENCES USER_ACCOUNT(User_ID) ON DELETE CASCADE
);

CREATE TABLE PRO_USER (
    User_ID INT PRIMARY KEY,
    Payment_Method VARCHAR(100),
    Next_Billing_Date TIMESTAMP,
    FOREIGN KEY (User_ID) REFERENCES USER_ACCOUNT(User_ID) ON DELETE CASCADE
);

-- ==============================================================================
-- NHÓM 2: CẤU TRÚC DỰ ÁN
-- ==============================================================================

CREATE TABLE WORKSPACE (
    Workspace_ID SERIAL PRIMARY KEY,
    Name VARCHAR(255) NOT NULL,
    Description TEXT,
    Owner_ID INT NOT NULL,
    FOREIGN KEY (Owner_ID) REFERENCES USER_ACCOUNT(User_ID)
);

CREATE TABLE BOARD (
    Board_ID SERIAL PRIMARY KEY,
    Board_Title VARCHAR(255) NOT NULL,
    Visibility_Status VARCHAR(50),
    Workspace_ID INT NOT NULL,
    Total_Members INT DEFAULT 0, -- Derived Attribute
    FOREIGN KEY (Workspace_ID) REFERENCES WORKSPACE(Workspace_ID) ON DELETE CASCADE
);

CREATE TABLE BOARD_MEMBER (
    User_ID INT NOT NULL,
    Board_ID INT NOT NULL,
    Role VARCHAR(100),
    PRIMARY KEY (User_ID, Board_ID),
    FOREIGN KEY (User_ID) REFERENCES USER_ACCOUNT(User_ID) ON DELETE CASCADE,
    FOREIGN KEY (Board_ID) REFERENCES BOARD(Board_ID) ON DELETE CASCADE
);

-- ==============================================================================
-- NHÓM 3: LUỒNG CÔNG VIỆC
-- ==============================================================================

CREATE TABLE LIST (
    List_ID SERIAL PRIMARY KEY,
    List_Name VARCHAR(255) NOT NULL,
    Position INT NOT NULL,
    Board_ID INT NOT NULL,
    FOREIGN KEY (Board_ID) REFERENCES BOARD(Board_ID) ON DELETE CASCADE
);

-- Note: Cover_Attachment_ID FK is added at the end due to circular dependency
CREATE TABLE CARD (
    Card_ID SERIAL PRIMARY KEY,
    Card_Title VARCHAR(255) NOT NULL,
    Card_Name VARCHAR(255),
    Description TEXT,
    Start_Date TIMESTAMP,
    Due_Date TIMESTAMP,
    Is_Due_Complete BOOLEAN DEFAULT FALSE,
    Duration INT, -- Derived Attribute
    List_ID INT NOT NULL,
    Cover_Attachment_ID INT, 
    FOREIGN KEY (List_ID) REFERENCES LIST(List_ID) ON DELETE CASCADE
);

CREATE TABLE CARD_ASSIGNMENT (
    User_ID INT NOT NULL,
    Card_ID INT NOT NULL,
    Assignment_Date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (User_ID, Card_ID),
    FOREIGN KEY (User_ID) REFERENCES USER_ACCOUNT(User_ID) ON DELETE CASCADE,
    FOREIGN KEY (Card_ID) REFERENCES CARD(Card_ID) ON DELETE CASCADE
);

CREATE TABLE CARD_DEPENDENCY (
    Blocked_Card_ID INT NOT NULL,
    Blocker_Card_ID INT NOT NULL,
    PRIMARY KEY (Blocked_Card_ID, Blocker_Card_ID),
    FOREIGN KEY (Blocked_Card_ID) REFERENCES CARD(Card_ID) ON DELETE CASCADE,
    FOREIGN KEY (Blocker_Card_ID) REFERENCES CARD(Card_ID) ON DELETE CASCADE
);

-- ==============================================================================
-- NHÓM 4: MỞ RỘNG
-- ==============================================================================

CREATE TABLE LABEL (
    Label_ID SERIAL PRIMARY KEY,
    Label_Name VARCHAR(255) NOT NULL,
    Color_Code VARCHAR(20),
    Board_ID INT NOT NULL,
    FOREIGN KEY (Board_ID) REFERENCES BOARD(Board_ID) ON DELETE CASCADE
);

CREATE TABLE CARD_LABEL_ASSIGNMENT (
    Card_ID INT NOT NULL,
    Label_ID INT NOT NULL,
    PRIMARY KEY (Card_ID, Label_ID),
    FOREIGN KEY (Card_ID) REFERENCES CARD(Card_ID) ON DELETE CASCADE,
    FOREIGN KEY (Label_ID) REFERENCES LABEL(Label_ID) ON DELETE CASCADE
);

-- [Weak Entity Cấp 1]
CREATE TABLE CHECKLIST (
    Card_ID INT NOT NULL,
    Checklist_ID INT NOT NULL, -- Partial Key
    Checklist_Title VARCHAR(255) NOT NULL,
    PRIMARY KEY (Card_ID, Checklist_ID),
    FOREIGN KEY (Card_ID) REFERENCES CARD(Card_ID) ON DELETE CASCADE
);

-- [Weak Entity Cấp 2]
CREATE TABLE CHECKLIST_ITEM (
    Card_ID INT NOT NULL,
    Checklist_ID INT NOT NULL,
    Item_ID INT NOT NULL, -- Partial Key
    Content TEXT NOT NULL,
    Is_Completed BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (Card_ID, Checklist_ID, Item_ID),
    FOREIGN KEY (Card_ID, Checklist_ID) REFERENCES CHECKLIST(Card_ID, Checklist_ID) ON DELETE CASCADE
);

CREATE TABLE ATTACHMENT (
    Card_ID INT NOT NULL,
    Attachment_ID INT NOT NULL,
    File_Name VARCHAR(255) NOT NULL,
    File_Url TEXT NOT NULL,
    File_Type VARCHAR(100),
    Upload_Date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    User_ID INT NOT NULL,
    PRIMARY KEY (Card_ID, Attachment_ID),
    FOREIGN KEY (Card_ID) REFERENCES CARD(Card_ID) ON DELETE CASCADE,
    FOREIGN KEY (User_ID) REFERENCES USER_ACCOUNT(User_ID) ON DELETE SET NULL
);

-- ==============================================================================
-- NHÓM 5: TƯƠNG TÁC (Weak Entity)
-- ==============================================================================

CREATE TABLE COMMENT (
    Card_ID INT NOT NULL,
    Comment_ID INT NOT NULL, -- Partial Key
    Content TEXT NOT NULL,
    Created_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    Updated_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    Is_Edited BOOLEAN DEFAULT FALSE, -- Derived Attribute
    User_ID INT NOT NULL,
    PRIMARY KEY (Card_ID, Comment_ID),
    FOREIGN KEY (Card_ID) REFERENCES CARD(Card_ID) ON DELETE CASCADE,
    FOREIGN KEY (User_ID) REFERENCES USER_ACCOUNT(User_ID) ON DELETE CASCADE
);

-- ==============================================================================
-- GIẢI QUYẾT CIRCULAR DEPENDENCY (CARD <-> ATTACHMENT)
-- ==============================================================================

ALTER TABLE CARD
ADD CONSTRAINT fk_card_cover_attachment
FOREIGN KEY (Card_ID, Cover_Attachment_ID) 
REFERENCES ATTACHMENT(Card_ID, Attachment_ID) ON DELETE SET NULL;