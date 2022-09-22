defprotocol TelemetryUI.Web.Component do
  def draw(component, assigns)
  def metric_data(component, metric, params)
end
