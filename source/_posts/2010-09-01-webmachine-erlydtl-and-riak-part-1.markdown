---
categories: [Riak, Databases, Functional Programming, HOWTO, Erlang, Webmachine]
date: 2010-09-01 23:29
updated: 2011-06-15 07:26:22
tags: [web development, Erlang, NoSQL, Webmachine, Riak, ErlyDTL]
comments: true
layout: post
title: "Webmachine, ErlyDTL and Riak - Part 1"
series: "Web Development with Erlang"
---
<img src="/uploads/2010/09/riak-logo.png" alt="Riak Logo" style="float:left;padding-right:5px;padding-bottom:5px;"/>It has been a long time coming, but the first post is finally here! This is the first in a series of post, as [promised a while ago][ErlangPost], covering off web development using [Erlang][]. This post is the ubiquitous "get up and running" post, which aims to get your environment set up so that you can dive in to development. The next post will detail how to handle a basic end-to-end web request.

<img src="/uploads/2010/09/Erlang_logo.png" width="150" style="float:right;margin-left:5px;margin-bottom:5px;"/>First up, a few things we need to be aware of before we begin:

1. The information in this post has only been verified on Linux ([Mint][] to be exact). It _should_ work just fine on Mac OSX. I'm almost certain that it _won't_ work on a Windows machine. So if you're a Windows developer, you'll have to wait for another post down the track which covers off how to get your environment ready to rock.
1. We'll be downloading, building and installing [Erlang][], [ErlyDTL][], [Riak][] and [Webmachine][].
1. [Rebar][] is the tool we'll be using to handle builds, but I won't be covering it in any depth.
1. You will need the latest versions of both [Mercurial][] and [Git][] so make sure they're downloaded and installed before you follow this article.
1. We'll be doing _some_ interaction with Riak via [curl][], so make sure you have it downloaded and installed as well.
1. This is intended to be a step-by-step guide targeted at those who are very new to web development in Erlang. This may not be the most ideal set up, nor the best way of doing certain things. I am hoping that those people who are more experienced than I will be able to provide feedback and guidance in areas where I am lacking.
1. Over the course of this series I'll be attempting to build an Erlang version of the [Code Smackdown][] site that I've been working on here and there with a [mate of mine][secretGeek]. You'll see that the sample application we're working on is called "csd" for obvious reasons.

OK, let's get into it. First up, Erlang.

<!--more-->

### Installing Erlang R14B02 ###

Download and installation is fairly simple. Right now we're not worried about enabling all of the features of Erlang, such as interfacing with Java and providing support for GTK. So the boilerplate functionality is enough. Here are the steps to follow:


    oj@nix ~/blog $ wget http://erlang.org/download/otp_src_R14B02.tar.gz

      ... snip ...

    oj@nix ~/blog $ tar -xzf otp_src_R14B02.tar.gz 
    oj@nix ~/blog $ cd otp_src_R14B02/
    oj@nix ~/blog/otp_src_R14B02 $ ./configure 

      ... snip ...

    oj@nix ~/blog/otp_src_R14B02 $ make

      ... snip ...

    oj@nix ~/blog/otp_src_R14B02 $ sudo make install

      ... snip ...



Done! Let's confirm that it has been set up correctly:


    oj@nix ~/blog $ erl
    Erlang R14B02 (erts-5.8.3) [source] [64-bit] [smp:2:2] [rq:2] [async-threads:0] [hipe] [kernel-poll:false]

    Eshell V5.8.3  (abort with ^G)
    1> q().
    ok


Excellent. Next let's get Riak going.


### Installing Riak 0.14 ###

Considering the power of the software you are about to set up, it is absolutely insane how easy it is to get it running. If any of you have tried to get [CouchDB][] running you'll no doubt have experienced a few quirks and a bit of pain getting it rolling. Not so with Riak. As mentioned at the start of the article, make sure you have a recent version of [Mercurial][] and [Git][] installed.


    oj@nix ~/blog$ hg --version
    Mercurial Distributed SCM (version 1.7.3)
    (see http://mercurial.selenic.com for more information)

    Copyright (C) 2005-2010 Matt Mackall and others
    This is free software; see the source for copying conditions. There is NO
    warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

    oj@nix ~/blog$ git --version
    git version 1.7.3.5

    oj@nix ~/blog $ git clone git://github.com/basho/riak
    Cloning into riak...
    remote: Counting objects: 10812, done.
    remote: Compressing objects: 100% (3468/3468), done.
    remote: Total 10812 (delta 7217), reused 10469 (delta 7020)
    Receiving objects: 100% (10812/10812), 8.83 MiB | 729 KiB/s, done.
    Resolving deltas: 100% (7217/7217), done.

    oj@nix ~/blog $ cd riak
    oj@nix ~/blog/riak $ make
    ./rebar get-deps
    ==> rel (get-deps)
    ==> riak (get-deps)
    Pulling cluster_info from {git,"git://github.com/basho/cluster_info",
                                   {branch,"master"}}
    Cloning into cluster_info...
    Pulling luwak from {git,"git://github.com/basho/luwak",{branch,"master"}}
    Cloning into luwak...
    Pulling riak_kv from {git,"git://github.com/basho/riak_kv",{branch,"master"}}
    Cloning into riak_kv...
    Pulling riak_err from {git,"git://github.com/basho/riak_err",
                               {branch,"master"}}
    Cloning into riak_err...
    ==> cluster_info (get-deps)
    ==> riak_kv (get-deps)
    Pulling riak_core from {git,"git://github.com/basho/riak_core",
                                {branch,"master"}}
    Cloning into riak_core...
    Pulling riakc from {git,"git://github.com/basho/riak-erlang-client",
                            {tag,"riakc-1.0.2"}}
    Cloning into riakc...
    Pulling luke from {git,"git://github.com/basho/luke",{tag,"luke-0.2.3"}}
    Cloning into luke...
    Pulling erlang_js from {git,"git://github.com/basho/erlang_js",
                                {tag,"erlang_js-0.5.0"}}
    Cloning into erlang_js...
    Pulling bitcask from {git,"git://github.com/basho/bitcask",{branch,"master"}}
    Cloning into bitcask...
    Pulling ebloom from {git,"git://github.com/basho/ebloom",{branch,"master"}}
    Cloning into ebloom...
    Pulling eper from {git,"git://github.com/dizzyd/eper.git",{branch,"master"}}
    Cloning into eper...
    ==> riak_core (get-deps)
    Pulling protobuffs from {git,"git://github.com/basho/erlang_protobuffs",
                                 {tag,"protobuffs-0.5.1"}}
    Cloning into protobuffs...
    Pulling basho_stats from {git,"git://github.com/basho/basho_stats","HEAD"}
    Cloning into basho_stats...
    Pulling riak_sysmon from {git,"git://github.com/basho/riak_sysmon",
                                  {branch,"master"}}
    Cloning into riak_sysmon...
    Pulling webmachine from {git,"git://github.com/basho/webmachine",
                                 {tag,"webmachine-1.8.0"}}
    Cloning into webmachine...
    ==> protobuffs (get-deps)
    ==> basho_stats (get-deps)
    ==> riak_sysmon (get-deps)
    ==> webmachine (get-deps)
    Pulling mochiweb from {git,"git://github.com/basho/mochiweb",
                               {tag,"mochiweb-1.7.1"}}
    Cloning into mochiweb...
    ==> mochiweb (get-deps)
    ==> riakc (get-deps)
    ==> luke (get-deps)
    ==> erlang_js (get-deps)
    ==> ebloom (get-deps)
    ==> bitcask (get-deps)
    ==> eper (get-deps)
    ==> luwak (get-deps)
    Pulling skerl from {git,"git://github.com/basho/skerl",{tag,"skerl-1.0.1"}}
    Cloning into skerl...
    ==> skerl (get-deps)
    ==> riak_err (get-deps)
    ./rebar compile
    ==> cluster_info (compile)
    Compiled src/cluster_info_ex.erl


      ... snip ...



I snipped a lot of the make output for obvious reasons. Let's build a few development nodes of Riak and cluster them together as indicated in the [Riak Fast Track][]:


    oj@nix ~/blog/riak $ make devrel
    mkdir -p dev
    (cd rel && ../rebar generate target_dir=../dev/dev1 overlay_vars=vars/dev1_vars.config)
    ==> rel (generate)
    mkdir -p dev
    (cd rel && ../rebar generate target_dir=../dev/dev2 overlay_vars=vars/dev2_vars.config)
    ==> rel (generate)
    mkdir -p dev
    (cd rel && ../rebar generate target_dir=../dev/dev3 overlay_vars=vars/dev3_vars.config)
    ==> rel (generate)

    oj@nix ~/blog/riak $ cd dev
    oj@nix ~/blog/riak/dev $ dev1/bin/riak start
    oj@nix ~/blog/riak/dev $ dev2/bin/riak start
    oj@nix ~/blog/riak/dev $ dev3/bin/riak start
    oj@nix ~/blog/riak/dev $ dev2/bin/riak-admin join dev1
    Sent join request to dev1

    oj@nix ~/blog/riak/dev $ dev3/bin/riak-admin join dev1
    Sent join request to dev1

    oj@nix ~/blog/riak/dev $ curl -H "Accept: text/plain" http://127.0.0.1:8091/stats
    {
      ... snip ...

      "nodename": "dev1@127.0.0.1",
        "connected_nodes": [
        "dev2@127.0.0.1",
        "dev3@127.0.0.1"
      ],

      ... snip ...

      "ring_members": [
        "dev1@127.0.0.1",
        "dev2@127.0.0.1",
        "dev3@127.0.0.1"
      ],
      "ring_num_partitions": 64,
      "ring_ownership": "[{'dev3@127.0.0.1',21},{'dev2@127.0.0.1',21},{'dev1@127.0.0.1',22}]",

      ... snip ...
    }


As we can see from the curl output, we now have a 3-node Riak cluster up and running. Those three nodes have the following traits:
<table border="1">
  <thead>
    <tr>
      <th>Name</th>
      <th>Protobuf Port</th>
      <th>HTTP Port</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>dev1@127.0.0.1</td>
      <td>8081</td>
      <td>8091</td>
    </tr>
    <tr>
      <td>dev2@127.0.0.1</td>
      <td>8082</td>
      <td>8092</td>
    </tr>
    <tr>
      <td>dev3@127.0.0.1</td>
      <td>8083</td>
      <td>8093</td>
    </tr>
  </tbody>
</table>
We can talk to any of these nodes and they will replicate their data to the other nodes. Nifty! Now that we have a Riak cluster running for development, let's get Webmachine ready.

### Installing Webmachine 0.8 ###

Again, the process is very simple:


    oj@nix ~/blog $ git clone git://github.com/basho/webmachine
    loning into webmachine...
    remote: Counting objects: 1183, done.
    remote: Compressing objects: 100% (484/484), done.
    remote: Total 1183 (delta 735), reused 1063 (delta 668)
    Receiving objects: 100% (1183/1183), 1.17 MiB | 294 KiB/s, done.
    Resolving deltas: 100% (735/735), done.

    oj@nix ~/blog $ cd webmachine/
    oj@nix ~/blog/webmachine $ make
    ==> webmachine (get-deps)
    Pulling mochiweb from {git,"git://github.com/mochi/mochiweb",{tag,"1.5.1"}}
    Cloning into mochiweb...
    ==> mochiweb (get-deps)
    ==> mochiweb (compile)
    Compiled src/mochiglobal.erl
    Compiled src/mochiweb_sup.erl

      ... snip ...



As you can see, Webmachine sits on top of the [Mochiweb][] web server.

To create our own application which sits on top of Webmachine, we can utilise the `new_webmachine.sh` script. So let's do that to create our Code Smackdown (csd) site:


    oj@nix ~/blog/webmachine $ scripts/new_webmachine.sh
    usage: new_webmachine.sh name [destdir]
    oj@nix ~/blog/webmachine $ scripts/new_webmachine.sh csd ..
    ==> priv (create)
    Writing /home/oj/blog/csd/README
    Writing /home/oj/blog/csd/Makefile
    Writing /home/oj/blog/csd/rebar.config
    Writing /home/oj/blog/csd/rebar
    Writing /home/oj/blog/csd/start.sh
    Writing /home/oj/blog/csd/src/csd.app.src
    Writing /home/oj/blog/csd/src/csd.erl
    Writing /home/oj/blog/csd/src/csd_app.erl
    Writing /home/oj/blog/csd/src/csd_sup.erl
    Writing /home/oj/blog/csd/src/csd_resource.erl
    Writing /home/oj/blog/csd/priv/dispatch.conf



Webmachine generates a fully functional website out of the box. So we should be able to build it, fire it up and see it in action:


    oj@nix ~/blog/webmachine $ cd ../csd
    oj@nix ~/blog/csd $ make
    ==> csd (get-deps)
    Pulling webmachine from {git,"git://github.com/basho/webmachine","HEAD"}
    Cloning into webmachine...
    ==> webmachine (get-deps)
    Pulling mochiweb from {git,"git://github.com/mochi/mochiweb",{tag,"1.5.1"}}
    Cloning into mochiweb...
    ==> mochiweb (get-deps)
    ==> mochiweb (compile)
    Compiled src/mochiglobal.erl

      ... snip ...

    oj@nix ~/blog/csd $ ./start.sh
    Erlang R14B02 (erts-5.8.3) [source] [64-bit] [smp:2:2] [rq:2] [async-threads:0] [hipe] [kernel-poll:false]

      ... snip ...

    PROGRESS REPORT==== 3-Apr-2011::22:38:36 ===
              supervisor: {local,csd_sup}
                 started: [{pid,<0.76.0>},
                           {name,webmachine_mochiweb},
                           {mfargs,
                               {webmachine_mochiweb,start,
                                   [[{ip,"0.0.0.0"},
                                     {port,8000},
                                     {log_dir,"priv/log"},
                                     {dispatch,[{[],csd_resource,[]}]}]]}},
                           {restart_type,permanent},
                           {shutdown,5000},
                           {child_type,worker}]

    =PROGRESS REPORT==== 3-Apr-2011::22:38:36 ===
             application: csd
              started_at: nonode@nohost


The application is now up and running. As you can see from the output, our csd application has been fired up and is listening on port 8000. Let's fire it up in a web browser to see if it works.

<img src="/uploads/2010/09/wm_default.png"/>

It's alive! We're almost done. Before we finish up, let's get set up our build to include some dependencies.

### Adding ErlyDTL and Riak Client Dependencies ###

Rebar makes this bit a walk in the park (thanks [Dave][], you rock!). Just make sure you stop your Webmachine node before continuing by typing `q().` into your Erlang console.

The `rebar.config` file is what drives rebar's dependency mechanism. We need to open this file and add the entries we need to include in our application. Webmachine's `start.sh` script by default includes all of the dependencies on start up, so after modifying the configuration, we don't have to do anything else (other than use the library of course).

Open up `rebar.config` in your [favourite editor][VIM], it should look something like this:

{% codeblock rebar.config lang:erlang %}
%%-*- mode: erlang -*-

{deps, [{webmachine, "1.8.*", {git, "git://github.com/basho/webmachine", "HEAD"}}]}.
{% endcodeblock %}


Edit the file so that it includes both ErlyDTL and the Riak Client:

{% codeblock rebar.config lang:erlang %}
%%-*- mode: erlang -*-
{deps,
  [
    {webmachine, "1.8.*", {git, "git://github.com/basho/webmachine", "HEAD"}},
    {riakc, ".*", {git, "git://github.com/basho/riak-erlang-client", "HEAD"}},
    {erlydtl, "0.6.1", {git, "git://github.com/OJ/erlydtl.git", "HEAD"}}
  ]
}.
{% endcodeblock %}


You'll notice that the `erlydtl` reference points at my own fork of the ErlyDTL project. This is because I have made it compile cleanly with rebar so that any dependent projects are also able to be build with rebar. Feel free to use your own fork if you like, but mine is there if you can't be bothered :)

Save the file and build!


    oj@nix ~/blog/csd $ make
    ==> mochiweb (get-deps)
    ==> webmachine (get-deps)
    ==> csd (get-deps)
    Pulling riakc from {git,"git://github.com/basho/riak-erlang-client","HEAD"}
    Cloning into riakc...
    Pulling erlydtl from {git,"git://github.com/OJ/erlydtl.git","HEAD"}
    Cloning into erlydtl...
    ==> riakc (get-deps)
    Pulling protobuffs from {git,"git://github.com/basho/erlang_protobuffs",
                                 {tag,"protobuffs-0.5.1"}}
    Cloning into protobuffs...
    ==> protobuffs (get-deps)
    ==> erlydtl (get-deps)
    ==> mochiweb (compile)
    ==> webmachine (compile)
    ==> protobuffs (compile)
    Compiled src/pokemon_pb.erl
    Compiled src/protobuffs_parser.erl

      ... snip ...



Dependencies sorted. For the final part of this blog post, we'll include a basic ErlyDTL template and use it to render the page so we can see how it works.

### Rendering an ErlyDTL Template ###

Rebar has built-in support for the compilation of ErlyDTL templates. It can be configured to behave how you want it to, but out of the box it...

* ... looks for `*.dtl` files in the `./templates` folder
* ... compiles each of the found templates into a module called `filename_dtl` (eg. `base.dtl` becomes the module base_dtl)
* ... puts the module beam files into the `ebin` directory

Very handy. Let's create a very simple template by creating a `templates` folder, and editing a new file in that folder called `sample.dtl`

{% codeblock templates/sample.dtl lang:html %}
<html><body>Hello from inside ErlyDTL. You passed in {{ "{" }}{ param }}.</body></html>
{% endcodeblock %}


Then open up `src/csd_resource.erl` and search for the `to_html()` function. It should look like this:

{% codeblock src/csd_resource.erl lang:erlang %}
to_html(ReqData, State) ->
    {"<html><body>Hello, new world</body></html>", ReqData, State}.
{% endcodeblock %}


Modify it to look like this:

{% codeblock src/csd_resource.erl lang:erlang %}
to_html(ReqData, State) ->
    {ok, Content} = sample_dtl:render([{param, "Slartibartfast"}]),
    {Content, ReqData, State}.
{% endcodeblock %}


For now, don't worry about the content of this file. I will cover this off in a future post.

In the past, we had to manually modify `ebin/csd.app` to include the template that we've just created. Thankfully, `rebar` has been updated so that it generates the `ebin/csd.app` file from the `src/csd.app.src` file automatically when the application is built. `rebar` adds the required modules from the `src` folder _and_ includes the templates from the `templates` folder. Therefore, with our template and module ready to go, all we need to do is build and run:


    oj@nix ~/blog/csd $ make
    ==> mochiweb (get-deps)
    ==> webmachine (get-deps)
    ==> protobuffs (get-deps)
    ==> riakc (get-deps)
    ==> erlydtl (get-deps)
    ==> csd (get-deps)
    ==> mochiweb (compile)
    ==> webmachine (compile)
    ==> protobuffs (compile)
    ==> riakc (compile)
    ==> erlydtl (compile)
    ==> csd (compile)
    Compiled src/csd_resource.erl
    Compiled templates/sample.dtl

    oj@nix ~/blog/csd $ ./start.sh 
    Erlang R14B02 (erts-5.8.3) [source] [64-bit] [smp:2:2] [rq:2] [async-threads:0] [hipe] [kernel-poll:false]

      ... snip ...

    ** Found 0 name clashes in code paths 

      ... snip ...

    =PROGRESS REPORT==== 3-Apr-2011::22:54:50 ===
             application: csd
              started_at: nonode@nohost


Notice how ErlyDTL outputs some information to indicate that no template names have clashed with any other modules.

The application is now running, let's see what it looks like:

<img src="/uploads/2010/09/wm_erlydtl.png"/>

### The End ###

We now have a working environment in which to do our development. In the next post, I'll cover some of the basics required to get Webmachine talking to Riak via [Protocol Buffers][].

Feedback and criticism welcome!

**Note:** The code for Part 1 (this post) can be found on [Github][Part1Code].

  [ErlangPost]: /posts/the-future-is-erlang/ "The Future is Erlang"
  [Basho]: http://basho.com/ "Basho Technologies"
  [Code Smackdown]: http://bitbucket.org/OJ/codesmackdown "Code Smackdown"
  [CouchDB]: http://couchdb.apache.org/ "CouchDB"
  [curl]: http://curl.haxx.se/ "cURL and libcurl"
  [Dave]: http://dizzyd.com/ "Gradual Epiphany"
  [Protocol Buffers]: http://en.wikipedia.org/wiki/Protocol_Buffers "Protocol Buffers"
  [Erlang]: http://erlang.org/ "Erlang"
  [Git]: http://git-scm.com/ "Git"
  [ErlyDTL]: http://github.com/evanmiller/erlydtl "ErlyDTL"
  [Mochiweb]: http://github.com/mochi/mochiweb "Mochiweb"
  [Mercurial]: http://hg-scm.com/ "Mercurial"
  [Mint]: http://linuxmint.com/ "Linux Mint"
  [secretGeek]: http://secretgeek.net/ "secretGeek"
  [Rebar]: http://www.basho.com/developers.html#Rebar "Rebar"
  [Riak]: http://www.basho.com/developers.html#Riak "Riak"
  [Webmachine]: http://www.basho.com/developers.html#Webmachine "Webmachine"
  [VIM]: http://www.vim.org/ "VIM"
  [Riak Fast Track]: https://wiki.basho.com/display/RIAK/The+Riak+Fast+Track "Riak Fast Track"
  [Part1Code]: https://github.com/OJ/csd/tree/Part1-20110403 "Source Code for Part 1"
