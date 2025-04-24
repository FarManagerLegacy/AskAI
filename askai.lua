local Info = Info or package.loaded.regscript or function(...) return ... end --luacheck: ignore 113/Info
local nfo = Info { _filename or ...,
  name        = "Ask AI";
  description = "bring ChatGPT to Far";
  version     = "1.7"; --https://semver.org/lang/ru/
  author      = "jd";
  url         = "https://forum.farmanager.com/viewtopic.php?t=13447";
  id          = "4618DD57-B187-441D-BFE2-B3C7CAD37B39";
  minfarversion = {3,0,0,6279,0}; --actl: LuaMacro 810
  --files       = "*.lua.cfg;*.preset";--todo

  options     = {
    key = "CtrlB",
    --keyList = "CtrlB:Hold",
    --keyOutput = "CtrlB:Double",
    keyCopy = "CtrlShiftIns",
    sharedParams = { apibase=1, max_tokens=1, temperature=1, top_p=1, top_k=1, role=1 },
    --smallDlg = true,
    stdEnvs = {
      apikey ={OPENAI_API_KEY=1},
      apibase={OPENAI_BASE_URL=1, OPENAI_API_BASE=1},
      model  ={OPENAI_API_MODEL=1, OPENAI_MODEL=1},
    },
    State = {
      isDlgOpened=false,
      useSession=2,
      useStream=1,
      useWrap=1, -- wrap lines
      wrapAt=80,
    },

    -- skip autodetection and use specified json module
    -- the module must provide `encode`, `decode`, and (optionally) `null`.
    --json_module="dkjson", -- http://dkolf.de/dkjson-lua/
  };
  --disabled    = false;
}
if not nfo or nfo.disabled then return end
local O = nfo.options
local F = far.Flags

local cfgpath = (_filename or ...):match"^(.*)[\\/]"
local _tmp = far.InMyConfig and far.InMyConfig() --luacheck: globals far.InMyConfig -- far2m
                             or win.GetEnv("FARLOCALPROFILE")
local State do
  local sh = sh or pcall(require,"sh") and require"sh" --LuaShell
  local _shared = sh and sh._shared or {}
  State = _shared.AskAI
  if not State then
    State = O.State
    _shared.AskAI = State
  end
end

local idProgress = win.Uuid"3E5021C5-47C7-4446-8E3B-13D3D9052FD8"
local function progress (text, title)
  local MINLEN = 22
  local len = math.max(text:len(), title and title:len() or 0, MINLEN)
  local items = {
    {F.DI_SINGLEBOX,0,  0,len+4,3,0,0,0,F.DIF_NONE,        title},
    {F.DI_TEXT,     0,  1,0,    1,0,0,0,F.DIF_CENTERGROUP, text},
  }
  return far.DialogInit(idProgress, -1, -1, len+4, 3, nil, items, F.FDLG_NONMODAL +(title and 0 or F.FDLG_KEEPCONSOLETITLE))
end

local function openOutput (outputFilename, mode)
  local CP = 65001
  local curModal = bit64.band(actl.GetWindowInfo().Flags, F.WIF_MODAL)==F.WIF_MODAL
  local opened
  for i=actl.GetWindowCount(),1,-1 do
    local wi = actl.GetWindowInfo(i)
    if wi.Type==F.WTYPE_EDITOR and wi.Name==outputFilename then
      opened = true
      if curModal then
        editor.SaveFile(wi.Id)
        editor.Quit(wi.Id)
      end
      break
    end
  end
  if mode=="existing" then
    if not (opened or win.GetFileAttr(outputFilename)) then
      mf.beep(); return
    end
  elseif not opened then
    win.DeleteFile(outputFilename)
  end
  local res
  if not curModal then
    local tryNotModal = F.EF_DISABLEHISTORY +F.EF_NONMODAL +F.EF_IMMEDIATERETURN +F.EF_OPENMODE_USEEXISTING
    res = editor.Editor(outputFilename, nil, nil, nil, nil, nil, tryNotModal, nil, nil, CP)
  end
  if curModal or res==F.EEC_LOADING_INTERRUPTED then
    editor.Editor(outputFilename, nil, nil, nil, nil, nil, F.EF_DISABLEHISTORY +F.EF_OPENMODE_NEWIFOPEN, nil, nil, CP)
  end
end

local buf
local function _words (chunk)
  --if chunk=="" then return function() end end
  if chunk then
    buf = buf..chunk
  end
  local eof = not chunk
  return function()
    if buf=="" then return nil end
    local space, word, other = string.match(buf, "^(%s*)(%S+%-)(.*)") --hyphen
    if not word then
      space, word, other = string.match(buf, "^(%s*)(%S+)(%s.*)")
    end
    if word then
      buf = other
      return space, word
    elseif eof then
      space, word = string.match(buf, "(%s*)(.*)") -- will always match
      buf = ""
      return space, word
    end
  end
end

local menu, dialog, utils --fwd decl.
local function getCfg (profile, cfgname)
  if not cfgname then
    local filename = utils.mload(profile, "cfgfile")
    local pathname = filename and utils.pathjoin(cfgpath,filename)
    local cfg = pathname and win.GetFileAttr(pathname) and utils.loadCfg(pathname,filename)
    return cfg and cfg.reachable and cfg
  elseif type(cfgname)=="string" then
    if cfgname=="" then return end -- use chooseCfg menu
    local pathname, filename
    if cfgname:match"[\\/]" then
      pathname = far.ConvertPath(cfgname)
      if string.sub(pathname,1,#cfgpath)==cfgpath then
        filename = string.sub(pathname,#cfgpath+2)
      end
    else
      filename = cfgname
      if not cfgname:match"%.lua%.cfg$" then
        filename = filename..".lua.cfg"
      end
      pathname = utils.pathjoin(cfgpath,filename)
    end
    local cfg = utils.loadCfg(pathname,filename)
    if not cfg.reachable then
      error(("%s: dependencies not found\nSee help and %s"):format(cfg.info.name, cfg.info.url))
    end
    return cfg
  end
end

local setBigCursor; if jit and jit.os=="Windows" then
  local ffi = require"ffi"
  pcall(ffi.cdef, [[
  //https://learn.microsoft.com/en-us/windows/console/console-cursor-info-str
  typedef struct _CONSOLE_CURSOR_INFO {
    DWORD dwSize;
    BOOL  bVisible;
  } CONSOLE_CURSOR_INFO, *PCONSOLE_CURSOR_INFO;
  //https://learn.microsoft.com/en-us/windows/console/setconsolecursorinfo
  BOOL SetConsoleCursorInfo(
          HANDLE              hConsoleOutput,
    const CONSOLE_CURSOR_INFO *lpConsoleCursorInfo
  );
  ]])
  local C = ffi.C
  local hConsoleOutput = C.GetStdHandle(-11)
  local ConsoleCursorInfo = ffi.new("CONSOLE_CURSOR_INFO",99,1)
  function setBigCursor()
    C.SetConsoleCursorInfo(hConsoleOutput, ConsoleCursorInfo)
  end
end

local lastOutputFilename --fwd decl.
local function askAI (prompt, profile, cfgname)
  profile = profile or "default"
  local cfg = getCfg(profile,cfgname) or cfgname
  if not cfg then return menu.chooseCfg(profile,prompt) end
  local processStream, prompt, linewrap, stream, outputFilename = dialog(profile, cfg, prompt, Editor.SelValue)
  if not processStream then return end
  utils.synchro(function() -- workaround for https://bugs.farmanager.com/view.php?id=3044
    local wi = actl.GetWindowInfo()
    assert(wi.Type==F.WTYPE_EDITOR and wi.Name==outputFilename, "oops, editor has not been opened")
    lastOutputFilename = outputFilename
    local Id = wi.Id
    editor.UndoRedo(Id, F.EUR_BEGIN)
    local ei = editor.GetInfo(Id)
    if linewrap=="dynamic" then
      linewrap = ei.WindowSizeX - 5
    end
    local s = editor.GetString(Id, ei.TotalLines)
    editor.SetPosition(Id, ei.TotalLines, s.StringLength+1)
    local i = ei.TotalLines
    if s.StringLength>0 then
      editor.InsertString(Id)
    end
    if i>1 then
      if string.len(editor.GetString(Id, i-1, 3))>0 then
        editor.InsertString(Id)
      end
      editor.InsertString(Id)
    end
    local autowrap = bit64.band(ei.Options, F.EOPT_AUTOINDENT)~=0
    if autowrap then editor.SetParam(Id, F.ESPT_AUTOINDENT, 0) end
    editor.InsertText(Id, "> "..prompt.."\n\n")
    local modal = bit64.band(F.WIF_MODAL, wi.Flags)~=0
    local hDlg = not modal and progress("Waiting for data..")
    local isFar3 = F.ACTL_GETFARMANAGERVERSION
    if isFar3 then
      editor.Redraw(Id)
      setBigCursor()
    end
    if modal then
      far.Message("Waiting for data..", "", "", "")
    end
    editor.SetTitle(Id, "Fetching response...")

    local start = Far.UpTime
    local function clockwatch ()
      return math.ceil((Far.UpTime-start)/100)/10
    end

    local code = false
    buf = ""
    local before1stToken,total,started,title
    local _,err = pcall(processStream, function (chunk, _title, nowrap)
      if not started then
        repeat until not win.ExtractKeyEx() -- clean kbd buffer
        before1stToken = clockwatch()
        editor.SetTitle(Id, ("Fetching response [%s s]"):format(before1stToken))
        if hDlg then
          if stream then
            hDlg:SetText(2, "Streaming data..")
          end
          if _title then
            title = _title
            hDlg:SetText(1, title)
          end
        end
        started = true
      end
      total = clockwatch()
      editor.SetTitle(Id, ("Fetching response [%s s] +%s s"):format(before1stToken, total-before1stToken))
      if nowrap then
        nowrap,chunk = chunk,nil
      end
      for space,word in _words(chunk) do
        editor.InsertText(Id, space:gsub("\r\n","\n")
                                   :gsub("\r$","")) -- partial
        if linewrap and not code and editor.GetInfo(Id).CurPos + word:len() > linewrap then
          editor.InsertString(Id)
        end
        editor.InsertText(Id, word)
        if linewrap then
          local backticks = space:match"\n" and word:match("^```")
                         or space=="" and editor.GetString(Id,nil,3):match"^%s*```%S*$"
          if backticks then code = not code end
        end
      end
      if nowrap then
        editor.InsertText(Id, nowrap)
      end
      if isFar3 then
        editor.Redraw(Id)
        setBigCursor()
      end
    end)
    editor.InsertString(Id)
    if err and err~="interrupted" then
      far.Message(err:gsub("\t", "   "), "Error", nil, "wl")
    end
    if autowrap then editor.SetParam(Id, F.ESPT_AUTOINDENT, 1) end
    editor.UndoRedo(Id, F.EUR_END)
    editor.SaveFile(Id)
    if hDlg then hDlg:Close() end
    title = (title and "["..title.."] " or "").."AI assistant response: "
    local status = total and total.." s" or "Error!"
    editor.SetTitle(Id, title..status)
  end)

  openOutput(outputFilename)
end

utils = assert(loadfile(cfgpath..package.config:sub(1,1).."utils.lua.1")) {
  State=State, O=O,
  cfgpath=cfgpath, name=nfo.name, _tmp=_tmp,
}

menu = assert(loadfile(utils.pathjoin(cfgpath, "menu.lua.1"))) {
  State=State, utils=utils, askAI=askAI,
  cfgpath=cfgpath, name=nfo.name,
}
dialog = assert(loadfile(utils.pathjoin(cfgpath, "dialog.lua.1"))) {
  State=State, O=O, utils=utils, menu=menu, askAI=askAI,
  cfgpath=cfgpath, name=nfo.name, _tmp=_tmp,
}

nfo.config  = function () mf.acall(menu.chooseCfg, "default") end;
nfo.help    = function () far.ShowHelp(cfgpath, nil, F.FHELP_CUSTOMPATH) end;
nfo.execute = function () mf.acall(askAI) end;

if Macro then
  Macro { description=nfo.name;
    area="Common"; key=O.key;
    id="AF167BA4-E362-449E-A3F7-FF65E716F075";
    condition=function() return not State.isDlgOpened end;
    action=function()
      mf.acall(askAI)
    end;
  }
  lastOutputFilename = utils.pathjoin(_tmp, "Ask AI.md") --default
  Macro { description=nfo.name..": reopen output";
    area="Common"; key=O.keyOutput or O.key..":Double";
    id="89C2EB3B-7D32-4BC8-B5D0-874C0B34367D";
    condition=function() return not State.isDlgOpened end;
    action=function()
      openOutput(lastOutputFilename, "existing")
    end;
  }
  Macro { description=nfo.name..": choose cfg";
    area="Common"; key=O.keyList or O.key..":Hold";
    id="FD155A5E-3415-4A9A-BD91-1D7BA91097F0";
    condition=function() return not State.isDlgOpened end;
    action=function()
      mf.acall(menu.chooseCfg, "default")
    end;
  }
  local codeStart,codeEnd = "^%s*```%S+$", "^(%s*)```$"
  Macro { description=nfo.name..": copy code / paragraphs";
    area="Editor"; key=O.keyCopy;
    filemask="Ask AI.md";
    id="353A2271-B739-41CE-AD47-BFDD109CBB17";
    action=function()
      local sel
      if Object.Selected then
        sel = Editor.SelValue:gsub("(%S[ -])\r?\n", "%1") -- unwrap
      else -- find code block
        local ei = editor.GetInfo()
        local id = ei.EditorID
        local start,finish,indent
        for i=ei.CurLine,1,-1 do
          local line = editor.GetString(id,i,3)
          if line:match(codeStart) then
            start = i; break
          elseif line:match(codeEnd) and i~=ei.CurLine then
            return
          end
        end
        if not start then return end
        local from = ei.CurLine + (start==ei.CurLine and 1 or 0)
        for i=from,ei.TotalLines do
          local line = editor.GetString(id,i,3)
          indent = line:match(codeEnd)
          if indent then
            finish = i; break
          elseif line:match(codeStart) then -- error
            return
          end
        end
        if not finish then -- code block not found
          return
        end
        editor.Select(id, F.BTYPE_STREAM, start+1, 1, 0, finish-start)
        sel = Editor.SelValue
        if indent:len()>0 then -- trim extra indent
          local arr = {}
          for line,eol in sel:gmatch"(.-)(\r?\n)" do
            if line:len()~=0 then
              if line:sub(1, indent:len())==indent then
                line = line:sub(indent:len()+1, -1)
              else -- something is wrong
                arr = false; break
              end
            end
            arr[#arr+1] = line..eol
          end
          if arr then sel = table.concat(arr) end
        end
      end
      mf.beep()
      far.CopyToClipboard(sel)
    end;
  }
  Macro { description=nfo.name..": unwrap text";
    area="Editor"; key="AltF2";
    filemask="Ask AI.md";
    id="F7E6330A-182A-41BE-8EDF-0EFC4C8168A8";
    action=function()
      local ei = editor.GetInfo()
      local id = ei.EditorID
      local n = 0
      for i=1, ei.TotalLines do
        local line = editor.GetString(id,i,0)
        if line.StringText:match"%S $" or line.StringText:match"%a%-$" then
          editor.SetString(id, i, line.StringText, "")
          n = n+1
        end
      end
      if n>0 and editor.SaveFile(id, ei.FileName) then --reload
        local title = editor.GetTitle(id)
        editor.Quit(id)
        local EFLAGS = {EF_NONMODAL=1, EF_IMMEDIATERETURN=1, EF_DISABLEHISTORY=1}
        editor.Editor(ei.FileName, title, nil,nil,nil,nil,EFLAGS,nil,nil,65001)
      else
        mf.beep()
      end
    end;
  }
  return
end

if _cmdline=="" then
  sh.acall(askAI)
elseif _cmdline then
  askAI(_cmdline)
else
  return askAI
end
