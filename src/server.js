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
app.post('/api/cards', async (req,res)=>{
    try{
        const {title, name, description, listid,startdate, duedate}= req.body;
        const [result] = await db.query('CALL InsertCard(?,?,?,?,?,?)', [title, name, description, startdate, duedate,listid]);
        res.status(201).json({Message: "Card created successfully"});
    }
    catch(error){
        res.status(400).json({error: error.message});
    }
});
app.get('/api/boards/:id/cards', async (req, res) => {
    try {
        const boardId = req.params.id;
        const [results] = await db.query('CALL GetCardsByBoard(?)', [boardId]);
        res.json(results[0]);
    } catch (error) {
        res.status(400).json({ error: error.message });
    }
});
app.get('/api/cards/:id/progress', async (req, res) => {
    try {
        const cardId = req.params.id;
        const [rows] = await db.query('SELECT GetCardProgress(?) AS progress', [cardId]);
        res.json(rows[0]);
    } catch (error) {
        res.status(400).json({ error: error.message });
    }
});
app.put('/api/cards/:id', async (req, res) => {
    try {
        const cardId = req.params.id;
        const { title, dueDate, isComplete } = req.body;

        await db.query('CALL UpdateCard(?, ?, ?, ?)', [cardId, title, dueDate, isComplete]);
        res.json({ message: "Card updated successfully" });
    } catch (error) {
        res.status(400).json({ error: error.message });
    }
});
app.delete('/api/cards/:id', async (req, res) => {
    try {
        const cardId = req.params.id;
        await db.query('CALL DeleteCard(?)', [cardId]);
        res.json({ message: "Card deleted successfully" });
    } catch (error) {
        res.status(400).json({ error: error.message });
    }
});
app.get('/api/boards/:id/statistics', async (req, res) => {
    try {
        const boardId = req.params.id;
        const minCards = req.query.minCards || 0;
        const [results] = await db.query('CALL GetListStatistics(?, ?)', [boardId, minCards]);
        res.json(results[0]);
    } catch (error) {
        res.status(400).json({ error: error.message });
    }
});

app.post('/api/cards/:id/assignments', async (req, res) => {
    try {
        const cardId = req.params.id;
        const { userId } = req.body;
        await db.query('INSERT INTO CARD_ASSIGNMENT (User_ID, Card_ID) VALUES (?, ?)', [userId, cardId]);
        res.status(201).json({ message: "Assigned successfully" });
    } catch (error) {
        res.status(400).json({ error: error.message });
    }
});

app.post('/api/cards/:id/dependencies', async (req, res) => {
    try {
        const blockerCardId = req.params.id;
        const { blockedCardId } = req.body;
        await db.query('INSERT INTO CARD_DEPENDENCY (Blocked_Card_ID, Blocker_Card_ID) VALUES (?, ?)', [blockedCardId, blockerCardId]);
        res.status(201).json({ message: "Dependency created successfully" });
    } catch (error) {
        res.status(400).json({ error: error.message });
    }
});
app.listen(PORT, () => {
    console.log(`Server is running on http://localhost:${PORT}`);
});