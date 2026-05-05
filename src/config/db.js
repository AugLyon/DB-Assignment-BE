import mysql from 'mysql2/promise';
import dotenv from 'dotenv';
import fs from 'fs';
dotenv.config();

// Create a connection pool
const pool = mysql.createPool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    port: process.env.DB_PORT,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
    ssl: {
        ca: fs.readFileSync('./src/config/ca-certificate.pem'),
        rejectUnauthorized: true
    }
});

pool.getConnection()
    .then(connection => {
        console.log('Successfully connected to the MySQL database!');
        connection.release();
    })
    .catch(error => {
        console.error('Database connection failed:', error);
    });

export default pool;