const sqlite3 = require('sqlite3').verbose();
const path = require('path');

// 创建数据库连接
const dbPath = path.resolve(__dirname, 'cadre_assessment.db');
const db = new sqlite3.Database(dbPath, (err) => {
  if (err) {
    console.error('数据库连接错误:', err.message);
  } else {
    console.log('成功连接到SQLite数据库');
  }
});

// 初始化数据库表结构
db.serialize(() => {
  // 创建干部表
  db.run(`CREATE TABLE IF NOT EXISTS cadres (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    department TEXT,
    position TEXT,
    major TEXT,
    class TEXT,
    grade TEXT,
    equipmentScore REAL DEFAULT 0
  )`, (err) => {
    if (err) {
      console.error('创建干部表错误:', err.message);
    } else {
      console.log('干部表创建成功');
    }
  });

  // 创建比赛成绩表
  db.run(`CREATE TABLE IF NOT EXISTS competitions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cadreId TEXT NOT NULL,
    name TEXT,
    level TEXT,
    award TEXT,
    score REAL,
    FOREIGN KEY (cadreId) REFERENCES cadres(id)
  )`, (err) => {
    if (err) {
      console.error('创建比赛成绩表错误:', err.message);
    } else {
      console.log('比赛成绩表创建成功');
    }
  });

  // 创建协会贡献表
  db.run(`CREATE TABLE IF NOT EXISTS contributions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cadreId TEXT NOT NULL,
    type TEXT,
    count INTEGER,
    totalScore REAL,
    FOREIGN KEY (cadreId) REFERENCES cadres(id)
  )`, (err) => {
    if (err) {
      console.error('创建协会贡献表错误:', err.message);
    } else {
      console.log('协会贡献表创建成功');
    }
  });

  // 创建新生指导表
  db.run(`CREATE TABLE IF NOT EXISTS trainings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cadreId TEXT NOT NULL,
    traineeName TEXT,
    hours REAL,
    score REAL,
    FOREIGN KEY (cadreId) REFERENCES cadres(id)
  )`, (err) => {
    if (err) {
      console.error('创建新生指导表错误:', err.message);
    } else {
      console.log('新生指导表创建成功');
    }
  });

  // 创建职责扣分表
  db.run(`CREATE TABLE IF NOT EXISTS deductions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cadreId TEXT NOT NULL,
    score REAL,
    reason TEXT,
    FOREIGN KEY (cadreId) REFERENCES cadres(id)
  )`, (err) => {
    if (err) {
      console.error('创建职责扣分表错误:', err.message);
    } else {
      console.log('职责扣分表创建成功');
    }
  });

  // 创建管理员密码表
  db.run(`CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT
  )`, (err) => {
    if (err) {
      console.error('创建设置表错误:', err.message);
    } else {
      // 默认密码设置
      db.get(`SELECT * FROM settings WHERE key = 'adminPassword'`, (err, row) => {
        if (err) {
          console.error('查询密码错误:', err.message);
        } else if (!row) {
          // 设置默认密码
          db.run(`INSERT INTO settings (key, value) VALUES ('adminPassword', '123456')`, (err) => {
            if (err) {
              console.error('设置默认密码错误:', err.message);
            } else {
              console.log('默认密码设置成功');
            }
          });
        }
      });
    }
  });
});

module.exports = db;