---
categories: [Software Development, WTF, C#]
date: 2009-02-10 21:22
tags: [assumptions, lock, multithreading, stupidity]
layout: post
title: "Always Question the Source (aka \"Don't Lock on Type Objects\")"
---
For one reason or another, I recently found myself perusing some code based on the <a href="http://www.lhotka.net/cslanet/" title="CSLA">CSLA</a> framework. While nosing around I came upon a snippet of code that I found rather disturbing. An example can be found <a href="http://www.lhotka.net/cslacvs/viewvc.cgi/trunk/cslacs/Csla/Core/BusinessBase.cs?revision=3690&view=markup" title="BusinessBase.cs">here</a> in the function called InitializeAuthorizationRules.

For those who are lazy, here is the particular snippet of code that caught my eye:

<!--more-->
{% codeblock lang:csharp %}
lock (this.GetType())
{
  // .. stuff ..
}
{% endcodeblock %}

If you want to see more, head over there and read up. There are quite a few instances of the code listed above.

So why is this disturbing? If you're not sure of the answer, take a bit of time to go and read up on C#'s <a href="http://msdn.microsoft.com/en-us/library/c5kehkcz.aspx" title="lock Statement (C# Reference)">lock</a> keyword. When you're done, ask yourself "what kind of object should I be using alongside the lock keyword?".

If the answer escapes you, then toodle over to <a href="http://www.mail-archive.com/bdotnet@groups.msn.com/msg06816.html" title="Why Lock(typeof(ClassName)) or SyncLock GetType(ClassName) Is Bad">this little doozy</a> for a blow by blow account. I'll quote a rather gifted developer friend of mine (who for now shall remain anonymous) who summed up nicely one of the issues that could occur if the above code makes it into your code base:
<blockquote><p>This is terrible, terrible, terrible.

Good luck with the cross-appdomain deadlock which brings down prod and can't be diagnosed without 2 weeks behind windbg.</p></blockquote> Soooo true.

Now that you know it's bad you might be wondering how a framework like CSLA managed to get polluted by it. Time to speculate!

You may have noticed that the article I linked above mentions that the practice of locking type objects was actually demonstrated/advocated on MSDN:
<blockquote><p>
This is even done in MSDN sample, makuing it the holy grail.
.
.
Rico Mariani, performance architect for the Microsoft .NET runtime and longtime
Microsoft developer, mentioned to Dr. GUI in an e-mail conversation recently that a
fairly common practice (and one that's, unfortunately, described in some of our
documentation right now, although we'll be fixing that) is actually quite problematic.
</p></blockquote>
<em>Note: Spelling mistakes and awful grammar in the quote above are, for once, not my fault.</em>

I'm guessing that the author(s) of CSLA were reading up on some multithreading documentation on MSDN and came across a sample which demonstrated locking type objects as shown above. Since they were reading MSDN, the apparent Bible for all things .NET, they may have assumed that whatever they saw could be taken as Gospel.

Unfortunately, no resource is perfect. Not even MSDN.

This is where I have my gripe. The authors of <strong>any</strong> software should <strong>always</strong> critique <strong>all</strong> of the code they come across during the course of development. Whether they wrote it themselves, got it from MSDN, read it on a blog site while researching or saw it in a book written by the author of the language. <em>NEVER EVER</em> assume that the code you are reading is 100% sound.

If the authors had thought about the <em>meaning</em> of the lock statement and had an understanding of exactly what <a href="http://msdn.microsoft.com/en-us/library/system.object.gettype.aspx" title="Object.GetType Method">GetType()</a> does (ie. always returns the <em>same</em> reference when called on the same type), then perhaps they might have figured out that using a lock on something that's accessible from <strong>any object in the process</strong> is a bad idea. It is opening the door for potential deadlocks if somebody else decides to do the same.

So I say again: <em>do not assume that the code you get off the Internet is safe!</em> Scrutinise it. Pull it to pieces. Understand it. Then, if all is safe and you're still comfortable with it, consider using it in your software. Don't assume that the author of the code knows what they're doing...

... unless it's me of course ;)

<!--adsense-->
