if Code.ensure_loaded?(ExMachina) and Code.ensure_loaded?(Faker) do
  defmodule Blunt.Testing.ExMachina.Factory do
    @moduledoc false
    @derive {Inspect, except: [:dispatch?]}
    defstruct [:message, values: [], dispatch?: false]

    defmodule Error do
      defexception [:errors]

      def message(%{errors: errors}) do
        inspect(errors)
      end
    end

    alias Blunt.Message
    alias Blunt.Message.Metadata

    alias Blunt.Testing.ExMachina.Values.{
      Constant,
      Lazy,
      Prop
    }

    def build(%__MODULE__{message: message, values: values, dispatch?: dispatch?} = factory, attrs, opts) do
      if Keyword.get(opts, :debug, false) do
        IO.inspect(factory)
      end

      data = Enum.reduce(values, attrs, &resolve_value/2)

      case Blunt.Behaviour.validate(message, Blunt.Message) do
        {:error, _} ->
          if function_exported?(message, :__struct__, 0) do
            struct!(message, data)
          else
            raise Error, errors: "#{inspect(message)} should be a struct to be used as a factory"
          end

        {:ok, message} ->
          data = populate_missing_props(data, message)

          final_message =
            case message.new(data) do
              {:ok, message, _discarded_data} ->
                message

              {:ok, message} ->
                message

              {:error, errors} ->
                raise Error, errors: errors

              message ->
                message
            end

          if dispatch?, do: dispatch(final_message, opts), else: final_message
      end
    end

    defp dispatch(%{__struct__: module} = message, opts) do
      unless Message.dispatchable?(message) do
        message
      else
        opts = Keyword.put(opts, :return, :response)

        case module.dispatch({:ok, message, %{}}, opts) do
          {:ok, value} -> value
          {:error, errors} -> raise Error, errors: errors
        end
      end
    end

    defp resolve_value(value, acc) do
      case value do
        %Constant{field: field, value: value} ->
          Map.put(acc, field, value)

        %Prop{field: field, value_path_or_func: path} when is_list(path) ->
          keys = Enum.map(path, &Access.key/1)
          value = get_in(acc, keys)
          Map.put(acc, field, value)

        %Prop{field: field, value_path_or_func: func} when is_function(func, 0) ->
          Map.put(acc, field, func.())

        %Prop{field: field, value_path_or_func: func} when is_function(func, 1) ->
          Map.put(acc, field, func.(acc))

        %Lazy{field: field, factory: factory} ->
          case Map.get(acc, field) do
            nil ->
              value = build(factory, acc, [])
              Map.put(acc, field, value)

            _value ->
              acc
          end
      end
    end

    defp populate_missing_props(attrs, message) do
      data =
        for {name, type, config} when not is_map_key(attrs, name) <- Metadata.fields(message), into: %{} do
          {name, fake(type, config)}
        end

      Map.merge(data, attrs)
    end

    def fake(type, config) do
      case type do
        {:array, type} -> [fake(type, config)]
        :id -> Enum.random(1..1000)
        :integer -> Enum.random(1..1000)
        :float -> Faker.Commerce.price()
        :decimal -> Faker.Commerce.price()
        :boolean -> Enum.random([true, false])
        :string -> Faker.Company.bullshit()
        :binary -> nil
        :map -> %{}
        :utc_datetime -> Faker.DateTime.between(~U[2000-01-01 00:00:00.000000Z], DateTime.utc_now())
        :utc_datetime_usec -> Faker.DateTime.between(~U[2000-01-01 00:00:00.000000Z], DateTime.utc_now())
        :naive_datetime -> Faker.DateTime.between(~N[2000-01-01 00:00:00.000000Z], NaiveDateTime.utc_now())
        :naive_datetime_usec -> Faker.DateTime.between(~N[2000-01-01 00:00:00.000000Z], NaiveDateTime.utc_now())
        :date -> Faker.Date.between(~D[2000-01-01], Date.utc_today())
        :time -> nil
        :time_usec -> nil
        :any -> Faker.Person.suffix()
        other -> other_fake(other, config)
      end
    end

    defp other_fake(binary_id, _config) when binary_id in [:binary_id, Ecto.UUID], do: UUID.uuid4()

    defp other_fake(enum, config) when enum in [:enum, Ecto.Enum] do
      values = Keyword.fetch!(config, :values)
      Enum.random(values)
    end
  end
end