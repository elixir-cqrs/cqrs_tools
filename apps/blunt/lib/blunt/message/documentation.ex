defmodule Blunt.Message.Documentation do
  @moduledoc false
  alias Blunt.Config
  alias Blunt.Message.Documentation
  alias Blunt.Message.Documentation.{FieldAndOptionDocs, MetadataDocs}

  defstruct [:message_module, :moduledoc, :shortdoc, :fielddoc, :optiondoc, :metadatadoc]

  def make(module) do
    case Module.get_attribute(module, :moduledoc) do
      false ->
        %Documentation{}

      {line, shortdoc} ->
        do_make(module, {line, shortdoc})

      nil ->
        do_make(module, {1, ""})
    end
  end

  defp do_make(module, {line, shortdoc}) do
    options = Module.get_attribute(module, :options)
    metadata = Module.get_attribute(module, :metadata)
    schema_fields = Module.get_attribute(module, :schema_fields)

    metadatadoc = MetadataDocs.generate(metadata)
    fielddoc = FieldAndOptionDocs.field_docs(schema_fields)
    optiondoc = if options, do: FieldAndOptionDocs.option_docs(options), else: ""

    %Documentation{
      shortdoc: shortdoc,
      fielddoc: fielddoc,
      optiondoc: optiondoc,
      message_module: module,
      metadatadoc: metadatadoc,
      moduledoc: {line || 1, shortdoc <> fielddoc <> metadatadoc}
    }
  end

  def generate_module_doc(%{module: module}) do
    docs =
      module
      |> Documentation.make()
      |> output_markdown(module)

    Module.put_attribute(module, :moduledoc, docs.moduledoc)
    doc_functions(docs)
  end

  defp output_markdown(%{moduledoc: {_line, moduledoc}} = docs, module) do
    case Config.documentation_output() do
      false ->
        docs

      true ->
        File.write!("#{inspect(module)}.md", to_string(moduledoc))
        docs

      path when is_binary(path) ->
        File.mkdir_p(path)
        File.write!("#{path}/#{inspect(module)}.md", to_string(moduledoc))
        docs
    end
  end

  defp doc_functions(%{shortdoc: shortdoc, fielddoc: fielddoc, optiondoc: optiondoc, metadatadoc: metadatadoc}) do
    shortdoc = shortdoc || ""
    fielddoc = fielddoc || ""
    optiondoc = optiondoc || ""
    metadatadoc = metadatadoc || ""

    quote do
      def __doc__(:short), do: unquote(shortdoc)
      def __doc__(:field), do: unquote(fielddoc)
      def __doc__(:option), do: unquote(optiondoc)
      def __doc__(:metadata), do: unquote(metadatadoc)
    end
  end

  def generate_constructor_doc(module) do
    %{message_module: message_module, fielddoc: fielddoc} = Documentation.make(module)
    docs = "Safely constructs a `#{inspect(message_module)}`"
    docs <> "\n\n" <> fielddoc
  end

  defmacro generate_dispatch_doc do
    quote do
      %{message_module: message_module, optiondoc: optiondoc} = Documentation.make(__MODULE__)
      docs = "Dispatches a validated `#{inspect(message_module)}`"

      case Module.get_attribute(__MODULE__, :options) do
        nil -> docs
        options -> docs <> "\n\n" <> optiondoc
      end
    end
  end
end
