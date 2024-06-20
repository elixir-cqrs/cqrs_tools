defmodule Blunt.Data.Factories.Factory do
  @moduledoc false

  alias IO.ANSI

  defmodule Error do
    defexception [:errors]

    def message(%{errors: errors}) do
      inspect(errors)
    end
  end

  @derive {Inspect, only: [:name, :message, :operation, :active_builder]}
  defstruct [
    :name,
    :message,
    :message_name,
    :final_message,
    :fields,
    :field_validations,
    :active_builder,
    :factory_module,
    operation: :build,
    input: %{},
    data: %{},
    values: [],
    builders: [],
    opts: []
  ]

  alias Blunt.Data.Factories.{Builder, InputConfiguration, Value, Values}

  def build(%__MODULE__{} = factory) do
    %{final_message: final_message} =
      factory
      |> normalize()
      |> init_builder()
      |> debug(:self)
      |> evaluate_values()
      |> build_final_message()
      |> debug(:final_message)

    final_message
  end

  defp init_builder(%{builders: builders, message: message} = factory) do
    case Enum.find(builders, & &1.recognizes?(message)) do
      nil ->
        raise Builder.NoBuilderError, message: "no builder found for '#{inspect(message)}'"

      active_builder ->
        fields = active_builder.message_fields(message)
        field_validations = active_builder.field_validations(message)

        %{
          factory
          | fields: fields,
            active_builder: active_builder,
            field_validations: field_validations
        }
    end
  end

  defp build_final_message(
         %{
           data: data,
           message: message,
           operation: operation,
           active_builder: builder,
           factory_module: factory_module
         } = factory
       ) do
    final_message =
      case builder.build(message, data) do
        {:ok, final_message} -> final_message
        final_message -> final_message
      end

    final_message =
      case operation do
        :build ->
          final_message

        :builder_dispatch ->
          builder.dispatch(final_message)

        operation ->
          case apply(factory_module, operation, [final_message]) do
            {:ok, result} -> result
            other -> other
          end
      end

    %{factory | final_message: final_message}
  end

  defp normalize(%{name: name, message: message, input: input, data: data, opts: opts, values: values} = factory) do
    name = String.trim_trailing(to_string(name), "_factory")
    message_name = message |> Module.split() |> List.last() |> to_string()
    opts = Keyword.merge(opts, name: name, message_name: message_name)

    # put input declarations at the top of all values.
    {inputs, values} = Enum.split_with(values, &match?(%Values.Input{}, &1))

    # put defaults declarations after input declarations
    {defaults, values} = Enum.split_with(values, &match?(%Values.Defaults{}, &1))

    # Allow turning on factory debug via input: %{debug_factory: true}
    default_debug = Keyword.get(opts, :debug, false)
    {debug, input} = Map.pop(input || %{}, :debug_factory, default_debug)
    opts = Keyword.put(opts, :debug, debug)

    %{
      factory
      | name: name,
        opts: opts,
        data: data || %{},
        message_name: message_name,
        values: inputs ++ defaults ++ values,
        input: InputConfiguration.configure(input)
    }
  end

  defp evaluate_values(%{input: input, values: values} = factory) do
    values = List.flatten(values)
    data = Enum.reduce(values, input, evaluate_value(factory))
    %{factory | data: data}
  end

  defp evaluate_value(factory) do
    fn value, data ->
      try do
        Value.evaluate(value, data, factory)
      rescue
        e -> raise Value.error(value, e, factory)
      end
    end
  end

  def log_value(%__MODULE__{opts: opts}, value, field, lazy, type) do
    if Keyword.get(opts, :debug, false) do
      field = ANSI.format([:blue, :bright, to_string(field)])
      type_prefix = if lazy, do: "lazy ", else: ""
      debug(value, "#{type_prefix}#{type} #{field}", opts)
    else
      value
    end
  end

  defp debug(%{opts: opts} = factory, :self) do
    if Keyword.get(opts, :debug, false) do
      label = ANSI.format([:green, "build"])
      debug(factory, label, opts)
    end

    factory
  end

  defp debug(%{final_message: final_message, opts: opts} = factory, :final_message) do
    if Keyword.get(opts, :debug, false) do
      label = ANSI.format([:green, "deliver"])

      final_message =
        cond do
          is_map(final_message) ->
            case Keyword.get(opts, :discarded_data, :hide) do
              value when value in [:hide, false] ->
                case Map.get(final_message, :discarded_data) do
                  nil ->
                    final_message

                  _ ->
                    Map.put(
                      final_message,
                      :discarded_data,
                      "configure the factory option 'discarded_data: true' to show"
                    )
                end

              _ ->
                final_message
            end

          true ->
            final_message
        end

      debug(final_message, label, opts)
    end

    factory
  end

  @colors [
    reset: [:reset, :yellow],
    atom: :cyan,
    string: :green,
    list: :default_color,
    boolean: :magenta,
    nil: :magenta,
    tuple: :default_color,
    binary: :default_color,
    map: :default_color
  ]

  defp debug(value, label, opts) do
    case Keyword.get(opts, :debug, false) do
      true ->
        name = Keyword.fetch!(opts, :name)
        message_name = Keyword.fetch!(opts, :message_name)

        title =
          ANSI.format([
            :blue,
            "blunt",
            " - ",
            :blue,
            name,
            :reset,
            " (",
            :light_black,
            message_name,
            ")"
          ])

        IO.inspect(value, label: "[#{title} #{label}]", syntax_colors: @colors)

      _ ->
        value
    end
  end

  def enable_debug(%__MODULE__{opts: opts} = factory) do
    %{factory | opts: [{:debug, true} | opts]}
  end
end
