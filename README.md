[![Actions Status](https://github.com/lizmat/IRC-Client-Plugin-Rakkable/actions/workflows/linux.yml/badge.svg)](https://github.com/lizmat/IRC-Client-Plugin-Rakkable/actions) [![Actions Status](https://github.com/lizmat/IRC-Client-Plugin-Rakkable/actions/workflows/macos.yml/badge.svg)](https://github.com/lizmat/IRC-Client-Plugin-Rakkable/actions) [![Actions Status](https://github.com/lizmat/IRC-Client-Plugin-Rakkable/actions/workflows/windows.yml/badge.svg)](https://github.com/lizmat/IRC-Client-Plugin-Rakkable/actions)

NAME
====

IRC::Client::Plugin::Rakkable - local rak searches by bot

SYNOPSIS
========

```raku
use IRC::Client;
use IRC::Client::Plugin::Rakkable;

.run with IRC::Client.new(
  :nick<Rakkable>,
  :host<irc.libera.chat>,
  :channels<#raku-dev #moarvm>,
  :plugins(IRC::Client::Plugin::Rakkable.new(
  )),
);
```

DESCRIPTION
===========

The `IRC::Client::Plugin::Rakkable` distribution provides an interface to run local `rak` searches and produce results of them on IRC channels (and gist results for further perusal).

AUTHOR
======

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/IRC-Client-Plugin-Rakkable . Comments and Pull Requests are welcome.

If you like this module, or what I'm doing more generally, committing to a [small sponsorship](https://github.com/sponsors/lizmat/) would mean a great deal to me!

COPYRIGHT AND LICENSE
=====================

Copyright 2025 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

