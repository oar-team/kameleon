.. _`workspace`:

---------
Workspace
---------

The workspaces are the folders containing your Kameleon recipes and builds.
When you use ``kameleon new`` the current directory is the workspace. A
workspace may contains several recipes.

*Be careful*: All the *steps are shared between recipes within a workspace*. So
if you do NOT want to share steps between different recipes you MUST use
different workspace.
