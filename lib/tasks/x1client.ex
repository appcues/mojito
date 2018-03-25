defmodule Mix.Tasks.X1client do
  use Mix.Task

  def run(["fetch-cacerts" | _]) do
    {_, 0} = System.cmd("curl", ["-so", "priv/cacerts.pem", "https://mkcert.org/generate/"])
    Mix.shell().info("Downloaded CA certificates to `priv/cacerts.pem`.")
  end

  def run(["make-test-certs" | _]) do
    cmd =
      "echo 'US\nMassachusetts\nBoston\nAppcues\nEngineering Department\nappcues.com\nteam@appcues.com' | openssl req -newkey rsa:2048 -nodes -keyout test/support/key.pem -x509 -days 36500 -out test/support/cert.pem 2>/dev/null"

    {_, 0} = System.cmd("bash", ["-c", cmd])
    Mix.shell().info("Created new certificates for HTTPS tests.")
  end

  def run([other | _]) do
    Mix.shell().error("no such command: #{other}")
    Mix.shell().info("Usage: mix x1client [fetch-cacerts | make-test-certs]")
  end
end
