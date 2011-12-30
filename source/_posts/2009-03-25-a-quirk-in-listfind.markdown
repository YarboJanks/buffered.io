---
categories: [Microsoft, Software Development, C#]
date: 2009-03-25 05:31
tags: [.net, C#, design, generics]
layout: post
title: "A Quirk in List.Find()"
---
Earlier today I was having a chat with a <a href="http://doomkeeper.com/" title="Jimmy's Blog">friend of mine</a>, who lives in Vancouver, about finding items that are stored in <a href="http://msdn.microsoft.com/en-us/library/6sh2ey19.aspx" title="List(T)">generic Lists</a>. He flicked me a code snippet that looked something like this:
{% codeblock lang:csharp %}
List<foo> list = new List<foo>();
// .. do some stuff
Foo f = list.Find(delegate(Foo f) { return foo.Name == "Bar"; });
{% endcodeblock %}

Straight away I fired back with an update to the code which used <a href="http://msdn.microsoft.com/en-us/library/bb397687.aspx" title="Lambda Expressions (C# Programming Guide)">lambda expressions</a> instead, as I'm a fan of how concise they are ;)

<!--more-->

{% codeblock lang:csharp %}
List<foo> list = new List<foo>();
// .. do some stuff
Foo f = list.Find(foo => foo.Name == "Bar");
{% endcodeblock %}

My friend ran this code against a data set that he had constructed and found that when the call to <a href="http://msdn.microsoft.com/en-us/library/x0b5b5bc.aspx" title="List(T).Find">Find()</a> was made, a <a href="http://msdn.microsoft.com/en-us/library/system.nullreferenceexception.aspx" title="System.NullReferenceException Class">NullReferenceException</a> was being thrown. I found this odd as I hadn't seen that before. <em>list</em> was definitely a valid reference and the lambda expression was well-formed as well. So what was wrong?

It turns out that even though <em>list</em> was a valid reference, it <strong>didn't contain any elements</strong>.

How odd! Why would the generic List object throw an exception when the user calls Find() when no elements are present? After a little bit of thinking I thought that I had the answer. I thought to myself:<blockquote cite="Myself"><p>What if the List was a container for a <a href="http://msdn.microsoft.com/en-us/library/34yytbws(VS.71).aspx" title="Value Types">value-type</a>, such as <em>int</em>? If you attempt to find a value in an empty list, then the function cannot return <em>null</em> because that isn't valid for value-types! Throwing an exception <em>does</em> make sense!</p></blockquote>
Isn't it amazing how easy it is to convince yourself of your own greatness? I thought I'd nailed it first go. So I proposed my argument to my friend, who initially was semi-sold on the idea.

Then I thought about it again and managed to convince myself that my apparent "brilliance" was, in fact, a failure. The perfect counter-argument to the above point is:<blockquote cite="Myself"><p>What happens when you have a List of ints which <em>does</em> contain elements and you attempt to search for a value that <strong>is not in the list</strong>?</p></blockquote>
It wasn't immediately obvious. So I tried something to see what would happen:
{% codeblock lang:csharp %}
List<int> list = new List<int>(new int[] { 1, 2, 3 });
int i = list.Find(x => x > 3);
// ....
{% endcodeblock %}

So what do you think the value of <em>i</em> is after those first two lines? Yes, you guessed it: <strong>Zero</strong>. Why? Well, duh, it's because <a href="http://msdn.microsoft.com/en-us/library/xwth0h0d.aspx" title="default Keyword">default(T)</a> for integers is Zero!

This is where little alarm bells started to ring in my head. I immediately whipped up an example where this would be considered bad:
{% codeblock lang:csharp %}
List<int> list = new List<int>(new int[] { 0, 1, 2, 3 });
int i = list.Find(x => x > 3);
// ....
{% endcodeblock %}

Again, <em>i</em> is Zero when this code is executed, but the result is very misleading. Zero is contained in the collection but doesn't match the predicate, yet Zero is returned because that's the default value for this value-type.

I thought this was a bit of a glaring hole in the design. So I went straight to the <a href="http://msdn.microsoft.com/en-us/library/xwth0h0d.aspx" title="List(T).Find">documentation</a> and found this:<blockquote><p>
<strong>Important Note:</strong>

When searching a list containing value types, make sure the default value for the type does not satisfy the search predicate. Otherwise, there is no way to distinguish between a default value indicating that no match was found and a list element that happens to have the default value for the type. If the default value satisfies the search predicate, use the <a href="http://msdn.microsoft.com/en-us/library/0k601hd9.aspx" title="FindIndex">FindIndex</a> method instead.</p></blockquote>
This was concerning for a couple of reasons. First of all, the designers have left it up to you to determine that this is the default behaviour. Yes I should be able to come to that conclusion myself, but I didn't until I got bitten :) So shut up! Secondly, you have to check your result value against your predicate <em>again</em> to be sure that it's not dodgey. For example:
{% codeblock lang:csharp %}
List<int> list = new List<int>(new int[] { 0, 1, 2, 3 });
int i = list.Find(x => x > 3);
if(i > 3)
{
  // .. valid value, do stuff ..
}
else
{
  // .. no item found
}
{% endcodeblock %}

Do <em>you</em> want to do that? I certainly don't. After a bit of back-and-forth with Jimbo, I thought that the best option for a generic List Find() function would be one that is akin to the good old C++ days. It would look something like this:
{% codeblock lang:csharp %}
bool Find<t>(Predicate<t> predicate, ref T output);
{% endcodeblock %}

This would mean that you could change your code to something like the following:
{% codeblock lang:csharp %}
int i;
List<int> list = new List<int>(new int[] { 0, 1, 2, 3 });
if(list.Find(x => x > 3, ref i))
{
  // .. valid value, do stuff ..
}
else
{
  // .. no item found, or empty list!
}
{% endcodeblock %}

Note how with this option you could easily support the case for empty lists at the same time. It would be helpful and meaningful. Only when the function returns true can you rely on the output parameter. It's very clear and caters for value-types and reference-types. It'd be easy to implement in an <a href="http://msdn.microsoft.com/en-us/library/bb383977.aspx" title="Extension Methods (C# Programming Guide)">extension method</a> as well. I'd prefer this solution over using FindIndex().

In case it's not obvious, this problem would no doubt exist in all functions on generic objects that attempt to return a single instance of <em>T</em> based on some form of predicate. <a href="http://msdn.microsoft.com/en-us/library/5kthb929.aspx" title="List(T).FindLast">FindLast()</a> would be another example.

I'm very keen to know the reasons behind the original design decision. I'm sure that minds far greater than mine parsed that problem and came up with that solution, probably for a very good reason.

What do you guys think?
