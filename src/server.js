import express from 'express';
import cors from 'cors';
import db from './config/db.js';

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());

app.get('/api/workspaces', async (req, res) => {
    try {
        const [rows] = await db.query('SELECT * FROM WORKSPACE WHERE Is_Deleted = FALSE');
        res.json(rows);
    } catch (error) {
        console.error("Error fetching workspaces:", error);
        res.status(500).json({ error: "Internal Server Error" });
    }
});
app.post('/api/cards', async (req, res) => {
    try {
        const { title, description, listId, startDate, dueDate } = req.body;
        const [result] = await db.query('CALL InsertCard(?,?,?,?,?)', [title, description, startDate, dueDate, listId]);
        res.status(201).json({ Message: "Card created successfully" });
    }
    catch (error) {
        if (error.sqlState === '45000')
            res.status(400).json({ error: error.message });
        else
            res.status(500).json({ error: "Internal Server Error" });
    }
});
app.get('/api/boards/:id/cards', async (req, res) => {
    try {
        const boardId = req.params.id;
        const [results] = await db.query('CALL GetCardsByBoard(?)', [boardId]);
        res.json(results[0]);
    } catch (error) {
        if (error.sqlState === '45000')
            res.status(400).json({ error: error.message });
        else
            res.status(500).json({ error: "Internal Server Error" });
    }
});
app.get('/api/cards/:id/progress', async (req, res) => {
    try {
        const cardId = req.params.id;
        const [rows] = await db.query('SELECT GetCardProgress(?) AS progress', [cardId]);
        res.json(rows[0]);
    } catch (error) {
        if (error.sqlState === '45000')
            res.status(400).json({ error: error.message });
        else
            res.status(500).json({ error: "Internal Server Error" });
    }
});
app.put('/api/cards/:id', async (req, res) => {
    try {
        const cardId = req.params.id;
        const { title, dueDate, isComplete } = req.body;

        await db.query('CALL UpdateCard(?, ?, ?, ?)', [cardId, title, dueDate, isComplete]);
        res.json({ message: "Card updated successfully" });
    } catch (error) {
        if (error.sqlState === '45000')
            res.status(400).json({ error: error.message });
        else
            res.status(500).json({ error: "Internal Server Error" });
    }
});
app.delete('/api/cards/:id', async (req, res) => {
    try {
        const cardId = req.params.id;
        await db.query('CALL DeleteCard(?)', [cardId]);
        res.json({ message: "Card deleted successfully" });
    } catch (error) {
        if (error.sqlState === '45000')
            res.status(400).json({ error: error.message });
        else
            res.status(500).json({ error: "Internal Server Error" });
    }
});
app.get('/api/boards/:id/statistics', async (req, res) => {
    try {
        const boardId = req.params.id;
        const minCards = req.query.minCards || 0;
        const [results] = await db.query('CALL GetListStatistics(?, ?)', [boardId, minCards]);
        res.json(results[0]);
    } catch (error) {
        if (error.sqlState === '45000')
            res.status(400).json({ error: error.message });
        else
            res.status(500).json({ error: "Internal Server Error" });
    }
});
app.get('/api/boards/:id/members', async (req, res) => {
    try {
        const boardId = req.params.id;
        const [rows] = await db.query(`CALL GetUserByBoard(?)`, [boardId]);
        res.json(rows[0]);
    } catch (error) {
        if (error.sqlState === '45000')
            res.status(400).json({ error: error.message });
        else
            res.status(500).json({ error: "Internal Server Error" });
    }
});
app.get('/api/boards/:id/assignments', async (req, res) => {
    try {
        const [rows] = await db.query(`CALL GetAssignmentByBoard(?)`, [req.params.id]);
        res.json(rows[0]);
    } catch (error) {
        if (error.sqlState === '45000')
            res.status(400).json({ error: error.message });
        else
            res.status(500).json({ error: "Internal Server Error" });
    }
});
app.get('/api/users/:userId/boards/:boardId/efficiency', async (req, res) => {
    try {
        const { userId, boardId } = req.params;

        const [rows] = await db.query('SELECT GetUserBoardEfficiency(?, ?) AS efficiencyScore', [userId, boardId]);
        res.json(rows[0]);
    } catch (error) {
        if (error.sqlState === '45000')
            res.status(400).json({ error: error.message });
        else
            res.status(500).json({ error: "Internal Server Error" });
    }
});
app.post('/api/cards/:id/assignments', async (req, res) => {
    try {
        const cardId = req.params.id;
        const { userId } = req.body;
        await db.query('INSERT INTO CARD_ASSIGNMENT (User_ID, Card_ID) VALUES (?, ?)', [userId, cardId]);
        res.status(201).json({ message: "Assigned successfully" });
    } catch (error) {
        if (error.sqlState === '45000')
            res.status(400).json({ error: error.message });
        else
            res.status(500).json({ error: "Internal Server Error" });
    }
});
app.get('/api/cards/:id/checklists', async (req, res) => {
    try {
        const [rows] = await db.query('SELECT * FROM CHECKLIST_ITEM WHERE Card_ID = ? AND Is_Deleted = FALSE', [req.params.id]);
        res.json(rows);
    } catch (error) {
        if (error.sqlState === '45000')
            res.status(400).json({ error: error.message });
        else
            res.status(500).json({ error: "Internal Server Error" });
    }
});
app.post('/api/cards/:id/checklists', async (req, res) => {
    try {
        const cardId = req.params.id;
        const { content, checklistId } = req.body;
        await db.query('CALL InsertChecklistItem(?,?,?)', [cardId, checklistId, content])
        res.status(201).json({ message: "Checklist item added" });
    } catch (error) {
        if (error.sqlState === '45000')
            res.status(400).json({ error: error.message });
        else
            res.status(500).json({ error: "Internal Server Error" });
    }
});
app.put('/api/checklists/:itemId', async (req, res) => {
    try {
        const { cardId, checklistId, isComplete } = req.body;
        await db.query('CALL ToggleChecklistItem(?, ?, ?, ?)', [cardId, checklistId, req.params.itemId, isComplete]);
        res.json({ message: "Checklist updated" });
    } catch (error) {
        if (error.sqlState === '45000')
            res.status(400).json({ error: error.message });
        else
            res.status(500).json({ error: "Internal Server Error" });
    }
});
app.listen(PORT, () => {
    console.log(`Server is running on http://localhost:${PORT}`);
});