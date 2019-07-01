defmodule ExJsonSchema.Validator.Error.BorutaFormatter do
  @moduledoc false

  alias ExJsonSchema.Validator.Error

  @spec format(ExJsonSchema.Validator.errors()) :: [String.t()]
  def format(errors) do
    Enum.map(errors, fn %Error{error: error, path: path} ->
      format(error, path)
    end)
  end

  def format(%Error.Required{missing: [missing]}, path) do
    "Required property #{missing} is missing at #{path}."
  end
  def format(%Error.Required{missing: missing}, path) do
    "Required properties #{Enum.join(missing, ", ")} are missing at #{path}."
  end

  def format(%Error.Pattern{expected: expected}, path) do
    "#{path} do match required pattern /#{expected}/."
  end

  def format(%Error.Type{actual: actual, expected: expected}, path) do
    "The type at #{path} `#{actual}` do not match the required types #{inspect(expected)}."
  end
end
