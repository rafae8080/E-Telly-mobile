const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');

const app = express();
const port = 3000;

app.use(cors());
app.use(express.json());

app.post('/api/users/register', async (req, res) => {
    try {
        const { fullName, email, barangay, street, password } = req.body;
        const hashedPassword = await bcrypt.hash(password, 10);
        // Registration logic would go here; database has been removed.
        res.status(201).json({ 
            message: 'Registered', 
            user: { fullName, email, barangay, street } 
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// app.get('/api/users', async (req, res) => {
//     try {
//         const users = await usersCollection.find().toArray();
//         res.json(users);
//     } catch (error) {
//         res.status(500).json({ error: error.message });
//     }
// });

app.get('/api/health', (req, res) => {
    res.json({ status: 'OK' });
});

app.listen(port, () => {
    console.log(`Server on port ${port}`);
});