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

`dev.wezterm` must be initialized with either a single keyword or a list of keyword, when searching through the list plugins installed by Wezterm, all keywords must be found in the `component` of the `wezterm.plugin.list()` thus it gives you some control to ensure that `dev.wezterm` will find the location of YOUR plugin.

In your main plugin file, if you need to load modules or submodules, the `dev` plugin will help you by finding the location where your plugin is installed and set up the wezterm require path, or you can set it up yourself.

If you need to access resources from the root of your plugin you can use the helper function `dev.get_plugin_path`

```lua
local M = {}

function M.init()
  dev.setup({"https", "user", "your_plugin"})

  -- Setting the require path for your plugin

  local require_path = dev.get_require_path()
  package.path = package.path .. ";" .. require_path

  -- or more direct

  dev.set_wezterm_require_path()

  -- then require your own packages

  local sub_module1 = require("sub.module1")
  local module2 = require("module2")

end
```

The plugin caches the folders when found and thus there is little overhead if you need to call it again.

## Why should I use it?

If your plugin is self contained in a single file you should not have a need for `dev.wezterm` unless you need to access resources that you have stored in the root of your plugin repository.

The location Wezterm stores its plugin will change depending on the OS it runs on, and the file name is a concatenation of the plugin URL. There is a good example on how to set it up in the Wezterm documentation [Plugins](https://wezterm.org/config/plugins.html) but I find it cumbersome, especially when [Developing a Plugin](https://wezterm.org/config/plugins.html#developing-a-plugin) that can be locally sourced.

## Using the plugin with a development branch

More cumbersome still than the local development is working on a development branch. Wezterm does not support URLs of the type `https://github.com/user/my_plugin#develop` unless you start moving the head (see [Making changes to a Existing Plugin](https://wezterm.org/config/plugins.html#making-changes-to-a-existing-plugin)). No doubt that it works as is, but `dev.wezterm` gives you the option of use the standard URL and by initializing it with `dev.setup({<keywords>}, true)` it will fetch the remote branch if not there, check it out, and update it if necessary.

## Events

`dev.wezterm` emits the following events that you can use in error conditions

- `dev.wezterm.dir_not_found`
- `dev.wezterm.error_fetching_branch(err)`
- `dev.wezterm.require_path_not_set`

## Contributions

Suggestions, Issues and PRs are welcome!
The features currently implemented are the ones I use the most, but your workflow might differ. As such, if you have any proposals on how to improve the plugin, then please feel free to make an issue or even better a PR!
