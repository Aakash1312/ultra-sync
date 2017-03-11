# Ultra-Sync package

Ultra-Sync package synchronizes scrolling of **asciidoc** and **markdown** documents. It can also sync normal text files. The two files to be synced should be opened in two different panes. After syncing, the contents of the files will correspond to each other on scrolling.

For ultra-sync package to deliver its best, it is required that documents are well written.

**Syncing asciidoc document**

![ascii-doc](https://cloud.githubusercontent.com/assets/10784031/23783684/57411e00-0583-11e7-802c-e806d21af61b.gif)

**Syncing markdown document**

![markdown](https://cloud.githubusercontent.com/assets/10784031/23783831/60f979c8-0584-11e7-8aaa-01d5ff873bbe.gif)

**Syncing normal text document**

![normal](https://cloud.githubusercontent.com/assets/10784031/23783778/0ba59222-0584-11e7-8667-9629d74857a0.gif)

# How to use
In order to use Ultra-Sync, open the documents to be synchronized in two different panes. Now toggle Ultra-Sync by pressing `ctrl-alt-e` or by using Packages menu in the atom window.
Once toggled, documents can synchronized by pressing `ctrl-alt-d`.
Press `ctrl-alt-e` again to deactivate the package.

# Settings
Ultra-Sync allows users to customize their experience. The package uses features like **autosync** to automatically synchronize scrolling as and when document is edited. Also, it uses **interpolation** technique to provide smoother scrolling.
It uses **levenshtein** algorithm for strong matching. If strong matching is disabled, then matching of documents can be less accurate.
These features however may reduce the processing speed. In such cases, user can disable them.

There are two types of syncing available. **Pcapture sync** uses different method of node traversal. Hence it can sometimes produce better results.

# Installation
Ultra-Sync can be installed from atom packages. `apm` can also be used:

`apm install ultra-sync`
