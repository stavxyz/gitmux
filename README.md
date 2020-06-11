
# gitmux

The `gitmux.sh` script is provided to help sync changes (**including commit history**) _across_ repositories. 

The script can be used to create brand new [destination] repositories from _any *or* all_ content within a source git repository. It can also be used to update repositories previously "forked" by gitmux (or forked in a more traditional manner).

### Usage Notes

* The recommended usage includes `-s`, which submits a pull request to your target repository with the resulting content. Although this is recommended, it is not the default, since it requires [`hub`](https://hub.github.com/) to be installed.

* The pull request mechanism allows for discrete modifications to be made in both the source and destination repositories. In other words, the sync performed by this script is one-way which _should_ allow for additional changes in both your source repository and destination repository over time.

* This script can be run many times for the same source and destination. For example, if you run this script for the first time on a Monday, and the **_source_** repository is updated on Wednesday, simply run this script again with the same arguments and it will generate a pull request with the latest updates from your _source_ repository.

* If `-c` is used, the destination repository will be created if it does not yet exist. [Requires \`hub\` GitHub CLI.](https://hub.github.com/)

* If `-s` is used, the pull request will be automatically submitted to your destination branch. [Requires \`hub\` GitHub CLI.](https://hub.github.com/)

* The script does not push updates to `master`, only to `update-from-${GIT_BRANCH}-${GIT_SHA}` where `GIT_BRANCH` is the source repository branch referenced (defaults to HEAD/master) and `GIT_SHA` is the equivalent commit hash for that branch. For this reason, you don't need to worry about this script modifying any branches except for the custom "feature branch" it creates for its own use on your remote.

* Changes make it into your destination repository's specified target branch ([default](https://help.github.com/en/articles/setting-the-default-branch) or `master` branch if not otherwise specified) through an auditable pull-request mechanism, and **are not** pushed to that branch directly by gitmux. If `-s` is not used or `hub` is not installed, you will need to merge the resulting changes from the gitmux feature branch into your destination branch manually.
 
* The _new_, or destination/target repository must have at least one commit (cannot be an empty repository) if you provide the repository path/url instead of having gitmux create it for you.

### gitmux FAQ

**1) Why doesnt this script push to my destination branch automatically?**

   That's dangerous. The best mechanism to view proposed changes is a
   Pull Request so that is the mechanism used by this script. A unique
   integration branch is created by this script in order to audit and
   view proposed changes and the result of the filtered source repository.

**2) This script always clones my source repo, can I just point to a local
   directory containing a git repository as the source?**

   Yes. Feel free to use a local path for the source repository. That will
   make the syncing much faster, but to minimize the chance that you miss
   updates made in your source repository, supplying a URL is more consistent.

 **3) I want to manage the rebase myself in order to cherry-pick specific chanages.
    Is that possible?**

   Sure is. Just supply -i to the script and you will be given a \`cd\`
   command that will allow you to drop into the temporary workspace.
   From there, you can complete the interactive rebase and push your
   changes to the remote named 'destination'. The distinction between
   remote names in the workspace is very imporant. To double-check, use
   `git remote --verbose show` inside the gitmux git workspace.

