
DROP PROCEDURE IF EXISTS InsertCard;
DROP PROCEDURE IF EXISTS UpdateCard;
DROP PROCEDURE IF EXISTS DeleteCard;
DROP TRIGGER IF EXISTS Before_Insert_Card_Assignment;
DROP TRIGGER IF EXISTS Before_Insert_Card_Duration;
DROP TRIGGER IF EXISTS trg_Before_Update_Card_Duration;
DROP PROCEDURE IF EXISTS GetCardsByBoard;
DROP PROCEDURE IF EXISTS GetListStatistics;
DROP FUNCTION IF EXISTS GetCardProgress;
DROP FUNCTION IF EXISTS GetUserBoardEfficiency;

DELIMITER //

CREATE PROCEDURE InsertCard(
    IN p_Card_Title VARCHAR(255),
    IN p_Card_Name VARCHAR(255),
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
    INSERT INTO CARD (Card_Title, Card_Name, Description, Start_Date, Due_Date, List_ID)
    VALUES (p_Card_Title, p_Card_Name, p_Description, p_Start_Date, p_Due_Date, p_List_ID);
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
    IF TRIM(p_New_Title) = '' THEN
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
        SET MESSAGE_TEXT = 'Delete Disallowed: This card is currently blocking other cards. You must remove dependencies before deleting.';
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
    WHERE c.Card_ID = NEW.Card_ID;
    
    SELECT COUNT(*) INTO is_member
    FROM BOARD_MEMBER
    WHERE User_ID = NEW.User_ID and Board_ID = board_id;
    
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
        SET NEW.Duration = DATEDIFF(NEW.Due_Date, NEW.Start_Date);
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
            SET NEW.Duration = DATEDIFF(NEW.Due_Date, NEW.Start_Date);
        ELSE
            SET NEW.Duration = NULL;
        END IF;
    END IF;
END //

CREATE PROCEDURE GetCardsByBoard(IN p_Board_ID INT)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM BOARD WHERE Board_ID = p_Board_ID AND Is_Deleted = FALSE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Search Error: Board ID not found.';
    END IF;

    SELECT 
        b.Board_Title,
        l.List_Name,
        c.Card_ID,
        c.Card_Title,
        c.Due_Date,
        c.Is_Due_Complete
    FROM CARD c
    JOIN LIST l ON c.List_ID = l.List_ID
    JOIN BOARD b ON l.Board_ID = b.Board_ID
    WHERE b.Board_ID = p_Board_ID 
      AND c.Is_Deleted = FALSE
    ORDER BY l.Position ASC, c.Card_Title ASC;
END //

CREATE PROCEDURE GetListStatistics(
    IN p_Board_ID INT, 
    IN p_Min_Card_Count INT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM BOARD WHERE Board_ID = p_Board_ID AND Is_Deleted = FALSE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Search Error: Board ID not found.';
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

CREATE FUNCTION GetCardProgress(p_Card_ID INT) 
RETURNS DECIMAL(5,2)
READS SQL DATA
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
READS SQL DATA
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
          AND c.Is_Deleted = FALSE;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_finished = 1;

    IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE User_ID = p_User_ID) OR 
       NOT EXISTS (SELECT 1 FROM BOARD WHERE Board_ID = p_Board_ID AND Is_Deleted = FALSE) THEN
        RETURN 0;
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