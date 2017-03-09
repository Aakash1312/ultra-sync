# Ultra-Sync package

Ultra-Sync package synchronizes scrolling of **asciidoc** and **markdown** documents. It can also sync normal text files. The two files to be synced should be opened in two different panes. After syncing, the contents of the files will correspond to each other on scrolling.

For ultra-sync package to deliver its best, it is required that documents are well written.

**Syncing asciidoc document**

![ascii-doc](https://github.com/Aakash1312/ImagesRepo/blob/master/gifs/ascii.gif?raw=true)

**Syncing markdown document**

![markdown](https://github.com/Aakash1312/ImagesRepo/blob/master/gifs/markdown.gif?raw=true)

**Syncing normal text document**

![normal](https://github.com/Aakash1312/ImagesRepo/blob/master/gifs/text.gif?raw=true)

# How to use
In order to use Ultra-Sync, open the documents to be synchronized in two different panes. Now toggle Ultra-Sync by pressing `ctrl-alt-e` or by using Packages menu in the atom window.
Once toggled, documents can synchronized by pressing `ctrl-alt-d`.

# Settings
Ultra-Sync allows users to customize their experience. The package uses features like **autosync** to automatically synchronize scrolling as and when document is edited. Also, it uses **interpolation** technique to provide smoother scrolling.
These features however may reduce the processing speed. In such cases, user can disable them.

# Installation
Ultra-Sync can be installed from atom packages. `apm` can also be used:

`apm install ultra-sync`
