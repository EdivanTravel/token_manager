defmodule TokenManager.TokenReleaser do
  use GenServer
  alias TokenManager.Tokens
  alias TokenManager.Repo
  alias TokenManager.Tokens.Token

  # Inicializa o GenServer
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Agenda a liberação de um token após X segundos.
  """
  def schedule_release(token_id, delay_seconds) do
    Process.send_after(__MODULE__, {:release, token_id}, delay_seconds * 1000)
  end

  # Inicialização
  def init(state), do: {:ok, state}

  # Handler para liberação
  def handle_info({:release, token_id}, state) do
    case Repo.get(Token, token_id) do
      %Token{status: "active"} = token ->
        Tokens.release_token(token)
      _ -> :noop
    end
    {:noreply, state}
  end
end
