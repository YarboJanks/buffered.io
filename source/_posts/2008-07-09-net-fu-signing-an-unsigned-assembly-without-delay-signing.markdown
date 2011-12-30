---
categories: [HOWTO, Microsoft, Security, Software Development, Tips/Tricks, C#]
date: 2008-07-09 12:13:23
tags: [.net, disassemble, ilasm, ildasm, MSIL, sign, snk, strong name]
layout: post
title: ".NET-fu: Signing an Unsigned Assembly (without Delay Signing)"
---
This article is also available in: <a href="http://www.otherbit.com/modules/blog/BlogContent.aspx?ID=174" title=".NET-FU : come trasformare in SIGNED un assembly UNSIGNED (senza ricorrere al DELAY SIGNING)">Italian</a>
<hr/>
The code-base that I am currently working with consists of a large set of binaries that are all <a href="http://msdn.microsoft.com/en-us/library/xc31ft41.aspx" title="Sign an Assembly with a Strong Name">signed</a>. The savvy .NET devs out there will know that any assembly that's used/referenced by a signed assembly must <em>also</em> be signed.

This is an issue when dealing with third-party libraries that are not signed. Sometimes you'll be lucky enough to be dealing with vendor that is happy to provide a set of signed assemblies, other times you won't. If your scenario fits the latter (as a recent one did for my colleagues and I), you need to sign the assemblies yourself. Here's how.<!--more-->

<em>Note:</em> <a href="http://msdn.microsoft.com/en-us/library/t07a3dye(VS.80).aspx" title="Delay Signing an Assembly">delay signing</a> is not covered in this article.

<h2>Scenario 1 - Foo and Bar</h2>
<strong>Foo</strong> is the component that you're building which has to be signed.
<strong>Bar</strong> is the third-party component that you're forced to use that <em>isn't</em>.

<img src="/uploads/2008/07/foobar.png" alt="Relationship between Foo and Bar" />
Grab <a href="/uploads/2008/07/bar.zip" title="Project/Binary for Bar"><em>Bar.dll</em> and project</a> along with <a href="/uploads/2008/07/foobar.zip" title="Project/Binary for Foo"><em>Foo.dll</em> and project</a> to see a source sample.

You'll notice <em>Foo</em> has a .snk which is used to sign <em>Foo.dll.</em> When you attempt to compile <em>Foo</em> you get the following error message:<blockquote><p>Assembly generation failed -- Referenced assembly 'Bar' does not have a strong name</p></blockquote>
We need to sign <em>Bar</em> in order for <em>Foo</em> to compile.

<img src="/uploads/2008/07/step1.jpg" style="float: right; margin-left: 5px; margin-bottom: 2px;" alt="Disassemble Bar" /><h3>Step 1 - Disassemble Bar</h3>
We need to open a command prompt which has the .NET framework binaries in the <a href="http://en.wikipedia.org/wiki/Path_%28computing%29" title="Path">PATH</a> <a href="http://en.wikipedia.org/wiki/Environment_variable" title="Environment variable">environment variable</a>. The easiest way to do this is to open a Visual Studio command prompt (which is usually under the "Visual Studio Tools" subfolder of "Visual Studio 200X" in your programs menu). Change directory so that you're in the folder which contains <em>Bar.dll</em>.

Use <a href="http://msdn.microsoft.com/en-us/library/f7dy01k1(VS.80).aspx" title="MSIL Disassembly">ildasm.exe</a> to disassemble the file using the <strong>/all</strong> and <strong>/out</strong>, like so:

    C:\Foo\bin> ildasm /all /out=Bar.il Bar.dll

The result of the command is a new file, <em>Bar.il</em>, which contains a dissassembled listing of <em>Bar.dll</em>.

<img src="/uploads/2008/07/step2.jpg" style="float: right; margin-left: 5px; margin-bottom: 2px;" alt="Rebuild and Sign Bar" /><h3>Step 2 - Rebuild and Sign Bar</h3>
We can now use <a href="http://msdn.microsoft.com/en-us/library/496e4ekx.aspx" title="MSIL Assembler">ilasm</a> to reassemble <em>Bar.il</em> back into <em>Bar.dll</em>, but at the same time specify a strong-name key to use to sign the resulting assembly. We pass in the value <em>Foo.snk</em> to the <strong>/key</strong> switch on the command line, like so:<div style="clear:both;"></div>

    C:\Foo\bin> ilasm /dll /key=Foo.snk Bar.il

    Microsoft (R) .NET Framework IL Assembler.  Version 2.0.50727.1434
    Copyright (c) Microsoft Corporation.  All rights reserved.
    Assembling 'Bar.il'  to DLL --> 'Bar.dll'
    Source file is ANSI

    Assembled method Bar.Bar::get_SecretMessage
    Assembled method Bar.Bar::.ctor
    Creating PE file

    Emitting classes:
    Class 1:        Bar.Bar

    Emitting fields and methods:
    Global
    Class 1 Methods: 2;
    Resolving local member refs: 1 -> 1 defs, 0 refs, 0 unresolved

    Emitting events and properties:
    Global
    Class 1 Props: 1;
    Resolving local member refs: 0 -> 0 defs, 0 refs, 0 unresolved
    Writing PE file
    Signing file with strong name
    Operation completed successfully

<em>Bar.dll</em> is now signed! All we have to do is reopen <em>Foo</em>'s project, remove the reference to <em>Bar.dll</em>, re-add the reference to the new signed assembly and rebuild. Sorted!

<h2>Scenario 2 - Foo, Bar and Baz</h2>
<strong>Foo</strong> is the component that you're building which has to be signed.
<strong>Bar</strong> is the third-party component that you're forced to use that <em>isn't</em>.
<strong>Baz</strong> is another third-party component that is required in order for you to use <em>Bar</em>.

<div class="LargeImage"><img src="/uploads/2008/07/foobarbaz.png" alt="Relationship between Foo, Bar and Baz"/></div>
Grab <a href="/uploads/2008/07/baz.zip" title="Project/Binary for Baz"><em>Baz.dll</em> and project</a>, <a href="/uploads/2008/07/barbaz.zip" title="Project/Binary for Bar"><em>Bar.dll</em> and project</a> along with <a href="/uploads/2008/07/foobarbaz.zip" title="Project/Binary for Foo"><em>Foo.dll</em> and project</a> for a sample source.

When you attempt to build <em>Foo</em> you get the same error as you do in the previous scenario. Bear in mind that this time, <strong>both</strong> <em>Bar.dll</em> and <em>Baz.dll</em> need to be signed. So first of all, follow the steps in <strong>Scenario 1</strong> for both <em>Bar.dll</em> and <em>Baz.dll</em>.

Done? OK. When you attempt to build <em>Foo.dll</em> after pointing the project at the new <em>Bar.dll</em> no compiler errors will be shown. Don't get too excited :)

When you attempt to <strong>use</strong> <em>Foo.dll</em> your world will come crashing down. The reason is because <em>Bar.dll</em> was originally built with a reference to an <u>unsigned version</u> of <em>Baz.dll</em>. Now that <em>Baz.dll</em> is signed we need to force <em>Bar.dll</em> to reference the <strong>signed</strong> version of <em>Baz.dll</em>.

<img src="/uploads/2008/07/step3.jpg" style="float: right; margin-left: 5px; margin-bottom: 2px;" alt="Hack the Disassembled IL" /><h3>Step 1 - Hack the Disassembled IL</h3>
Just like we did in the previous steps we need to disassemble the binary that we need to fix. This time, make sure you disassemble the new binary that you created in the previous step (this binary has been signed, and will contain the signature block for the strong name). Once <em>Bar.il</em> has been created using ildasm, open it up in a <a href="http://www.vim.org/" title="VIM - secretGeek loves it.. no really, he does!">text editor</a>.

Search for the reference to <em>Baz</em> -- this should be located a fair way down the file, somewhere near the top of the actual code listing, just after the comments. Here's what it looks like on my machine:

    .assembly extern /*23000002*/ Baz
    {
      .ver 1:0:0:0
    }

This external assembly reference is missing the all-important public key token reference. Before we can add it, we need to know what the public key token is for <em>Bar.dll</em>. To determine this, we can use the <a href="http://msdn.microsoft.com/en-us/library/k5b5tt23(VS.80).aspx" title="Strong Name Tool">sn.exe</a> utility, like so:

    C:\Foo\bin> sn -Tp Baz.dll

    Microsoft (R) .NET Framework Strong Name Utility  Version 3.5.21022.8
    Copyright (c) Microsoft Corporation.  All rights reserved.

    Public key is
    0024000004800000940000000602000000240000525341310004000001000100a59cd85e10658d
    9229d54de16c69d0b53b31f60bb4404b86eb3b8804203aca9d65412a249dfb8e7b9869d09ce80b
    0d9bdccd4943c0004c4e76b95fdcdbc6043765f51a1ee331fdd55ad25400d496808b792723fc76
    dee74d3db67403572cddd530cadfa7fbdd974cef7700be93c00c81121d978a3398b07a9dc1077f
    b331ca9c

    Public key token is 2ed7bbec811020ec

Now we return to <em>Bar.il</em> and modify the assembly reference so that the public key token is specified. This is what it should look like after modification:

    .assembly extern /*23000002*/ Baz
    {
      .publickeytoken = (2E D7 BB EC 81 10 20 EC )
      .ver 1:0:0:0
    }

Save your changes.

<img src="/uploads/2008/07/step4.jpg" style="float: right; margin-left: 5px; margin-bottom: 2px;" alt="Reassemble Bar" /><h3>Step 2 - Reassemble Bar</h3>
This step is just a repeat of previous steps. We are again using ilasm to reassemble <em>Bar.dll</em>, but this time from the new "hacked" <em>Bar.il</em> file. We must use the exact same command line as we did previously, and we still need to specify the <em>Foo.snk</em> for signing the assembly. To save you having to scroll up, here it is again:

    C:\Foo\bin> ilasm /dll /key=Foo.snk Bar.il

    Microsoft (R) .NET Framework IL Assembler.  Version 2.0.50727.1434
    Copyright (c) Microsoft Corporation.  All rights reserved.
    Assembling 'Bar.il'  to DLL --> 'Bar.dll'
    Source file is ANSI

    Assembled method Bar.Bar::get_SecretMessage
    Assembled method Bar.Bar::.ctor
    Creating PE file

    Emitting classes:
    Class 1:        Bar.Bar

    Emitting fields and methods:
    Global
    Class 1 Fields: 1;      Methods: 2;
    Resolving local member refs: 3 -> 3 defs, 0 refs, 0 unresolved

    Emitting events and properties:
    Global
    Class 1 Props: 1;
    Resolving local member refs: 0 -> 0 defs, 0 refs, 0 unresolved
    Writing PE file
    Signing file with strong name
    Operation completed successfully

Open up <em>Foo</em>'s project, remove and re-add the reference to <em>Bar.dll</em>, making sure you point to the new version that you just created. <em>Foo.dll</em> will not only build, but this time it will run!

<h2>Disclaimer</h2>
"Hacking" third-party binaries in this manner <strong><em>may</em> breach the license agreement</strong> of those binaries. Please make sure that you are not breaking the license agreement before adopting this technique.

I hope this helps!
