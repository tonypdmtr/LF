--==============================================================================
-- Convert text between CRLF (Windows), LF (Linux), and CR (Mac) <tonyp@acm.org>
--==============================================================================

--require 'init'

local cc = table.concat
local unpack = table.unpack or unpack

--------------------------------------------------------------------------------
local options = {
  crlf = false,                         -- Windows format (CR/LF)
  cr = false,                           -- Mac format (CR only)
  subdirs = false,                      -- process subdirectories
  trim = true,                          -- trim trailing blanks
  ltrim = false,                        -- trim leading blanks
  xtrim = false,                        -- trim multiple blank lines
  xxtrim = false,                       -- trim all blank lines
  force = false,                        -- force processing of skipped extensions
  bforce = false,                       -- force processing of binary files
  quiet = true,                         -- quiet mode shows only skipped
  }
--------------------------------------------------------------------------------
-- Trim string of leading, trailing and multiple internal spaces (or user char)

function string:trim(c)
  local esc = '%s'
  if c == nil then c = ' ' else esc = escape_magic(c) end
  return (self:gsub(esc..'+',c):gsub('^'..esc,''):gsub(esc..'$',''))
end

--------------------------------------------------------------------------------
-- Trim string of leading spaces (or user char)

function string:ltrim(c)
  local esc = '%s'
  if c ~= nil then esc = escape_magic(c) end
  return (self:gsub('^'..esc..'+',''))
end

--------------------------------------------------------------------------------
-- Trim string of trailing spaces (or user char)

function string:rtrim(c)
  local esc = '%s'
  if c ~= nil then esc = escape_magic(c) end
  return (self:gsub(esc..'+$',''))
end

--------------------------------------------------------------------------------
-- Save a text file as Windows, Linux, or Mac

function putfile(filename,lines,eol)
  eol = eol or 'Linux'                  --default platform
  if type(lines) == 'string' then lines = lines:split('\n',true) end
  assert(type(filename) == 'string','String expected for 1st arg')
  assert(type(lines) == 'table','Table expected for 2nd arg')
  assert(type(eol) == 'string','String expected for 3rd arg')
  eol = eol:lower()
  local platforms = {
    ['win'    ] = '\013\010',
    ['win32'  ] = '\013\010',
    ['win64'  ] = '\013\010',
    ['windows'] = '\013\010',
    ['mac'    ] = '\013',
    ['linux'  ] = '\010',
  }
  eol = platforms[ eol ]
  if eol == nil then
    error('Unsupported platform')
    return
  end
  if filename == '' then
    print(cc(lines,eol))
  else
    collectgarbage()
    io.open(filename,'wb'):write(cc(lines,eol),eol):close()
  end
end

--------------------------------------------------------------------------------
-- f'' formatted strings like those introduced in Python v3.6
-- However, you must use Lua style format modifiers as with string.format()
--------------------------------------------------------------------------------

function f(s)
  local env = copy(_ENV)                --start with all globals
  local i,k,v,fmt = 0
  repeat
    i = i + 1
    k,v = debug.getlocal(2,i)           --two levels up (1 level is this repeat block)
    if k ~= nil then env[k] = v end
  until k == nil
  local
  function go(s)
    local fmt
    s,fmt = s:sub(2,-2):split('::')
    if s:match '%b{}' then s = (s:gsub('%b{}',go)) end
    s = eval(s,env)
    if fmt ~= nil then
      if fmt:match '%b{}' then fmt = eval(fmt:sub(2,-2),env) end
      s = fmt:format(s)
    end
    return s
  end
  return (s:gsub('%b{}',go))
end

--------------------------------------------------------------------------------

function copy(t)              --returns a simple (shallow) copy of the table
  if type(t) == 'table' then
    local ans = {}
    for k,v in next,t do ans[ k ] = v end
    return ans
  end
  return t
end

--------------------------------------------------------------------------------

function eval(expr,vars)
  --evaluate a string expression with optional variables
  if expr == nil then return end
  vars = vars or {}
  assert(type(expr) == 'string','String expected as 1st arg')
  assert(type(vars) == 'table','Variable table expected as 2nd arg')
  local env = {abs=math.abs,acos=math.acos,asin=math.asin,atan=math.atan,
               atan2=math.atan2,ceil=math.ceil,cos=math.cos,cosh=math.cosh,
               deg=math.deg,exp=math.exp,floor=math.floor,fmod=math.fmod,
               frexp=math.frexp,huge=math.huge,ldexp=math.ldexp,log=math.log,
               max=math.max,min=math.min,modf=math.modf,pi=math.pi,pow=math.pow,
               rad=math.rad,random=math.random,randomseed=math.randomseed,
               sin=math.sin,sinh=math.sinh,sqrt=math.sqrt,tan=math.tan,
               tanh=math.tanh}
  for name,value in pairs(vars) do env[name] = value end
  local a,b = pcall(load('return '..expr,nil,'t',env))
  if a == false then return nil,b else return b end
end

--------------------------------------------------------------------------------
-- Escape special pattern characters in string to be treated as simple characters
--------------------------------------------------------------------------------

local
function escape_magic(s)
  local MAGIC_CHARS_SET = '[()%%.[^$%]*+%-?]'
  if s == nil then return end
  return (s:gsub(MAGIC_CHARS_SET,'%%%1'))
end

--------------------------------------------------------------------------------

function run(cmd,debug)
  debug = debug == nil
  assert(type(cmd) == 'string','cmd should be the string of the command to run')
  if debug then print('Running...',cmd) end
  local f = io.popen(cmd)
  local ans = f:read('*a')
  f:close()
  return ans
end

--------------------------------------------------------------------------------
-- Split a string on the given delimiter (multi-space by default)
--------------------------------------------------------------------------------

function string:split(delimiter,tabled)
  tabled = tabled or false              --default is unpacked
  local ans = {}
  for item in self:gsplit(delimiter) do
    ans[#ans+1] = item
  end
  if tabled then return ans end
  return unpack(ans)
end

--------------------------------------------------------------------------------
-- Returns iterator to split string on given delimiter (multi-space by default)
--------------------------------------------------------------------------------

function string:gsplit(delimiter)
  if delimiter == nil then return self:gmatch '%S+' end --default delimiter is any number of spaces
  if delimiter == '' then return self:gmatch '.' end --each character separately
  if type(delimiter) == 'number' then   --break string in equal-size chunks
    local index = 1
    local ans
    return function()
             ans = self:sub(index,index+delimiter-1)
             if ans ~= '' then
               index = index + delimiter
               return ans
             end
           end
  end
  if self:sub(-#delimiter) ~= delimiter then self = self .. delimiter end
  return self:gmatch('(.-)'..escape_magic(delimiter))
end

--------------------------------------------------------------------------------

function united_parms(t)
  assert(type(t) == 'table','Table expected')
  local ans = {}
  for _,parm in ipairs(t) do
    if parm:sub(1,1) ~= '-' then ans[#ans+1] = parm end
  end
  return cc(ans,',')
end

--------------------------------------------------------------------------------
-- Path/File exists

function file_exists(path)
  if path == nil then return end
  local f = io.open(path)
  if f == nil then return end
  f:close()
  return path
end

--------------------------------------------------------------------------------

function filelist(filemasks,recursive) --separate masks with comma if needed
  recursive = recursive or false
  filemasks = filemasks or '*'
  if filemasks == '.' then filemasks = '*' end
  filemasks = filemasks:gsub('\\','/')
  if filemasks:sub(1,1) == '@' then
    local ans = {}
    for filemask in io.lines(filemasks:sub(2)) do
      ans[#ans+1] = filemask
    end
    filemasks = cc(ans,',')
  end
  local s,ans,path,last_path = '','','',''
  for file in filemasks:gsplit(',') do
    if not file:match('^%s*$') then
      path,file = file:match('^(.-)([^/\\]-)$')
      if file == '' then file = '*' end
      path = (path or ''):gsub('/','\\')
      if path ~= '' then last_path = path end
      if file:match('^%.') then file = '*'..file end
      if recursive then
        s = 'for /r '..last_path..' %i in ($LIST$) do @echo %i'
      else
        s = 'for %i in ($LIST$) do @echo %i'
        file = last_path .. file
      end
      file = file:gsub('%%','%%%%')
      s = s:gsub('%$LIST%$',file)
      ans = ans .. run(s,false)
    end
  end
  --return ans:gsplit('\n')             --this will not filter lines at all
  ans = ans:split('\n',true)            --convert text to a table
  local key,line
  return function()
           repeat
             key,line = next(ans,key)
             if key == nil then return end
             if line:match('%S+') and file_exists(line) then
               return line              --only non-blank lines and existing filenames
             end
           until false
         end
end

--------------------------------------------------------------------------------

local
function is_text_file(filename)
  if options.bforce then return true end
  local empty_flag = true
  for line in io.lines(filename) do
    if not line:match '^[\1\2\7\9\10\12\13\32-\126\128-\255]*$' then
      collectgarbage()
      return false
    end
    empty_flag = false
  end
  collectgarbage()
  if empty_flag then return end
  return true
end

--------------------------------------------------------------------------------

local
function bad_extension(filename)
  if options.force then return false end
  assert(type(filename) == 'string','String expected')
  filename = filename:lower()
  if filename:match('[\\/]_fossil_$') then return true
  elseif filename:match('[\\/]prog.cfg$') then return false end
  return filename:match('%.zip$') or
         filename:match('%.rar$') or
         filename:match('%.exe$') or
         filename:match('%.dll$') or
         filename:match('%.com$') or
         filename:match('%.bin$') or
         filename:match('%.iso$') or
         filename:match('%.lib$') or
         filename:match('%.pdf$') or
         filename:match('%.jpg$') or
         filename:match('%.png$') or
         filename:match('%.ico$') or
         filename:match('%.bmp$') or
         filename:match('%.gif$') or
         filename:match('%.jav$') or
         filename:match('%.wav$') or
         filename:match('%.mp[34]$') or
         filename:match('%.mpeg4?$') or
         filename:match('%.obj$') or
         filename:match('%.7z$') or
         filename:match('%.db$') or
         filename:match('%.fossil$') or
         filename:match('%.xls$')
end

--------------------------------------------------------------------------------

local
function do_file(filename)
  if filename == nil then return end

  local eol = options.crlf and 'Windows' or options.cr and 'Mac' or 'Linux'

  if bad_extension(filename) then
    print('Skipped forbidden   '..filename)
    return
  end

  local status = is_text_file(filename)
  if status == nil then
    print('Skipped empty file  '..filename)
    return
  elseif not is_text_file(filename) then
    print('Skipped binary file '..filename)
    return
  end

  local ans = {}

  if not options.quiet then io.write('Processing '..filename:quote('"')) end
  local f = io.open(filename)
  if f == nil then
    io.write('\rCould not open "'..filename..'" (skipped)\n')
    return
  end
  ------------------------------------------------------------------------------
  local
  function add(line)
    line = options.trim and line:rtrim() or line
    line = options.ltrim and line:ltrim() or line
    if options.xtrim and line:rtrim() == '' then
      if #ans > 0 and ans[#ans] <> '' then ans[#ans+1] = '' end
    elseif line:rtrim() ~= '' or not options.xxtrim then
      ans[#ans+1] = line
    end
  end
  ------------------------------------------------------------------------------
  for line in f:lines() do
    if line:match('\013') then
      for line in line:gsplit('\013') do add(line) end
      if ans[ #ans ] == '' then ans[ #ans ] = nil end --in case we processed a final line terminator
    else
      add(line)
    end
  end
  f:close()

  -- remove trailing empty lines
  for i = #ans, 1, -1 do
    if ans[i] ~= '' then break end
    ans[i] = nil
  end
  --

  putfile(filename,ans,eol)

  if not options.quiet  then
    if options.crlf then
      io.write(' (Windows')
    elseif options.cr then
      io.write(' (Mac')
    else
      io.write(' (Linux')
    end
    if options.trim then io.write ' & right-trimmed' end
    io.write(')\n')
  end
end

--------------------------------------------------------------------------------

if arg[1] == nil then
  print [[
Copyright (c) 2021 by Tony Papadimitriou <tonyp@acm.org>

Usage: LF [directory/][<filemask>] ... [option(s)]

       Convert a text file between CRLF (Windows), LF (Linux), and CR (Mac)
       Examples:
         .txt                 all TXT files
         .txt .inc            all TXT and all INC files
         /temp/.txt /mot/.inc all \TEMP\*.TXT and all \MOT\*.INC files
         makefile -s          all MAKEFILE in current and all subdirectories
       If filemask is missing then all files are processed.
       Options can appear anywhere in the command line.
       Current options are (on/off options toggle on each use):
       -s      : subdirectories will also be processed
       -lf     : lines will end with LF (Linux), same as -linux       [default]
       -linux  : lines will end with LF (Linux), same as -lf          [default]
       -crlf   : lines will end with CRLF (Windows), same as -win
       -win    : lines will end with CRLF (Windows), same as -crlf
       -cr     : lines will end with CR (Mac), same as -mac
       -mac    : lines will end with CR (Mac), same as -cr
       -trim   : trim trailing blanks (also -t)                       [default]
       -notrim : do not trim trailing blanks (also -nt)
       -ltrim  : trim leading blanks (also -l)
       -xtrim  : trim multiple blank lines (also -x)
       -xx     : same as -xtrim (-x) but leaves no blank lines at all
       -quiet  : quiet mode does not display 'Processing...' message (also -q)
       -verbose: display all processed files (also -v)                [default]
       -force  : force processing of forbidden extensions
       -bforce : force processing of binary files
       (Only the last -crlf -win -cr -mac -lf -linux is effective.)]]
  return
end

-- Detect if subdirectories should also be processed
for _,option in ipairs(arg) do
  option = option:trim():lower()
  if option == '-s' then
    options.subdirs = true
  elseif option == '-t' or option == '-trim' then
    options.trim = true
  elseif option == '-x' or option == '-xtrim' then
    options.xtrim = true
    options.xxtrim = false
  elseif option == '-xx' then
    options.xxtrim = true
    options.xtrim = false
  elseif option == '-l' or option == '-ltrim' then
    options.ltrim = true
  elseif option == '-nt' or option == '-notrim' then
    options.trim = false
  elseif option == '-crlf' or option == '-win' then
    options.crlf = true
    options.cr = false
  elseif option == '-cr' or option == '-mac' then
    options.cr = true
    options.crlf = false
  elseif option == '-lf' or option == '-linux' then
    options.cr = false
    options.crlf = false
  elseif option == '-force' then
    options.force = true
  elseif option == '-bforce' then
    options.bforce = true
  elseif option == '-q' or option == '-quiet' then
    options.quiet = true
  elseif option == '-v' or option == '-verbose' then
    options.quiet = false
  elseif option:sub(1,1) == '-' then
    print('Unrecognized option '..option:quote())
    return
  end
end

local count = 0
for filename in filelist(united_parms(arg),options.subdirs) do
  if not filename:lower():match '.git[\\/]' then
    print(filename)
    do_file(filename)
    count = count + 1
  end
end

print(f'{count} file(s) processed!')
