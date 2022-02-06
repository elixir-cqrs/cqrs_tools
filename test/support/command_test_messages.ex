defmodule Cqrs.CommandTest.Protocol do
  defmodule CommandOptions do
    use Cqrs.Command

    option :debug, :boolean, default: false
    option :audit, :boolean, default: true
  end

  defmodule DispatchNoHandler do
    use Cqrs.Command

    field :name, :string, required: true
    field :dog, :string, default: "maize"
  end

  defmodule CommandViaCommandMacro do
    use Cqrs

    defcommand do
      field :name, :string, required: true
      field :dog, :string, default: "maize"
    end
  end

  defmodule DispatchWithHandler do
    use Cqrs.Command

    field :name, :string, required: true
    field :dog, :string, default: "maize"

    option :reply_to, :pid, required: true
    option :error_at, :enum, values: [:before_dispatch, :handle_authorize, :handle_dispatch]
  end

  defmodule CommandWithEventDerivations do
    use Cqrs.Command

    field :name, :string, required: true
    field :dog, :string, default: "maize"

    derive_event DefaultEvent

    derive_event EventWithExtras do
      field :date, :date
    end

    derive_event EventWithDrops, drop: [:dog]

    derive_event EventWithExtrasAndDrops, drop: [:dog] do
      field :date, :date
    end

    @event_ns Cqrs.CommandTest.Events

    derive_event NamespacedEventWithExtrasAndDrops, drop: [:dog], ns: @event_ns do
      field :date, :date
    end
  end
end
