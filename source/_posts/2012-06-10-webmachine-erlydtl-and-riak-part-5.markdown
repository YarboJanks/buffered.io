---
date: 2012-06-10 21:30
categories: [Riak, Functional Programming, HOWTO, Erlang, Webmachine, ErlyDTL, BackboneJS, Bootstrp]
tags: [Riak, Functional Programming, HOWTO, Erlang, Webmachine, ErlyDTL, BackboneJS, Bootstrap]
comments: true
layout: post
title: "Webmachine, ErlyDTL and Riak - Part 5"
series: "Web Development with Erlang"
---

{% img right /uploads/2010/09/riak-logo.png 'Riak Logo' %}Newcomers to the series should first take a look at the previous four parts of the [series][] ([Part 1][], [Part 2][], [Part 3][], [Part 4][]) first to make sure that you're up to speed. Feel free to read on if you feel comfortable with the general concepts in use.

When we finished [Part 4][] we were able to authenticate users using [Twitter][] and [OAuth][], which is great as we can delegate the responsibility of password management to an external entity.

Now that we know who people are, we want them to be able to do something meanigful with their accounts. That's what this post is all about.

<!--more-->

## <a id="agenda"></a>Agenda

So far it has been hard to see what the goal of this application is. Given the piecemeal nature of the posts it's hard to project that vision, especially when the content is quite code-heavy. By the end of this post, we'll not only have a "proper" web application that performs useful functions, we'll be able to see what this "Code Smackdown" thing really is all about.

This post is going to cover the following topics:

1. _[Riak][] Secondary Indexes_ - We'll be using these so that we can link code snippet submissions to the users who submitted them.
1. _[Map/Reduce][MapRed]_ - We're going to end up with data stored in our database and we're going to want to query it. Map/reduce is where it's at!
1. _Form submission handling with [Webmachine][]_ - Users will be able to submit code snippet pairs to the system once they're logged in. They'll also be able to vote on submitted snippets.
1. _Listing of submissions per-user_ - Viewing the submissions for a given user will pull out a list from Riak using the secondary indexes and map/reduce. This will allow a user to see what snippets they've submitted.
1. _Static file serving_ - Our new UI will require the serving of static content. There are quite a few ways to do this, one of which is using a custom Webmachine resource. We won't be doing that, instead we'll use [Nginx][] which does a much better job.
1. _Tidying up of templates/UI_ - Now that we've got some content to render, we'll put together some nicer templates and harness [Twitter Bootstrap][] to make the site a little nicer to look at. You'll notice that the emphasis will drop off from [ErlyDTL][] as we'll be doing more rendering of content on the client side using [Handlebars][] while using [Backbone.js][] for logic, routing and event handling.

Lots of UI work has been done for this post, but most of that work will not be discussed in detail as there's already enough content to get through. As always the source code is available so you can read it and play with it. You'll find the link at the end of the post.

Prior to continuing you should make sure you have the latest version of [Riak][] installed. If you don't, please go and do this now (read [Part 1][] to learn how to build Riak from scratch).

With that ... don your robe and Wizard's hat and let's begin.

## <a id="enabling-secondary-indexes"></a>Enabling Secondary Indexes

As already mentioned we're going to be storing data in Riak and using the [Secondary Index][] feature to make it easier to link data together and do certain types of queries over that data. Given this requirement the first thing we should do is enable secondary indexes on our cluster.

As per the [Riak wiki entry][Secondary Index] ...

> As of version 1.0, Secondary Indexes are enabled by configuring Riak to use the
> ELevelDB backend `riak_kv_eleveldb_backend`. Currently, the ELevelDB backend is the
> only index-capable backend.

So we need to go through our Riak development cluster configuration and make sure that our backend is set up correctly. Before continuing, make sure your cluster is no longer running:

{% codeblock lang:bash %}
riak/dev $ dev1/bin/riak stop
ok
riak/dev $ dev2/bin/riak stop
ok
riak/dev $ dev3/bin/riak stop
ok
{% endcodeblock %}

To modify all the `app.config` files easily we can run one simple command:

-> TODO: add the two wildcards to the path below
{% codeblock lang:bash %}
riak/dev $ vim ./-wildcardsgohere-/app.config
{% endcodeblock %}

This will open [VIM][] with all of the `app.config` files open so that we can easily made the necessary modifications. In each of these files, find the `riak_kv` configuration section and change the backend like so:

{% codeblock apps/csd_core/rebar.config (partial) lang:erlang %}
... snip ...

%% Riak KV config
{riak_kv, [
          %% Storage_backend specifies the Erlang module defining the storage
          %% mechanism that will be used on this node.
          {storage_backend, riak_kv_eleveldb_backend},
          ... snip ...
]}
... snip ...
{% endcodeblock %}

Done. Don't forget to make sure your dev cluster is running again before you continue:

{% codeblock lang:bash %}
riak/dev $ dev1/bin/riak start
riak/dev $ dev2/bin/riak start
riak/dev $ dev3/bin/riak start
{% endcodeblock %}

## <a id="schema-design"></a>Schema Design

Before we get going with any more of the implementation, we need to consider the design of the "schema" we're going to use when storing our data in Riak. We want our users to be able to:

1. Submit snippets the system.
1. See a list of snippets they have submitted to the system (and down the track see other lists using filters).
1. Vote for the left- or right- hand snippets to indicate which they prefer.
1. See that they have voted for a snippet before and be reminded of which one they voted for.

At the centre of this data there is the _snippet_. The snippet has the following fields:

* `title`: A simple descriptive label.
* `left`: One way of performing a function in a given language.
* `right`: Another way of performing the same function in a given language (which may not be the same as the language used for `left`).
* `created`: A date/time when the snippet was created/submitted.
* `key`: A key/ID which identifies the snippet.

These fields will be stored as a blob of JSON.

We also need to store with the snippet an identifier for the user that submitted it. Rather than storing this with the payload, we are instead going to create a secondary index which contains this information. We can then use this index to query the store to find out the snippets a user has submitted. This index will be called `userid`.

In future posts we will probably include more indexes and/or fields, but for the functionality we're aiming to build for this post these fields are sufficient.

Next we need to store votes. In a typical RDMBS this problem is well-known and the solutions out there are also well-known. In a KV store this isn't necessarily the case. What I propose in this post is _a possible way_ of solving this problem. I do not in any way claim that this is _the best way_. With this, this is what we're going to do...

A `vote` needs to keep track of who submitted it along with the snippet it was put against. It also needs to have an indication of whether the user preferred the left or right hand side of the snippet. When these votes are stored, we also want to be able to query the in such a way so that, for a given snippet, we can quickly count the number of votes and which way those votes went. This is quite important as the tallying of the votes and displaying them on screen is a key part of the idea behind the application.

To identify a vote the key needs to be made up of both the `userid` of the person who submitted it and the `key` of the snippet the vote. Therefore, for the `vote` bucket we'll create keys in the format: *userid-snippetkey*

While this makes sense, it doesn't make it easy for us to figure out which votes went against which snippets. To do this, we'll create a secondary index on the vote which contains the snippet key. This will give us a faster way of finding votes that relate to a key while still keeping the votes separate in the bucket. We can then do a map/reduce over the index and pull out the votes.

Originally I had pondered the idea of having another secondary index which contained the vote direction (`left` or `right`) and doing multiple map/reduces over the data to count the items. This seemed silly to me. I didn't think it made sense to invoke two map/reduce jobs when I could do the same thing with one. As a result, I decided to put the direction of the vote inside the vote payload itself as this can be used during a single map/reduce job to total both `left` and `right` votes. Down the track the user is going to want to be able to look at what they've voted on (as part of a history timeline), so we'll also add a `userid` index.

Finally, we are going to need to store some more meaningful information about a user for future use, so we'll create a `user` bucket and store some metadata for each user with their Twitter ID as the key.

Here's a visual of what we should end up with:

{% img /uploads/2012/06/part5-db-schema.png 'CSD Schema' %}

Now that we have the basics of the schema out of the way, the first thing we should do is adjust our Riak module to include the new features we'll need to do with secondary indexing and map/reduce.

## <a id="handling-2i"></a>Handling 2i in csd\_riak

In Riak secondary indexes (2i) are stored as extra metadata alongside the Riak object. Two types of indexes are currently support: `integer` and `binary`. These index types are indicated using a naming convention, such that `integer` indexes are suffixed with `_int` and `binary` indexes are suffixed with `_bin`. Secondary indexes are stored as a key/value pair tuple inside the `index` section of the meta data.

So to start with let's define a few index-specific macros and helper functions.

{% codeblock apps/csd_core/src/csd_riak.erl (partial) lang:erlang %}
% ... snip ...

-define(INDEX_KEY, <<"index">>).
-define(INDEX_SUFFIX_INT, <<"_int">>).
-define(INDEX_SUFFIX_BIN, <<"_bin">>).

% ... snip ...

index(int, Name) ->
  iolist_to_binary([Name, ?INDEX_SUFFIX_INT]);
index(bin, Name) ->
  iolist_to_binary([Name, ?INDEX_SUFFIX_BIN]).

% ... snip ...
{% endcodeblock %}

Here the `index` function is a simple function which allows us to generate an index name based on a type and a name. This can be called like so: `IndexName = index(int, "userid").` - We'll make use of this in other areas, including the `csd_riak_mr` module which we'll cover off shortly.

Next we'll define some functions which make it easier to add indexes to Riak objects.

{% codeblock apps/csd_core/src/csd_riak.erl (partial) lang:erlang %}
% ... snip ...

set_index(RiakObj, Type, Name, Value) ->
  Meta = riakc_obj:get_update_metadata(RiakObj),
  Index = case dict:find(?INDEX_KEY, Meta) of
    error -> [];
    {ok, I} -> I
  end,
  NewIndex = dict:to_list(dict:store(index(Type, Name), value(Value), dict:from_list(Index))),
  riakc_obj:update_metadata(RiakObj, dict:store(?INDEX_KEY, NewIndex, Meta)).

set_indexes(RiakObj, Indexes) ->
  Meta = riakc_obj:get_update_metadata(RiakObj),
  Index = case dict:find(?INDEX_KEY, Meta) of
    error -> [];
    {ok, I} -> I
  end,
  UpdatedIndexes = lists:foldl(fun({T, N, V}, I) ->
        dict:store(index(T, N), value(V), I)
    end,
    dict:from_list(Index), Indexes),
  NewIndex = dict:to_list(UpdatedIndexes),
  riakc_obj:update_metadata(RiakObj, dict:store(?INDEX_KEY, NewIndex, Meta)).

get_index(RiakObj, Type, Name) ->
  Meta = riakc_obj:get_metadata(RiakObj),
  Indexes = dict:fetch(?INDEX_KEY, Meta),
  IndexKey = binary_to_list(index(Type, Name)),
  Value = proplists:get_value(IndexKey, Indexes),
  case Type of
    int -> list_to_integer(Value);
    bin -> Value
  end.

% ... snip ...
{% endcodeblock %}

The first function, `set_index`, is used to update a Riak object instance and include a single new index of a certain type. This function gets existing _update metadata_ (different to "normal" metatdata in that this is what will be used to update the object when saved) and then attemps to retrieve the `index` section of that data. If found adds the new index value to the list of indexes. If it's not found then the new indexes is simply inserted into an empty list. This information is then written into a new Riak object via the `riakc:update_metadata/2` function.

This code can be called like so: `NewObj = csd_riak:set_index(RiakObj, int, "userid", 12345).`

This code converts between lists and dictionaries because I want existing index values to be overwritten with the new values.

The second function, `set_indexes`, is an extended version of `set_index` in that it allows you to set more than one key at a time. Instead of a single type/name/value combination it accepts a list of tuples of `{type, name, value}`.

The third function, `get_index`, is a helper function which is designed to get the value of certain index. Note how this function accesses _existing_ metadata via `get_metadata/1` rather than `get_update_metadata/1`. This is due to us being interested in an existing index, not in one that is about to be updated when we next save. Note that we have to convert the index key from `binary` to a `string` because the proplist keys for the index values are all strings. While we're here, we do a converstion of the value to an integer if the index type is an integer.

This code can be called like so: `UserId = csd_riak:get_index(RiakObj, int, "userid").`

Last of all you may have noticed that a couple of these functions are calling another function called `value/1`. It looks like this:

{% codeblock apps/csd_core/src/csd_riak.erl (partial) lang:erlang %}
% ... snip ...

%% ------------------------------------------------------------------
%% Private Function Definitions
%% ------------------------------------------------------------------

value(V) when is_list(V) ->
  list_to_binary(V);
value(V) ->
  V.
{% endcodeblock %}

As you can see this is an internal function which is there to help make sure that values are in the right format when being stored as an index.

With the 2i interface now taken care of, let's take a look at what we need to do for map/reduce.

## <a id="supporting-mapreduce"></a>Supporting Map/Reduce in csd\_riak

As you're already aware, Riak's map/reduce interface requires a set of _inputs_, one or more _map_ phases and zero or more _reduce_ phases. We could manually construct each of these components each time we want to execute a map/reduce job but that doesn't quite feel right to me. Instead, I prefer to have a "usable" module that helps construct properly-formed map/reduce jobs to reduce the risk of the caller doing the wrong thing. Callers of our modules shouldn't have to know about the format of Riak's map/reduce interface in order to use it. So we'll provide a helper module which wraps this up.

Before we look at the code, bear in mind that this module supports enough functionality to provide what is needed for the application so far. Down the track extra features will be added to support other ways of doing map/reduce, but for now they are beyond the scope of this version of the application.

With that, let's take a look at the code.

{% codeblock apps/csd_core/src/csd_riak_mr.erl lang:erlang %}
-module(csd_riak_mr).
-author('OJ Reeves <oj@buffered.io>').

%% ------------------------------------------------------------------
%% API Function Exports
%% ------------------------------------------------------------------

-export([
    create/0,
    run/2,
    add_input_index/5,
    add_map_js/2,
    add_map_js/3,
    add_map_js/4,
    add_reduce_js/2,
    add_reduce_js/3,
    add_reduce_js/4,
    add_reduce_sort_js/2,
    add_reduce_sort_js/3
  ]).

%% ------------------------------------------------------------------
%% Private Record Definitions
%% ------------------------------------------------------------------

-record(mr, {
    in_ind = undefined,
    %% TODO: when the need arises add support for other inputs
    %% including {bucket, key} and {bucket, key, arg}.
    phases = []
  }).

%% ------------------------------------------------------------------
%% API Function Definitions
%% ------------------------------------------------------------------

%% @doc Create a mew map/reduce job instance.
create() ->
  #mr{}.

run(RiakPid, #mr{in_ind=Input, phases=P}) ->
  % phases are pushed in reverse, so reverse them before using them
  Phases = lists:reverse(P),
  Result = riakc_pb_socket:mapred(RiakPid, Input, Phases),
  Result.

%% @doc Creates a map/reduce Input phase for a secondary index input.
add_input_index(MR=#mr{}, Bucket, Type, Index, Value) when is_integer(Value) ->
  add_input_index(MR, Bucket, Type, Index, integer_to_list(Value));
add_input_index(MR=#mr{}, Bucket, Type, Index, Value) when is_list(Value) ->
  add_input_index(MR, Bucket, Type, Index, list_to_binary(Value));
add_input_index(MR=#mr{}, Bucket, Type, Index, Value) when is_binary(Value) ->
  MR#mr{
    in_ind = {index, Bucket, csd_riak:index(Type, Index), Value}
  }.

%% @doc Creates a map/reduce Map phase from raw JS source. This overload
%%      defaults Keep to true and Arg to none.
add_map_js(MR=#mr{}, JsSource) ->
  add_map_js(MR, JsSource, true).

%% @doc Creates a map/reduce Map phase from raw JS source. This overload
%%      defaults Arg to none.
add_map_js(MR=#mr{}, JsSource, Keep) ->
  add_map_js(MR, JsSource, Keep, none).

%% @doc Creates a map/reduce Map phase from raw JS source.
add_map_js(MR=#mr{phases=P}, JsSource, Keep, Arg) ->
  MR#mr{
    phases = [{map, {jsanon, JsSource}, Arg, Keep}|P]
  }.

%% @doc Creates a map/reduce Reduce phase from raw JS source. This overload
%%      defaults Keep to true and Arg to none.
add_reduce_js(MR=#mr{}, JsSource) ->
  add_reduce_js(MR, JsSource, true).

%% @doc Creates a map/reduce Reduce phase from raw JS source. This overload
%%      defaults Keep to true.
add_reduce_js(MR=#mr{}, JsSource, Keep) ->
  add_reduce_js(MR, JsSource, Keep, none).

%% @doc Creates a map/reduce Reduce phase from raw JS source.
add_reduce_js(MR=#mr{phases=P}, JsSource, Keep, Arg) ->
  MR#mr{
    phases = [{reduce, {jsanon, JsSource}, Arg, Keep}|P]
  }.

%% @doc Creates a map/reduce Reduce sort phase using Riak's built in sort function
%%      using the specified comparison function written in raw JS. This overload
%%      defaults Keep to true.
add_reduce_sort_js(MR=#mr{}, CompareFun) ->
  add_reduce_sort_js(MR, CompareFun, true).

%% @doc Creates a map/reduce Reduce sort phase using Riak's built in sort function
%%      using the specified comparison function written in raw JS.
add_reduce_sort_js(MR=#mr{phases=P}, CompareFun, Keep) ->
  MR#mr{
    phases = [{reduce, {jsfun, <<"Riak.reduceSort">>}, CompareFun, Keep}|P]
  }.
{% endcodeblock %}

Most of this code is (hopefully) self-explanatory but to cover things in general:

* `#mr` is an internally defined record which will accumulate a set of inputs and phases to execute against riak. This is internal so that external callers are "forced" to use the module to construct a map/reduce job.
* The `create/0` function simply creates an instance of a `#mr` record that the user can start to add map/reduce details to.
* Each of the `add_*` functions is used to add an input or a phase to to a `#mr` record. For this version of the application we're use JavaScript for our map/reduce phases. Functions that deal with JavaScript tend to have `_js` as a suffix.
* The `add_reduce_sort_js/3` function is one example of where we're using an internal Riak javascript reduce function. This function sorts elements during the reduce phase and uses a user-defined JavaScript function passed in as an argument to the phase.
* The `run/2` function executes the map/reduce job in Riak and returns the result.

This module makes use of the `csd_riak:index/2` function which helps create well-formed index names. This is used when constructing index inputs.

That's map/reduce taken care of (for now). With the guts of boilerplate Riak interaction taken care of, let's have a look at our approach to data storage.

## <a id="goodby-csdcoreserver"></a>Goodbye `csd_core_server`

When I first started working on this application I created `csd_core_server` with the intent of using it as a bridge between the application and Riak. This module, implemented as a [gen_server][], would have been responsible for handling and managing a pool of connections to Riak.

This concern has changed given that we are now using [Pooler][] to solve this problem for us. As a result, the idea of having a `gen_server` doesn't really make sense. Instead it makes more sense to have a module which handles interacting with [Pooler][] so that other areas of the application don't need to know it's there.

`csd_core_server` has now been removed and replaced with another module called `csd_db`. This new module is not a `gen_server`, it is simple a plain module which exposes an interface to the database.

Abstraction purists might argue that this is a positive as it gives us the ability to swap our database out for something else and the consumers of `csd_db` wouldn't even know. This might be true, but that's not really the goal. The goal is to put all the [Pooler][] interaction in a single spot.

Rather than show the module here in its entirity, we'll break it up into chunks: snippets, users and votes. Each of these chunks will be looked at when we dive into storage of those individual bits of data. To give an idea of the purpose that it serves see the following diagram:

{% img /uploads/2012/06/part5-db-modules.png 'Database Module Interaction' %}

The modules on the left invoke functions on `csd_db` which then invokes functions on the respective store modules passing in an extra parameter which is a `RiakPid` so that the store modules can talk to Riak. Simple!

Since `csd_db` is just a helper that we'll be using across all modules, let's take a look at it first.

{% codeblock apps/csd_core/src/csd_db.erl (partial) lang:erlang %}
-module(csd_db).
-author('OJ Reeves <oj@buffered.io>').

%% --------------------------------------------------------------------------------------
%% API Function Exports
%% --------------------------------------------------------------------------------------

-export([get_snippet/1, save_snippet/1, list_snippets/1]).
-export([get_user/1, save_user/1]).
-export([get_vote/1, save_vote/1, vote_count_for_snippet/1, vote_count_for_snippet/2]).

%% --------------------------------------------------------------------------------------
%% Snippet API Function Definitions
%% --------------------------------------------------------------------------------------

save_snippet(Snippet) ->
   pooler:use_member(fun(RiakPid) -> csd_snippet_store:save(RiakPid, Snippet) end).

get_snippet(SnippetKey) ->
  pooler:use_member(fun(RiakPid) -> csd_snippet_store:fetch(RiakPid, SnippetKey) end).

list_snippets(UserId) ->
  pooler:use_member(fun(RiakPid) -> csd_snippet_store:list_for_user(RiakPid, UserId) end).

%% --------------------------------------------------------------------------------------
%% User API Function Definitions
%% --------------------------------------------------------------------------------------

get_user(UserId) ->
  pooler:use_member(fun(RiakPid) -> csd_user_store:fetch(RiakPid, UserId) end).

save_user(User) ->
  pooler:use_member(fun(RiakPid) -> csd_user_store:save(RiakPid, User) end).

%% --------------------------------------------------------------------------------------
%% Vote API Function Definitions
%% --------------------------------------------------------------------------------------

get_vote(VoteId) ->
  pooler:use_member(fun(RiakPid) -> csd_vote_store:fetch(RiakPid, VoteId) end).

save_vote(Vote) ->
  pooler:use_member(fun(RiakPid) -> csd_vote_store:save(RiakPid, Vote) end).

vote_count_for_snippet(SnippetId) ->
   pooler:use_member(fun(RiakPid) ->
        csd_vote_store:count_for_snippet(RiakPid, SnippetId)
    end).

vote_count_for_snippet(SnippetId, UserId) ->
  pooler:use_member(fun(RiakPid) ->
        csd_vote_store:count_for_snippet(RiakPid, SnippetId, UserId)
    end).

{% endcodeblock %}

The pattern we're applying should now be obvious. Each function just proxies the call to another module which takes all the source parameters plus a `pid` which can be used to talk to Riak.

With that out of the way, let's dive into what the individual modules do.

## <a id="storing-snippets"></a>Storing Snippets

Until now we've only ever stored snippets and we haven't really done anything complicated with them. The earlier versions of our `csd_snippet` module, the one which encapsulated the snippet functionaliy, contained methods which covered two concerns: construction/creation of the snippet and storing/retrieval of snippets. Rather than continuing to mix concerns, we're going to break this module up into two: `csd_snippet` and `csd_snippet_store`. The aim is for the former to act like an API to the snippet functionality. This is the one that will be invoked from our web application. The latter will be invoked by the former in the cases where data needs to be written to or read from the data store.

Hopefully now you can see where this fits into the diagram shown above. `csd_snippet` is paired with `csd_snippet_store` and `csd_db` is used as a bridge between the two which provides the connections to Riak.

### <a id="csd_snippet"></a>`csd_snippet` module

`csd_snippet` has changed drastically since we last looked at it, so let's go through the module bit by bit as it currently stands.

{% codeblock apps/csd_core/src/csd_snippet.erl (partial) lang:erlang %}
% ... snip ...

%% --------------------------------------------------------------------------------------
%% Internal Record Definitions
%% --------------------------------------------------------------------------------------

-record(snippet, {
    user_id,
    key,
    title,
    left,
    right,
    created
  }).

% ... snip ...
{% endcodeblock %}

The `snippet` record is an internal container for all the data we need when dealing with a single snippet. Some of this information is stored in Riak as part of the payload, other detail is stored as an index. More to come on this later.

{% codeblock apps/csd_core/src/csd_snippet.erl (partial) lang:erlang %}
% ... snip ...

%% --------------------------------------------------------------------------------------
%% API Function Definitions
%% --------------------------------------------------------------------------------------

to_snippet(Title, Left, Right, UserId) ->
  #snippet{
    user_id = UserId,
    key = csd_riak:new_key(),
    title = Title,
    left = Left,
    right = Right,
    created = csd_date:utc_now()
  }.

% ... snip ...
{% endcodeblock %}

`to_snippet/4` allows construction of snippets from basic information: `title`, `left`, `right` and `user_id`. Behind the scenes we determine the current date/time in UTC format (details of this function coming later) and store that alongside the snippet in the `created` field. We also generate a new (hopefully unique) key for the snippet at the same time.

{% codeblock apps/csd_core/src/csd_snippet.erl (partial) lang:erlang %}
% ... snip ...

fetch(SnippetKey) when is_list(SnippetKey) ->
  fetch(list_to_binary(SnippetKey));
fetch(SnippetKey) when is_binary(SnippetKey) ->
  csd_db:get_snippet(SnippetKey).

save(Snippet=#snippet{}) ->
  csd_db:save_snippet(Snippet).

list_for_user(UserId) ->
  csd_db:list_snippets(UserId).

% ... snip ...
{% endcodeblock %}

These three functions are the "main" functions, so to speak. That is, the main opertions that are done with snippets are fetching, saving and listing. Each one of them simply passes the call on to `csd_db` to invoke functions on `csd_snippet_store` with a Riak connection. Details of what those functions do are coming shortly.

{% codeblock apps/csd_core/src/csd_snippet.erl (partial) lang:erlang %}
% ... snip ...

set_user_id(Snippet=#snippet{}, UserId) ->
  Snippet#snippet{
    user_id = UserId
  }.

get_user_id(#snippet{user_id=UserId}) ->
  UserId.

get_key(#snippet{key=Key}) ->
  Key.

set_key(Snippet=#snippet{}, NewKey) ->
  Snippet#snippet{
    key = NewKey
  }.

% ... snip ...
{% endcodeblock %}

The functions listed above are basic get and set operations for certain pieces of information that live within the snippet. When storing snippets, we need to be able to set a secondary index value for `user_id` and given that the structure of the snippet is hidden to all outside of the `csd_snippet` module this function is required to expose the user's id.

At this point it might not be as obvious as to why we need to provide the ability to set a key on the snippet, but this will come clear later on when we look at [snippet submission](#snippet-submission).

{% codeblock apps/csd_core/src/csd_snippet.erl (partial) lang:erlang %}
% ... snip ...

to_json(#snippet{key=K, title=T, left=L, right=R, created=C}) ->
  Data = [{key, K}, {title, T}, {left, L}, {right, R}, {created, C}],
  csd_json:to_json(Data, fun is_string/1).

from_json(SnippetJson) ->
  Data = csd_json:from_json(SnippetJson, fun is_string/1),
  #snippet{
    key = proplists:get_value(key, Data),
    title = proplists:get_value(title, Data),
    left = proplists:get_value(left, Data),
    right = proplists:get_value(right, Data),
    created = proplists:get_value(created, Data)
  }.

% ... snip ...
{% endcodeblock %}

The above functions are obviously used to convert snippets to and from JSON. These are used when passing snippets to the browser or for storing them in the database.

{% codeblock apps/csd_core/src/csd_snippet.erl (partial) lang:erlang %}
% ... snip ...

%% --------------------------------------------------------------------------------------
%% Private Function Definitions
%% --------------------------------------------------------------------------------------

is_string(title) -> true;
is_string(left) -> true;
is_string(right) -> true;
is_string(created) -> true;
is_string(_) -> false.

{% endcodeblock %}

This last function exists as a helper function during conversion between Erlang proplists and JSON format and is used to highlight those values which are intended to be strings.

That covers off the interface to the snippet "schema", but it doesn't show how an individual snippet ends up in the database. Let's take a look at the code in the storage module `csd_snippet_store`.

### <a id="csd_snippet_store"></a>`csd_snippet_store` module

To start with, let's look at the module header including some handy defines which we'll need to dive into a little bit.

{% codeblock apps/csd_core/src/csd_snippet_store.erl (partial) lang:erlang %}
-module(csd_snippet_store).
-author('OJ Reeves <oj@buffered.io>').

-define(BUCKET, <<"snippet">>).
-define(USERID_INDEX, "userid").
-define(LIST_MAP_JS, <<"function(v){var d = Riak.mapValuesJson(v)[0]; return [{key:d.key,title:d.title,created:d.created}];}">>).
-define(REDUCE_SORT_JS, <<"function(a,b){return a.created<b.created?1:(a.created>b.created?-1:0);}">>).

% ... snip ...
{% endcodeblock %}

The first two defines are obvious. The next two are much more interesting. Here we can see some JavaScript code that we're going to be using during map/reduce phases when searching for snippets. Given that the code above isn't that nice to read, let's expand it out to see what it's doing:

{% codeblock LIST_MAP_JS lang:javascript %}
function(v)
{
  var d = Riak.mapValuesJson(v)[0];
  return [{ key: d.key, title: d.title, created: d.created }];
}
{% endcodeblock %}

Map functions in Riak take up to 3 values:

1. The value being mapped over. If the map phase is the first of the phases then this value will be the full object pulled from Riak.
1. The key data associated with the value. This is the (optional) value that is passed in alongside the key in the input phase.
1. A value passed into the map phase which remains consistent for each value that is mapped over.

In our case, we're only interested in the first argument, the value that is coming out of Riak. We're also only interested in the contents of the value itself. We use the built-in function `Riak.mapValuesJson` to pull out the value as JSON. From that value we're only interested in the `key`, the `title` and the `created` properties. The map function much produce a list of values, so we return this new JSON object wrapped in a list.

It's not yet obvious, though it will be, but this is the function that will be used when we list all of the snippets that a single user has submitted. Next up is the reduce phase:

{% codeblock REDUCE_SORT_JS lang:javascript %}
function(a, b)
{
  return a.created < b.created ? 1 : (a.created > b.created ? -1 : 0);
}
{% endcodeblock %}

Those of you familiar with Riak will have noticed that this function doesn't look like a typical reduce function. In Riak the reduce phase functions have the same signature as map functions. The function shown above does not fit this description.

In our reduce phase for listing a user's snippets, we're only interested in sorting the snippets by the date in which they were submitted (most recent first). The function above takes two snippets and returns the result of the comparison based on the date. This function is used in conjunction with another built-in function, `Riak.reduceSort`. We pass in our sort comparison to the reduce phase as the argument to the phase and the built-in will execute it for each required comparison to make the resulting list of values ordered correctly.

With that out of the way, let's take a look at the first of the Erlang functions which fetches a single snippet based on its key.

{% codeblock apps/csd_core/src/csd_snippet_store.erl (partial) lang:erlang %}
% ... snip ...

%% --------------------------------------------------------------------------------------
%% API Function Exports
%% --------------------------------------------------------------------------------------

-export([save/2, fetch/2, list_for_user/2]).

%% --------------------------------------------------------------------------------------
%% API Function Definitions
%% --------------------------------------------------------------------------------------

fetch(RiakPid, Key) ->
  case csd_riak:fetch(RiakPid, ?BUCKET, Key) of
    {ok, RiakObj} ->
      SnippetJson = csd_riak:get_value(RiakObj),
      Snippet = csd_snippet:from_json(SnippetJson),
      UserId = csd_riak:get_index(RiakObj, int, ?USERID_INDEX),
      {ok, csd_snippet:set_user_id(Snippet, UserId)};
    {error, Reason} ->
      {error, Reason}
  end.

% ... snip ...
{% endcodeblock %}

The first thing you'll notice is that the first parameter to the function is the `RiakPid` which we will use to talk to Riak. The second parameter is the `Key` (identifier) of the snippet. The function calls `csd_riak:fetch` which attempts to pull a Riak object out of Riak using the key as the id for the object to read.

If that succeeds then a valid Riak object is returned. This contains all the detail of the object as it is stored in Riak including meta data. At this point we're only interested in two things:

1. The value stored in the object (which should be the snippet data in JSON format).
1. The value of the `user_id` index which identifies the person who created the snippet.

These two values are pulled from the Riak object and are used to construct a valid snippet instance which is then returned to the caller.

We're also interested in listing snippets for a given user, so let's take a look at the code for that:

{% codeblock apps/csd_core/src/csd_snippet_store.erl (partial) lang:erlang %}
% ... snip ...

list_for_user(RiakPid, UserId) ->
  MR1 = csd_riak_mr:add_input_index(csd_riak_mr:create(), ?BUCKET, int,
    ?USERID_INDEX, UserId),
  MR2 = csd_riak_mr:add_map_js(MR1, ?LIST_MAP_JS, false),
  MR3 = csd_riak_mr:add_reduce_sort_js(MR2, ?REDUCE_SORT_JS),

  Result = case csd_riak_mr:run(RiakPid, MR3) of
    {ok, [{1, List}]} -> List;
    {ok, []} -> []
  end,
  {ok, Result}.

% ... snip ...
{% endcodeblock %}

Here's where we are first using our new map/reduce module to help construct a valid map/reduce job which pulls out the list of snippets. The first line of the function is specifying that we're interested in all values in `?BUCKET` (the snippet bucket) which have an `int` index called `?USERID_INDEX` (the index of the submitting user's id) that is the same as the specified `UserId` passed into the function. We then take this job and add a JavaScript map phase where we pass in the `?LIST_MAP_JS` (details of which we have just seen above). Notice that we pass in `false` as the last parameter as we're not interested in returning the results of this phase from the query, we just want those values passed to the next phase.

The last of the phases is a JavaScript reduce phase that uses Riak's sorting functionality. We pass in `?REDUCE_SORT_JS` which causes the sort to happen in reverse chronological order.

With our map/reduce constructed, we execute this in Riak and check the result. The first thing to note is that we're currently not checking for errors. Right now we want the process to crash should an error occur. Later in the series we'll be looking a bit more at error handling, but for the purpose of this post it's out of scope.

The two patterns we do check for cover the two cases that may arise in normal use. When the map/reduce job runs and succeeds, the result will be in the format: `{ok, [{<phase number>, <results>}]}`. Phase numbers are zero-based. The list that is returned will only contain the results that we asked Riak to keep.

Given these conditions we can see that if the map/reduce job runs and extracts results, we can expect to see a list with one element in it which is the result of the reduce phase. Matching this to `{ok, [{1, List}]}` gives us direct access to the results in the `List` value.

If, however, there isn't any data in Riak that matches the query Riak will return no results for the phase. Hence we also need to match against this case, `{ok, []}`, and return an empty list which implies that there aren't any entries.

Now that listing snippets for the user is done, let's look at the save functionality.

{% codeblock apps/csd_core/src/csd_snippet_store.erl (partial) lang:erlang %}
% ... snip ...

save(RiakPid, Snippet) ->
  Key = csd_snippet:get_key(Snippet),
  case csd_riak:fetch(RiakPid, ?BUCKET, Key) of
    {ok, RiakObj} ->
      NewRiakObj = csd_riak:update(RiakObj, csd_snippet:to_json(Snippet)),
      persist(RiakPid, NewRiakObj, Snippet);
    {error, notfound} ->
      RiakObj = csd_riak:create(?BUCKET, Key, csd_snippet:to_json(Snippet)),
      persist(RiakPid, RiakObj, Snippet)
  end.

%% --------------------------------------------------------------------------------------
%% Private Function Definitions
%% --------------------------------------------------------------------------------------

persist(RiakPid, RiakObj, Snippet) ->
  UserId = csd_snippet:get_user_id(Snippet),
  UpdatedRiakObj = csd_riak:set_index(RiakObj, int, ?USERID_INDEX, UserId),
  ok = csd_riak:save(RiakPid, UpdatedRiakObj),
  {ok, Snippet}.

{% endcodeblock %}

Let's start by looking at the `persist` function as this is invoked in two spots inside the `save` function. As you can see when the snippet is persisted we take the id of the user who submitted it and add a new index to the Riak object which contains this value. We then push the object into the store. Easy peasy!

The `save` function is also quite self-explanatory. It first attempts to fetch an existing object from Riak using the snippet's key as the identifier. If the value exists, this value is updated with the new snippet information. If it doesn't exist, a new Riak object is created. Both of these code paths call the `persist` function to finish the job of storing the snippet.

We're done! That's the full story of snippet storage. Let's launch the application and play with storing snippets.

{% codeblock snippet storage in action lang:erlang %}
$ make webstart
... snip ...

1> S = csd_snippet:to_snippet("The Basics", "var x = 1;", "int x = 1;", 12345).
{snippet,12345,<<"AIUWiw==">>,"The Basics","var x = 1;",
         "int x = 1;",<<"2012-06-05T21:28:20.314Z">>}
2> csd_snippet:save(S).
{ok,{snippet,12345,<<"AIUWiw==">>,"The Basics","var x = 1;",
             "int x = 1;",<<"2012-06-05T21:28:20.314Z">>}}
3> csd_snippet:fetch("AIUWiw==").
{ok,{snippet,12345,<<"AIUWiw==">>,"The Basics","var x = 1;",
             "int x = 1;","2012-06-05T21:28:20.314Z"}}
{% endcodeblock %}

One thing you'll notice here is that we've added a snippet for a user with an Id of `12345`. This user _does not exist_ in Riak. In Riak you can add an index for a particular value but there is no way of adding the equivalent of a foreign key in the RDBMS world.

While we're here, let's see what Riak gives is when we talk directly to it via curl:

{% codeblock snippet storage in action lang:bash %}
$ curl -i http://127.0.0.1:8091/riak/snippet/AIUWiw==
HTTP/1.1 200 OK
X-Riak-Vclock: a85hYGBgzGDKBVIcMRuuc/nPTpqdwZTImMfK8Our00m+LAA=
x-riak-index-userid_int: 12345
Vary: Accept-Encoding
Server: MochiWeb/1.1 WebMachine/1.9.0 (someone had painted it blue)
Link: </riak/snippet>; rel="up"
Last-Modified: Tue, 05 Jun 2012 21:28:26 GMT
ETag: "5E5aOqpuUZa30DpSVytdn7"
Date: Tue, 05 Jun 2012 21:37:09 GMT
Content-Type: application/json
Content-Length: 117

{"key":"AIUWiw==","title":"The Basics","left":"var x = 1;","right":"int x = 1;","created":"2012-06-05T21:28:20.314Z"}%   
{% endcodeblock %}

You can see that the detail we're getting matches that which we pulled straight out of our application, including the `X-riak-index-userid_int` header which contains the Id of the user the submitted the snippet.

Everything looks in order. Next let's handle storage of votes.

## <a id="storing-votes"></a>Storing Votes

Storage of a snippet is a great thing, but it is ultimatley meaningless of people can't indicate which one they prefer. What we need to be able to do is provide the ability to vote so that users of the site can see which side of the snippet users feel is the best.

We've already discussed the approach that we're going to take. Let's dive into the code.

### <a id="csd_vote"></a>`csd_vote` module

{% codeblock apps/csd_core/src/csd_vote.erl (partial) lang:erlang %}
-module(csd_vote).
-author('OJ Reeves <oj@buffered.io>').

%% --------------------------------------------------------------------------------------
%% API Function Exports
%% --------------------------------------------------------------------------------------

-export([
    to_vote/3,
    fetch/2,
    save/1,
    get_user_id/1,
    get_which/1,
    get_id/1,
    get_id/2,
    to_json/1,
    from_json/1,
    get_snippet_id/1,
    count_for_snippet/1,
    count_for_snippet/2,
    random_votes/2
  ]).

%% --------------------------------------------------------------------------------------
%% Internal Record Definitions
%% --------------------------------------------------------------------------------------

-record(vote, {
    user_id,
    snippet_id,
    which,
    time
  }).

-record(count, {
    left,
    right,
    which
  }).

% ... snip ...
{% endcodeblock %}

Here we can see that we're following a similar pattern to what we did with snippets. We have an internal `vote` record which indicates which user submitted the vote, which snippet the vote is for, which side of the snippet they voted for (`"left"` or `"right"`) and a timestamp. Hopefully there's nothing in here that will surprise anyone.

The next record, `count`, is a little more interesting. It will make more sense after we see where it is used, but in short the purpose of this record is to group the results of a map/reduce job which counts the number of votes for a given snippet and which side the votes were for. If the search is conducted by a known (ie. logged-in user) the record will also indicate which side of the snippet they voted for (if any).

{% codeblock apps/csd_core/src/csd_vote.erl (partial) lang:erlang %}
% ... snip ...

%% --------------------------------------------------------------------------------------
%% API Function Definitions
%% --------------------------------------------------------------------------------------

to_vote(UserId, SnippetId, Which="left") when is_integer(UserId) ->
  to_vote_inner(UserId, SnippetId, Which);
to_vote(UserId, SnippetId, Which="right") when is_integer(UserId) ->
  to_vote_inner(UserId, SnippetId, Which).

% ... snip ...
{% endcodeblock %}

`to_vote` is a simple function that is used to create an instance of a vote. The interface of this function is designed to stop callers from submitting vote for anything other than `"left"` or `"right"`, as this wouldn't make sense to the system. This function calls an internal version which is defined a bit later on.

{% codeblock apps/csd_core/src/csd_vote.erl (partial) lang:erlang %}
% ... snip ...

count_for_snippet(SnippetId) ->
  {ok, {L, R}} = csd_db:vote_count_for_snippet(SnippetId),
  {ok, #count{
    left = L,
    right = R,
    which = ""
  }}.

count_for_snippet(SnippetId, UserId) ->
  {ok, {L, R, W}} = csd_db:vote_count_for_snippet(SnippetId, UserId),
  {ok, #count{
    left = L,
    right = R,
    which = W
  }}.

% ... snip ...
{% endcodeblock %}

These two functions are the magic that makes the vote counting tick. They both essentially do the same thing but for one small difference. The first, `count_for_snippet/1` takes a single parameter which is the Id of the snippet. It make a call to the `csd_db` module to kick off a map/reduce job in Riak. The result is a pair of values, `{L, R}`, where `L` is the total number of votes for the left side of the snippet and `R` is the total number for the right side. This search is done outside of the context of a known user. The result of a call to this function is a record which doesn't have a meaningful value for the `which` record member.

The second function, `count_for_snippet/2`, is the same as the first except that it also takes the identifier of the user that is conducting the search. This version of the function also calls a counterpart in `csd_db`, but the result is different in that it also contains the side of the snippet which that particular user voted for. This `which` value will be either `"left"`, `"right"` or `""`. If it's `""` then that indicates that the user hasn't voted on this snippet.

Next up we have the standard serialisation functions.

{% codeblock apps/csd_core/src/csd_vote.erl (partial) lang:erlang %}
% ... snip ...

to_json(#vote{time=T, which=W, snippet_id=S, user_id=U}) ->
  csd_json:to_json([
      {time, T},
      {user_id, U},
      {snippet_id, S},
      {which, W}],
    fun is_string/1);

to_json(#count{left=L, right=R, which=W}) ->
  csd_json:to_json([
      {left, L},
      {right, R},
      {which, W}],
    fun is_string/1).

% ... snip ...
{% endcodeblock %}

By now these functions should be self-explanatory, so we'll kick on to something more interesting.

{% codeblock apps/csd_core/src/csd_vote.erl (partial) lang:erlang %}
% ... snip ...

fetch(UserId, SnippetId) when is_integer(UserId) ->
  csd_db:get_vote(get_id(UserId, SnippetId)).

save(Vote=#vote{}) ->
  csd_db:save_vote(Vote).

get_user_id(#vote{user_id=U}) ->
  U.

get_which(#vote{which=W}) ->
  W.

get_snippet_id(#vote{snippet_id=S}) ->
  S.

get_id(#vote{user_id=U, snippet_id=S}) ->
  get_id(U, S).

get_id(UserId, SnippetId) when is_integer(UserId) ->
  iolist_to_binary([integer_to_list(UserId), "-", SnippetId]).

% ... snip ...
{% endcodeblock %}

The functions are also rather rudimentary and fit the usual pattern that we're applying across our application. The one thing to note here is that a vote doesn't have its own identifer that is generated. Instead, the key that is used to identify a vote in the `vote` bucket is a combination of the user's Id and the snippet's Id.

At this point the requirement for the accessor functions won't be clear. Keep them in mind, we'll cover them off a bit later when we look at the code that's closer to the UI.

Next up here's a typical deserialisation function.

{% codeblock apps/csd_core/src/csd_vote.erl (partial) lang:erlang %}
% ... snip ...

from_json(Json) ->
  List = csd_json:from_json(Json, fun is_string/1),
  #vote{
    time = proplists:get_value(time, List),
    user_id = proplists:get_value(user_id, List),
    snippet_id = proplists:get_value(snippet_id, List),
    which = proplists:get_value(which, List)
  }.

% ... snip ...
{% endcodeblock %}

Nothing too stellar here either. After converting the JSON back into a proplist, we're just poking the the values into our `vote` record.

{% codeblock apps/csd_core/src/csd_vote.erl (partial) lang:erlang %}
% ... snip ...

random_votes(SnippetId, NumVotes) ->
  random:seed(erlang:now()),
  lists:map(fun(_) ->
        Which = case random:uniform(99999999) rem 2 of
          0 -> "left";
          _ -> "right"
        end,
        V = to_vote(random:uniform(99999999), SnippetId, Which),
        save(V) end, lists:seq(1, NumVotes)),
  ok.

% ... snip ...
{% endcodeblock %}

The `random_votes` function is something that I decided to put in to simulate larger numbers of votes. Given that the system isn't live, I wanted to be able to generate votes for a given snippet so that I could see the affect on the UI. Leaving this function in makes sense for the benefit of my awesome reader(s) so they can see the effect themselves. Ultimately it doesn't belong in the _production_ version.

Now for the last two functions in the module.

{% codeblock apps/csd_core/src/csd_vote.erl (partial) lang:erlang %}
% ... snip ...

%% --------------------------------------------------------------------------------------
%% Private Function Definitions
%% --------------------------------------------------------------------------------------

to_vote_inner(UserId, SnippetId, Which) ->
  #vote{
    user_id = UserId,
    snippet_id = SnippetId,
    time = csd_date:utc_now(),
    which = Which
  }.

is_string(time) -> true;
is_string(which) -> true;
is_string(snippet_id) -> true;
is_string(_) -> false.

{% endcodeblock %}

`to_vote_inner` is a simple function called by `to_vote` at the top of the module. It's there just to reduce code duplication. `is_string` is the classic helper function which tells the JSON serialiser/deserialiser which values are strings and which aren't.

We're done with the handling module, next we need to dive into how these are stored.

### <a id="csd_vote_store"></a>`csd_vote_store` module

That's votes done. The last thing we're going to store is a bit of user information.

## <a id="storing-users"></a>Storing Users

### <a id="csd_vote"></a>`csd_vote` module

### <a id="csd_user_store"></a>`csd_user_store` module

## <a id="snippet-submission"></a>Code Snippet Submission

Let's start by creating a new resource which we'll be using to handle the form submission. First, edit `app.config` and add a new dispatch rule like so:

{% codeblock apps/csd_web/priv/app.config lang:erlang %}
{csd_web,
  [
    {web,
      [
        ... snip ...
        {dispatch,
          [
            ... snip ...
            {["snippet"], csd_web_snippet_submit_resource, []},
            ... snip ...
          ]}
      ]
    },
    ... snip ...
  ]}
{% endcodeblock %}

Notice how we're using the same resource URI as the one used to GET snippets (as shown in [Part 3][]). This is to appear more RESTful. We'll be POSTing to `/snippet` to submit a new snippet while GETting from `/snippet/_snippet-id_` to read those which already exist.

Now that the route is set up, we need to create the resource which will handle it. Here is the full listing which we'll go through in detail:

{% codeblock apps/csd_web/src/csd_web_snippet_submit_resource.erl lang:erlang %}
{% endcodeblock %}


TODO BEFORE POSTING
-------------------

**Note:** The code for Part 5 (this post) can be found on [Github][Part5Code].

[Part5Code]: https://github.com/OJ/csd/tree/Part5-??? "Source code for Part 5"
[Twitter]: http://twitter.com/ "Twitter"
[OAuth]: http://oauth.net/ "OAuth"
[Erlang]: http://erlang.org/ "Erlang"
[Webmachine]: http://www.basho.com/developers.html#Webmachine "Webmachine"
[JSON]: http://json.org/ "JavaScript Object Notation"
[Part 1]: /posts/webmachine-erlydtl-and-riak-part-1/ "Wembachine, ErlyDTL and Riak - Part 1"
[Part 2]: /posts/webmachine-erlydtl-and-riak-part-2/ "Wembachine, ErlyDTL and Riak - Part 2"
[Part 3]: /posts/webmachine-erlydtl-and-riak-part-3/ "Wembachine, ErlyDTL and Riak - Part 3"
[Part 4]: /posts/webmachine-erlydtl-and-riak-part-4/ "Wembachine, ErlyDTL and Riak - Part 4"
[Riak]: http://www.basho.com/developers.html#Riak "Riak"
[ErlyDTL]: http://github.com/evanmiller/erlydtl "ErlyDTL"
[Rebar]: http://www.basho.com/developers.html#Rebar "Rebar"
[mochijson2]: https://github.com/mochi/mochiweb/blob/master/src/mochijson2.erl "Mochiweb's json module"
[Mochiweb]: https://github.com/mochi/mochiweb "Mochiweb"
[OTP]: http://en.wikipedia.org/wiki/Open_Telecom_Platform "Open Telecom Platform"
[cURL]: http://curl.haxx.se/ "cURL homepage"
[WebmachineRedirects]: http://buffered.io/posts/redirects-with-webmachine/ "Redirects with Webmachine"
[wrq]: http://wiki.basho.com/Webmachine-Request.html "Request data"
[MapRed]: http://wiki.basho.com/MapReduce.html "Riak Map/Reduce"
[series]: http://buffered.io/series/web-development-with-erlang/ "Web Development with Erlang"
[Nginx]: http://nginx.org/ "Nginx"
[Twitter bootstrap]: http://twitter.github.com/bootstrap/ "Twitter Bootstrap"
[Handlebars]: http://handlebarsjs.com/ "Handlebars templating"
[Backbone.js]: http://documentcloud.github.com/backbone/ "Backbone.js"
[Secondary Index]: http://wiki.basho.com/Secondary-Indexes.html "Secondary Indexes in Riak"
[VIM]: http://www.vim.org/ "VIM"
[gen_server]: http://www.erlang.org/doc/man/gen_server.html "Erlang gen_server"
[Pooler]: https://github.com/OJ/pooler "Pooler"
