defmodule Blunt.Behaviour do
  @moduledoc false

  defmodule Error do
    defexception [:message]
  end

  @spec validate(atom, atom) :: {:error, String.t()} | {:ok, atom}

  def validate(module, behaviour_module) when is_atom(module) do
    error = "#{inspect(module)} is not a valid #{inspect(behaviour_module)}"

    case Code.ensure_compiled(module) do
      {:module, module} ->
        case has_all_callbacks?(module, behaviour_module) do
          true ->
            {:ok, module}

          {:error, missing_callbacks} ->
            missing = inspect(missing_callbacks)
            actual = module.__info__(:functions) |> inspect()
            error = "#{error}\nExpected: #{missing}\nGot: #{actual}"
            {:error, error}
        end

      _ ->
        {:error, error}
    end
  end

  def validate(_module, _behaviour_module) do
    {:error, :not_a_module}
  end

  @spec validate!(atom, atom) :: atom

  def validate!(module, behaviour_module) do
    case validate(module, behaviour_module) do
      {:ok, module} -> module
      {:error, error} -> raise Error, message: error
    end
  end

  def is_valid?(module, behaviour_module) do
    case validate(module, behaviour_module) do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp has_all_callbacks?(module, behaviour_module) do
    callbacks = behaviour_module.behaviour_info(:callbacks)
    optional_callbacks = behaviour_module.behaviour_info(:optional_callbacks) |> Keyword.keys()

    missing_callbacks =
      callbacks
      |> Enum.reject(fn {name, _arity} -> Enum.member?(optional_callbacks, name) end)
      |> Enum.reject(fn {name, arity} ->
        function_exported?(module, name, arity)
      end)

    case missing_callbacks do
      [] -> true
      missing_callbacks -> {:error, missing_callbacks}
    end
  end
end
