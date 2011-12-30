---
categories: [WTF]
date: 2006-12-20 05:24
layout: post
title: "WTF: You'll Never Amount to Anything"
---
Yes, it just gets better and better! This beauty is just a few of the lines that make up a <em>huge</em> "property get" in C#. Count the WTFs in this crazy baby:

{% codeblock lang:csharp %}
string amount = "";
double Amount = 0;
try
{
	amount = (string)r["Amount"];
	Amount = Convert.ToDouble(amount);
}
catch
{
	// use formula rather than value
	AmountFormula = amount;
	Amount = 0;
}
{% endcodeblock %}

If I had a prize, I'd give one away, but I don't. So instead, you'll have to settle for kudos. How many can you find?

WTFness: 9 / 10.
