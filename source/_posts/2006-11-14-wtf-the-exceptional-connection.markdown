---
categories: [WTF]
date: 2006-11-14 11:37
layout: post
title: "WTF: The Exceptional Connection"
---
This would have to be close to the dumbest way of verifying the state of a connection :) Well, that might not be true, but it's definitely one of the dumbest ways.

This is a funky snippet of code that was extracted from a system I'm doing some work on at the moment:
{% codeblock lang:csharp %}
public static bool IsValid(OracleConnection conn)
{
	OracleCommand cmd = new OracleCommand("select 1 from dual", conn);
	cmd.CommandType = CommandType.Text;
	cmd.ExecuteReader();
	cmd.Dispose();
	return true;
}
{% endcodeblock %}

So, if it doesn't hurl an exception at you, it's valid! Nice work eh? So if you have to check for exceptions anyway, why not just try using the connection in the first place and handle THAT exception instead?

<strong>*shudders*</strong>

WTFness: 9 / 10
