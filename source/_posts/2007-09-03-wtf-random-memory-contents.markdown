---
categories: [Software Development, WTF, C#]
date: 2007-09-03 15:40
comments: true
layout: post
title: "WTF: Random Memory Contents"
---
If any of you out there are able to give me <strong>ONE GOOD REASON</strong> why <em>anyone</em> would do something like this, then please let me know. Below are "customised" realloc() and malloc() I recently stumbled across (yes, they get called. A <strong>LOT</strong>):
{% codeblock lang:cpp %}
void *mcRealloc( void *P, int SIZE )
{
  int oldSize = _msize( P );

  P = realloc( P, SIZE );

  if ( P )
  {
    for ( int i = oldSize; i < SIZE; i++ )
    {
      ((char *) P)[i] = (char) rand();
    }
  }

  return P;
}

void *mcMalloc( int SIZE )
{
  void *P;

  P = malloc( SIZE );

  if ( P )
  {
    for ( int i = 0; i < SIZE; i++ )
    {
      ((char *) P)[i] = (char) rand();
    }
  }

  return P;
}
{% endcodeblock %}

Is it just me, or is this a <strong>huge</strong> WTF?
