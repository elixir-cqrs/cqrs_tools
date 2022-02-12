defmodule Cqrs.Entity.Identity do
  @moduledoc false

  alias Cqrs.Entity.Error

  def pop(opts) do
    {identity, opts} =
      opts
      |> Keyword.update(:identity, {:id, Ecto.UUID, autogenerate: false}, &ensure/1)
      |> Keyword.pop!(:identity)

    {identity, opts}
  end

  def ensure({name, type}), do: {name, type, []}
  def ensure({name, type, config}), do: {name, type, config}

  def ensure(value) when value in [false, nil] do
    raise Error, message: "Entities require a primary key"
  end

  def ensure(_other) do
    raise Error, message: "identity must be either {name, type} or {name, type, options}"
  end
end