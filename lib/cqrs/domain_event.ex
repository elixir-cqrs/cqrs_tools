defmodule Cqrs.DomainEvent do
  defmacro __using__(opts) do
    quote do
      use Cqrs.Message,
          [require_all_fields?: false]
          |> Keyword.merge(unquote(opts))
          |> Keyword.put(:dispatch?, false)
          |> Keyword.put(:message_type, :event)

      @doc """
      Creates a `#{inspect(__MODULE__)}` event and unwraps it from the :ok tuple if successful`
      """
      @spec create(values :: Input.t(), overrides :: Input.t()) :: {:ok, struct()} | {:error, any()}
      def create(values, overrides \\ []) do
        with {:ok, event} <- new(values, overrides) do
          event
        end
      end
    end
  end
end