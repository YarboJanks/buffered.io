---
published: false
date: 2011-10-13 22:00
categories: [Riak, Databases, Functional Programming, HOWTO, Erlang, Webmachine]
tags: [web development, Erlang, NoSQL, Webmachine, Riak, ErlyDTL, Twitter]
comments: true
layout: post
title: "Webmachine, ErlyDTL and Riak - Part 4"
series: "Web Development with Erlang"

---

<img src="/uploads/2010/09/riak-logo.png" alt="Riak Logo" style="float:left;padding-right:5px;padding-bottom:5px;"/>For those of you who are new to the series, you may want to check out [Part 1][], [Part 2][] and [Part 3][] before reading this post. It will help give you some context as well as introduce you to some of the jargon and technology that I'm using. If you've already read then, or don't want to, then please read on!

Upon finishing [Part 3][] of the series we were finally able to read data from [Riak][] and see it appear in our web page. This was the first stage in seeing a full end-to-end web application functioning. Of course there is still a great deal to do! So now that we're able to read data, moving into writing data is very simple. Rather than dedicate a whole post to writing data, I wanted to include the process of writing data in a post that was wrapped up in something more useful.

<!--more-->

Agenda
------

In this post we're going to hit a few points of pain:

1. Another slight refactor! We need to manage Riak connections in a smarter way, so we'll do that first.
1. We'll be dealing with more configuration so we'll change the way our application deals with configuration so that it's all in the one spot and a little easier to manage.
1. Add the ability for users to sign in. To keep this simple and avoid the need for users to manage yet another login, we're going to use [Oauth][] and let people sign in with their [Twitter][] accounts.
1. Write Oauth tokens to the Riak store.
1. Store a session cookie in the user's browser to keep track of their credentials (using HMAC).

After we've achieved these goals we'll have a much more functional web application, we'll know how to push data into Riak, and we'll have the grounds on which to build more functionality for our CodeSmackdown application.

Again, be warned, this post is a bit of a whopper! So get yourself a drink and get comfortable. Here we go!

Another Slight Refactor
-----------------------

Now that we're at the stage where Riak is going to get used more often we need to do a better job of handlng and managing the connections to the cluster. Ideally we should pool a bunch of connetions and reuse them across different requests. This reduces the overhead of creating and destroying connections all the time. Initially we're going to make use of Seth's [Pooler][] application (with a slight modification) to handle the pooling of Riak connections for us.

### Fixing HAProxy ###

So now that we have a plan to pool connections, the first thing we need to fix is our load-balancer's configuration. At the moment we have configured [HAProxy][] with the following settings:

{% codeblock dev.haproxy.conf lang:bash %}
# now set the default settings for each sub-section
defaults
  .
  .
  # specify some timeouts (all in milliseconds)
  timeout connect 5000
  timeout client 50000
  timeout server 50000
  .
  .
{% endcodeblock %}


As you can see we've forced the timeout of connections which means that every connection that is made to the proxy will be killed off when it has been inactive for a long enough period of time. If you were paying attention to the output in the application console window you'd have seen something like this appear after making a request:

    =ERROR REPORT==== 13-Aug-2011::20:52:01 ===
    ** Generic server <0.99.0> terminating 
    ** Last message in was {tcp_closed,#Port<0.2266>}
    ** When Server state == {state,"127.0.0.1",8080,false,false,undefined,
                                   undefined,
                                   {[],[]},
                                   1,[],infinity,100}
    ** Reason for termination == 
    ** disconnected

    =CRASH REPORT==== 13-Aug-2011::20:52:01 ===
      crasher:
        initial call: riakc_pb_socket:init/1
        pid: <0.99.0>
        registered_name: []
        exception exit: disconnected
          in function  gen_server:terminate/6
        ancestors: [csd_core_server,csd_core_sup,<0.52.0>]
        messages: []
        links: [<0.54.0>]
        dictionary: []
        trap_exit: false
        status: running
        heap_size: 377
        stack_size: 24
        reductions: 911
      neighbours:
        neighbour: [{pid,<0.54.0>},
                      {registered_name,csd_core_server},
                      {initial_call,{csd_core_server,init,['Argument__1']}},
                      {current_function,{gen_server,loop,6}},
                      {ancestors,[csd_core_sup,<0.52.0>]},
                      {messages,[]},
                      {links,[<0.53.0>,<0.99.0>]},
                      {dictionary,[]},
                      {trap_exit,false},
                      {status,waiting},
                      {heap_size,987},
                      {stack_size,9},
                      {reductions,370}]

    =SUPERVISOR REPORT==== 13-Aug-2011::20:52:01 ===
         Supervisor: {local,csd_core_sup}
         Context:    child_terminated
         Reason:     disconnected
         Offender:   [{pid,<0.54.0>},
                      {name,csd_core_server},
                      {mfargs,{csd_core_server,start_link,[]}},
                      {restart_type,permanent},
                      {shutdown,5000},
                      {child_type,worker}]


    =PROGRESS REPORT==== 13-Aug-2011::20:52:01 ===
              supervisor: {local,csd_core_sup}
                 started: [{pid,<0.104.0>},
                           {name,csd_core_server},
                           {mfargs,{csd_core_server,start_link,[]}},
                           {restart_type,permanent},
                           {shutdown,5000},
                           {child_type,worker}]


This is paired up with the following output from the HAProxy console:

    00000010:riaks.srvcls[0009:000a]
    00000010:riaks.clicls[0009:000a]
    00000010:riaks.closed[0009:000a]
    0000000e:webmachines.srvcls[0006:0007]
    0000000e:webmachines.clicls[0006:0007]
    0000000e:webmachines.closed[0006:0007]

These logs from the console clearly indicate that HAProxy is doing exactly what we've told it to do. It's killing off the connections after a period of time.

For a connection pool this is not a good idea. Therefore we need to modify this configuration so that it doesn't kill off connections. Thankfully this is a very simple thing to do! We delete the lines that force `client` and `server` timeouts (I'm commenting the lines out to make it obvious which ones you need to remove):

{% codeblock dev.haproxy.conf lang:bash %}
# now set the default settings for each sub-section
defaults
  .
  .
  # specify some timeouts (all in milliseconds)
  timeout connect 5000
  #timeout client 50000
  #timeout server 50000
  .
  .
{% endcodeblock %}

After making this change to the configuration, HAProxy will no longer kill off the connections. Therefore it's up to us to manage them.

### Connection Pooling ###

Given that it is _not_ one of the goals of this series to demonstrate how to create a connection pooling application in Erlang, we're going to use an application that's already out there to do it for us. This application is called [Pooler][]. Out of the box this application does Erlang process pooling, and given that our Riak connections are each Erlang processes, this suits us perfectly.

One thing that I didn't like about the interface to Pooler was that it relied on the caller managing the lifetime of the connection. As a result, I made a small change to the interface in my own [fork][PoolerFork] which I think helps keep things a little cleaner. This application will be making use of this fork.

First up, we need to add another dependency in our `rebar.config` file which will pull this application in from Github at a dependency.

{% codeblock rebar.config lang:erlang %}
%%-*- mode: erlang -*-
{deps,
  [
    {mochiweb, ".*", {git, "git://github.com/mochi/mochiweb", "HEAD"}},
    {riakc, ".*", {git, "git://github.com/basho/riak-erlang-client", "HEAD"}},
    {pooler, ".*", {git, "git://github.com/OJ/pooler", "HEAD"}}
  ]
}.
{% endcodeblock %}

Build the application so that the dependency is pulled and built:

{% codeblock lang:bash %}
oj@hitchens ~/code/csd $ make

   ... snip ... 

Pulling pooler from {git,"git://github.com/OJ/pooler","HEAD"}
Cloning into pooler...
==> pooler (get-deps)

   ... snip ... 

==> pooler (compile)
Compiled src/pooler_app.erl
Compiled src/pooler_pooled_worker_sup.erl
Compiled src/pooler_pool_sup.erl
Compiled src/pooler_sup.erl
Compiled src/pooler.erl

   ... snip ... 
{% endcodeblock %}

Next we need to take the scalpel to `csd_core`. When we first created this application, it was intended to manage all of the interaction with Riak and to manage the intracacies of dealing with snippets and other objects without exposting Riak's inner workings to the `csd_web` application. To do this we put a [gen_server][] in place, called `csd_core_server`, which handled the incoming requests. It internally established connections to Riak and used them without destroying them.

For now, we'll be keeping this `gen_server` in place but we're going to make some modifications to it:

1. We'll start and stop `pooler` when our `csd_core` application starts and stops.
1. We'll change the way configuration is managed and add the configuration for `pooler`.
1. We'll be removing the code that establishes the connections.
1. We'll pass the calls through to Riak using the new `pooler` application.

Let's get to it.

#### Starting and Stopping Pooler ####

Given that we're using `pooler` the first thing we need to do is make sure that it loads and runs when `csd_core` fires up. To do this, we need to modify `csd_core.erl` so that it looks like this:

{% codeblock apps/csd_core/src/csd_core.erl lang:erlang %}
%% @author OJ Reeves <oj@buffered.io>
%% @copyright 2011 OJ Reeves

%% @doc csd_core startup code

-module(csd_core).
-author('OJ Reeves <oj@buffered.io>').
-export([start/0, start_link/0, stop/0]).

ensure_started(App) ->
    case application:start(App) of
        ok ->
            ok;
        {error, {already_started, App}} ->
            ok
    end.

%% @spec start_link() -> {ok,Pid::pid()}
%% @doc Starts the app for inclusion in a supervisor tree
start_link() ->
    start_common(),
    csd_core_sup:start_link().

%% @spec start() -> ok
%% @doc Start the csd_core server.
start() ->
    start_common(),
    application:start(csd_core).

%% @spec stop() -> ok
%% @doc Stop the csd_core server.
stop() ->
    Res = application:stop(csd_core),
    application:stop(pooler),
    application:stop(crypto),
    Res.

%% @private
start_common() ->
    ensure_started(crypto),
    ensure_started(pooler).
{% endcodeblock %}

This code will start and stop the `pooler` application along with our application. Exactly what we need!

#### Fixing Configuration ####

Our rudimentary configuration module, `csd_riak_config.erl`, is now obsolete. We're going to remove it and replace it with something a little more complicated which will not only make it easier to handle configuration using Erlang's built-in [configuration][] handling, but we'll add some code which will make it easier to access configuration both in development _and_ once the application has been deployed.

Let's start by creating a new file:

{% codeblock apps/csd_core/priv/app.config lang:erlang %}
[
  {pooler, [
      {pools, [
          [
            {name, "haproxy"},
            {max_count, 30},
            {init_count, 5},
            {start_mfa, {riakc_pb_socket, start_link, ["127.0.0.1", 8080]}}
          ]
        ]}
    ]}
].
{% endcodeblock %}

`pooler` is smart enough to pool connections across multiple nodes. This is quite a nifty feature, but not one that we're making use of because we have HAProxy in place. Therefore, the configuration above is telling pooler to use just one single node/pool (ie. the proxy), to create 5 connections and to allow up to 30 to be created if required.

The last parameter in the configuration, `start_mfa`, tells `pooler` which module, function and arguments to invoke to create the Erlang process from. In our case we want it to create a pool of Riak client connections, hence why we've specified the `start_link` function in the `riakc_pb_socket` module.

Next we modify our `Makefile` so that when we invoke `make webstart` the configuration is properly included:

{% codeblock Makefile lang:bash %}
.PHONY: deps

REBAR=`which rebar || ./rebar`

all: deps compile

compile:
    @$(REBAR) compile

app:
    @$(REBAR) compile skip_deps=true

deps:
    @$(REBAR) get-deps

clean:
    @$(REBAR) clean

distclean: clean
    @$(REBAR) delete-deps

test: app
    @$(REBAR) eunit skip_deps=true

webstart: app
    exec erl -pa $(PWD)/apps/*/ebin -pa $(PWD)/deps/*/ebin -boot start_sasl -config $(PWD)/apps/csd_core/priv/app.config -s reloader -s csd_core -s csd_web

proxystart:
    @haproxy -f dev.haproxy.conf
{% endcodeblock %}

At this point we are able to build and run the application just as we were before. The first thing you'll notice is that the HAProxy console immediately registers 5 new connections:

{% codeblock lang:bash %}
0000004:dbcluster.accept(0005)=0006 from [127.0.0.1:34536]
00000005:dbcluster.accept(0005)=0008 from [127.0.0.1:58770]
00000006:dbcluster.accept(0005)=000a from [127.0.0.1:44734]
00000007:dbcluster.accept(0005)=000c from [127.0.0.1:33874]
00000008:dbcluster.accept(0005)=000e from [127.0.0.1:35815]
{% endcodeblock %}

This is evidence that `pooler` is doing its job and starting with 5 connections. Now that we have this in place, let's get rid of the old configuration:

{% codeblock lang:bash %}
oj@hitchens ~/code/csd $ rm apps/csd_core/src/csd_riak_config.erl 
{% endcodeblock %}

That was easy! We now need to remove any references to this module, thankfully the only module that used was `csd_core_server.erl`, and that's the one we're going to fix up now. After removing references to the configuration, removing connection creation and replacing it with calls to `pooler`, `csd_core_server` now looks like this:

{% codeblock apps/csd_core/src/csd_core_server.erl lang:erlang %}
-module(csd_core_server).
-behaviour(gen_server).
-define(SERVER, ?MODULE).

%% ------------------------------------------------------------------
%% API Function Exports
%% ------------------------------------------------------------------

-export([start_link/0, get_snippet/1, save_snippet/1]).

%% ------------------------------------------------------------------
%% gen_server Function Exports
%% ------------------------------------------------------------------

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%% ------------------------------------------------------------------
%% API Function Definitions
%% ------------------------------------------------------------------

start_link() ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

save_snippet(Snippet) ->
  gen_server:call(?SERVER, {save_snippet, Snippet}, infinity).

get_snippet(SnippetKey) ->
  gen_server:call(?SERVER, {get_snippet, SnippetKey}, infinity).

%% ------------------------------------------------------------------
%% gen_server Function Definitions
%% ------------------------------------------------------------------

init([]) ->
  {ok, undefined}.

handle_call({save_snippet, Snippet}, _From, State) ->
  SavedSnippet = pooler:use_member(fun(RiakPid) -> csd_snippet:save(RiakPid, Snippet) end),
  {reply, SavedSnippet, State};

handle_call({get_snippet, SnippetKey}, _From, State) ->
  Snippet = pooler:use_member(fun(RiakPid) -> csd_snippet:fetch(RiakPid, SnippetKey) end),
  {reply, Snippet, State};

handle_call(_Request, _From, State) ->
  {noreply, ok, State}.

handle_cast(_Msg, State) ->
  {noreply, State}.

handle_info(_Info, State) ->
  {noreply, State}.

terminate(_Reason, _State) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.
{% endcodeblock %}

Here you can see we're making use of the [pooler:use_member][] function to easily wrap up the management of the connection's usage lifetime. All traces of the old configuration are gone. We can now rebuild the application using `make`, fire it up using `make webstart` and hit the [same page](http://localhost/snippet/B41kUQ==) as before resulting in the same content appearing on screen.

We have now successfully removed the old configuration and connection handling code, and we've replaced it with `pooler` to handle a pool of connections to the Riak proxy. The last part of our refactor is around configuration for the front-end web application.

Rewiring Configuration
----------------------

Our configuration is going to get more complicated, so to make sure that we're able to better handle and manage it we're going to set up a similar structure to what we had set up in the `csd_core` application (in the previous section). The first thing we're going to change is the way that the **Webmachine** routes are loaded. Right now, they're stored in `apps/tr\_web/priv/dispatch.conf`. This configuration belongs alongside others, so we'll move that to an `app.config` file and re-jig the code to load it from there.

First up, rename the file:

    oj@air ~/code/csd/apps/csd_web/priv $ mv dispatch.conf app.config

Now let's edit it so that it takes the appropriate format:

{% codeblock apps/csd_web/priv/app.config lang:erlang %}
%%-*- mode: erlang -*-
[
  {sasl,
    [
      {sasl_error_logger, {file, "log/sasl-error.log"}},
      {errlog_type, error},
      {error_logger_mf_dir, "log/sasl"},      % Log directory
      {error_logger_mf_maxbytes, 10485760},   % 10 MB max file size
      {error_logger_mf_maxfiles, 5}           % 5 files max
    ]
  },
  {csd_web,
    [
      {web,
        [
          {ip, "0.0.0.0"},
          {port, 8000},
          {log_dir, "priv/log"},
          {dispatch,
            [
              {[], csd_web_resource, []},
              {["snippet", key], csd_web_snippet_resource, []}
            ]
          }
        ]
      }
    ]
  }
].
{% endcodeblock %}

A few things to note here:

1. I've included the `sasl` configuration for later tweaking.
1. the `csd_web` section is named that way so that it is matches the application name. This makes the auto-wiring work.
1. The Webmachine configuration for application is now in a subsection called `web`. Inside this section is the original `dispatch` that we had in our old `dispatch.conf`. This configuration sections takes the _exact_ form that Webmachine expects when we start its process in our supervisor.

At this point we need to go and fiddle with the way Webmachine loads its configuration so that it picks up these details. We'll start by defining a helper which will make it easy to get access to configuration for the `csd_web` application.

{% codeblock apps/csd_web/src/csd_conf.erl lang:erl %}
% TODO: put the file in here when it's done
{% endcodeblock %}

Configuration helpers are now in place, let's fix the Webmachine loader in `csd_web_sup.erl`.

{% codeblock apps/csd_web/src/csd_conf.erl (partial) lang:erl %}
% ... snip ... %
%% @spec init([]) -> SupervisorTree
%% @doc supervisor callback.
init([]) ->
  WebConfig = conf:get_section(web),
  Web = {webmachine_mochiweb,
    {webmachine_mochiweb, start, [WebConfig]},
    permanent, 5000, worker, dynamic},
  Processes = [Web],
  {ok, { {one_for_one, 10, 10}, Processes} }.
% ... snip ... %
{% endcodeblock %}

This little snippet delegates the responsibility of all Webmachine-related stuff to the `app.config` file. Let's include this in our `Makefile` when we start our application.

{% codeblock Makefile (partial) lang:bash %}
webstart: app
	exec erl -pa $(PWD)/apps/*/ebin -pa $(PWD)/deps/*/ebin -boot start_sasl -config $(PWD)/apps/csd_web/priv/app.config -config $(PWD)/apps/csd_core/priv/app.config -s reloader -s csd_core -s csd_web
{% endcodeblock %}

All we've done here is add another `-config` parameter and pointed it at the new `app.config` file in the `csd_web/src` folder. Fire up the application and it _should_ behave exactly as it did before.

Now that we have our configuration tweaked we have finalised the last of the refactoring tasks (at least for now). It's now time to start designing our user login functionality.

Handling User Logins
--------------------

Handling logins isn't necessarily as simple as it looks. Remember, [Webmachine][] is not a Web application framework, it's a feature-rich tool which helps us build well-behaving RESTful HTTP applications. The idea of a "session" is a (leaky) abstraction that web developers have added to web applications to aid in preventing users from having to manually sign in each time they want to access a resource. This abstraction tends to be handled through cookies.

We'll be doing the same, but given that we don't have anything in place at all we're going to have to come up with our own method for handling authentication of the user via cookies.

Bearing in mind that we'll be making use of Twitter, via Oauth, to deal with the process of authentication, the login process will consist of the following steps:

1. The user clicks a "login via Twitter" button.
1. The server handles the request and negotiates a [request token][] with Twitter using Oauth.
1. The application redirects the user to Twitter on a special URL which contains Oauth request information.
1. The user is asked to sign in to Twitter, if they haven't already during the course of their browser session.
1. Twitter then confirms that the user does intend to sign-in to CodeSmackdown using their Twitter credentials, and redirects the user back to the application.
1. If the user approves the process, the application is handed a verification token which is then used to generate an Oauth [access token][] with Twitter. This access token is what is used to allow the user to easily sign in to the application from this point onward.

Prepare yourself, you're about to learn how to do Oauth in Erlang! But before we can do that, we need to register our application with Twitter.

### Creating a new Twitter Application ###

Start by browsing to the [Twitter application registration page][TwitterNewApp] and signing in with your Twitter account credentials. You'll be taken to a page where you can enter the details of the application. Leave the Callback URL blank as we'll be using OAuth, but fill out the rest of the deails. Once you've filled out the details you'll being presented with a standard set of OAuth-related bits which we'll be using down the track. I'll of course be using my own registered application name (Code Smackdown) along with the keys. Given these keys are specific to my application I will not be making them part of the source (sorry).

Once you're registered, we're ready to take the OAuth configuration information from Twitter and plug it into our own configuration. Re-open `csd_web/priv/app.config` and create a new section called `twitter` under the `csd_web` section and add the following

{% codeblock apps/csd_web/priv/app.config (partial) lang:erlang %}
% ... snip ... %
  {csd_web,
    [
      % ... snip ... %
      {twitter,
        [
          {consumer_key, "< your application's key goes here >"},
          {consumer_secret, "< your application's secret goes here >"},
          {request_token_url, "https://twitter.com/oauth/request_token"},
          {access_token_url, "https://twitter.com/oauth/access_token"},
          {authorize_url, "https://twitter.com/oauth/authorize"},
          {authenticate_url, "https://twitter.com/oauth/authenticate"},
          {current_user_info_url, "https://twitter.com/account/verify_credentials.json"},
          {lookup_users_url, "https://api.twitter.com/1/users/lookup.json"},
          {direct_messages_list_url, "https://twitter.com/direct_messages.json"}
        ]
      }
    ]
  }
% ... snip ... %
{% endcodeblock %}

The first two values come straight from Twitter and would have been given to you upon registering your application. The rest are URLs that we'll be using later on.

Now that we've got our configuration locked in we can get started on managing the requests. For this we need to understand how OAuth actually works.

A deep-dive into the ins and outs of OAuth is beyond the scope of this article. I recommend having a read of [this presentation on OAuth][OAuthPresso] which gives a good overview. The rest of this article will fill the gaps as to how it all works.

### Implementing OAuth ###

Using OAuth requires us to invoke HTTP requests to Twitter. We could go through the pain of doing this manually, but instead we're going to use another Open Source utility which has the ability to handle this for us.



[OAuthPresso]: http://www.slideshare.net/leahculver/oauth-open-api-authentication "OAuth overview"
[TwitterNewApp]: https://dev.twitter.com/apps/new "New Twitter Application"
[Erlang]: http://erlang.org/ "Erlang"
[Webmachine]: http://www.basho.com/developers.html#Webmachine "Webmachine"
[JSON]: http://json.org/ "JavaScript Object Notation"
[Part 1]: /posts/webmachine-erlydtl-and-riak-part-1/ "Wembachine, ErlyDTL and Riak - Part 1"
[Part 2]: /posts/webmachine-erlydtl-and-riak-part-2/ "Wembachine, ErlyDTL and Riak - Part 2"
[Part 3]: /posts/webmachine-erlydtl-and-riak-part-3/ "Wembachine, ErlyDTL and Riak - Part 3"
[Riak]: http://www.basho.com/developers.html#Riak "Riak"
[ErlyDTL]: http://github.com/evanmiller/erlydtl "ErlyDTL"
[Rebar]: http://www.basho.com/developers.html#Rebar "Rebar"
[mochijson2]: https://github.com/mochi/mochiweb/blob/master/src/mochijson2.erl "Mochiweb's json module"
[Mochiweb]: https://github.com/mochi/mochiweb "Mochiweb"
[OTP]: http://en.wikipedia.org/wiki/Open_Telecom_Platform "Open Telecom Platform"
[cURL]: http://curl.haxx.se/ "cURL homepage"
