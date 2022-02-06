defmodule Cqrs.Message do
  alias Cqrs.Message.{Changeset, Contstructor, Dispatch, Field, Introspection, Option, Schema}

  @callback handle_validate(Changeset.t()) :: Changeset.t()
  @callback after_validate(struct()) :: struct()

  defmacro __using__(opts \\ []) do
    quote do
      dispatch? = Keyword.get(unquote(opts), :dispatch?, false)
      message_type = Keyword.get(unquote(opts), :message_type, :message)
      create_jason_encoders? = Cqrs.Message.create_jason_encoders?(unquote(opts))
      require_all_fields? = Keyword.get(unquote(opts), :require_all_fields?, false)

      Module.register_attribute(__MODULE__, :options, accumulate: true)
      Module.register_attribute(__MODULE__, :schema_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :required_fields, accumulate: true)

      Module.put_attribute(__MODULE__, :dispatch?, dispatch?)
      Module.put_attribute(__MODULE__, :message_type, message_type)
      Module.put_attribute(__MODULE__, :require_all_fields?, require_all_fields?)
      Module.put_attribute(__MODULE__, :create_jason_encoders?, create_jason_encoders?)

      import Cqrs.Message, only: [field: 2, field: 3, option: 2, option: 3]

      @behaviour Cqrs.Message
      @before_compile Cqrs.Message

      @impl true
      def handle_validate(changeset), do: changeset

      @impl true
      def after_validate(message), do: message

      defoverridable after_validate: 1
    end
  end

  defmacro __before_compile__(_env) do
    constructor =
      quote do
        Contstructor.generate(%{
          name: :new,
          has_fields?: Enum.count(@schema_fields) > 0,
          has_required_fields?: Enum.count(@required_fields) > 0
        })
      end

    quote location: :keep do
      require Cqrs.Message.{Changeset, Dispatch, Introspection, Schema}

      Module.eval_quoted(__MODULE__, unquote(constructor))

      Schema.generate()
      Changeset.generate()
      Introspection.generate()

      if @dispatch? do
        Dispatch.generate()
      end

      Module.delete_attribute(__MODULE__, :options)
      Module.delete_attribute(__MODULE__, :dispatch?)
      Module.delete_attribute(__MODULE__, :schema_fields)
      Module.delete_attribute(__MODULE__, :required_fields)
      Module.delete_attribute(__MODULE__, :require_all_fields?)
      Module.delete_attribute(__MODULE__, :create_jason_encoders?)
    end
  end

  @spec field(name :: atom(), type :: atom(), keyword()) :: any()
  defmacro field(name, type, opts \\ []),
    do: Field.record(name, type, opts)

  @spec option(name :: atom(), type :: any(), keyword()) :: any()
  defmacro option(name, type, opts \\ []) when is_atom(name) and is_list(opts),
    do: Option.record(name, type, opts)

  @doc false
  def create_jason_encoders?(opts) do
    explicit = Keyword.get(opts, :create_jason_encoders?, true)
    configured = Application.get_env(:cqrs_tools, :create_jason_encoders, true)

    explicit && configured
  end
end