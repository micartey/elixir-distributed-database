default:
    @just --list

[group("build")]
build-release:
    MIX_ENV=prod mix release --overwrite

[group("build")]
start-release:
    JWT_SECRET=ahjsdjajdjkahkjdhasd _build/prod/rel/eddb/bin/eddb start

[group("build")]
start-remote:
    _build/prod/rel/eddb/bin/eddb remote

test:
    mix test

start:
    iex -S mix

start-node-a:
    iex --name node_a@127.0.0.1 -S mix

start-node-b:
    iex --name node_b@127.0.0.1 --eval "Node.connect(:'node_a@127.0.0.1')" -S mix

[group("hex")]
publish:
    mix hex.publish
