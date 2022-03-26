-- local date = fa.sharedmemory("read", 0, 8, 0)
-- local date = 0
-- local progress = fa.sharedmemory("read", 10, 10, 0)
local progress = 0
local server = "10.0.0.10:999" -- IP address of FTP server
local serverDir = "***" -- FTP server upload folder
local user = "***" -- FTP user name
local passwd = "***" -- FTP password
local ftpstring = "ftp://"..user..":"..passwd.."@"..server..serverDir -- Assemble FTP command string

-- Latest folder
-- check everytime
local folders = {}
for item in lfs.dir("/DCIM") do
    if string.match(item, "%d%d%d%d%d%d%d%d") then
        table.insert(folders, item)
    end
end
table.sort(folders)
local date = folders[#folders]
-- txt method
-- local folder_txt = io.open("/folder.txt", "r")
-- date = folder_txt:read()
-- folder_txt:close()
-- sharedmemory method
-- if date=="\000\000\000\000\000\000\000\000" then
--     local folders = {}
--     for item in lfs.dir("/DCIM") do
--         if string.match(item, "%d%d%d%d%d%d%d%d") then
--             table.insert(folders, item)
--         end
--     end
--     table.sort(folders)
--     local folder = folders[#folders]
--     fa.sharedmemory("write", 0, 8, folder)
--     date = fa.sharedmemory("read", 0, 8, 0)
-- end
local path = "/DCIM/"..date -- Folder to upload file is located

-- Latest progress
-- txt method
local progress_txt = io.open("/progress.txt", "r")
local temp = progress_txt:read()
if temp~=nil then
    progress = temp
end
progress_txt:close()
-- print(progress)
-- sharedmemory method
-- if progress=="\000\000\000\000\000\000\000\000\000\000" then
--     progress = 0
-- end

local new_file = true
while new_file do
    -- print(progress)
    local result, filelist, time = fa.search("file", path, progress)
    if result ~= 1 then
        -- print("Break")
        break
    end
    if time==0 then
        -- new_file = false
        -- print("No new file")
        fa.sleep(60000)
        result, filelist, time = fa.search("file", path, progress)
        if time==0 then
            new_file = false
            -- print("Timeout")
        end
    else
        local file = string.sub(filelist, -26, -2)
        -- print(file)
        -- print(time)
        progress = time
        -- local response = 1
        local response = fa.ftp("put", ftpstring.."/"..date.."/"..file, path.."/"..file)
        if response~=nil then
            -- txt method
            progress_txt = io.open("/progress.txt", "w+")
            progress_txt:write(progress)
            progress_txt:close()
            -- sharedmemory method
            -- fa.sharedmemory("write", 10, 10, time)
            -- progress = fa.sharedmemory("read", 10, 10, 0)
        end
    end
end
-- print("Done")