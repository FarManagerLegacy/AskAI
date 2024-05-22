-------------------------------------------------------
-- sample config file
-------------------------------------------------------

-- http://luacheck.readthedocs.io/en/stable/config.html

local options = {

  std = "_G+luamacro",
  --globals={};
  read_globals={"_context", "_import", "_isWindows", "_optional", "_pathjoin", "_pipeOut", "_quote", "_tmpfile"};
  new_globals={"clearSession", "config", "env", "exe", "name", "predefined", "prompt", "sessionFile", "showSession", "url"};
  --new_read_globals={};
  --not_globals={};
  --global=false;
  --allow_defined=true;
  --allow_defined_top=true;

  --unused=false;
  --unused_args=false;
  --unused_secondaries=false;

  --redefined=false;

  --max_line_length=false;

  --max_line_length=120;
  --max_code_line_length=120;
  --max_string_line_length=120;
  --max_comment_line_length=120;

    -- http://luacheck.readthedocs.org/en/stable/cli.html#patterns
    -- https://luacheck.readthedocs.io/en/stable/warnings.html

  --ignore={"61"}; --whitespace issues
  --enable={};
  --only={};
  --inline=false;

    -->> cmdline mode only <<--
  --color=false;
  --codes=true;
  --formatter="default";
  --cache=true;
  --jobs=1
  --exclude_files={};
  --include_files={};

}

return options
