---
categories: [Linux, Shortcuts, Technology]
date: 2009-02-16 07:24
tags: [debian, gentoo, maintenance, sysadmin]
layout: post
title: "Server Refresh"
---
Over the weekend I revamped the webserver. Over the last month or two I've been bummed about the amount of overhead in maintaining a <a href="Gentoo" title="http://www.gentoo.org/">Gentoo</a> install as my webserver. Now before any of you Gentoo zealots have a whinge, let me explain.

Yes, <a href="Portage" title="http://en.wikipedia.org/wiki/Portage_(software)">Portage</a> is cool. It's quick, it builds stuff from source, etc. While that power is great, it's a pain in the butt at the same time. Especially when you're running on a <a href="VPS" title="http://en.wikipedia.org/wiki/Virtual_private_server">VPS</a>. I am tired of the underlying bits and pieces changing constantly and me having to muck around with masking and unmasking packages just to get things to update and play nicely together.

I made the decision to switch to <a href="Debian" title="http://www.debian.org/">Debian</a> and I am happy I did it. I don't think the time I'll have to spend maintaining the server will be as high as before. This is all about productivity and as far as I'm concerned this is going to reduce my workload. Given that my software installs don't change once I've got the server up and running, I shouldn't have to spend that amount of time keeping things running.

As always, there's a risk of teething problems when you do a full reinstall. So if anyone out there is having issues then please <a href="Contact me" title="/contact-me/">let me know</a>. Cheers! :)
