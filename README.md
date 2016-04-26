# wine-staging-git-helper
**wine-staging-git-helper.sh** BASH script.

Gentoo Wine-Staging helper script designed to work with the **app-emulation/wine** package. Specifically a custom **wine-9999.ebuild**, from the **bobwya** Layman overlay. Designed to work with the **+staging** (USE flag) version of **wine-9999.ebuild** using:
* Wine git tree (http://source.winehq.org/git/wine.git/)
* Wine-Staging git tree (https://github.com/wine-compholio/wine-staging)

**get_upstream_wine_commit()**:
Supplied with a given SHA-1 Wine-Staging git commit - returns the corresponding upstream SHA-1 Wine git commit.

**walk_wine_staging_git_tree()**:
parses the Wine-Staging git tree with a SHA-1 Wine git commit - from any branch in the Wine git tree. The script returns a SHA-1 Wine-Staging git commit corresponding to the (supplied) upstream SHA-1 Wine git commit.

**find_closest_wine_commit()**:
In the event of failure, of first call to **walk_wine_staging_git_tree()** function, walk the Wine git tree (bi-directionally) and find the closest commit - to the (supplied) upstream SHA-1 Wine git commit - that has a supported downstream Wine-Staging SHA-1 git commit.

Plus other minor ancillary (self-evident) functions!
