var drawGraphs = function(data) {
  drawTotalCallsGraph(JSON.parse(data.results.total_calls), '#callsChart');
  drawLineGraph(JSON.parse(data.results.jitter), {'target': '#jitterChart', 'xAxis': 'Time', 'yAxis': 'Jitter'});
  drawLineGraph(JSON.parse(data.results.packet_loss), {'target': '#packetLossChart', 'xAxis': 'Time', 'yAxis': 'Packet Loss'});
  drawLineGraph(JSON.parse(data.results.call_rate), {'target': '#callRateChart', 'xAxis': 'Time', 'yAxis': 'Calls'});
  drawLineGraph(JSON.parse(data.results.target_resources), {'target': '#targetResourcesChart', 'xAxis': 'Time', 'yAxis': 'Resources'});
}

var displayStats = function(data) {
  $('#totalCalls').html("").append(data.stats.total_calls);
  $('#successfulCalls').html("").append(data.stats.successful_calls);
  $('#failedCalls').html("").append(data.stats.failed_calls);
  $('#avgCallDuration').html("").append(data.stats.avg_call_duration);
  $('#avgCPS').html("").append(data.stats.avg_cps);
  $('#avgJitter').html("").append(data.stats.avg_jitter);
  $('#maxJitter').html("").append(data.stats.max_jitter);
  $('#avgPktLoss').html("").append(data.stats.avg_packet_loss);
  $('#maxPktLoss').html("").append(data.stats.max_packet_loss);
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
<<<<<<< HEAD
=======

var increaseCallRate = function(test_run_id) {
  if(test_run_id !== null) {
    var element = document.getElementById("tfield_call_rate");
    var current_call_rate = +(element.value) || 0;
    current_call_rate += 10;
    $.ajax({
      type: "POST",
      dataType: "json",
      url: "/test_runs/" + test_run_id + "/change_call_rate",
      data: { change: 10, current_call_rate: current_call_rate },
      success: function(data) {
        element.value = current_call_rate;
      },
      error: function() {
        //alert("failed to increase call rate!!")
      }
    })
  }
}

var decreaseCallRate = function(test_run_id) {
  if(test_run_id !== null) {
    var element = document.getElementById("tfield_call_rate");
    var current_call_rate = +(element.value) || 0;
    if(current_call_rate > 0){
      current_call_rate -= 10;
      $.ajax({
        type: "POST",
        dataType: "json",
        url: "/test_runs/" + test_run_id + "/change_call_rate",
        data: { change: -10, current_call_rate: current_call_rate },
        success: function(data) {
          element.value = current_call_rate;
        },
        error: function() {
          //alert("failed to increase call rate!!")
        }
      })
    }
  }
}
<<<<<<< HEAD
>>>>>>> add UI for Rampping (up/down)
=======

var submitCallRate = function(test_run_id) {
  if(test_run_id !== null) {
    var element = document.getElementById("tfield_call_rate");
    var current_call_rate = +(element.value) || 0;
    if(current_call_rate > 0){
      $.ajax({
        type: "POST",
        dataType: "json",
        url: "/test_runs/" + test_run_id + "/change_call_rate",
        data: { change: 0, current_call_rate: current_call_rate },
        success: function(data) {
          element.value = current_call_rate;
        },
        error: function() {
          //alert("failed to increase call rate!!")
        }
      })
    }
  }
}
>>>>>>> add a submit button for call rate
