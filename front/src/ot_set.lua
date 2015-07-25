-- Set an OT document to the specified value using transformations.
-- Read arguments
local content = ARGV[1]
local message = cjson.decode(ARGV[2])
local op_expiretime = tonumber(ARGV[3])
local doc_expiretime = tonumber(ARGV[4])
local ops_key = KEYS[1]
local doc_key = KEYS[2]
local sub_key = KEYS[3]
local cnt_key = KEYS[4]

-- Load the document's current content from Redis
local old_content = redis.call("GET", doc_key)

if type(old_content)=="boolean" then
	-- Document doesn't exist.  Make an operation to set its content.
	message.ops = {content}

elseif old_content==content then
	-- Document exists and is already set to the desired value.  Exit.
	return 0

else
	-- Document exists but needs to be updated to the desired value.
	-- TODO: This is the most naive operation to transform the old document into
	-- the new one.  Change this to something more clever.
	message.ops = {-string.len(old_content), content}
end

-- Update Redis
redis.call("SET", doc_key, content)
redis.call("INCR", cnt_key)
redis.call("RPUSH", ops_key, cjson.encode(message.ops))
redis.call("PUBLISH", sub_key, cjson.encode(message))

-- Touch the operation keys' expire value
redis.call("EXPIRE", ops_key, op_expiretime)
redis.call("EXPIRE", doc_key, doc_expiretime)
redis.call("EXPIRE", cnt_key, doc_expiretime)

return 1