var displayTestRunResults = function(data) {
  $("#inProgress").hide();
  $("#graphs").show();
  $("#stats").show();
  drawTotalCallsGraph(JSON.parse(data.results.total_calls), '#callsChart');
  drawLineGraph(JSON.parse(data.results.jitter), {'target': '#jitterChart', 'xAxis': 'Time', 'yAxis': 'Jitter'});
  drawLineGraph(JSON.parse(data.results.packet_loss), {'target': '#packetLossChart', 'xAxis': 'Time', 'yAxis': 'Packet Loss'});
  drawLineGraph(JSON.parse(data.results.call_rate), {'target': '#callRateChart', 'xAxis': 'Time', 'yAxis': 'Calls'});
  drawLineGraph(JSON.parse(data.results.target_resources), {'target': '#targetResourcesChart', 'xAxis': 'Time', 'yAxis': 'Resources'});
}

var processTestRunResults = function(data) {
  if(data.results == undefined || data.results == null) {
    window.testRunCD.update(+(new Date) + 10000);
    window.testRunCD.start();
  } else {
    displayTestRunResults(data);
  }
}

var refreshTestRun = function(test_run_id) {
  if(test_run_id !== null) {
    $.ajax({
      type: "GET",
      dataType: "json",
      url: "/test_runs/" + test_run_id + "/results.json",
      success: function(data) { processTestRunResults(data) }
    });
  }
}
