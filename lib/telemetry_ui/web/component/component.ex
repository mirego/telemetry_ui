defprotocol TelemetryUI.Web.Component do
  def to_html(metric, assigns)
  def to_image(metric, extension, assigns)
end
