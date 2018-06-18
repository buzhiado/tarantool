env = require('test_run')
vclock_diff = require('fast_replica').vclock_diff
test_run = env.new()


SERVERS = { 'autobootstrap1', 'autobootstrap2', 'autobootstrap3' }

--
-- Start servers
--
test_run:create_cluster(SERVERS)

--
-- Wait for full mesh
--
test_run:wait_fullmesh(SERVERS)

--
-- Check vclock
--
vclock1 = test_run:get_vclock('autobootstrap1')
vclock_diff(vclock1, test_run:get_vclock('autobootstrap2'))
vclock_diff(vclock1, test_run:get_vclock('autobootstrap3'))

--
-- Switch off third replica
--
test_run:cmd("switch autobootstrap3")
repl = box.cfg.replication
box.cfg{replication = ""}

--
-- Insert rows
--
test_run:cmd("switch autobootstrap1")
s = box.space.test
for i = 1, 5 do s:insert{i} box.snapshot() end
s:select()
fio = require('fio')
path = fio.pathjoin(fio.abspath("."), 'autobootstrap1/*.xlog')
-- Depend on first master is a leader or not it should be 5 or 6.
#fio.glob(path) >= 5
errinj = box.error.injection
errinj.set("ERRINJ_NO_DISK_SPACE", true)
function insert(a) s:insert(a) end
_, err = pcall(insert, {6})
err:match("ailed to write")
-- add a little timeout so gc could finish job
fiber = require('fiber')
while #fio.glob(path) ~= 2 do fiber.sleep(0.01) end
#fio.glob(path)
test_run:cmd("switch default")
--
-- Stop servers
--
test_run:drop_cluster(SERVERS)
