# dev.wezterm

Simple wezterm plugin to determine a plugin location within a dev environment or in deployment

## Features

- Returns a plugin path after its installation
- Returns the plugin root path
- Adds the plugin root path to the Wezterm package path
- Manage development branch easily

## Setup and example

1. Require the plugin:

```lua
local wezterm = require("wezterm")
local dev = wezterm.plugin.require("https://github.com/chrisgve/dev.wezterm")
```

2. Usage
   `dev.wezterm` must be initialized with either a single keyword or a list of keywords, when searching through the list of plugins installed by Wezterm, all keywords must be found in the `component` of the `wezterm.plugin.list()` thus it gives you some control to ensure that `dev.wezterm` will find the location of YOUR plugin.

There is a simple `opts` table defined as

```lua
opts = {
  auto = true|false,
  fetch_branch = true|false,
}
```

`fetch_branch` will ensure that the version of your plugin is pointing to the branch as defined by the `#<branch>`. `auto` will the setup automatically and return the path of the plugin.

3. Automated setup

```lua
local M = {}

local dev = wezterm.plugin.require("https://github.com/chrisgve/dev.wezterm")

local module1
local module2

-- your code
...

function M.init()
  local opts = { auto = true }
  local plugin_dir

  _, plugin_dir = dev.setup({"http", "user", "your_plugin"}, opts)

  module1 = require("module1")
  module2 = require("module2")
end

M.init()

return M
```

In this mode you can do everything in one go, it will search for your plugin, update the `package.path` with your plugin and return the your plugin path if you need it, and by adding `fetch_branch = true` to the `opts` it will ensure that the correct branch is active.

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
  local opts = nil
  M.hashkey = dev.setup({"https", "user", "your_plugin"}, opts)
end

M.init()

return M
```

In this case the initialization of the plugin only returns a hashkey unique to your plugin that you must store. Later depending on your needs you can get your plugin path or set the require path by using your unique hashkey.

## Why should I use it?

If your plugin is self contained in a single file you should not have a need for `dev.wezterm` unless you need to access resources that you have stored in the root of your plugin repository.

The location Wezterm stores its plugin will change depending on the OS it runs on, and the file name is a concatenation of the plugin URL. There is a good example on how to set it up in the Wezterm documentation [Plugins](https://wezterm.org/config/plugins.html) but I find it rather cumbersome, especially when [Developing a Plugin](https://wezterm.org/config/plugins.html#developing-a-plugin) that can be locally sourced.

## Using the plugin with a development branch

**Experimental feature**
More cumbersome still than the local development is working on a development branch. Wezterm does not support URLs of the type `https://github.com/user/my_plugin#develop` unless you start moving the head (see [Making changes to a Existing Plugin](https://wezterm.org/config/plugins.html#making-changes-to-a-existing-plugin)). No doubt that it works as is, but `dev.wezterm` gives you the option of use the standard URL and by adding `fetch_branch = true` to your `opts` table `dev.setup({<keyword list>}, opts)` will fetch the remote branch if it exists, check it out, and update it if necessary. In case it fails doing so it will emit `dev.wezterm.error_fetching_branch(err)`.

## Events

`dev.wezterm` emits the following events that you can use in error conditions

- `dev.wezterm.error_fetching_branch(err)` -- It was not possible to fetch and select the branch
- `dev.wezterm.invalid_hashkey(key)` -- No or invalid hashkey provided
- `dev.wezterm.no_keywords` -- No keywords were provided to search the plugin
- `dev.wezterm.plugin_not_found` -- The provided keywords did not allow for the plugin to be found
- `dev.wezterm.require_path_not_set` -- The plugin was not found and thus the `package.path` could not be set

## Contributions

Suggestions, Issues and PRs are welcome!
The features currently implemented are the ones I use the most, but your workflow might differ. As such, if you have any proposals on how to improve the plugin, then please feel free to make an issue or even better a PR!
