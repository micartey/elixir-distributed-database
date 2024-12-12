# Eddb

`eddb` is a distributed (unstructured) database

## Functions

### get

`get` will retrive the data from all neighbors and check which update is the newest.
After finding the newest change, the data will be shared.

> [!NOTE]
> This has no affect on the data on the current node.
> If you want the data to be merged, call the `sync` function

### get_local

`get_local` will only retrive data from the current node.
Thus, this operation is significantly faster.

### put

`put` will store the data on the current node.
Data with the same key in the same topic will be overwritten, but the old data will be kept in the history.

### put (With optimistic locking)

`put` with optimistic locking is similar to the normal put operation.
However, you can specify the expected current state and **only** if the expection matches with the data on the node, the new data will be stored.

> [!NOTE]
> In some cases you want the data to be expected on all nodes, this can currently only be somewhat archived by calling the `sync` functiojn before

### sync

`sync` will merge the data from all neighbors.
The data with the newest timestamp is considered the current state.
