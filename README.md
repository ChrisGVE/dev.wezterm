# dev.wezterm

Simple wezterm plugin to determine a plugin location within a dev environment or in deployment.

## Features

- Returns a plugin path after its installation
- Returns the plugin root path
- Adds the plugin root path to the Wezterm package path
- Consistent error handling with event emissions

## Setup and example

1. Require the plugin:

```lua
local wezterm = require("wezterm")
local dev = wezterm.plugin.require("https://github.com/chrisgve/dev.wezterm")
```

2. Usage

   `dev.wezterm` must be initialized with either a single keyword or a list of keywords. When searching through the list of plugins installed by Wezterm, all keywords must be found in the `component` of the `wezterm.plugin.list()`, giving you control to ensure that `dev.wezterm` will find the location of YOUR plugin.

   There is a simple `opts` table defined as:

```lua
opts = {
  keywords = string|string[],
  auto = true|false,       -- Automatically set up the require path
}
```

- `auto`: Will set up everything automatically and return the path of the plugin.

3. Automated setup

```lua
local M = {}

local dev = wezterm.plugin.require("https://github.com/chrisgve/dev.wezterm")

local module1
local module2

-- your code
...

function M.init()
  local opts = { keywords = { "https", "git-user", "your_plugin" }, auto = true }

  local plugin_dir = dev.setup(opts)

  module1 = require("module1")
  module2 = require("module2")
end

M.init()

return M
```

In this mode, you can do everything in one go. It will search for your plugin, update the `package.path` with your plugin path, and return the plugin path if you need it.

4. Manual setup

```lua
local M = {}

local dev = wezterm.plugin.require("https://github.com/chrisgve/dev.wezterm")

M.hashkey = nil

local sub_module1
local module2

-- your code
...

local function need_plugin_dir()
  ...
  local plugin_dir = dev.get_plugin_path(M.hashkey)
end


local function load_modules()
  dev.set_wezterm_require_path(M.hashkey)
  sub_module1 = require("sub.module1")
  module2 = require("module2")
end


function M.init()
  local opts = { keywords = {"https", "git-user", "your_plugin" }, auto = false }
  M.hashkey = dev.setup(opts)
end

M.init()

return M
```

In this case, the initialization of the plugin only returns a hashkey unique to your plugin that you must store. Later, depending on your needs, you can get your plugin path or set the require path by using your unique hashkey.

## Hosted local repository

If you need to host your plugin on a local repository, requiring your plugins in the format `wezterm.plugin.require("file:///...)` will no longer work. Since you are not cloning your plugins directly from Github.com the typical keywords to search plugins won't work for you, i.e. "https", "plugin author" don't appear in the required path. Here is a solution, in your `wezterm.lua`:

```lua
local dev = wezterm.plugin.require("file:///location of your plugins/folder/dev.wezterm")

local subst = {
  https = "file",
  chrisgve = "folder",
  -- other plugin authors = "folder"
}

dev.set_substitutions(subst)

-- require other plugins
```

Since plugin are cached and loaded only once, this snippet will load `dev.wezterm` first, and will allow you to provide a substitution dictionary that will be used to:

- finalize the setup of `dev.wezterm` since it is also located in a different location than expected
- force `dev.wezterm` to substitute keywords provided by other plugin authors such that you can require them despite the change of expected location.

## Why should I use it?

If your plugin is self-contained in a single file, you should not have a need for `dev.wezterm` unless you need to access resources that you have stored in the root of your plugin repository.

The location where Wezterm stores its plugins will change depending on the OS it runs on, and the file name is a concatenation of the plugin URL. There is a good example on how to set it up in the Wezterm documentation [Plugins](https://wezterm.org/config/plugins.html), but it can be cumbersome, especially when [Developing a Plugin](https://wezterm.org/config/plugins.html#developing-a-plugin) that can be locally sourced.

## Using the plugin with a development branch

**Experimental feature** -- No longer available in the main branch, only in development

Working with a development branch can be more complicated. Wezterm does not support URLs of the type `https://github.com/user/my_plugin#develop` unless you start moving the HEAD (see [Making changes to a Existing Plugin](https://wezterm.org/config/plugins.html#making-changes-to-a-existing-plugin)).

`dev.wezterm` gives you the option to use the standard URL and by adding `fetch_branch = true` to your `opts` table. `dev.setup({<keyword list>}, opts)` will:

1. Fetch the remote branch if it exists
2. Check it out
3. Update it if necessary

If it fails during any of these steps, it will emit one of the specific error events (see below).

## Events

`dev.wezterm` emits the following events that you can use to handle error conditions:

- `dev.wezterm.invalid_hashkey` - No or invalid hashkey provided
- `dev.wezterm.invalid_opts` - Invalid options provided to setup
- `dev.wezterm.no_keywords` - No keywords were provided to search the plugin
- `dev.wezterm.plugin_not_found` - The provided keywords did not allow for the plugin to be found
- `dev.wezterm.require_path_not_set` - The plugin was not found and thus the `package.path` could not be set

You can listen for these events in your WezTerm configuration to handle errors gracefully:

```lua
wezterm.on("dev.wezterm.plugin_not_found", function()
  wezterm.log_warn("Could not find the plugin. Make sure it's installed correctly.")
end)
```

## Contributions

Suggestions, Issues, and PRs are welcome!

The features currently implemented are the ones I use the most, but your workflow might differ. If you have any proposals on how to improve the plugin, please feel free to make an issue or even better a PR!

- For bug reports, please provide steps to reproduce and relevant error messages
- For feature requests, please explain your use case and why it would be valuable
- For PRs, please ensure your code follows the existing style and includes appropriate documentation
