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

    --debug=true,
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

local utils = assert(loadfile(cfgpath..package.config:sub(1,1).."utils.lua.1")) {
  State=State, O=O,
  cfgpath=cfgpath, name=nfo.name, _tmp=_tmp,
}

local output = utils.load"output.lua.1" {utils=utils}

local dialog = utils.load"dialog.lua.1" {
  State=State, O=O, utils=utils, output=output,
  cfgpath=cfgpath, name=nfo.name, _tmp=_tmp,
}

local function askAI (opts)
  opts = not opts and {} or type(opts)=="table" and opts or error "opts should be table"
  opts.profile = opts.profile or "default"
  opts.context = opts.context or Editor.SelValue
  dialog(opts)
end

nfo.config  = function () mf.acall(askAI, {cfg=""}) end;
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
  State.lastOutputFilename = utils.pathjoin(_tmp, "Ask AI.md") --default
  Macro { description=nfo.name..": reopen output";
    area="Common"; key=O.keyOutput or O.key..":Double";
    id="89C2EB3B-7D32-4BC8-B5D0-874C0B34367D";
    condition=function() return not State.isDlgOpened end;
    action=function()
      output(State.lastOutputFilename)
    end;
  }
  Macro { description=nfo.name..": choose cfg";
    area="Common"; key=O.keyList or O.key..":Hold";
    id="FD155A5E-3415-4A9A-BD91-1D7BA91097F0";
    condition=function() return not State.isDlgOpened end;
    action=function()
      mf.acall(askAI, {cfg=""})
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
  sh.acall(askAI, sh.eval(_cmdline))
else
  return askAI
end
