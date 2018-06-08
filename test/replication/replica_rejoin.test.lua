env = require('test_run')
test_run = env.new()
engine = test_run:get_cfg('engine')

test_run:cleanup_cluster()

--
-- gh-461: check that a replica refetches the last checkpoint
-- in case it fell behind the master.
--
box.schema.user.grant('guest', 'replication')
_ = box.schema.space.create('test', {engine = engine})
_ = box.space.test:create_index('pk')
_ = box.space.test:insert{1}
_ = box.space.test:insert{2}
_ = box.space.test:insert{3}

-- Join a replica, then stop it.
test_run:cmd("create server replica with rpl_master=default, script='replication/replica.lua'")
test_run:cmd("start server replica")
test_run:cmd("switch replica")
box.info.replication[1].upstream.status == 'follow' or box.info
box.space.test:select()
_ = box.schema.space.create('replica') -- will disappear after rejoin
test_run:cmd("switch default")
test_run:cmd("stop server replica")

-- Restart the server to purge the replica from
-- the garbage collection state.
test_run:cmd("restart server default")

-- Make some checkpoints to remove old xlogs.
checkpoint_count = box.cfg.checkpoint_count
box.cfg{checkpoint_count = 1}
_ = box.space.test:delete{1}
_ = box.space.test:insert{10}
box.snapshot()
_ = box.space.test:delete{2}
_ = box.space.test:insert{20}
box.snapshot()
_ = box.space.test:delete{3}
_ = box.space.test:insert{30}
#box.info.gc().checkpoints -- 1
box.cfg{checkpoint_count = checkpoint_count}

-- Restart the replica. Since xlogs have been removed,
-- it is supposed to rejoin without changing id.
test_run:cmd("start server replica")
box.info.replication[2].downstream.vclock ~= nil or box.info
test_run:cmd("switch replica")
box.info.replication[1].upstream.status == 'follow' or box.info
box.space.test:select()
box.space.replica == nil -- was removed by rejoin
_ = box.schema.space.create('replica')
test_run:cmd("switch default")

-- Make sure the replica follows new changes.
for i = 10, 30, 10 do box.space.test:update(i, {{'!', 1, i}}) end
vclock = test_run:get_vclock('default')
_ = test_run:wait_vclock('replica', vclock)
test_run:cmd("switch replica")
box.space.test:select()

-- Check that restart works as usual.
test_run:cmd("restart server replica")
box.info.replication[1].upstream.status == 'follow' or box.info
box.space.test:select()
box.space.replica ~= nil

-- Cleanup.
test_run:cmd("switch default")
test_run:cmd("stop server replica")
test_run:cmd("cleanup server replica")
box.space.test:drop()
box.schema.user.revoke('guest', 'replication')
