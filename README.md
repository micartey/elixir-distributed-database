# Eddb

<div align="center">
  <img src="https://img.shields.io/badge/Written%20in-elixir-%238238ab?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Hex.pm-eddb-%235764c9?style=for-the-badge" />
</div>

<br />

`eddb` is a distributed database for unstructured data

## Functions

### get

`get` will retrive the data from all neighbors and check which update is the newest.
Only the newest data will be returned.

> [!NOTE]
> This has no affect on the data on the current node.
> If you want the data to be merged, call the `sync` function

```elixir
Database.Database.get_worker("worker1")
|> GenServer.call({:get, "topic", "key"})
```

### get_local

`get_local` will only retrive the newest data from the current node.
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
> Contrary to the normal put operation will this operation check the expected data on all nodes and compare it with the newest data

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

### delete

`delete` will delete data **locally**.

A better solution would be setting the value to nil or any other placeholder value as the newer timestamp would make it the source-of-truth.

```elixir
Database.Database.get_worker("worker1")
|> GenServer.call({:delete, "topic", "key"})
```
