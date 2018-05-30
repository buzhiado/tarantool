env = require('test_run')
test_run = env.new()
test_run:cmd("push filter ".."'\\.lua.*:[0-9]+: ' to '.lua...\"]:<line>: '")

--
-- gh-3273: Move Triggers to server
--

box.sql.execute("CREATE TABLE t1(x INTEGER PRIMARY KEY);")
box.sql.execute("CREATE TABLE t2(x INTEGER PRIMARY KEY);")
box.sql.execute([[CREATE TRIGGER t1t AFTER INSERT ON t1 BEGIN INSERT INTO t2 VALUES(1); END; ]])
box.space._trigger:select()

-- checks for LUA tuples
tuple = {"T1T", {sql = "CREATE TRIGGER t1t AFTER INSERT ON t1 BEGIN INSERT INTO t2 VALUES(1); END;"}}
box.space._trigger:insert(tuple)

tuple = {"T1t", {sql = "CREATE TRIGGER t1t AFTER INSERT ON t1 BEGIN INSERT INTO t2 VALUES(1); END;"}}
box.space._trigger:insert(tuple)

tuple = {"T1t", {sql = "CREATE TRIGGER t12t AFTER INSERT ON t1 BEGIN INSERT INTO t2 VALUES(1); END;"}}
box.space._trigger:insert(tuple)

box.space._trigger:select()


-- test, didn't trigger t1t degrade
box.sql.execute("INSERT INTO t1 VALUES(1);")
-- test duplicate index error
box.sql.execute("INSERT INTO t1 VALUES(1);")
box.sql.execute("SELECT * FROM t2;")
box.sql.execute("DELETE FROM t2;")


-- test triggers
tuple = {"T2T", {sql = "CREATE TRIGGER t2t AFTER INSERT ON t1 BEGIN INSERT INTO t2 VALUES(2); END;"}}
box.space._trigger:insert(tuple)
tuple = {"T3T", {sql = "CREATE TRIGGER t3t AFTER INSERT ON t1 BEGIN INSERT INTO t2 VALUES(3); END;"}}
box.space._trigger:insert(tuple)
box.space._trigger:select()
box.sql.execute("INSERT INTO t1 VALUES(2);")
box.sql.execute("SELECT * FROM t2;")
box.sql.execute("DELETE FROM t2;")

-- test t1t after t2t and t3t drop
box.sql.execute("DROP TRIGGER T2T;")
box.space._trigger:delete("T3T")
box.space._trigger:select()
box.sql.execute("INSERT INTO t1 VALUES(3);")
box.sql.execute("SELECT * FROM t2;")
box.sql.execute("DELETE FROM t2;")

-- insert new SQL t2t and t3t
box.sql.execute([[CREATE TRIGGER t2t AFTER INSERT ON t1 BEGIN INSERT INTO t2 VALUES(2); END; ]])
box.sql.execute([[CREATE TRIGGER t3t AFTER INSERT ON t1 BEGIN INSERT INTO t2 VALUES(3); END; ]])
box.space._trigger:select()
box.sql.execute("INSERT INTO t1 VALUES(4);")
box.sql.execute("SELECT * FROM t2;")

-- clean up
box.space._trigger:delete("T1T")
box.space._trigger:delete("T2T")
box.space._trigger:delete("T3T")
box.sql.execute("DROP TABLE t1;")
box.sql.execute("DROP TABLE t2;")
box.space._trigger:select()


test_run:cmd("clear filter")
