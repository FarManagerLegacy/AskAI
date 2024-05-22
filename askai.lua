local Info = Info or package.loaded.regscript or function(...) return ... end --luacheck: ignore 113/Info
local nfo = Info { _filename or ...,
  name        = "Ask AI";
  description = "bring ChatGPT to Far";
  version     = "1"; --http://semver.org/lang/ru/
  author      = "jd";
  url         = "https://forum.farmanager.com/viewtopic.php?t=13447";
  id          = "4618DD57-B187-441D-BFE2-B3C7CAD37B39";
  minfarversion = {3,0,0,5047,0}; --FDLG_NONMODAL
  --files       = "*.lua.cfg;*.preset";--todo

  options     = {
    key = "CtrlB",
    --keyList = "CtrlB:Hold",
    sharedParams = { apikey=1, apibase=1, max_tokens=1, model=1, temperature=1, top_p=1, top_k=1, role=1 },
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
    }
  };
  --disabled    = false;
}
if not nfo or nfo.disabled then return end
local O = nfo.options
local F = far.Flags

local cfgpath = (_filename or ...):match"^(.*)[\\/]"
local _tmp = win.GetEnv("FARLOCALPROFILE")

local State do
  local sh = sh or pcall(require,"sh") and require"sh" --LuaShell
  local _shared = sh and sh._shared or {}
  State = _shared.AskAI
  if not State then
    State = O.State
    _shared.AskAI = State
  end
end

local function _pathjoin (...)
  return table.concat({...}, package.config:sub(1,1))
end

local outputFilename = _pathjoin(_tmp, "Ask AI.md")

local function HelpTopic (name)
  return ("<%s\\>%s"):format(cfgpath,name)
end

local idProgress = win.Uuid"3E5021C5-47C7-4446-8E3B-13D3D9052FD8"
local function progress (text, title)
  local len = math.max(text:len(), title and title:len() or 0, 7)
  local items = {
    {F.DI_SINGLEBOX,0,0,len+4,3,0,0,0,F.DIF_NONE,        title},
    {F.DI_TEXT,     2,1,    0,1,0,0,0,F.DIF_CENTERGROUP, text},
  }
  return far.DialogInit(idProgress, -1, -1, len+4, 3, nil, items, F.FDLG_NONMODAL)
end

local buf = ""
local function _words (chunk)
  if chunk then
    buf = buf..chunk
  end
  local eof = not chunk
  return function()
    if buf=="" then return nil end
    local space, word, other = buf:match("^(%s*)(%S+)(%s.*)")
    if word then
      buf = other
      return space, word
    elseif eof then
      space, word = buf:match("(%s*)(.*)") -- will always match
      buf = ""
      return space, word
    end
  end
end

local chooseCfg, dialog, utils --fwd decl.
local default = _pathjoin(cfgpath, "default")
local function askAI (prompt, cfg)
  if not cfg then
    local success, filename = pcall(utils.readFile, default)
    local pathname = success and _pathjoin(cfgpath, filename)
    if not pathname or not win.GetFileAttr(pathname) then
      chooseCfg(prompt)
      return
    end
    cfg = utils.loadCfg(pathname)
  end
  local processStream, prompt, linewrap = dialog(cfg, prompt, Editor.SelValue)
  if not processStream then return end
  far.Timer(0, function (t)
    t:Close()
    local wi = far.AdvControl(F.ACTL_GETWINDOWINFO)
    assert(wi.Type==F.WTYPE_EDITOR and wi.Name==outputFilename, "oops, editor has not been opened")
    local Id = wi.Id
    editor.SetTitle(Id, "Fetching response...")
    local modal = bit64.band(F.WIF_MODAL, wi.Flags)~=0
    local hDlg = not modal and progress("Waiting for data..")
    if modal then
      far.Message("Waiting for data..", "", "", "")
    end
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
      editor.InsertString(Id)
      i = i+2
      editor.SetPosition(Id, i)
    end
    editor.InsertText(Id, "> "..prompt.."\n\n")
    far.Text()

    local start = Far.UpTime
    local autowrap = bit64.band(ei.Options, F.EOPT_AUTOINDENT)~=0
    if autowrap then editor.SetParam(Id, F.ESPT_AUTOINDENT, 0) end
    processStream (function (chunk)
      if start and hDlg then
        hDlg:send(F.DM_SETTEXT, 2, "Streaming data..")
        hDlg:send(F.DM_SETTEXT, 1, (math.ceil((Far.UpTime-start)/100)/10).." s")
        start = false
      end
      for space,word in _words(chunk) do
        editor.InsertText(Id, space)
        if linewrap and editor.GetInfo(Id).CurPos + word:len() > linewrap then
          editor.InsertText(Id, "\n")
        end
        editor.InsertText(Id, word)
      end
      editor.Redraw(Id)
    end)
    if autowrap then editor.SetParam(Id, F.ESPT_AUTOINDENT, 1) end
    editor.UndoRedo(Id, F.EUR_END)
    if hDlg then hDlg:send(F.DM_CLOSE) end
    editor.SetTitle(Id, "AI assistant response:")
  end)

  local CP = 65001
  local flags = F.EF_DELETEONLYFILEONCLOSE +F.EF_DISABLEHISTORY
  local tryNotModal = flags +F.EF_NONMODAL +F.EF_IMMEDIATERETURN +F.EF_OPENMODE_USEEXISTING
  local res = editor.Editor(outputFilename, nil, nil, nil, nil, nil, tryNotModal, nil, nil, CP)
  if res==F.EEC_LOADING_INTERRUPTED then
    editor.Editor(outputFilename, nil, nil, nil, nil, nil, flags +F.EF_OPENMODE_NEWIFOPEN, nil, nil, CP)
  end
end

utils = assert(loadfile(_pathjoin(cfgpath, "utils.lua.1"))) {
  State=State, _pathjoin=_pathjoin, _tmp=_tmp, cfgpath=cfgpath, name=nfo.name,
}
chooseCfg = assert(loadfile(_pathjoin(cfgpath, "menu.lua.1"))) {
  State=State, cfgpath=cfgpath, name=nfo.name, default=default, utils=utils, hlf=HelpTopic "UtilitiesList", askAI=askAI,
}
dialog = assert(loadfile(_pathjoin(cfgpath, "dialog.lua.1"))) {
  O=O, State=State,
  name=nfo.name, hlf=HelpTopic"", outputFilename=outputFilename, clearSession=utils.clearSession,
  chooseCfg=chooseCfg, askAI=askAI,
}

nfo.config  = function () mf.acall(chooseCfg) end;
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
  Macro { description=nfo.name..": choose cfg";
    area="Common"; key=O.keyList or O.key..":Hold";
    id="FD155A5E-3415-4A9A-BD91-1D7BA91097F0";
    condition=function() return not State.isDlgOpened end;
    action=function()
      mf.acall(chooseCfg)
    end;
  }
  return
end

if _cmdline=="" then
  sh.acall(askAI)
  --sh.acall(chooseCfg)
elseif _cmdline then
  askAI(_cmdline)
else
  return askAI
end
