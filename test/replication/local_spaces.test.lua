env = require('test_run')
test_run = env.new()

--
-- gh-3443: Check that changes done to spaces marked as local
-- are not replicated, but vclock is still promoted.
--

s1 = box.schema.space.create('test1')
_ = s1:create_index('pk')
s2 = box.schema.space.create('test2', {is_local = true})
_ = s2:create_index('pk')
s1.is_local
s2.is_local
_ = s1:insert{1}
_ = s2:insert{1}
box.snapshot()
_ = s1:insert{2}
_ = s2:insert{2}

box.schema.user.grant('guest', 'replication')
test_run:cmd("create server replica with rpl_master=default, script='replication/replica.lua'")
test_run:cmd("start server replica")

test_run:cmd("switch replica")
box.space.test1.is_local
box.space.test2.is_local
box.space.test1:select()
box.space.test2:select()
for i = 1, 3 do box.space.test2:insert{i, i} end

test_run:cmd("switch default")
_ = s1:insert{3}
_ = s2:insert{3}
vclock = test_run:get_vclock('default')
_ = test_run:wait_vclock('replica', vclock)

test_run:cmd("switch replica")
box.space.test1:select()
box.space.test2:select()
test_run:cmd("restart server replica")
box.space.test1:select()
box.space.test2:select()

test_run:cmd("switch default")
test_run:cmd("stop server replica")
test_run:cmd("cleanup server replica")
box.schema.user.revoke('guest', 'replication')

s1:select()
s2:select()

s1:drop()
s2:drop()
