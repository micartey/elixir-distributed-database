# Eddb

<div align="center">
  <img src="https://img.shields.io/badge/elixir-%234B275F.svg?style=for-the-badge&logo=elixir&logoColor=white" />
</div>

`eddb` is a distributed database for unstructured data

## Functions

### get

`get` will retrive the data from all neighbors and check which update is the newest.
After finding the newest change, the data will be shared.

> [!NOTE]
> This has no affect on the data on the current node.
> If you want the data to be merged, call the `sync` function

```elixir
Database.Database.get_worker("worker1")
|> GenServer.call({:get, "topic", "key"})
```

### get_local

`get_local` will only retrive data from the current node.
Thus, this operation is significantly faster.

```elixir
Database.Database.get_worker("worker1")
|> GenServer.call({:get_local, "topic", "key"})
```

### put

`put` will store the data on the current node.
Data with the same key in the same topic will be overwritten, but the old data will be kept in the history.

```elixir
Database.Database.get_worker("worker1")
|> GenServer.call({:put, "topic", "key", "value"})
```

### put (With optimistic locking)

`put` with optimistic locking is similar to the normal put operation.
However, you can specify the expected current state and **only** if the expection matches with the data on the node, the new data will be stored.

> [!NOTE]
> In some cases you want the data to be expected on all nodes, this can currently only be somewhat archived by calling the `sync` function before

```elixir
Database.Database.get_worker("worker1")
|> GenServer.call({:put, "topic", "key", "currentValue", "newValue"})
```

### sync

`sync` will merge the data from all neighbors.
The data with the newest timestamp is considered the current state.

```elixir
Database.Database.get_worker("worker1")
|> GenServer.call({:sync, "topic"})
```
