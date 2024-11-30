local msg = require 'mp.msg'
local utils = require 'mp.utils'

local handler = {
	"%.webp$",
}

-- lazyinit a temporary directory
local get_tmp_dir
do
	local function clean_tmp(tmp)
		assert(tmp ~= '/', "tmp dir is root, not removing")
		utils.subprocess {args = {"find", tmp, "-type", "f", "-exec", "rm", "{}", "+"}}
	end
	local tmp_dir
	function get_tmp_dir()
		if tmp_dir then
			clean_tmp(tmp_dir)
			return tmp_dir
		end
		local tmp = utils.subprocess({args = {"mktemp", "-d"}}).stdout
		tmp = tmp:sub(1, -2)
		assert(tmp:match("^/tmp/"), "mktemp did not return in tmp")
		tmp_dir = tmp
		return tmp
	end
end


local function gstreamer_convert(file, work_dir)
	utils.subprocess {
		args = {
			"gst-launch-1.0",
			"filesrc", "location=" .. file,
			"!", "decodebin",
			"!", "videoconvert",
			"!", "x264enc",
			"!", "hlssink2", "playlist-root=" .. work_dir, "playlist-location=" .. work_dir .. "/playlist.m3u8", "location=" .. work_dir .. "/segment%%05d.ts"
		}
	}
end

mp.add_hook("on_load", 10, function()
	local f = mp.get_property("stream-open-filename")
	for _, v in ipairs(handler) do
		if f:match(v) then
			local tmp = get_tmp_dir()
			gstreamer_convert(f, tmp)
			mp.set_property("stream-open-filename", tmp .. "/playlist.m3u8")
			break
		end
	end
end)

