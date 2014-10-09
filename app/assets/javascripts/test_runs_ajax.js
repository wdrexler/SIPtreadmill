var drawGraphs = function(data) {
  drawTotalCallsGraph(JSON.parse(data.results.total_calls), '#callsChart');
  drawLineGraph(JSON.parse(data.results.jitter), {'target': '#jitterChart', 'xAxis': 'Time', 'yAxis': 'Jitter'});
  drawLineGraph(JSON.parse(data.results.packet_loss), {'target': '#packetLossChart', 'xAxis': 'Time', 'yAxis': 'Packet Loss'});
  drawLineGraph(JSON.parse(data.results.call_rate), {'target': '#callRateChart', 'xAxis': 'Time', 'yAxis': 'Calls'});
  drawLineGraph(JSON.parse(data.results.target_resources), {'target': '#targetResourcesChart', 'xAxis': 'Time', 'yAxis': 'Resources'});
}

var displayStats = function(data) {
  $('#totalCalls').append(data.stats.total_calls);
  $('#successfulCalls').append(data.stats.successful_calls);
  $('#failedCalls').append(data.stats.failed_calls);
  $('#avgCallDuration').append(data.stats.avg_call_duration);
  $('#avgCPS').append(data.stats.avg_cps);
  $('#avgJitter').append(data.stats.avg_jitter);
  $('#maxJitter').append(data.stats.max_jitter);
  $('#avgPktLoss').append(data.stats.avg_packet_loss);
  $('#maxPktLoss').append(data.stats.max_packet_loss);
}
var displayTestRunResults = function(data) {
  $("#inProgress").hide();
  $("#graphs").show();
  $("#stats").show();
  drawGraphs(data);
  displayStats(data);
}

var processTestRunResults = function(data) {
  $('#statusLabel > span').switchClass($('#statusLabel > span').attr('class').split(' ')[1], data.status_class);
  $('#statusLabel > span').html(data.status_display);
  if(data.status_display === "Complete" || data.status_display === "Errors" || data.status_display === "Warnings") {
    window.clearInterval(window.testRunInterval);
  }
  if(data.results == undefined || data.results == null) {
    return;
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
