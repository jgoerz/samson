h2. How to work with this repository


This repostiory will be tracking the upstream master branch:
https://github.com/zendesk/samson

This has several impliactions:
1. Our workflow will be more complicated.
2. Changes we make to our repo, we want to make available to upstream (as much as possible) so we
   don't diverge.
3. When you make code commits, you'll need to commit and test them on our repo, keeping in mind
   you'll want to create a github pull request to incorporate those changes.

Local repo setup:

```
git checkout git@git.plansource.com:app/ps-deployment-server.git 
git remote add github https://github.com/zendesk/samson.git
```
You'll need to fork Zendesk/Samson repo on your github account.  Then add another remote on your
local repo:

```
git remote add git@github.com:YOUR_GITHUB_USERNAME_HERE/samson.git
```

If you do the above, your local master branch points to Plansource's master.

h2. How to merge upstream master into ours.

```
# Assuming:
# $ ~/ps-deployment-server$ git remote -vv
# github  https://github.com/zendesk/samson.git (fetch)
# github  https://github.com/zendesk/samson.git (push)
# github-jgoerz   git@github.com:jgoerz/samson.git (fetch)
# github-jgoerz   git@github.com:jgoerz/samson.git (push)
# origin  git@git.plansource.com:app/ps-deployment-server.git (fetch)
# origin  git@git.plansource.com:app/ps-deployment-server.git (push)
#
# $ ~/ps-deployment-server$ git branch -vv
# jg-master    44b527f [github-jgoerz/master] Merge pull request #2438 from zendesk/grosser/comment
# master       44b527f [origin/master] Merge pull request #2438 from zendesk/grosser/comment
# * zd-master    44b527f [github/master] Merge pull request #2438 from zendesk/grosser/comment

git checkout master
git fetch --all
git merge github/master
git push origin master
```

h2. How to create pull request on Github

1.  Make sure your personal github repository is up to date.
2.  Create a local branch off of your personal github repository.
3.  Merge your changes into your branch.
4.  Push
5.  Create pull request.

```
git fetch --all
git checkout -b your-feature-branch github-jgoerz/master
# make changes or
git merge origin/your-feature-branch # This is a branch you modified on Plansource
git push github-jgoerz/your-feature-branch
```

Navigate to your fork on Github.  It should pop something up asking you if you want to create a pull
request.

h2.  Branch management

Remember that branches you create are just "pointers" to remote repositories.  When you create a
local branch, it's important you use this format:

```
git checkout -b your-feature-branch-name REMOTE/branch-fork-point-on-remote-usually-master
# make changes
git push -u your-feature-branch-name REMOTE/your-feature-branch-name
```

Where REMOTE is the remote where you want the changes to go.  You can always change where a local
branch points to with:

```
git branch your-local-branch --set-upstream-to=remote/remote-branch-name
```
