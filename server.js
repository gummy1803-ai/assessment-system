const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const db = require('./db');

const app = express();
const PORT = process.env.PORT || 3000;

// 中间件
app.use(cors());
app.use(bodyParser.json());

// 根路径处理
app.get('/', (req, res) => {
  res.json({
    message: '干部考核管理系统同步服务器',
    version: '1.0.0',
    status: 'running',
    documentation: '访问 /api/ 端点获取API信息',
    endpoints: {
      sync: '/api/sync/all',
      cadres: '/api/cadres',
      competitions: '/api/competitions',
      contributions: '/api/contributions',
      trainings: '/api/trainings',
      deductions: '/api/deductions'
    }
  });
});

// API路由

// 1. 干部管理API

// 获取所有干部
app.get('/api/cadres', (req, res) => {
  db.all('SELECT * FROM cadres', [], (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    res.json(rows);
  });
});

// 获取单个干部
app.get('/api/cadres/:id', (req, res) => {
  const { id } = req.params;
  db.get('SELECT * FROM cadres WHERE id = ?', [id], (err, row) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    res.json(row);
  });
});

// 创建/更新干部
app.post('/api/cadres', (req, res) => {
  const { id, name, department, position, major, class: className, grade, equipmentScore } = req.body;
  
  if (!id || !name) {
    return res.status(400).json({ error: '缺少必要参数' });
  }
  
  db.run(
    `INSERT OR REPLACE INTO cadres (id, name, department, position, major, class, grade, equipmentScore) 
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [id, name, department, position, major, className, grade, equipmentScore || 0],
    function(err) {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      res.json({ message: '干部信息保存成功' });
    }
  );
});

// 删除干部
app.delete('/api/cadres/:id', (req, res) => {
  const { id } = req.params;
  
  // 先删除相关数据
  db.run('DELETE FROM competitions WHERE cadreId = ?', [id], (err) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    
    db.run('DELETE FROM contributions WHERE cadreId = ?', [id], (err) => {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      
      db.run('DELETE FROM trainings WHERE cadreId = ?', [id], (err) => {
        if (err) {
          res.status(500).json({ error: err.message });
          return;
        }
        
        db.run('DELETE FROM deductions WHERE cadreId = ?', [id], (err) => {
          if (err) {
            res.status(500).json({ error: err.message });
            return;
          }
          
          // 删除干部信息
          db.run('DELETE FROM cadres WHERE id = ?', [id], function(err) {
            if (err) {
              res.status(500).json({ error: err.message });
              return;
            }
            res.json({ message: '干部信息删除成功' });
          });
        });
      });
    });
  });
});

// 2. 比赛成绩API

// 获取所有比赛成绩
app.get('/api/competitions', (req, res) => {
  db.all('SELECT * FROM competitions', [], (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    res.json(rows);
  });
});

// 按干部获取比赛成绩
app.get('/api/competitions/cadre/:id', (req, res) => {
  const { id } = req.params;
  db.all('SELECT * FROM competitions WHERE cadreId = ?', [id], (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    res.json(rows);
  });
});

// 添加比赛成绩
app.post('/api/competitions', (req, res) => {
  const { cadreId, name, level, award, score } = req.body;
  
  if (!cadreId || !score) {
    return res.status(400).json({ error: '缺少必要参数' });
  }
  
  db.run(
    `INSERT INTO competitions (cadreId, name, level, award, score) 
     VALUES (?, ?, ?, ?, ?)`,
    [cadreId, name, level, award, score],
    function(err) {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      res.json({ message: '比赛成绩添加成功' });
    }
  );
});

// 删除比赛成绩
app.delete('/api/competitions/:id', (req, res) => {
  const { id } = req.params;
  db.run('DELETE FROM competitions WHERE id = ?', [id], function(err) {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    res.json({ message: '比赛成绩删除成功' });
  });
});

// 3. 协会贡献API

// 获取所有协会贡献
app.get('/api/contributions', (req, res) => {
  db.all('SELECT * FROM contributions', [], (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    res.json(rows);
  });
});

// 按干部获取协会贡献
app.get('/api/contributions/cadre/:id', (req, res) => {
  const { id } = req.params;
  db.all('SELECT * FROM contributions WHERE cadreId = ?', [id], (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    res.json(rows);
  });
});

// 添加协会贡献
app.post('/api/contributions', (req, res) => {
  const { cadreId, type, count, totalScore } = req.body;
  
  if (!cadreId || !count || !totalScore) {
    return res.status(400).json({ error: '缺少必要参数' });
  }
  
  db.run(
    `INSERT INTO contributions (cadreId, type, count, totalScore) 
     VALUES (?, ?, ?, ?)`,
    [cadreId, type, count, totalScore],
    function(err) {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      res.json({ message: '协会贡献添加成功' });
    }
  );
});

// 删除协会贡献
app.delete('/api/contributions/:id', (req, res) => {
  const { id } = req.params;
  db.run('DELETE FROM contributions WHERE id = ?', [id], function(err) {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    res.json({ message: '协会贡献删除成功' });
  });
});

// 4. 新生指导API

// 获取所有新生指导记录
app.get('/api/trainings', (req, res) => {
  db.all('SELECT * FROM trainings', [], (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    res.json(rows);
  });
});

// 按干部获取新生指导记录
app.get('/api/trainings/cadre/:id', (req, res) => {
  const { id } = req.params;
  db.all('SELECT * FROM trainings WHERE cadreId = ?', [id], (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    res.json(rows);
  });
});

// 添加新生指导记录
app.post('/api/trainings', (req, res) => {
  const { cadreId, traineeName, hours, score } = req.body;
  
  if (!cadreId || !traineeName || !hours || !score) {
    return res.status(400).json({ error: '缺少必要参数' });
  }
  
  db.run(
    `INSERT INTO trainings (cadreId, traineeName, hours, score) 
     VALUES (?, ?, ?, ?)`,
    [cadreId, traineeName, hours, score],
    function(err) {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      res.json({ message: '新生指导记录添加成功' });
    }
  );
});

// 删除新生指导记录
app.delete('/api/trainings/:id', (req, res) => {
  const { id } = req.params;
  db.run('DELETE FROM trainings WHERE id = ?', [id], function(err) {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    res.json({ message: '新生指导记录删除成功' });
  });
});

// 5. 职责扣分API

// 获取所有职责扣分
app.get('/api/deductions', (req, res) => {
  db.all('SELECT * FROM deductions', [], (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    res.json(rows);
  });
});

// 按干部获取职责扣分
app.get('/api/deductions/cadre/:id', (req, res) => {
  const { id } = req.params;
  db.all('SELECT * FROM deductions WHERE cadreId = ?', [id], (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    res.json(rows);
  });
});

// 添加职责扣分
app.post('/api/deductions', (req, res) => {
  const { cadreId, score, reason } = req.body;
  
  if (!cadreId || !score) {
    return res.status(400).json({ error: '缺少必要参数' });
  }
  
  db.run(
    `INSERT INTO deductions (cadreId, score, reason) 
     VALUES (?, ?, ?)`,
    [cadreId, score, reason],
    function(err) {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      res.json({ message: '职责扣分添加成功' });
    }
  );
});

// 删除职责扣分
app.delete('/api/deductions/:id', (req, res) => {
  const { id } = req.params;
  db.run('DELETE FROM deductions WHERE id = ?', [id], function(err) {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    res.json({ message: '职责扣分删除成功' });
  });
});

// 6. 数据同步API

// 获取所有数据（用于同步）
app.get('/api/sync/all', (req, res) => {
  const data = {
    cadres: [],
    competitions: [],
    contributions: [],
    trainings: [],
    deductions: []
  };
  
  db.all('SELECT * FROM cadres', [], (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    data.cadres = rows;
    
    db.all('SELECT * FROM competitions', [], (err, rows) => {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      data.competitions = rows;
      
      db.all('SELECT * FROM contributions', [], (err, rows) => {
        if (err) {
          res.status(500).json({ error: err.message });
          return;
        }
        data.contributions = rows;
        
        db.all('SELECT * FROM trainings', [], (err, rows) => {
          if (err) {
            res.status(500).json({ error: err.message });
            return;
          }
          data.trainings = rows;
          
          db.all('SELECT * FROM deductions', [], (err, rows) => {
            if (err) {
              res.status(500).json({ error: err.message });
              return;
            }
            data.deductions = rows;
            
            // 发送所有数据
            res.json(data);
          });
        });
      });
    });
  });
});

// 批量同步数据（用于上传本地数据到服务器）
app.post('/api/sync/upload', (req, res) => {
  const { cadres, competitions, contributions, trainings, deductions } = req.body;
  
  // 开始事务
  db.run('BEGIN TRANSACTION', (err) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    
    // 1. 同步干部数据
    const cadrePromises = cadres.map(cadre => {
      return new Promise((resolve, reject) => {
        db.run(
          `INSERT OR REPLACE INTO cadres (id, name, department, position, major, class, grade, equipmentScore) 
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
          [cadre.id, cadre.name, cadre.department, cadre.position, cadre.major, cadre.class, cadre.grade, cadre.equipmentScore || 0],
          function(err) {
            if (err) {
              reject(err);
            } else {
              resolve();
            }
          }
        );
      });
    });
    
    // 2. 同步比赛成绩
    const competitionPromises = competitions.map(comp => {
      return new Promise((resolve, reject) => {
        db.run(
          `INSERT OR REPLACE INTO competitions (id, cadreId, name, level, award, score) 
           VALUES (?, ?, ?, ?, ?, ?)`,
          [comp.id, comp.cadreId, comp.name, comp.level, comp.award, comp.score],
          function(err) {
            if (err) {
              reject(err);
            } else {
              resolve();
            }
          }
        );
      });
    });
    
    // 执行所有同步操作
    Promise.all([...cadrePromises, ...competitionPromises])
      .then(() => {
        // 3. 同步协会贡献
        const contributionPromises = contributions.map(contrib => {
          return new Promise((resolve, reject) => {
            db.run(
              `INSERT OR REPLACE INTO contributions (id, cadreId, type, count, totalScore) 
               VALUES (?, ?, ?, ?, ?)`,
              [contrib.id, contrib.cadreId, contrib.type, contrib.count, contrib.totalScore],
              function(err) {
                if (err) {
                  reject(err);
                } else {
                  resolve();
                }
              }
            );
          });
        });
        
        return Promise.all(contributionPromises);
      })
      .then(() => {
        // 4. 同步新生指导
        const trainingPromises = trainings.map(train => {
          return new Promise((resolve, reject) => {
            db.run(
              `INSERT OR REPLACE INTO trainings (id, cadreId, traineeName, hours, score) 
               VALUES (?, ?, ?, ?, ?)`,
              [train.id, train.cadreId, train.traineeName, train.hours, train.score],
              function(err) {
                if (err) {
                  reject(err);
                } else {
                  resolve();
                }
              }
            );
          });
        });
        
        return Promise.all(trainingPromises);
      })
      .then(() => {
        // 5. 同步职责扣分
        const deductionPromises = deductions.map(ded => {
          return new Promise((resolve, reject) => {
            db.run(
              `INSERT OR REPLACE INTO deductions (id, cadreId, score, reason) 
               VALUES (?, ?, ?, ?)`,
              [ded.id, ded.cadreId, ded.score, ded.reason],
              function(err) {
                if (err) {
                  reject(err);
                } else {
                  resolve();
                }
              }
            );
          });
        });
        
        return Promise.all(deductionPromises);
      })
      .then(() => {
        // 提交事务
        db.run('COMMIT', (err) => {
          if (err) {
            res.status(500).json({ error: err.message });
            return;
          }
          res.json({ message: '数据同步成功' });
        });
      })
      .catch(err => {
        // 回滚事务
        db.run('ROLLBACK', () => {
          res.status(500).json({ error: err.message });
        });
      });
  });
});

// 7. 密码管理API

// 获取管理员密码
app.get('/api/settings/password', (req, res) => {
  db.get('SELECT value FROM settings WHERE key = ?', ['adminPassword'], (err, row) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    res.json({ password: row ? row.value : '123456' });
  });
});

// 更新管理员密码
app.post('/api/settings/password', (req, res) => {
  const { password } = req.body;
  
  if (!password) {
    return res.status(400).json({ error: '缺少密码参数' });
  }
  
  db.run(
    `INSERT OR REPLACE INTO settings (key, value) 
     VALUES (?, ?)`,
    ['adminPassword', password],
    function(err) {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      res.json({ message: '密码更新成功' });
    }
  );
});

// 8. 清除所有数据API
app.delete('/api/sync/clear', (req, res) => {
  // 开始事务
  db.run('BEGIN TRANSACTION', (err) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    
    // 删除所有表数据
    db.run('DELETE FROM deductions', [], (err) => {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      
      db.run('DELETE FROM trainings', [], (err) => {
        if (err) {
          res.status(500).json({ error: err.message });
          return;
        }
        
        db.run('DELETE FROM contributions', [], (err) => {
          if (err) {
            res.status(500).json({ error: err.message });
            return;
          }
          
          db.run('DELETE FROM competitions', [], (err) => {
            if (err) {
              res.status(500).json({ error: err.message });
              return;
            }
            
            db.run('DELETE FROM cadres', [], (err) => {
              if (err) {
                res.status(500).json({ error: err.message });
                return;
              }
              
              // 重置自动增量ID
              db.run('DELETE FROM sqlite_sequence WHERE name IN (?, ?, ?, ?, ?)', 
                ['competitions', 'contributions', 'trainings', 'deductions', 'cadres'], (err) => {
                  if (err) {
                    res.status(500).json({ error: err.message });
                    return;
                  }
                  
                  // 提交事务
                  db.run('COMMIT', (err) => {
                    if (err) {
                      res.status(500).json({ error: err.message });
                      return;
                    }
                    res.json({ message: '所有数据已清除' });
                  });
                }
              );
            });
          });
        });
      });
    });
  });
});

// 启动服务器
app.listen(PORT, () => {
  console.log(`服务器运行在 http://localhost:${PORT}`);
});

// 关闭数据库连接
process.on('SIGINT', () => {
  db.close((err) => {
    if (err) {
      console.error('关闭数据库错误:', err.message);
    } else {
      console.log('数据库连接已关闭');
    }
    process.exit(0);
  });
});