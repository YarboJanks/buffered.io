---
categories: [Blogging]
date: 2011-02-15 20:44
tags: [blogging, python, blogofile]
layout: post
title: "Now Powered by Blogofile"
---
<a href="/uploads/2011/02/V8SFIEngine2001.jpg" title="Time for a new engine" rel="lightbox"><img src="/uploads/2011/02/V8SFIEngine2001.jpg" width="150" style="float:right;margin-left:5px;margin-bottom:5px;" alt="Time for a new engine"/></a>When I [first started blogging][FirstPost] back in 2006 the platform of choice at the time was [Wordpress][Wordpress], a feature-rich blogging platform build with [PHP][php]. Since then the platform has improved substantially and the number of community-driven contributions and plug-ins has increased to a massive number. I've thoroughly enjoyed using Wordpress for the past 5 years and would recommend it to anyone (I already have!) who is looking for a quality blogging platform.

For me, however, Wordpress was becoming less and less appealing. This isn't due to a failing in the platform itself, but more because my needs/desires for my blogging engine were changing.

<!--more-->

One of the curses of maintaining a technical blog is that the posts very quickly "expire". Their use-by date can be very short, and hence it becomes a burden to keep them up to date. So far, I've not done a great job of updating my posts, partly due to laziness, and partly because doing it using Wordpress is a little painful. I was looking for a solution to this problem, and nothing that I could see coming out of the Wordpress community was helping. What I really wanted was to have instant access to posts on my file system, not via a web front-end. Ideally, I would be able to store all of my posts in a [Mercurial][hg] repository.

I was also tired of having to write posts using straight HTML. I am not a fan of using online editors. Browsers are unpredictable and a stray keystroke can move you from your page to another page, resulting in you losing anything that hasn't been saved along the way. Also, the editors are terrible, relatively featureless and often buggy. Wordpress's editor, while very good, is not my cup of tea. It was getting to the point where I really wanted to write my posts in [Markdown][Markdown] instead. I am aware of some plug-ins which allow this kind of functionality, but my experiences with them weren't that great. I wanted to write things in VIM and easily save/publish to the site without having to leave VIM.

Recently I have received offers of help in updating content from other people in the technical community. They have been interested in getting access to the content so they can contribute in keeping it up to date. Providing access to these people would be painful using Wordpress as a tool. Not because it doesn't do access control, but because the workflow is just unpleasant. Ultimately the ideal scenario is to store my Mercurial repository, with all the posts in it, on [Bitbucket][bitbucket] so that other people can fork the repository, make changes and submit [pull requests][pull-request] when they have modified the content. I could easily merge the changes and republish my site.

Apart from the workflow and technical reasons, I was very interested in changing the way the site was served. The blog content is totally static except for two cases, both of which can be handled externally:

  * Comments - for a while I've been using [Disqus][disqus] to handle my comments. The platform is awesome. No spam, no need to get people to sign in to comment, no overhead. Can't recommend it enough.
  * Post updates - posts are updated by me and only me. All I needed was a way of converting my posts to a static HTML website and then copying that to my webserver.

Since I had no need for a _dynamic_ site, I could easily move away from PHP and database-driven content. All I needed was a bit of help.

Enter Blogofile
---------------
  > Blogofile is a static website compiler, primarily (though not exclusively) designed to be a simple blogging engine. It requires no database and no special hosting environment. You customize a set of templates with Mako, create posts in a markup language of your choice (see Post Content) and Blogofile renders your entire website as static HTML and Atom/RSS feeds which you can then upload to any old web server you like.

Exactly what I need! I'm no [Python][python] guru, but I knew I had enough coding chops to pick up the essentials to hack together a template which would suit my needs. I decided to dive in. My plan was:

  * Port my current WP theme to Blogofile (which uses [Mako][mako] behind the scenes).
  * Hack the engine a little to include:
    * OpenID delegation support
    * Feedburner support
    * Google Analytics integration
    * Series support
  * Get a [free Micro instance][micro-instance] running on [EC2][ec2] with [Python][python] and [Mercurial][hg] installed.
  * Set up a Mercurial hook which regenerates the site and makes it available to the public when content is pushed to the repository.
  * Migrate the content from the WP site to a set of Markdown posts.
  * Fix links/images/etc from the previous posts and include them in the new site content.
  * Hack a few other things to make sure the content looks relatively similar, including the support for the `<!--more-->` tag (which splits posts in WP).

It will come as no surprise that I had to learn a little bit along the way :) I'm now exposed to how Python hangs together, and I have a (relatively) solid grasp of Mako templates.

The net result is the site that you're now looking at! From my side of the planet the speed different is noticable, and the experience of publishing to it is as simple as `hg commit -m "message" && hg push web` - I don't have to leave VIM at all to do that. All of my goals have been met, and I'm happy :)

Now this task is out of the way, I'll be continuing work on my [Erlang blog series][erlang-series]. I'm looking forward to having the next post done and ready for your critique.

For those of you considering other blogging platforms which suit different workflows better than the mainstream options, be sure to check [Blogofile][blogofile] out. It's a great system, and worth the effort of diving into. I'm happy to answer questions if you have any.

Until next time!

  [FirstPost]: /posts/office-registration-and-activation/
  [Wordpress]: http://wordpress.org/
  [php]: http://www.php.net/
  [hg]: http://hg-scm.org/
  [markdown]: http://daringfireball.net/projects/markdown/
  [bitbucket]: http://bitbucket.org/
  [pull-request]: http://confluence.atlassian.com/display/BITBUCKET/Forking+a+Bitbucket+Repository
  [disqus]: http://disqus.com/
  [blogofile]: http://blogofile.com/
  [python]: http://www.python.org/
  [mako]: http://www.makotemplates.org/
  [micro-instance]: http://aws.amazon.com/free/
  [ec2]: http://aws.amazon.com/ec2/
  [erlang-series]: /series/web-development-with-erlang/
