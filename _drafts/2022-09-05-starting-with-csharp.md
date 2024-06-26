---
layout: post
title:  "Starting with C#"
date:   2022-09-06T00:31:06.114Z
categories: development
externalImage: https://raw.githubusercontent.com/rancher/k3d/main/docs/static/img/k3d_logo_black_blue.svg
---
After years of avoiding writing any code that needed to be compiled, I am in a role where it makes sense for me to re-familiarize myself with C#. I have written code in C# in the past, but I would say that the last time I did any serious C# programming was about 14 years ago, which was way back at C# 3.0. This time around I'm going to install all the latest bits and bobs for C# 10.0 by installing .NET 6.0. That's easy enough by going to [https://dotnet.microsoft.com/en-us/download](https://dotnet.microsoft.com/en-us/download) and grabbing the installer, ensuring you choose the SDK installer, not the Runtime installer. If this is the first time you are using the `dotnet` CLI, you may need to configure a NuGet source:

```bash
# to check existing sources, run:
dotnet nuget list source
# to add the nuget.org source
dotnet nuget add source https://api.nuget.org/v3/index.json -n "nuget.org"
```

I already have VS Code installed, but that installer can be found at [https://code.visualstudio.com/Download](https://code.visualstudio.com/Download). The last tool that is fundamental to any type of development is a Version Control System, VCS. Here I will use [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git). With all of these tools at the ready, creating a new console app is as easy as running the following (_note that shell commands here are being ran in PowerShell on Windows, but should work for Bash as well on Linux or Mac):

```bash
# create directory for the code
mkdir MyConsoleApp
# move into the directory
cd MyConsoleApp
# initialize Git
git init
# grab a C# specific .gitignore file
curl https://gist.githubusercontent.com/takekazuomi/10955889/raw/734642c6760915003d36bb124fdae03bb293ae4f/csharp.gitignore >.gitignore
# create a separate directory for the "App" (so I can add another project for "Tests" later)
mkdir MyConsoleApp
# use the dotnet CLI "console" template to create a project
dotnet new console --language C# --langVersion 10 --use-program-main true --output MyConsoleApp
# commit the current state of things
git add .
git commit -m 'Initial commit of template code'
# start VS Code with the current 
code .
```

Once VS Code starts up, things may behave differently if you already have the [C# extension](https://marketplace.visualstudio.com/items?itemName=ms-dotnettools.csharp) installed, so you may wish to install that and then restart VS Code, at which point you should be asked if you want some necessary, additional items to be created, which you should answer "yes" to so that your `.vscode` folder will be created, containing an initial `launch.json` and `tasks.json`. At this point you can press `F5` to build and run the application, resulting in an oh so glorious "Hello, World!" (along with a lot of debug information). While I use VS Code for most of my day to day work, blogging is easier to share console commands, so let's see how that looks:

```bash
# commit the .vscode directory that was created
git add .vscode
git commit -m 'Adding autogenerated .vscode folder'
# run the app
dotnet run --project MyConsoleApp/MyConsoleApp.csproj
```

If you were in the App subdirectory `MyConsoleApp.App` already, you can get away with just running `dotnet run` without the `--project` flag.

I mentioned tests, and although I'm not going to write any meaningful tests here, I will share how to create the project, in this case going with the xUnit testing framework:

```bash
dotnet new xunit --language C# --output MyConsoleApp.Tests
git add MyConsoleApp.Tests
git commit -m 'Adding autogenerated unit tests'
```

One more optional thing that can be done is to create a Solution, which will group your projects together. This can be particularly useful if you choose to use [Visual Studio](https://visualstudio.microsoft.com/vs/community/) instead of VS Code.

```bash
dotnet new sln
dotnet sln add ./MyConsoleApp/MyConsoleApp.csproj
dotnet sln add ./MyConsoleApp.Tests/MyConsoleApp.Tests.csproj
git add ./MyConsoleApp.sln
git commit -m 'Adding solution'
```

Additional conveniences of having a solution file are that you can now run `dotnet build` from the root of your code repository and all of the projects in the solution will be built, and using `dotnet test` from the root will run all tests that can be found, i.e. any project in the solution named `*Tests.csproj`.
