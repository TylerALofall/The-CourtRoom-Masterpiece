# Evidence Management System - Complete Setup Guide

## 🚀 Quick Start

### Prerequisites
- Node.js 18+ installed
- Google Cloud Console account (for Drive & Gemini APIs)
- SQLite3 installed

### Step 1: Clone/Create Project
```bash
mkdir evidence-management-system
cd evidence-management-system
```

### Step 2: Save the Files
1. Save the HTML file as `public/index.html`
2. Save the server code as `server.js`
3. Save the package.json file
4. Create `.env` file with your credentials

### Step 3: Install Dependencies
```bash
npm install
```

### Step 4: Set Up Google APIs

#### A. Google Drive API Setup
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project or select existing
3. Enable Google Drive API
4. Create credentials (OAuth 2.0 Client ID)
5. Add authorized redirect URI: `http://localhost:3000/auth/google/callback`
6. Copy Client ID and Client Secret to `.env`

#### B. Gemini API Setup
1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Create API key
3. Copy to `.env` file as `GEMINI_API_KEY`

### Step 5: Initialize Database
```bash
node scripts/init-database.js
```

### Step 6: Start the Server
```bash
npm start
# or for development with auto-reload
npm run dev
```

### Step 7: Access the Application
Open browser to: `http://localhost:3000`

---

## 📁 Project Structure

```
evidence-management-system/
├── server.js                 # Main server file
├── package.json             # Dependencies
├── .env                     # Environment variables
├── evidence.db              # SQLite database
├── public/
│   └── index.html          # Frontend application
├── uploads/                 # Uploaded files
├── backups/                 # Database backups
├── logs/                    # Application logs
└── scripts/
    ├── init-database.js     # Database initialization
    ├── backup.js           # Backup script
    └── migrate.js          # Migration script
```

---

## 🔧 Utility Scripts

### scripts/init-database.js
```javascript
const sqlite3 = require('sqlite3').verbose();
const { open } = require('sqlite');
const path = require('path');

async function initDatabase() {
    const db = await open({
        filename: path.join(__dirname, '..', 'evidence.db'),
        driver: sqlite3.Database
    });

    console.log('Initializing database...');

    // Create all tables
    await db.exec(`
        CREATE TABLE IF NOT EXISTS evidence_cards (
            uid TEXT PRIMARY KEY,
            location TEXT,
            date_of_event DATE,
            time_of_event TIME,
            claim_clause TEXT,
            claim_element TEXT,
            parties_involved TEXT,
            description_of_evidence TEXT,
            depiction_quote TEXT,
            significance TEXT,
            precedence TEXT,
            oath_of_auth TEXT,
            notes TEXT,
            complements_uid TEXT,
            citation TEXT,
            source TEXT,
            state_produced BOOLEAN,
            screenshot_url TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            sha256_hash TEXT
        );

        CREATE TABLE IF NOT EXISTS files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uid TEXT,
            filename TEXT,
            original_name TEXT,
            mimetype TEXT,
            size INTEGER,
            path TEXT,
            drive_id TEXT,
            sha256_hash TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (uid) REFERENCES evidence_cards(uid)
        );

        CREATE TABLE IF NOT EXISTS analysis (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uid TEXT,
            prompt TEXT,
            result TEXT,
            model TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (uid) REFERENCES evidence_cards(uid)
        );

        CREATE TABLE IF NOT EXISTS case_law (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uid TEXT,
            case_name TEXT,
            citation TEXT,
            relevance TEXT,
            summary TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (uid) REFERENCES evidence_cards(uid)
        );

        CREATE INDEX IF NOT EXISTS idx_evidence_date ON evidence_cards(date_of_event);
        CREATE INDEX IF NOT EXISTS idx_evidence_claim ON evidence_cards(claim_element);
        CREATE INDEX IF NOT EXISTS idx_files_uid ON files(uid);
        CREATE INDEX IF NOT EXISTS idx_analysis_uid ON analysis(uid);
    `);

    console.log('Database initialized successfully!');
    await db.close();
}

initDatabase().catch(console.error);
```

### scripts/backup.js
```javascript
const sqlite3 = require('sqlite3').verbose();
const { open } = require('sqlite');
const fs = require('fs').promises;
const path = require('path');

async function backupDatabase() {
    const db = await open({
        filename: path.join(__dirname, '..', 'evidence.db'),
        driver: sqlite3.Database
    });

    const backupDir = path.join(__dirname, '..', 'backups');
    await fs.mkdir(backupDir, { recursive: true });

    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupFile = path.join(backupDir, `backup_${timestamp}.json`);

    const backup = {
        timestamp: new Date().toISOString(),
        evidence_cards: await db.all('SELECT * FROM evidence_cards'),
        files: await db.all('SELECT * FROM files'),
        analysis: await db.all('SELECT * FROM analysis'),
        case_law: await db.all('SELECT * FROM case_law')
    };

    await fs.writeFile(backupFile, JSON.stringify(backup, null, 2));
    console.log(`Backup created: ${backupFile}`);

    // Clean old backups (keep last 30)
    const files = await fs.readdir(backupDir);
    const backupFiles = files
        .filter(f => f.startsWith('backup_'))
        .sort()
        .reverse();

    for (let i = 30; i < backupFiles.length; i++) {
        await fs.unlink(path.join(backupDir, backupFiles[i]));
        console.log(`Deleted old backup: ${backupFiles[i]}`);
    }

    await db.close();
}

backupDatabase().catch(console.error);
```

### scripts/migrate.js
```javascript
const sqlite3 = require('sqlite3').verbose();
const { open } = require('sqlite');
const path = require('path');

async function migrate() {
    const db = await open({
        filename: path.join(__dirname, '..', 'evidence.db'),
        driver: sqlite3.Database
    });

    console.log('Running migrations...');

    // Add new columns if they don't exist
    try {
        await db.exec(`ALTER TABLE evidence_cards ADD COLUMN tags TEXT`);
        console.log('Added tags column');
    } catch (e) {
        // Column already exists
    }

    try {
        await db.exec(`ALTER TABLE evidence_cards ADD COLUMN priority INTEGER DEFAULT 0`);
        console.log('Added priority column');
    } catch (e) {
        // Column already exists
    }

    console.log('Migrations complete!');
    await db.close();
}

migrate().catch(console.error);
```

---

## 🔐 Security Configuration

### Generate Secure Keys
```bash
# Generate JWT Secret
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"

# Generate Session Secret
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"

# Generate Encryption Key (32 chars)
node -e "console.log(require('crypto').randomBytes(16).toString('hex'))"
```

---

## 📊 API Endpoints

### Evidence Cards
- `GET /api/evidence` - Get all evidence cards
- `GET /api/evidence/:uid` - Get specific evidence card
- `POST /api/evidence` - Create new evidence card
- `PUT /api/evidence/:uid` - Update evidence card
- `DELETE /api/evidence/:uid` - Delete evidence card

### Files
- `POST /api/upload/:uid` - Upload files for evidence
- `GET /api/files/:uid` - Get files for evidence

### Analysis
- `POST /api/gemini/analyze` - Analyze with Gemini AI
- `POST /api/search/rag` - RAG search
- `GET /api/analysis/:uid` - Get analysis for evidence

### Import/Export
- `GET /api/export/csv` - Export to CSV
- `POST /api/import/csv` - Import from CSV
- `GET /api/backup` - Download full backup
- `POST /api/restore` - Restore from backup

### Google Drive
- `GET /auth/google` - Initiate Google auth
- `POST /api/drive/upload` - Upload to Drive

---

## 🎯 Features

### Core Features
✅ Evidence card creation with full JSON schema support
✅ File upload and management
✅ Google Drive integration
✅ Gemini AI analysis
✅ RAG search with AI-powered insights
✅ CSV import/export
✅ Database backup/restore
✅ Timeline view
✅ SHA-256 hash verification
✅ Full-text search
✅ Parties tracking

### Advanced Features
✅ Multi-file upload
✅ OCR support for PDFs and images
✅ Case law management
✅ Automated backups
✅ API rate limiting
✅ Secure file storage
✅ Real-time analysis

---

## 🚨 Troubleshooting

### Common Issues

1. **Database locked error**
   - Solution: Close other connections to the database
   - Run: `fuser evidence.db` to check processes

2. **Gemini API errors**
   - Check API key in `.env`
   - Verify quota limits in Google AI Studio

3. **Google Drive auth issues**
   - Ensure redirect URI matches exactly
   - Check OAuth consent screen configuration

4. **File upload failures**
   - Check `MAX_FILE_SIZE` in `.env`
   - Ensure `uploads/` directory exists and has write permissions

---

## 📈 Performance Tips

1. **Database Optimization**
   ```sql
   VACUUM;
   ANALYZE;
   ```

2. **Enable Compression**
   - Already configured in server.js with compression middleware

3. **Use CDN for Static Files**
   - Consider CloudFlare or similar for production

4. **Regular Backups**
   - Set up cron job: `0 2 * * * node /path/to/scripts/backup.js`

---

## 🔄 Updates & Maintenance

### Update Dependencies
```bash
npm update
npm audit fix
```

### Check Database Integrity
```bash
sqlite3 evidence.db "PRAGMA integrity_check;"
```

### Clean Old Files
```bash
find ./uploads -mtime +90 -delete
find ./backups -mtime +30 -delete
```

---

## 📝 Production Deployment

### Using Docker
```bash
docker-compose up -d
```

### Using PM2
```bash
npm install -g pm2
pm2 start server.js --name evidence-system
pm2 save
pm2 startup
```

### SSL Setup
1. Get SSL certificate (Let's Encrypt recommended)
2. Update nginx.conf with SSL configuration
3. Update redirect URI in Google Console

---

## 💡 Usage Tips

### Evidence Card Best Practices
1. Use consistent UID format (e.g., claim_number + defendant_number)
2. Always include date and time for timeline accuracy
3. Add comprehensive case law citations
4. Use tags for easy categorization

### File Management
1. Name files descriptively before upload
2. Keep file sizes under 50MB for optimal performance
3. Use PDF format for documents when possible

### Search Optimization
1. Include key terms in description and notes
2. Use consistent terminology across cards
3. Regular backups before major changes

---

## 🆘 Support

For issues or questions:
1. Check logs in `./logs` directory
2. Review API responses in browser console
3. Verify all environment variables are set
4. Test with smaller datasets first

---

## 📜 License

MIT License - Feel free to modify for your needs

---

## 🎉 Ready to Go!

Your Evidence Management System is now fully configured with:
- ✅ Gemini AI integration for intelligent analysis
- ✅ Google Drive for cloud storage
- ✅ CSV database for mail merge
- ✅ RAG search for finding relevant evidence
- ✅ Complete file library with page linking
- ✅ Automated backups
- ✅ Trial presentation ready

Access at: **http://localhost:3000**

Good luck with your case, Tyler! 💪⚖️