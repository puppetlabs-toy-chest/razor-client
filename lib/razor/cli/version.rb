# -*- encoding: utf-8 -*-
module Razor
  module CLI
    # Define the Razor version, and stash it in a constant.

    # The running version of Razor.  Razor follows the tenets of [semantic
    # versioning](http://semver.org), and this version number reflects the rules
    # as of SemVer 2.0.0
    VERSION = Gem.loaded_specs["razor-client"].version.to_s
  end
end
