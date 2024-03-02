defmodule HamsatWeb.CommonComponents do
  use Phoenix.Component

  attr :text, :string, required: true

  def mono_copy(assigns) do
    ~H"""
    <div class="text-sm border bg-gray-100 text-gray-700 px-2 py-1 flex items-center gap-4">
      <div class="flex-1 font-mono"><%= @text %></div>
      <div class="flex-shrink">
        <button phx-update="ignore" class="link" phx-hook="CopyToClipboard" id="copy-feed" data-copy={@text}>
          Copy
        </button>
      </div>
    </div>
    """
  end
end
