defmodule ExJsonSchema.Validator.Error.BorutaFormatter do
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
end
