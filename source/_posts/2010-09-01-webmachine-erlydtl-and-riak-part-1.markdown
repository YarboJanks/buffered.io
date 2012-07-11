---
categories: [Riak, Databases, Functional Programming, HOWTO, Erlang, Webmachine]
date: 2010-09-01 23:29
updated: 2012-07-11 21:50
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

### Installing Erlang R15B01 ###

Download and installation is fairly simple. Right now we're not worried about enabling all of the features of Erlang, such as interfacing with Java and providing support for GTK. So the boilerplate functionality is enough. Here are the steps to follow:


{% codeblock %}
oj@air ~/blog $ wget http://erlang.org/download/otp_src_R15B01.tar.gz

  ... snip ...

oj@air ~/blog $ tar -xzf otp_src_R15B01.tar.gz 
oj@air ~/blog $ cd otp_src_R15B01/
oj@air ~/blog/otp_src_R15B01 $ ./configure 

  ... snip ...

oj@air ~/blog/otp_src_R15B01 $ make

  ... snip ...

oj@air ~/blog/otp_src_R15B01 $ sudo make install

  ... snip ...
{% endcodeblock %}

Done! Let's confirm that it has been set up correctly:

{% codeblock %}
oj@air ~/blog $ erl
Erlang R15B01 (erts-5.9.1) [source] [64-bit] [smp:2:2] [rq:2] [async-threads:0] [hipe] [kernel-poll:false]

Eshell V5.9.1  (abort with ^G)
1> q().
ok
{% endcodeblock %}

Excellent. Next let's get Riak going.


### Installing Riak 1.1.4

Considering the power of the software you are about to set up, it is absolutely insane how easy it is to get it running. If any of you have tried to get [CouchDB][] running you'll no doubt have experienced a few quirks and a bit of pain getting it rolling. Not so with Riak. As mentioned at the start of the article, make sure you have a recent version of [Mercurial][] and [Git][] installed.

{% codeblock %}
oj@air ~/blog $ git clone git://github.com/basho/riak
Cloning into riak...
remote: Counting objects: 12989, done.
remote: Compressing objects: 100% (4210/4210), done.
remote: Total 12989 (delta 8494), reused 12871 (delta 8386)
Receiving objects: 100% (12989/12989), 9.82 MiB | 168 KiB/s, done.
Resolving deltas: 100% (8494/8494), done.

oj@air ~/blog $ cd riak
oj@air ~/blog/riak $ make

./rebar get-deps
==> rel (get-deps)
==> riak (get-deps)
Pulling cluster_info from {git,"git://github.com/basho/cluster_info",
                               {branch,"master"}}
Cloning into cluster_info...
Pulling riak_kv from {git,"git://github.com/basho/riak_kv",{branch,"master"}}
Cloning into riak_kv...
Pulling riak_search from {git,"git://github.com/basho/riak_search",
                              {branch,"master"}}
Cloning into riak_search...
Pulling riak_control from {git,"git://github.com/basho/riak_control",
                               {branch,"master"}}
Cloning into riak_control...
==> cluster_info (get-deps)
==> riak_kv (get-deps)
Pulling riak_core from {git,"git://github.com/basho/riak_core","master"}
Cloning into riak_core...
Pulling luke from {git,"git://github.com/basho/luke","master"}
Cloning into luke...
Pulling erlang_js from {git,"git://github.com/basho/erlang_js","master"}
Cloning into erlang_js...
Pulling bitcask from {git,"git://github.com/basho/bitcask","master"}
Cloning into bitcask...
Pulling merge_index from {git,"git://github.com/basho/merge_index","master"}
Cloning into merge_index...
Pulling ebloom from {git,"git://github.com/basho/ebloom","master"}
Cloning into ebloom...
Pulling eper from {git,"git://github.com/basho/eper.git","master"}
Cloning into eper...
Pulling eleveldb from {git,"git://github.com/basho/eleveldb.git","master"}
Cloning into eleveldb...
Pulling sext from {git,"git://github.com/esl/sext","master"}
Cloning into sext...
Pulling riak_pipe from {git,"git://github.com/basho/riak_pipe.git","master"}
Cloning into riak_pipe...
Pulling riak_api from {git,"git://github.com/basho/riak_api.git","master"}
Cloning into riak_api...
==> riak_core (get-deps)
Pulling lager from {git,"git://github.com/basho/lager",{branch,"master"}}
Cloning into lager...
Pulling poolboy from {git,"git://github.com/basho/poolboy",{branch,"master"}}
Cloning into poolboy...
Pulling protobuffs from {git,"git://github.com/basho/erlang_protobuffs",
                             {branch,"master"}}
Cloning into protobuffs...
Pulling basho_stats from {git,"git://github.com/basho/basho_stats","HEAD"}
Cloning into basho_stats...
Pulling riak_sysmon from {git,"git://github.com/basho/riak_sysmon",
                              {branch,"master"}}
Cloning into riak_sysmon...
Pulling webmachine from {git,"git://github.com/basho/webmachine",
                             {branch,"master"}}
Cloning into webmachine...
Pulling folsom from {git,"git://github.com/basho/folsom.git",
                         {branch,"master"}}
Cloning into folsom...
==> lager (get-deps)
==> poolboy (get-deps)
==> protobuffs (get-deps)
Pulling meck from {git,"git://github.com/eproxus/meck",{branch,"master"}}
Cloning into meck...
==> meck (get-deps)
==> basho_stats (get-deps)
==> riak_sysmon (get-deps)
==> webmachine (get-deps)
Pulling mochiweb from {git,"git://github.com/basho/mochiweb",
                           {tag,"1.5.1-riak-1.0.x-fixes"}}
Cloning into mochiweb...
==> mochiweb (get-deps)
==> folsom (get-deps)
Pulling bear from {git,"git://github.com/boundary/bear.git","master"}
Cloning into bear...
==> bear (get-deps)
==> luke (get-deps)
==> erlang_js (get-deps)
==> bitcask (get-deps)
==> merge_index (get-deps)
==> ebloom (get-deps)
==> eper (get-deps)
Pulling getopt from {git,"git://github.com/jcomellas/getopt.git",
                         {tag,"v0.4.3"}}
Cloning into getopt...
==> getopt (get-deps)
==> eleveldb (get-deps)
Cloning into leveldb...
Note: checking out 'fbe66f44e9abeb4f2de3c89d91573b7879226e6c'.

You are in 'detached HEAD' state. You can look around, make experimental
changes and commit them, and you can discard any commits you make in this
state without impacting any branches by performing another checkout.

If you want to create a new branch to retain commits you create, you may
do so (now or later) by using -b with the checkout command again. Example:

  git checkout -b new_branch_name

HEAD is now at fbe66f4... Merge pull request #17 from basho/mv-compress-msg
==> sext (get-deps)
Pulling edown from {git,"git://github.com/esl/edown.git","HEAD"}
Cloning into edown...
==> edown (get-deps)
==> riak_pipe (get-deps)
==> riak_api (get-deps)
Pulling riak_pb from {git,"git://github.com/basho/riak_pb.git","master"}
Cloning into riak_pb...
==> riak_pb (get-deps)
==> lucene_parser (get-deps)
==> riak_search (get-deps)
==> riak_control (get-deps)
./rebar compile
==> cluster_info (compile)
Compiled src/cluster_info_ex.erl

   ... snip ...

==> riak_core (compile)
Compiling src/riak_core.proto

=INFO REPORT==== 11-Jul-2012::22:06:02 ===
Writing header file to "riak_core_pb.hrl"

=INFO REPORT==== 11-Jul-2012::22:06:02 ===
Writing beam file to "riak_core_pb.beam"
Compiled src/gen_nb_server.erl

   ... snip ...

==> riak_pb (compile)
Compiling src/riak.proto

Compiled src/admin_gui.erl
Compiled src/admin_cluster.erl
==> rel (compile)
==> riak (compile)
Compiled src/etop_txt.erl
{% endcodeblock %}

I snipped a lot of the make output for obvious reasons. Let's build a few development nodes of Riak and cluster them together as indicated in the [Riak Fast Track][]:

{% codeblock %}
oj@air ~/blog/riak $ make devrel
mkdir -p dev
(cd rel && ../rebar generate target_dir=../dev/dev1 overlay_vars=vars/dev1_vars.config)
==> rel (generate)
mkdir -p dev
(cd rel && ../rebar generate target_dir=../dev/dev2 overlay_vars=vars/dev2_vars.config)
==> rel (generate)
mkdir -p dev
(cd rel && ../rebar generate target_dir=../dev/dev3 overlay_vars=vars/dev3_vars.config)
==> rel (generate)
mkdir -p dev
(cd rel && ../rebar generate target_dir=../dev/dev4 overlay_vars=vars/dev4_vars.config)
==> rel (generate)

oj@air ~/blog/riak $ cd dev
oj@air ~/blog/riak/dev $ dev1/bin/riak start
oj@air ~/blog/riak/dev $ dev2/bin/riak start
oj@air ~/blog/riak/dev $ dev3/bin/riak start
oj@air ~/blog/riak/dev $ dev4/bin/riak start
oj@air ~/blog/riak/dev $ dev2/bin/riak-admin cluster join dev1
Success: staged join request for 'dev2@127.0.0.1' to dev1
oj@air ~/blog/riak/dev $ dev3/bin/riak-admin cluster join dev1
Success: staged join request for 'dev3@127.0.0.1' to dev1
oj@air ~/blog/riak/dev $ dev4/bin/riak-admin cluster join dev1
Success: staged join request for 'dev4@127.0.0.1' to dev1
{% endcodeblock %}

At this point our Riak cluster should be up and running. Rather than assume let's make sure.

{% codeblock %}
oj@air ~/blog/riak/dev $ dev4/bin/riak-admin ringready
TRUE All nodes agree on the ring ['dev1@127.0.0.1','dev2@127.0.0.1',
                                  'dev3@127.0.0.1','dev4@127.0.0.1']
{% endcodeblock %}

As we can see from the output, we now have a 4-node Riak cluster up and running. Those four nodes have the following traits:
<table style="border: 1px solid black; width:100%;">
  <thead>
    <tr>
      <th style="border: 1px solid black; padding: 3px;">Name</th>
      <th style="border: 1px solid black; padding: 3px;">Protobuf Port</th>
      <th style="border: 1px solid black; padding: 3px;">HTTP Port</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td style="border: 1px solid black; padding: 3px;">dev1@127.0.0.1</td>
      <td style="border: 1px solid black; padding: 3px;">8081</td>
      <td style="border: 1px solid black; padding: 3px;">8091</td>
    </tr>
    <tr>
      <td style="border: 1px solid black; padding: 3px;">dev2@127.0.0.1</td>
      <td style="border: 1px solid black; padding: 3px;">8082</td>
      <td style="border: 1px solid black; padding: 3px;">8092</td>
    </tr>
    <tr>
      <td style="border: 1px solid black; padding: 3px;">dev3@127.0.0.1</td>
      <td style="border: 1px solid black; padding: 3px;">8083</td>
      <td style="border: 1px solid black; padding: 3px;">8093</td>
    </tr>
    <tr>
      <td style="border: 1px solid black; padding: 3px;">dev4@127.0.0.1</td>
      <td style="border: 1px solid black; padding: 3px;">8084</td>
      <td style="border: 1px solid black; padding: 3px;">8094</td>
    </tr>
  </tbody>
</table>

We can talk to any of these nodes and they will replicate their data to the other nodes. Nifty! Now that we have a Riak cluster running for development, let's get Webmachine ready.

### Installing Webmachine 1.9.1 ###

Again, the process is very simple:

{% codeblock %}
oj@air ~/blog $ git clone git://github.com/basho/webmachine
Cloning into webmachine...
remote: Counting objects: 1512, done.
remote: Compressing objects: 100% (611/611), done.
remote: Total 1512 (delta 957), reused 1409 (delta 869)
Receiving objects: 100% (1512/1512), 1.32 MiB | 225 KiB/s, done.
Resolving deltas: 100% (957/957), done.

oj@air ~/blog $ cd webmachine
oj@air ~/blog/webmachine $ make
==> webmachine (get-deps)
Pulling mochiweb from {git,"git://github.com/basho/mochiweb",
                           {tag,"1.5.1-riak-1.0.x-fixes"}}
Cloning into mochiweb...
==> mochiweb (get-deps)
==> mochiweb (compile)
Compiled src/mochiweb_sup.erl

   ... snip ...

==> webmachine (compile)
Compiled src/webmachine_util.erl

   ... snip ...

Compiled src/webmachine_request.erl
{% endcodeblock %}

As you can see, Webmachine sits on top of the [Mochiweb][] web server.

To create our own application which sits on top of Webmachine, we can utilise the `new_webmachine.sh` script. So let's do that to create our Code Smackdown (csd) site:

{% codeblock %}
oj@air ~/blog/webmachine $ scripts/new_webmachine.sh
usage: new_webmachine.sh name [destdir]
oj@air ~/blog/webmachine $ scripts/new_webmachine.sh csd ..
==> priv (create)
Writing /Users/oj/code/tmp/csd/README
Writing /Users/oj/code/tmp/csd/Makefile
Writing /Users/oj/code/tmp/csd/rebar.config
Writing /Users/oj/code/tmp/csd/rebar
Writing /Users/oj/code/tmp/csd/start.sh
Writing /Users/oj/code/tmp/csd/src/csd.app.src
Writing /Users/oj/code/tmp/csd/src/csd.erl
Writing /Users/oj/code/tmp/csd/src/csd_app.erl
Writing /Users/oj/code/tmp/csd/src/csd_sup.erl
Writing /Users/oj/code/tmp/csd/src/csd_resource.erl
Writing /Users/oj/code/tmp/csd/priv/dispatch.conf
{% endcodeblock %}

Webmachine generates a fully functional website out of the box. So we should be able to build it, fire it up and see it in action:

{% codeblock %}
oj@air ~/blog/webmachine $ cd ../csd
oj@air ~/blog/csd $ make
==> csd (get-deps)
Pulling webmachine from {git,"git://github.com/basho/webmachine","HEAD"}
Cloning into webmachine...
==> webmachine (get-deps)
Pulling mochiweb from {git,"git://github.com/basho/mochiweb",
                           {tag,"1.5.1-riak-1.0.x-fixes"}}
Cloning into mochiweb...
==> mochiweb (get-deps)
==> mochiweb (compile)
Compiled src/mochiweb_sup.erl

   ... snip ...

Compiled src/csd_sup.erl

oj@air ~/blog/csd $ ./start.sh
Erlang R15B01 (erts-5.9.1) [source] [64-bit] [smp:4:4] [async-threads:0] [hipe] [kernel-poll:false]

   ... snip ...

=PROGRESS REPORT==== 11-Jul-2012::22:31:27 ===
          supervisor: {local,csd_sup}
             started: [{pid,<0.75.0>},
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

=PROGRESS REPORT==== 11-Jul-2012::22:31:27 ===
         application: csd
          started_at: nonode@nohost

{% endcodeblock %}

The application is now up and running. As you can see from the output, our csd application has been fired up and is listening on port 8000. Let's fire it up in a web browser to see if it works.

<img src="/uploads/2010/09/wm_default.png"/>

It's alive! We're almost done. Before we finish up, let's get set up our build to include some dependencies.

### Adding ErlyDTL and Riak Client Dependencies ###

Rebar makes this bit a walk in the park (thanks [Dave][], you rock!). Just make sure you stop your Webmachine node before continuing by typing `q().` into your Erlang console.

The `rebar.config` file is what drives rebar's dependency mechanism. We need to open this file and add the entries we need to include in our application. Webmachine's `start.sh` script by default includes all of the dependencies on start up, so after modifying the configuration, we don't have to do anything else (other than use the library of course).

Open up `rebar.config` in your [favourite editor][VIM], it should look something like this:

{% codeblock rebar.config lang:erlang %}
%%-*- mode: erlang -*-

{deps, [{webmachine, "1.9.*", {git, "git://github.com/basho/webmachine", "HEAD"}}]}.
{% endcodeblock %}


Edit the file so that it includes both ErlyDTL and the Riak Client:

{% codeblock rebar.config lang:erlang %}
%%-*- mode: erlang -*-
{deps,
  [
    {webmachine, ".*", {git, "git://github.com/basho/webmachine", "HEAD"}},
    {riakc, ".*", {git, "git://github.com/basho/riak-erlang-client", "HEAD"}},
    {erlydtl, ".*", {git, "git://github.com/OJ/erlydtl.git", "HEAD"}}
  ]
}.
{% endcodeblock %}


You'll notice that the `erlydtl` reference points at my own fork of the ErlyDTL project. This is because I have made it compile cleanly with rebar so that any dependent projects are also able to be build with rebar. Feel free to use your own fork if you like, but mine is there if you can't be bothered :)

Save the file and build!


{% codeblock %}
oj@air ~/blog/csd $ make
==> mochiweb (get-deps)
==> webmachine (get-deps)
==> csd (get-deps)
Pulling riakc from {git,"git://github.com/basho/riak-erlang-client","HEAD"}
Cloning into riakc...

  ... snip ...
{% endcodeblock %}

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

{% codeblock %}
oj@air ~/blog/csd $ make
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

oj@air ~/blog/csd $ ./start.sh 
Erlang R15B01 (erts-5.9.1) [source] [64-bit] [smp:2:2] [rq:2] [async-threads:0] [hipe] [kernel-poll:false]

  ... snip ...

** Found 0 name clashes in code paths 

  ... snip ...

=PROGRESS REPORT==== 11-Jul-2012::22:31:27 ===
         application: csd
          started_at: nonode@nohost
{% endcodeblock %}

Notice how ErlyDTL outputs some information to indicate that no template names have clashed with any other modules.

The application is now running, let's see what it looks like:

<img src="/uploads/2010/09/wm_erlydtl.png"/>

### The End ###

We now have a working environment in which to do our development. In the next post, I'll cover some of the basics required to get Webmachine talking to Riak via [Protocol Buffers][].

Feedback and criticism welcome!

**Note:** The code for Part 1 (this post) can be found on [Github][Part1Code].

Other parts in this series: [Part 2][], [Part 3][], [Part 4][], [Part 5][]

  [Part 2]: /posts/webmachine-erlydtl-and-riak-part-2/ "Webmachine, ErlyDTL and Riak - Part 2"
  [Part 3]: /posts/webmachine-erlydtl-and-riak-part-3/ "Webmachine, ErlyDTL and Riak - Part 3"
  [Part 4]: /posts/webmachine-erlydtl-and-riak-part-4/ "Webmachine, ErlyDTL and Riak - Part 4"
  [Part 5]: /posts/webmachine-erlydtl-and-riak-part-5/ "Webmachine, ErlyDTL and Riak - Part 5"
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
