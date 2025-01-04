defprotocol TelemetryUI.Web.Component do
  @moduledoc false
  def to_html(metric, assigns)
  def to_image(metric, assigns)
end
