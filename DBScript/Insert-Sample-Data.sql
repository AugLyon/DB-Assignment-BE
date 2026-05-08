SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE COMMENT;
TRUNCATE TABLE ATTACHMENT;
TRUNCATE TABLE CHECKLIST_ITEM;
TRUNCATE TABLE CHECKLIST;
TRUNCATE TABLE CARD_LABEL_ASSIGNMENT;
TRUNCATE TABLE LABEL;
TRUNCATE TABLE CARD_DEPENDENCY;
TRUNCATE TABLE CARD_ASSIGNMENT;
TRUNCATE TABLE CARD;
TRUNCATE TABLE LIST;
TRUNCATE TABLE BOARD_MEMBER;
TRUNCATE TABLE BOARD;
TRUNCATE TABLE WORKSPACE;
TRUNCATE TABLE PRO_USER;
TRUNCATE TABLE FREE_USER;
TRUNCATE TABLE USER_PROFILE;
TRUNCATE TABLE USER_PREFERENCE;
TRUNCATE TABLE USER_POWER_UP;
TRUNCATE TABLE USER_ACCOUNT;

SET FOREIGN_KEY_CHECKS = 1;

INSERT INTO USER_ACCOUNT (Email, Password_hash) VALUES
('alice.smith@example.com', 'hashed_pwd_001'),
('bob.jones@example.com', 'hashed_pwd_002'),
('charlie.brown@example.com', 'hashed_pwd_003'),
('diana.prince@example.com', 'hashed_pwd_004'),
('evan.wright@example.com', 'hashed_pwd_005'),
('fiona.gallagher@example.com', 'hashed_pwd_006'),
('george.lucas@example.com', 'hashed_pwd_007'),
('hannah.montana@example.com', 'hashed_pwd_008'),
('ian.malcolm@example.com', 'hashed_pwd_009'),
('julia.roberts@example.com', 'hashed_pwd_010');

INSERT INTO USER_POWER_UP (User_ID, Power_Up_Name) VALUES
(1, 'Calendar View'),
(2, 'Voting'),
(3, 'Custom Fields'),
(4, 'Automation limits'),
(5, 'Advanced Mapping');

INSERT INTO USER_PREFERENCE (User_ID, Theme_Mode, Language, Notification_Setting) VALUES
(1, 'Dark', 'English', 'All'),
(2, 'Light', 'Spanish', 'Mentions Only'),
(3, 'System', 'French', 'None'),
(4, 'Dark', 'German', 'All'),
(5, 'Light', 'English', 'Mentions Only'),
(6, 'Dark', 'English', 'All'),
(7, 'Light', 'English', 'None'),
(8, 'System', 'Spanish', 'Mentions Only'),
(9, 'Dark', 'French', 'All'),
(10, 'Light', 'German', 'None');

INSERT INTO USER_PROFILE (User_ID, First_Name, Last_Name, Time_zone, Contact, Avatar_Url) VALUES
(1, 'Alice', 'Smith', 'UTC', '+1234567890', 'https://avatar.com/u1.png'),
(2, 'Bob', 'Jones', 'PST', '+1987654321', 'https://avatar.com/u2.png'),
(3, 'Charlie', 'Brown', 'EST', '+1555123456', 'https://avatar.com/u3.png'),
(4, 'Diana', 'Prince', 'GMT', '+1555987654', 'https://avatar.com/u4.png'),
(5, 'Evan', 'Wright', 'CET', '+1555111222', 'https://avatar.com/u5.png'),
(6, 'Fiona', 'Gallagher', 'EST', '+1555333444', 'https://avatar.com/u6.png'),
(7, 'George', 'Lucas', 'PST', '+1555555666', 'https://avatar.com/u7.png'),
(8, 'Hannah', 'Montana', 'EST', '+1555777888', 'https://avatar.com/u8.png'),
(9, 'Ian', 'Malcolm', 'UTC', '+1555999000', 'https://avatar.com/u9.png'),
(10, 'Julia', 'Roberts', 'GMT', '+1555222111', 'https://avatar.com/u10.png');

INSERT INTO FREE_USER (User_ID, Ad_Tracking_ID, Storage_Limit) VALUES
(1, 'track_abc123', 500),
(2, 'track_def456', 500),
(3, 'track_ghi789', 500),
(4, 'track_jkl012', 500),
(5, 'track_mno345', 500);

INSERT INTO PRO_USER (User_ID, Payment_Method, Next_Billing_Date) VALUES
(6, 'Visa ending 1234', '2026-01-15 00:00:00'),
(7, 'Mastercard ending 5678', '2026-01-20 00:00:00'),
(8, 'PayPal', '2026-02-01 00:00:00'),
(9, 'Amex ending 9012', '2026-02-10 00:00:00'),
(10, 'Apple Pay', '2026-03-05 00:00:00');

INSERT INTO WORKSPACE (Name, Description, Owner_ID) VALUES
('Development Team', 'Software engineering projects', 6),
('Marketing & Sales', 'Campaign tracking', 7),
('HR Department', 'Recruiting and onboarding', 8),
('Personal Life', 'Groceries and chores', 1),
('Design Studio', 'UI/UX mockups', 9);

INSERT INTO BOARD (Board_Title, Visibility_Status, Workspace_ID, Total_Members) VALUES
('Sprint 42', 'Private', 1, 2),
('Q4 Ad Campaign', 'Workspace', 2, 1),
('New Hires 2026', 'Private', 3, 1),
('Weekly Chores', 'Public', 4, 1),
('Mobile App Redesign', 'Workspace', 5, 1);

INSERT INTO BOARD_MEMBER (User_ID, Board_ID, Role) VALUES
(6, 1, 'Admin'),
(1, 1, 'Member'),
(7, 2, 'Admin'),
(8, 3, 'Admin'),
(1, 4, 'Admin');

INSERT INTO LIST (List_Name, Position, Board_ID) VALUES
('Backlog', 1, 1),
('In Progress', 2, 1),
('Done', 3, 1),
('Drafts', 1, 2),
('Published', 2, 2);

INSERT INTO CARD (Card_Title, Description, Start_Date, Due_Date, List_ID) VALUES
('Setup Database Schema', 'Create SQL tables', '2025-11-01 09:00:00', '2025-11-05 17:00:00', 1),
('Write API Endpoints', 'RESTful API in Node.js', '2025-11-03 10:00:00', '2025-11-10 17:00:00', 1),
('Fix Login Bug', 'Users cannot reset password', '2025-11-02 08:00:00', '2025-11-04 12:00:00', 2),
('Write SEO Blog', 'Target keywords: tech, code', '2025-11-01 09:00:00', '2025-11-15 17:00:00', 4),
('Deploy to Production', 'Push v1.2 to AWS', '2025-11-12 22:00:00', '2025-11-13 02:00:00', 1);

INSERT INTO CARD_ASSIGNMENT (User_ID, Card_ID) VALUES
(6, 1),
(1, 2),
(6, 3),
(7, 4),
(1, 5);

INSERT INTO CARD_DEPENDENCY (Blocked_Card_ID, Blocker_Card_ID) VALUES
(2, 1), 
(5, 2), 
(5, 3), 
(4, 1), 
(3, 1); 

INSERT INTO LABEL (Label_Name, Color_Code, Board_ID) VALUES
('Urgent', '#FF0000', 1),
('Backend', '#0000FF', 1),
('Frontend', '#00FF00', 1),
('Copywriting', '#FFFF00', 2),
('Bug', '#FF8C00', 1);

INSERT INTO CARD_LABEL_ASSIGNMENT (Card_ID, Label_ID) VALUES
(1, 2),
(2, 2),
(3, 5),
(3, 1),
(4, 4);

INSERT INTO CHECKLIST (Card_ID, Checklist_ID, Checklist_Title) VALUES
(1, 1, 'Database Tables Required'),
(1, 2, 'QA Verification'),
(2, 1, 'List of Routes'),
(3, 1, 'Testing Scenarios'),
(4, 1, 'SEO Keywords Included');

INSERT INTO CHECKLIST_ITEM (Card_ID, Checklist_ID, Item_ID, Content, Is_Completed) VALUES
(1, 1, 1, 'Create USER table', TRUE),
(1, 1, 2, 'Create BOARD table', FALSE),
(2, 1, 1, 'GET /users', FALSE),
(3, 1, 1, 'Test with wrong password', TRUE),
(4, 1, 1, 'Use word "software"', FALSE);

INSERT INTO ATTACHMENT (Card_ID,  File_Name, File_Url, File_Type, User_ID) VALUES
(1, 'schema_diagram.png', 'https://s3.aws.com/files/schema.png', 'image/png', 6),
(2,'api_docs.pdf', 'https://s3.aws.com/files/docs.pdf', 'application/pdf', 1),
(3,'error_log.txt', 'https://s3.aws.com/files/error.txt', 'text/plain', 6),
(4, 'draft_v1.docx', 'https://s3.aws.com/files/draft.docx', 'application/msword', 7),
(5, 'deployment_guide.pdf', 'https://s3.aws.com/files/deploy.pdf', 'application/pdf', 6);

INSERT INTO COMMENT (Card_ID, Comment_ID, Content, User_ID) VALUES
(1, 1, 'I will start working on this today.', 6),
(1, 2, 'Let me know if you need help.', 1),
(2, 1, 'Waiting on the schema to be finished.', 1),
(3, 1, 'I reproduced the error on my local machine.', 6),
(4, 1, 'Draft is 50% complete.', 7);

UPDATE CARD SET Cover_Attachment_ID = 1 WHERE Card_ID = 1;
UPDATE CARD SET Cover_Attachment_ID = 2 WHERE Card_ID = 2;
UPDATE CARD SET Cover_Attachment_ID = 3 WHERE Card_ID = 3;
UPDATE CARD SET Cover_Attachment_ID = 4 WHERE Card_ID = 4;
UPDATE CARD SET Cover_Attachment_ID = 5 WHERE Card_ID = 5;