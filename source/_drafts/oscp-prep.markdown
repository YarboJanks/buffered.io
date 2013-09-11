In a [recent post][oscp_me] I told the story of my experience earning the [OSCP][] certification. In this post I'd like to offer an opinion on what kind of preparation people should do prior to undertaking the course. The goal here is to help people maximise the value of their lab time and help avoid some potential frustration due to lack of sufficient preparation.

This is very much an opinion piece. Please do not take this as an instruction manual.

<!--more-->

General Knowledge
-----------------

Being a savvy computer should go without saying, but I'm stating it for the record anyway. By _savvy_ I really mean very capable and versed in all computing concepts:

* Operating Systems - If Windows is all you know, then you've got a lot of work ahead of you. You need to be across multiple operating systems, including Windows and Linux, and be comfortable with basic administration and configuration of both.
* File Systems - You should know that such a thing exists and that there are many types and implementations available across the different operating systems.
* Command Lines - If you're bound to the GUI then the first thing you should do is learn to live on the command line. Learn the basic commands, the power commands, piping, chaining and general scripting of the environment.
* Networking - You should know what an IP address is, why it's important, how to get one and how to set one up yourself. You need to understand subnets, routing, and a stack of commands that go with investigating a computer's network configuration.
* Privileges - An understanding of restricted vs elevated users. What _root_ is; what _SYSTEM_ is; what commands you can use to change your privileges.
* Applications - Breaking into machines isn't a fixed or exact science. Various applications can give you more functionality than you might think on the surface. Dive into man pages or help files of a bunch of well-known applications and learn about their modes, switches and extensions.
* Shells - That means `bash`, `sh`, `zsh`, `cmd` or whatever else takes your fancy. Get familiar with as many as possible and attempt to master at least one. Shells are your friend, and often they're all you've got!
* Scripting - Learn to automate activities via scripts. This can be via shell scripts, or by using a language like [Python][] or [Ruby][]. Gluing a bunch of tools together in scripts will allow you to quickly automate jobs that can be tedious when done by hand.

As a general indication, if you're able to script the creation and execution of network configuration files to allow you to connect to a WiFi access point then you're off to a good start. If you know the difference between [ext4][] and [Reiserfs][] then you get bonus points. If you can create administrative users from the command line on multiple operating systems you're doing well.

You should also be able to enable/disable firewalls and use tools such as [telnet][], [ssh][], [ftp][] and [netcat][] directly from the command line. You should know how to find files on the file system that have certain attributes and/or contain certain sequences of text/bytes. You should get a grounding in [nmap][], which is going to be the starting point to many of your attacks. You should become one with [Burp][], [ZAP][], and [DirBuster][].

Practice
--------

  [oscp_me]: /posts/oscp-and-me/ "OSCP and Me"
