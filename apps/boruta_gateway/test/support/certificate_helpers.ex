defmodule BorutaGateway.CertificateHelpers do
  @moduledoc false

  alias BorutaGateway.Certificate

  def regenerate_certificate!(root_ca) do
    paths = Certificate.paths()

    Enum.each([paths.certificate, paths.private_key], &File.rm/1)
    Certificate.ensure!(root_ca)
  end
end
