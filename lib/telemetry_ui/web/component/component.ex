defprotocol TelemetryUI.Web.Component do
  def render(metric, assigns)
  def metric_data(metric, params)
end
