---
layout: post
title: "Webmachine, ErlyDTL and Riak - Part 6"
date: 2013-06-01 07:47
comments: false
series: "Web Development with Erlang"
tags: [Riak, Riak Search, Functional Programming, HOWTO, Erlang, Webmachine, ErlyDTL, BackboneJS, Bootstrap]
categories: [Riak, Riak Search, Functional Programming, HOWTO, Erlang, Webmachine, ErlyDTL, BackboneJS, Bootstrap]
---

{% img left /uploads/2010/09/riak-logo.png 'Riak Logo' %}Newcomers to the series should first take a look at the previous five parts of the [series][] ([Part 1][], [Part 2][], [Part 3][], [Part 4][], [Part 5][]) to make sure that you're up to speed. Feel free to read on if you feel comfortable with the general concepts in use.

Last year when we finished [Part 5][] we finally had a functional application which allowed us to post and view snippets, and vote on those snippets. It was exciting. The post was a little on the large side, and hence that's why it's take a while to get around to writing this one (a bit of a break was needed). In this post, we're going to focus on tidying up some of the functionality, refactoring a few areas and using more appropriate solutions to certain problems in our application.

<!--more-->

## <a id="agenda"></a>Agenda

This post is all about improving what we have. We'll be adding just one new bit of functionality while making this improvements. Here's what's on the cards:

1. Updating Twitter URLs to properly match the current API.
1. Updating to Webmachine 1.10.
1. Removing the existing ID generation implementation and replacing it with [Flake][].
1. Replacing [mochijson2][] with [Jiffy][], a JSON library implemented as [NIFs][]. We get speed improvements (not that we're suffering greatly here) and in my view a slightly nicer syntax.
1. Removing all JavaScript Map/Reduce functionality from the application and replacing it with either Erlang Map/Reduce calls or [Riak Search][].
1. Removing all use of Erlang atoms in proplists which are intended for JSON serialisation.
1. Replacing strings with Erlang binaries wherever possible.
1. Removing old JSON code which is no longer required.
1. Implementing paging of submitted snippets on the user detail view.

Let's get cracking.

## <a id="twitter-api"></a>Twitter API Updates

When we first implemented Twitter integration it was back in February 2012. Since then the API for Twitter has changed a little bit. Thankfully those updates haven't been too drastic, but there is one change that broke our application. That is, the URL that we were using to get the user's Twitter username has changed. Even though the URL has changed, the structure of the JSON that is retrieved is still the same, so to fix the problem we simply have to update the URL that is used in the `current_user_info_url` setting:

``` erlang apps/csd_web/priv/app.config (partial)
%% ... snip ...
{current_user_info_url, "https://api.twitter.com/1.1/account/verify_credentials.json"}
%% ... snip ...
```

Done. Our login process now works correctly again.

## <a id="webmachine-update"></a>Updating Webmachine to v1.10

Even though it's not considered best practice, for this series we have included Webmachine as a `rebar` dependency which points directly to `HEAD` in the Git repository. This means that each time we pull dependencies we'll be getting the latest version. Yes, I know, grab your torch and pitch fork!

The good thing is that updating our dependencies to the latest version is as simple as deleting the dependency. In our case, we're going to flush them all out, and get them again. Like so:

``` bash
$ make distclean
# ... snip ...
$ make
# ... snip ...
```

You're now running the latest version of Webmachine. The Basho folk have made some juicy changes in Webmachine 1.10, but the API remains the same which means we don't actually need to make any code changes to enjoy the fruits of the latest release.

## <a id="id-generation"></a>Better ID Generation

I'll be honest, the first attempt at generating IDs for snippets was rather dire. It was enough to get by, but it's now past time to remote it and replace it with something reliable. Rather than attempt to create something myself that would generate IDs that are unique across clusters of machines, I felt it would be better to stand on the shoulders of giants and make use of [Flake][], by [Boundary][].

Flake gives us the ability to easily generate identifiers which will be unique. Check out the [documentation][flakedocs] for more detail.

So one issue with Flake is that, out of the box, it doesn't work as a `rebar` dependency. I was going to clone the source and make the appropriate changes, but I realised (after looking at the [network graph][flakenetwork]) someone else had already [done that][flakerebarbranch]. So we'll add this as the dependency instead.

ID generation lives in `csd_core`, so we need to open up the `rebar.config` for this application:

``` erlang apps/csd_core/rebar.config (partial)
%% ... snip ...
{flake, "0\.7", {git, "git://github.com/timadorus/flake.git", {branch, "rebar_dep"}}}
%% ... snip ...
```

Before we can use `flake` we need to add some configuration which will tell it how to behave. This means we need to modify the `app.config` as well. Here's what it looks like:

``` erlang apps/csd_core/priv/app.config (partial)
[
  {flake, [
      {interface, "en0"},
      {timestamp_path, "/tmp/flake/timestamp-dets"},
      {allowable_downtime, 2592000000}
    ]},
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
```

The `flake` section is obviously what has been added. The meaning of the parameters can be found in the [Flake documentation][flakedocs] if you're keen to find out more about them. Make sure you change the `interface` option to a local network interface otherwise it won't work. `en0` is the interface ID for my Macbook's WiFi NIC.

Next we need to make sure the application is started and stopped at the appropriate times. So let's fix that up in `csd_core.erl`:

``` erlang apps/csd_core/rebar.config (partial)
start_link() ->
  start_common(),
  pooler_sup:start_link().

%% ... snip ...

start() ->
  start_common().

%% ... snip ...

stop() ->
  application:stop(pooler),
  application:stop(flake),
  application:stop(crypto),
  ok.

%% ... snip ...

start_common() ->
  ensure_started(crypto),
  ensure_started(flake),
  ensure_started(pooler).
```

Here I've created `start_common` which is used in both possible startup scenarios, and I have added `flake` as an application to be started. I've also indicated that it should be stopped in the `stop` function. That's all we need to do to ensure the application is running, now we just need to use it. Again, this is very simple thanks to the nature of the API.

There is a function in `flake_server` called `id`, which generates an ID. It has two implementations:

1. `id/0` - this implementation generates a new ID and returns it as an Erlang binary.
1. `id/1` - this implementation takes a single parameter, which is the base of the desired ID, and generates an ID using that base as a way to represent the ID. The result is return as an Erlang string (ie. a list of integers).

For our needs, the second implementation is desirable as we can choose to go with a base of `62`, which gives us an ID made up of characters `0-9`, `a-z` and `A-Z`. We know that these are identifiers that can easily be specified in a URL without any issues with regards to special characters and escaping/encoding.

Let's open up `csd_riak`, which is where IDs are generated, and make our changes to the `new_id` functions. Firstly, we'll remove one of the overloads as we won't be needing it any more. Second, we'll invoke the call to the `flake_server` instead of our <del>crappy</del>custom code.

``` erlang apps/csd_core/rebar.config (partial)
%% ... snip ...
-export([
    connect/1,
    create/3,
    create/4,
    fetch/3,
    update/2,
    get_value/1,
    save/2,
    get_index/3,
    set_index/4,
    set_indexes/2,
    index/2,
    new_key/0,
    search/4
  ]).

%% ... snip ...

%% @spec new_key() -> key()
%% @doc Generate an close-to-unique key that can be used to identify
%%      an object in riak. We now make use of Flake to do this for us.
new_key() ->
  %% Base-62 key gives us keys with 0-9, a-z and A-Z
  {ok, Key} = flake_server:id(62),
  list_to_binary(Key).
```

Note how we're still returning the value as a `binary`. This is because the rest of the source expects a binary to come out of this function call. Doing so means we don't need to adjust any calling code at all.

With that in place, we can now use our application. Run `make` so that the dependencies are pulled and the application is built, fire up the proxy (`make proxystart`) in another console fire up the application (`make webstart`) create a new snippet and ... voilà!

{% img /uploads/2013/06/new-id.png 'Newly generated ID from Flake' %}

There, much better.

## <a id="json-rejig"></a>Rejigging JSON handling

I made the changes to the JSON parsing at the same time as doing other things so the changes are intermingled a little. As a result I'm going to show where the JSON handling was updated as we go through the other sections. However, it's worth noting that we do need to include [Jiffy][] as a dependency from here, so let's include that in our `rebar` config:

``` erlang apps/csd_core/rebar.config (partial)
%% ... snip ...
{jiffy, ".*", {git, "git://github.com/OJ/jiffy", "HEAD"}},
%% ... snip ...
```

Now let's dive into the meat of the changes.

## <a id="vote-count-rejig"></a>Rejigging Vote Count Map/Reduce

### JavaScript Map/Reduce isn't ideal

Those of you who are experienced with Riak will already know this, but JavaScript is not a good choice for map/reduce functionality in Riak for queries that get executed often. For ad-hoc jobs they can be a real bonus, but they do come with some caveats:

* Each Javascript M/R job has to be executed in an instance of the embedded Javascript VMs.
* The number of VMs loaded into Riak is finite (though configurable).
* If the number of concurrent Javascript M/R jobs exceeds the number of VMs then the job has to wait for one to become free. Waiting is bad.
* Javascript jobs are slower than Erlang jobs.

There are other issues too, which don't directly relate to what we're doing. These are enough for now.

{% pullquote %}
We'll be aggregating vote counts quite often, so we don't really want to have these queries running in Javascript. So, instead, we're going to port them over to Erlang. {" Erlang will allow us to run many more instances of the job concurrently "} (thanks to the epicly cheap cost of an Erlang process). It will also run the job faster than the JS version.
{% endpullquote %}

### Erlang Map/Reduce is the way to go

In our Erlang version of the map/reduce job that aggregates vote counts, we're going to avoid the cost of deserialising the value from JSON into a form Erlang can understand by making sure that the details we need are stored in secondary indexes. This means we can reach into the object's metadata (something that's already present) and get access to the data we need.

The only thing that isn't already stored as a 2i key is the `which` value (ie. the value that indicates if the user voted _left_ or _right_). So we need to add that to `csd_vote_store`, like so:

``` erlang apps/csd_core/src/csd_vote_store.erl (partial)
%% ... snip ...
-define(WHICH_INDEX, <<"which">>).
%% ... snip ...

save(RiakPid, Vote) ->
  VoteId = csd_vote:get_id(Vote),
  UserId = csd_vote:get_user_id(Vote),
  SnippetId = csd_vote:get_snippet_id(Vote),
  Which = csd_vote:get_which(Vote),

  case csd_riak:fetch(RiakPid, ?BUCKET, VoteId) of
    {ok, _RiakObj} ->
      {error, "User has already voted on this snippet."};
    {error, notfound} ->
      RiakObj = csd_riak:create(?BUCKET, VoteId, csd_vote:to_json(Vote)),
      Indexes = [
        {bin, ?SNIPPET_INDEX, SnippetId},
        {int, ?USER_INDEX, UserId},
        {bin, ?WHICH_INDEX, Which}
      ],

      NewRiakObj = csd_riak:set_indexes(RiakObj, Indexes),
      ok = csd_riak:save(RiakPid, NewRiakObj),
      {ok, Vote}
  end.
```

OK, let's take a look at the code which runs the vote count aggregation, ported from Javascript to Erlang with a few tweaks:

``` erlang apps/csd_core/riak_modules/csd_riak_mapreduce.erl
-module(csd_riak_mapreduce).
-author('OJ Reeves <oj@buffered.io>').

-export([map_count_votes/3, reduce_count_votes/2]).

-define(WHICH_INDEX, <<"which_bin">>).
-define(USER_INDEX, <<"userid_int">>).

map_count_votes({error, notfound}, _KeyData, _Arg) ->
  [];
map_count_votes(RiakObject, _KeyData, CurrentUserId) ->
  Meta = riak_object:get_metadata(RiakObject),
  Indexes = dict:fetch(<<"index">>, Meta),

  Which = proplists:get_value(?WHICH_INDEX, Indexes),
  User = proplists:get_value(?USER_INDEX, Indexes),

  case {Which, User} of
    {undefined, _} -> [];
    {<<"left">>, CurrentUserId} -> [[1, 0, Which]];
    {<<"right">>, CurrentUserId} -> [[0, 1, Which]];
    {<<"left">>, _} -> [[1, 0, <<>>]];
    {<<"right">>, _} -> [[0, 1, <<>>]]
  end.

reduce_count_votes(Vals, _Arg) ->
  [lists:foldl(fun reduce_count/2, [0, 0, <<>>], Vals)].
  
reduce_count([L1, R1, <<>>], [L2, R2, W2]) ->
  [L1 + L2, R1 + R2, W2];
reduce_count([L1, R1, W1], [L2, R2, <<>>]) ->
  [L1 + L2, R1 + R2, W1].
```

The first things to note:

1. The module is not part of the application's source tree. This is because this module is going to be compiled and deployed to Riak, not with the rest of `csd`.
1. There is one map function and one reduce function export, these are the ones we'll be calling from our map/reduce job.

The `map_count_votes` function is where the meat of the code is for this aggregator. The first four lines of the function body consist of code that reaches into the Riak object's meta data and pulls out values for two indexes:

1. `Which` - this contains `<<"left">>` or `<<"right">>` depending on what the user voted for.
1. `User` - this contains the ID of the user who submitted the vote.

We can then match against those indexes to cover the cases that we're looking for. If the vote, for some reason, doesn't have a `which` 2i, then we just ignore the vote and return an "null" (ie. the empty list, which indicates that we're ignoring this value). If it does have the index, then we check the value of the index and attempt to match the current user's ID (passed in via the map/reduce call ... more to come on this a bit later). Matching against this ID tells us that the vote we're currently mapping over is the vote that the current user has cast.

This means we can not only infer counts, we can figure out which side of the snippet the currently logged in user voted for.

As before, the values that we return from our map function take the shape of `[left-vote-count, right-vote-count, which-side-user-voted]`. If we match against the user's ID, then we store the value of the `which` 2i in the third location, otherwise we leave it black (ie. `<<>>`). If the current vote object is a left vote the values we return are `1` and `0` for the first two elements, respectively).

When the map phase has finished we will have a stack of values that we can then add together, while carrying through the side which the current user voted for.

The reduce phase, defined in `reduce_count_votes`, simply adds up all of these values using a `fold`. Lefts (`L1` and `L2`) are added together and Rights (`R1` and `R2`) are added together to get the total votes for each side. The only bit of wizardry it does while performing the fold is making sure that we carry over any non-null value for the current user's vote. If the current user hasn't voted, or there is no current user (ie. they're not signed in), then the total will come out with an empty binary for the third value implying that the system doesn't know which side was voted for by that user.

When run our map/reduce query we will end up with a single output which takes the form:

``` erlang
[[TotalVotesLeft, TotalVotesRight, WhichSideCurrentUserVotedForOrEmptyBinary]]
```

With our module defined, we now need to deploy this to Riak. If you haven't already done so, you'll need to add module paths to your riak node's configuration. In my development cluster, I configured all the nodes to look at `/tmp/riak` for modules. To do this, you have to open up the `app.config` for each of your nodes and add a new line to the configuration section called `riak_kv`, like so:

``` erlang dev1/etc/app.config
%% ... snip ...
%% Riak KV config
{riak_kv, [
          %% Tell riak to look at /tmp/riak for custom modules
          {add_paths, ["/tmp/riak"]},

          %% Storage_backend specifies the Erlang module defining the storage
          %% mechanism that will be used on this node.
          {storage_backend, riak_kv_eleveldb_backend},
%% ... snip ...
```

The `add_paths` setting is what works the magic here. Make sure you restart all of your nodes when this has been done so that they know where to look:

``` bash
$ dev1/bin/riak stop && dev1/bin/riak start
.
.
$ dev4/bin/riak stop && dev4/bin/riak start
```

Next, we need to compile our module and deploy it. To make this easier I hacked something into my Makefile so that I didn't have to think about it again. When redeploying modules to Riak you also have to tell the nodes to reload the modules, so I included that in the script too. It looks like this:

``` bash Makefile
# ... snip ...

RIAK_MOD_DIR=/tmp/riak

# ... snip ...

modules:
	@cd apps/csd_core/riak_modules \
		&& erlc *.erl \
		&& mkdir -p ${RIAK_MOD_DIR} \
		&& cp ./*.beam ${RIAK_MOD_DIR}

depmod:
	@~/code/riak/dev/dev1/bin/riak-admin erl-reload \
		&& ~/code/riak/dev/dev2/bin/riak-admin erl-reload \
		&& ~/code/riak/dev/dev3/bin/riak-admin erl-reload \
		&& ~/code/riak/dev/dev4/bin/riak-admin erl-reload

# ... snip ...
```

You'll obviously have to adjust this to include your own paths to your running Riak nodes. With this in place I can execute `make modules` to have all modules in the `riak_modules` folder recompiled and copied over to the target folder. I can then `make depmod` which tells each node in the cluster to reload any custom Erlang modules.

Now that we have the custom module in place, we have to invoke this from our code. This means removing all the Javascript from `csd_vote_store` and replacing all the `*_js` function calls with `*_erl` equivalents. The problem here is that we don't yet have support for calling Erlang modules in our helper API. Let's add those now:

``` erlang apps/csd_core/src/csd_riak_mr.erl (partial)
%% ... snip ...
-export([
    %% ... snip ...
    add_map_erl/3,
    add_map_erl/4,
    add_map_erl/5,
    add_reduce_erl/3,
    add_reduce_erl/4,
    add_reduce_erl/5,
    %% ... snip ...
  ]).

%% ... snip ...

add_map_erl(MR=#mr{}, Mod, Fun) ->
  add_map_erl(MR, Mod, Fun, true).

add_map_erl(MR=#mr{}, Mod, Fun, Keep) ->
  add_map_erl(MR, Mod, Fun, Keep, none).

add_map_erl(MR=#mr{phases=P}, Mod, Fun, Keep, Arg) ->
  MR#mr{
    phases = [{map, {modfun, Mod, Fun}, Arg, Keep}|P]
  }.

%% ... snip ...

add_reduce_erl(MR=#mr{}, Mod, Fun) ->
  add_reduce_erl(MR, Mod, Fun, true).

add_reduce_erl(MR=#mr{}, Mod, Fun, Keep) ->
  add_reduce_erl(MR, Mod, Fun, Keep, none).

add_reduce_erl(MR=#mr{phases=P}, Mod, Fun, Keep, Arg) ->
  MR#mr{
    phases = [{reduce, {modfun, Mod, Fun}, Arg, Keep}|P]
  }.

%% ... snip ...
```

These functions should hopefully be fairly self-explanatory. These just make it a little easier/nicer to add Erlang module/function pairs to the map and reduce phases. We can now call those from vote store code. Here's the essence of the changes (with all the JS removed):

``` erlang apps/csd_core/src/csd_vote_store.erl (partial)
%% ... snip ...

-define(MR_MOD, csd_riak_mapreduce).
-define(MR_MAP_COUNT, map_count_votes).
-define(MR_RED_COUNT, reduce_count_votes).

%% ... snip ...

count_for_snippet(RiakPid, SnippetId) ->
  case count_for_snippet(RiakPid, SnippetId, <<"">>) of
    {ok, {Left, Right, _}} -> {ok, {Left, Right}};
    Error -> Error
  end.

count_for_snippet(RiakPid, SnippetId, UserId) ->
  MR1 = csd_riak_mr:add_input_index(csd_riak_mr:create(), ?BUCKET, bin,
    ?SNIPPET_INDEX, SnippetId),
  MR2 = csd_riak_mr:add_map_erl(MR1, ?MR_MOD, ?MR_MAP_COUNT, false, UserId),
  MR3 = csd_riak_mr:add_reduce_erl(MR2, ?MR_MOD, ?MR_RED_COUNT),
  case csd_riak_mr:run(RiakPid, MR3) of
    {ok, []} -> {ok, {0, 0, <<"">>}};
    {ok, [{1, [[Left, Right, Which]]}]} -> {ok, {Left, Right, Which}};
    Error -> Error
  end.

%% ... snip ...
```

First we just define a couple of helper macros to put the names of our modules and funtions in the one spot.

The two overloads for `count_for_snippet` are the same functions that were there before but with a few obvious changes. The second implementation, which takes the `UserId`, is where the magic happens. THe first implementation is just a wrapper over the second which ignores the `Which` value that comes out of the query.

Hopefully it's clear to see that we add an Erlang map phase which calls our custom map function, followed by an Erlang reduce phase which calls our custom reduce function. After executing our job, we match against the result and just extract the values that we expect to see using pattern matching and return something that looks a little friendlier to the caller.

Javascript has now been removed from our vote counting and the application should function just as it did before, only a bit quicker, plus we know that it will be able to deal with a lot more concurrent requests than before. Also: Unicorns.

## <a id="snippet-search"></a>Removing Snippet List Map/Reduce

The last thing we're going to fix up is the listing of snippets on a user's profile page. Initially we did this via another Javascript Map/Reduce job. This job also had the job of sorting results. Instead of doing all that heavy lifting, we're going to avoid doing Map/Reduce altogether. Instead we're going to make use of [Riak Search][] to do the querying while making use of the fact that `Flake` is now generating our keys to help us sort them chronologically.

### Enabling Riak Search

Sorry, but we're going to have to open up the `app.config` files for our Riak nodes again and make sure that the search function is enabled like so:

``` erlang dev1/etc/app.config (partial)
%% ... snip ...

%% Riak Search Config
{riak_search, [
              %% To enable Search functionality set this 'true'.
              {enabled, true}
             ]},

%% ... snip ...
```

Restart your nodes again so that this setting is picked up. With search enabled we are now able to tell Riak that we want to index a bucket for search. We need to set this up on each bucket we want search to work with otherwise none of the value in the JSON will be indexed. Given that we're interested in indexing the `snippet` bucket, this is how we enable search on our cluster:

``` bash
$ dev1/bin/search-cmd install snippet
$ dev2/bin/search-cmd install snippet
$ dev3/bin/search-cmd install snippet
$ dev4/bin/search-cmd install snippet
```

**Note:** I'm not sure if I need to enable this on every node or just on one node in the cluster, I need to confirm this behaviour with Basho.

From here, every value that is written to the `snippet` bucket will be indexed for searching.

  [series]: /series/web-development-with-erlang/ "Web Development with Erlang"
  [Part 1]: /posts/webmachine-erlydtl-and-riak-part-1/ "Webmachine, ErlyDTL and Riak - Part 1"
  [Part 2]: /posts/webmachine-erlydtl-and-riak-part-2/ "Webmachine, ErlyDTL and Riak - Part 2"
  [Part 3]: /posts/webmachine-erlydtl-and-riak-part-3/ "Webmachine, ErlyDTL and Riak - Part 3"
  [Part 4]: /posts/webmachine-erlydtl-and-riak-part-4/ "Webmachine, ErlyDTL and Riak - Part 4"
  [Part 5]: /posts/webmachine-erlydtl-and-riak-part-5/ "Webmachine, ErlyDTL and Riak - Part 5"
  [Flake]: https://github.com/boundary/flake "Flake"
  [mochijson2]: https://github.com/mochi/mochiweb/blob/master/src/mochijson2.erl
  [Jiffy]: https://github.com/davisp/jiffy
  [NIFs]: http://www.erlang.org/doc/tutorial/nif.html
  [Riak Search]: http://docs.basho.com/riak/latest/tutorials/querying/Riak-Search/
  [flakenetwork]: https://github.com/boundary/flake/network
  [flakedocs]: https://github.com/boundary/flake#flake-a-decentralized-k-ordered-id-generation-service-in-erlang "Flake docs"
  [flakerebarbranch]: https://github.com/timadorus/flake/tree/rebar_dep "Flake as a rebar dep"
  [Boundary]: http://boundary.com/ "Boundary"

