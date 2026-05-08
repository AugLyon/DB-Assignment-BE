
DROP PROCEDURE IF EXISTS InsertCard;
DROP PROCEDURE IF EXISTS UpdateCard;
DROP PROCEDURE IF EXISTS DeleteCard;

DROP TRIGGER IF EXISTS Before_Insert_Card_Assignment;
DROP TRIGGER IF EXISTS Before_Insert_Card_Duration;
DROP TRIGGER IF EXISTS trg_Before_Update_Card_Duration;
DROP TRIGGER IF EXISTS trg_After_Update_Board_Member;
DROP TRIGGER IF EXISTS trg_After_Delete_Board_Member;
DROP TRIGGER IF EXISTS trg_Before_Update_Comment;
DROP TRIGGER IF EXISTS trg_Before_Insert_Card_Label_Assignment;
DROP TRIGGER IF EXISTS trg_Before_Update_Card_Label_Assignment;
DROP TRIGGER IF EXISTS trg_Before_Update_Card;

DROP PROCEDURE IF EXISTS GetCardsByBoard;
DROP PROCEDURE IF EXISTS GetListStatistics;
DROP PROCEDURE IF EXISTS GetUserByBoard;
DROP PROCEDURE IF EXISTS GetAssignmentByBoard;
DROP PROCEDURE IF EXISTS ToggleChecklistItem;
DROP PROCEDURE IF EXISTS InsertChecklistItem;
DROP FUNCTION IF EXISTS GetCardProgress;
DROP FUNCTION IF EXISTS GetUserBoardEfficiency;

DELIMITER //

CREATE PROCEDURE InsertCard(
    IN p_Card_Title VARCHAR(255),
    IN p_Description TEXT,
    IN p_Start_Date DATETIME,
    IN p_Due_Date DATETIME,
    IN p_List_ID INT
)
BEGIN
    IF p_Card_Title IS NULL OR TRIM(p_Card_Title) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: Card title cannot be empty.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM LIST WHERE List_ID = p_List_ID AND Is_Deleted = FALSE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: The specified List_ID does not exist.';
    END IF;
    IF p_Start_Date IS NOT NULL AND p_Due_Date IS NOT NULL AND p_Due_Date < p_Start_Date THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: Due Date cannot be earlier than Start Date.';
    END IF;
    INSERT INTO CARD (Card_Title, Description, Start_Date, Due_Date, List_ID)
    VALUES (p_Card_Title, p_Description, p_Start_Date, p_Due_Date, p_List_ID);
END //

CREATE PROCEDURE UpdateCard(
    IN p_Card_ID INT,
    IN p_New_Title VARCHAR(255),
    IN p_New_Due_Date DATETIME,
    IN p_Is_Due_Complete BOOLEAN
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM CARD WHERE Card_ID = p_Card_ID AND Is_Deleted = FALSE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Update Error: The specified Card does not exist or was deleted.';
    END IF;
    IF p_New_Title is null or TRIM(p_New_Title) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Update Error: Card title cannot be set to empty.';
    END IF;
    IF p_Is_Due_Complete = TRUE AND p_New_Due_Date IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Update Error: Cannot mark a card as complete if it has no Due Date.';
    END IF;
    
    UPDATE CARD 
    SET Card_Title = p_New_Title, 
        Due_Date = p_New_Due_Date, 
        Is_Due_Complete = p_Is_Due_Complete
    WHERE Card_ID = p_Card_ID;
END //

CREATE PROCEDURE DeleteCard(
    IN p_Card_ID INT
)
BEGIN
    DECLARE is_blocker INT DEFAULT 0;
    IF NOT EXISTS (SELECT 1 FROM CARD WHERE Card_ID = p_Card_ID AND Is_Deleted = FALSE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Delete Error: Card does not exist or is already deleted.';
    END IF;
    
    SELECT COUNT(*) INTO is_blocker 
    FROM CARD_DEPENDENCY 
    WHERE Blocker_Card_ID = p_Card_ID;

    IF is_blocker > 0 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Delete Disallowed: Card is blocking others. Please remove dependencies first.';
    END IF;
    
    DELETE FROM CARD_DEPENDENCY WHERE Blocked_Card_ID = p_Card_ID;

    UPDATE CARD 
    SET Is_Deleted = TRUE, 
        Deleted_At = CURRENT_TIMESTAMP 
    WHERE Card_ID = p_Card_ID;
END //

CREATE TRIGGER Before_Insert_Card_Assignment
BEFORE INSERT ON CARD_ASSIGNMENT
FOR EACH ROW
BEGIN 
    DECLARE board_id INT;
    DECLARE is_member INT;
    
    SELECT l.Board_ID INTO board_id
    FROM CARD c
    JOIN LIST l ON c.List_ID = l.List_ID 
    WHERE c.Card_ID = NEW.Card_ID AND c.Is_Deleted = FALSE AND l.Is_Deleted = FALSE;

    IF board_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Assignment Error: The specified Card does not exist.';
    END IF;

    SELECT COUNT(*) INTO is_member
    FROM BOARD_MEMBER
    WHERE User_ID = NEW.User_ID AND Board_ID = board_id AND Is_Deleted = FALSE;
    
    IF is_member = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Business Constraint Violated: User must be a member of the board to be assigned to this card.';
    END IF; 
END //

CREATE TRIGGER Before_Insert_Card_Duration
BEFORE INSERT ON CARD
FOR EACH ROW
BEGIN 
    IF NEW.Start_Date IS NOT NULL AND NEW.Due_Date IS NOT NULL THEN
        IF NEW.Due_Date < NEW.Start_Date THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: Due Date cannot be earlier than Start Date.';
        ELSE
            SET NEW.Duration = DATEDIFF(NEW.Due_Date, NEW.Start_Date);
        END IF;
    ELSE
        SET NEW.Duration = NULL;
    END IF;
END //

CREATE TRIGGER trg_Before_Update_Card_Duration
BEFORE UPDATE ON CARD
FOR EACH ROW
BEGIN
    IF NOT (NEW.Start_Date <=> OLD.Start_Date) OR NOT (NEW.Due_Date <=> OLD.Due_Date) THEN
        IF NEW.Start_Date IS NOT NULL AND NEW.Due_Date IS NOT NULL THEN
            IF NEW.Due_Date < NEW.Start_Date THEN
                SIGNAL SQLSTATE '45000' 
                SET MESSAGE_TEXT = 'Validation Error: Due Date cannot be earlier than Start Date.';
            ELSE
                SET NEW.Duration = DATEDIFF(NEW.Due_Date, NEW.Start_Date);
            END IF;
        ELSE
            SET NEW.Duration = NULL;
        END IF;
    END IF;
END //

CREATE TRIGGER trg_After_Update_Board_Member
AFTER UPDATE ON BOARD_MEMBER
FOR EACH ROW
BEGIN
    DECLARE admin_count INT;
    IF OLD.Role = 'Admin' AND (NEW.Role = 'Member' OR NEW.Is_Deleted = TRUE) THEN
        SELECT COUNT(*) INTO admin_count
        FROM BOARD_MEMBER
        WHERE Board_ID = NEW.Board_ID AND Role = 'Admin' AND Is_Deleted = FALSE; 
        IF admin_count = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A Board must have at least 1 Admin';
        END IF;
    END IF;
END //
CREATE TRIGGER trg_After_Delete_Board_Member
AFTER DELETE ON BOARD_MEMBER
FOR EACH ROW
BEGIN
    DECLARE admin_count INT;
    IF OLD.Role = 'Admin' THEN
        SELECT COUNT(*) INTO admin_count
        FROM BOARD_MEMBER
        WHERE Board_ID = OLD.Board_ID AND Role = 'Admin' AND Is_Deleted = FALSE; 
        IF admin_count = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A Board must have at least 1 Admin';
        END IF;
    END IF;
END //

CREATE TRIGGER trg_Before_Update_Comment
BEFORE UPDATE ON COMMENT
FOR EACH ROW
BEGIN
    IF NOT (OLD.Content <=> NEW.Content) THEN
        SET NEW.Is_Edited = TRUE;
    END IF;
END //

CREATE TRIGGER trg_Before_Insert_Card_Label_Assignment
BEFORE INSERT ON CARD_LABEL_ASSIGNMENT
FOR EACH ROW
BEGIN
    DECLARE v_Board_ID INT;
    DECLARE v_Label_Board_ID INT;
    SELECT l.Board_ID INTO v_Board_ID
    FROM CARD c 
    JOIN LIST l ON c.List_ID = l.List_ID
    WHERE c.Card_ID = NEW.Card_ID;

    SELECT Board_ID INTO v_Label_Board_ID
    FROM LABEL
    WHERE Label_ID = NEW.Label_ID;

    IF (v_Board_ID != v_Label_Board_ID) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Label scope error: Cannot assign label from another board.';
    END IF;  
END //

CREATE TRIGGER trg_Before_Update_Card_Label_Assignment
BEFORE UPDATE ON CARD_LABEL_ASSIGNMENT
FOR EACH ROW
BEGIN
    DECLARE v_Board_ID INT;
    DECLARE v_Label_Board_ID INT;

    IF OLD.Card_ID != NEW.Card_ID OR OLD.Label_ID != NEW.Label_ID THEN

        SELECT l.Board_ID INTO v_Board_ID
        FROM CARD c 
        JOIN LIST l ON c.List_ID = l.List_ID
        WHERE c.Card_ID = NEW.Card_ID;

        SELECT Board_ID INTO v_Label_Board_ID
        FROM LABEL
        WHERE Label_ID = NEW.Label_ID;

        IF (v_Board_ID != v_Label_Board_ID) THEN
          SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Label scope error: Cannot update assignment with a label from another board.';
        END IF;  
        
    END IF;
END //

CREATE TRIGGER trg_Before_Update_Card
BEFORE UPDATE ON CARD
FOR EACH ROW
BEGIN
	DECLARE v_Attachment_Card_ID INT;
    IF NOT (OLD.Cover_Attachment_ID <=> NEW.Cover_Attachment_ID) THEN
        SELECT a.Card_ID INTO v_Attachment_Card_ID
        FROM ATTACHMENT a
        WHERE Attachment_ID = NEW.Cover_Attachment_ID;

        IF(v_Attachment_Card_ID != NEW.Card_ID) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Attachment scope error: Attachment do not belong to this card.';
        END IF;
    END IF;
END //

CREATE PROCEDURE ToggleChecklistItem(IN p_Card_ID INT, IN p_Checklist_ID INT, IN p_Item_ID INT, IN p_Is_Completed BOOLEAN)
BEGIN
    DECLARE v_total INT DEFAULT 0;
    DECLARE v_completed INT DEFAULT 0;

    IF NOT EXISTS (SELECT 1 FROM CARD WHERE Card_ID = p_Card_ID AND Is_Deleted = FALSE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Insert error: Card not found.';
    END IF;

    UPDATE CHECKLIST_ITEM 
    SET Is_Completed = p_Is_Completed 
    WHERE Card_ID = p_Card_ID AND Checklist_ID = p_Checklist_ID AND Item_ID = p_Item_ID AND Is_Deleted = FALSE;

    SELECT COUNT(*), IFNULL(SUM(CASE WHEN Is_Completed = TRUE AND Is_Deleted = FALSE THEN 1 ELSE 0 END), 0)
    INTO v_total, v_completed
    FROM CHECKLIST_ITEM
    WHERE Card_ID = p_Card_ID AND Is_Deleted = FALSE;

    IF v_total > 0 AND v_total = v_completed THEN
        UPDATE CARD SET Is_Due_Complete = TRUE WHERE Card_ID = p_Card_ID;
    ELSE
        UPDATE CARD SET Is_Due_Complete = FALSE WHERE Card_ID = p_Card_ID;
    END IF;
END //

CREATE PROCEDURE InsertChecklistItem(IN p_Card_ID INT, IN p_Checklist_ID INT, IN p_Content TEXT)
BEGIN
    DECLARE v_Max_Item_ID INT;
    DECLARE v_Next_Item_ID INT;

    IF NOT EXISTS (SELECT 1 FROM CARD WHERE Card_ID = p_Card_ID AND Is_Deleted = FALSE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Insert error: Card not found.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM CHECKLIST WHERE Checklist_ID = p_Checklist_ID AND Card_ID = p_Card_ID AND Is_Deleted = FALSE ) THEN
        INSERT INTO CHECKLIST (Card_ID, Checklist_ID, Checklist_Title) VALUES (p_Card_ID, p_Checklist_ID, CONCAT('Checklist ', p_Checklist_ID));
    END IF;
    
    SELECT MAX(Item_ID) INTO v_Max_Item_ID
    FROM CHECKLIST_ITEM
    WHERE Card_ID = p_Card_ID AND Checklist_ID = p_Checklist_ID;

    SET v_Next_Item_ID = IFNULL(v_Max_Item_ID, 0) + 1;

    INSERT INTO CHECKLIST_ITEM (Card_ID, Checklist_ID, Item_ID, Content, Is_Completed) 
    VALUES (p_Card_ID, p_Checklist_ID, v_Next_Item_ID, p_Content, FALSE);
END //

CREATE PROCEDURE GetCardsByBoard(
    IN p_Board_ID INT,
    IN p_Start_Time DATETIME,
    IN p_End_Time DATETIME
)
BEGIN
    -- 1. Validate Board Existence
    IF NOT EXISTS (SELECT 1 FROM BOARD WHERE Board_ID = p_Board_ID AND Is_Deleted = FALSE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Search Error: Board ID not found.';
    END IF;

    -- 2. Query Cards within Timeframe
    SELECT 
        b.Board_Title,
        l.List_Name,
        c.Card_ID,
        c.Card_Title,
        c.Start_Date,
        c.Due_Date,
        c.Is_Due_Complete,
        c.Duration
    FROM CARD c
    JOIN LIST l ON c.List_ID = l.List_ID
    JOIN BOARD b ON l.Board_ID = b.Board_ID
    WHERE b.Board_ID = p_Board_ID 
      AND c.Is_Deleted = FALSE 
      AND l.Is_Deleted = FALSE
      -- NEW: Timeframe filters
      AND (p_Start_Time IS NULL OR c.Start_Date >= p_Start_Time)
      AND (p_End_Time IS NULL OR c.Due_Date <= p_End_Time)
    ORDER BY l.Position ASC, c.Card_Title ASC;
END //

CREATE PROCEDURE GetListStatistics(
    IN p_Board_ID INT, 
    IN p_Min_Card_Count INT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM BOARD WHERE Board_ID = p_Board_ID AND Is_Deleted = FALSE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Search Error: Board ID does not exist or was deleted.';
    END IF;
    SELECT 
        l.List_ID,
        l.List_Name,
        COUNT(c.Card_ID) AS Total_Cards
    FROM LIST l
    LEFT JOIN CARD c ON l.List_ID = c.List_ID AND c.Is_Deleted = FALSE
    WHERE l.Board_ID = p_Board_ID
      AND l.Is_Deleted = FALSE
    GROUP BY l.List_ID, l.List_Name
    HAVING Total_Cards >= p_Min_Card_Count 
    ORDER BY Total_Cards DESC; 
END //

CREATE PROCEDURE GetUserByBoard(IN p_Board_ID INT)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM BOARD WHERE Board_ID = p_Board_ID AND Is_Deleted= FALSE ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Search Error: Board ID does not exist or was deleted.';
    END IF;
    SELECT u.First_Name, u.Last_Name,u.User_ID
    FROM USER_PROFILE u 
    JOIN BOARD_MEMBER b ON b.User_ID = u.User_ID
    WHERE b.Board_ID = p_Board_ID AND b.Is_Deleted = FALSE AND u.Is_Deleted = FALSE;
END//

CREATE PROCEDURE GetAssignmentByBoard(IN p_Board_ID INT)
BEGIN
    IF NOT EXISTS (SELECT 1 FROm BOARD WHERE Board_ID = p_Board_ID AND Is_Deleted = FALSE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Search Error: Board ID does not exist or was deleted.';
    END IF;
    SELECT u.User_ID,u.First_Name, u.Last_Name, c.Card_ID
    FROM CARD_ASSIGNMENT ca
    JOIN USER_PROFILE u ON ca.User_ID = u.User_ID
    JOIN CARD c ON ca.Card_ID = c.Card_ID
    JOIN LIST l on c.List_ID = l.List_ID
    WHERE l.Board_ID = p_Board_ID AND c.Is_Deleted = FALSE AND ca.Is_Deleted = FALSE AND l.Is_Deleted = FALSE AND u.Is_Deleted = FALSE;
END//

CREATE FUNCTION GetCardProgress(p_Card_ID INT) 
RETURNS DECIMAL(5,2)
reads sql data
BEGIN
    DECLARE v_done INT DEFAULT 0;
    DECLARE v_total INT DEFAULT 0;
    DECLARE v_is_completed BOOLEAN;
    DECLARE v_finished INT DEFAULT 0;
    
    DECLARE cur_items CURSOR FOR 
        SELECT Is_Completed FROM CHECKLIST_ITEM WHERE Card_ID = p_Card_ID AND Is_Deleted = FALSE;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_finished = 1;
    IF NOT EXISTS (SELECT 1 FROM CARD WHERE Card_ID = p_Card_ID AND Is_Deleted = FALSE) THEN
        RETURN -1.00;
    END IF;

    set v_finished = 0;
    OPEN cur_items;

    read_loop: LOOP
        FETCH cur_items INTO v_is_completed;
        IF v_finished THEN
            LEAVE read_loop;
        END IF;

        SET v_total = v_total + 1;
        IF v_is_completed = TRUE THEN
            SET v_done = v_done + 1;
        END IF;
    END LOOP;

    CLOSE cur_items;

    IF v_total = 0 THEN 
        RETURN 0.00; 
    ELSE 
        RETURN (v_done * 100.0) / v_total;
    END IF;
END //

CREATE FUNCTION GetUserBoardEfficiency(p_User_ID INT, p_Board_ID INT) 
RETURNS INT
reads sql data
BEGIN
    DECLARE v_assigned_count INT DEFAULT 0;
    DECLARE v_completed_count INT DEFAULT 0;
    DECLARE v_status BOOLEAN;
    DECLARE v_finished INT DEFAULT 0;
    
    DECLARE cur_efficiency CURSOR FOR 
        SELECT c.Is_Due_Complete 
        FROM CARD_ASSIGNMENT ca
        JOIN CARD c ON ca.Card_ID = c.Card_ID
        JOIN LIST l ON c.List_ID = l.List_ID
        WHERE ca.User_ID = p_User_ID 
          AND l.Board_ID = p_Board_ID
          AND c.Is_Deleted = FALSE
          AND ca.Is_Deleted = FALSE
          AND l.Is_Deleted = FALSE
          AND c.Due_Date IS NOT NULL;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_finished = 1;

    IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE User_ID = p_User_ID AND Is_Deleted = FALSE) OR 
       NOT EXISTS (SELECT 1 FROM BOARD WHERE Board_ID = p_Board_ID AND Is_Deleted = FALSE) THEN
        RETURN -1;
    END IF;

    OPEN cur_efficiency;

    eff_loop: LOOP
        FETCH cur_efficiency INTO v_status;
        IF v_finished THEN
            LEAVE eff_loop;
        END IF;

        SET v_assigned_count = v_assigned_count + 1;
        IF v_status = TRUE THEN
            SET v_completed_count = v_completed_count + 1;
        END IF;
    END LOOP;

    CLOSE cur_efficiency;

    IF v_assigned_count = 0 THEN 
        RETURN 0; 
    ELSE 
        RETURN (v_completed_count * 100) / v_assigned_count;
    END IF;
END //

DELIMITER ;